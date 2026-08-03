---
name: lsc
description: >-
  Querying Indeed's LSC (Large Scale Change) manager API — listing a change's jobs, pulling agent transcripts,
  and extracting structured blocks an agent emitted. Covers the Okta bearer-token setup that is easy to get
  wrong. Use when reading LSC batch results, diagnosing what an LSC-dispatched agent did, or scraping
  structured output across a fleet of repos.
---

# LSC manager API

`https://lsc-manager.sandbox.indeed.net/api/v1` — the orchestrator that runs one agent session per repo for a
batch migration. Everything here is read-only GET.

## Auth: the part that wastes an hour

The API validates an Okta **JWT access token**. Three distinct failure modes, each with its own error string:

| Server says | Means |
|---|---|
| `302` → `id.indeed.tech/oauth2/.../v1/authorize` | No `Authorization` header at all |
| `Jwt is not in the form of Header.Payload.Signature` | Not a JWT. A **refresh token** produces exactly this — it is opaque, ~1280 chars, zero dots. Refresh tokens go to `/token` to mint an access token; they are never sent as a bearer |
| `Jwt issuer is not configured` | Well-formed JWT from an authorization server this service doesn't trust |
| `Jwt is expired` | Tokens live ~1 hour |

**Getting a token that works:** browser DevTools → Network → any `/api/v1/…` request → Request Headers → copy
`Authorization`. That value comes from the app's own AS by construction, so the issuer matches. DevTools →
Application → Local Storage under an `okta-token-storage` key also works, but that's the raw token with no
`Bearer ` prefix.

**Storing it.** Never put a token in a command — tool calls are transcribed. Use a mode-600 header file and pass
it by path, which also keeps it out of `argv` and therefore out of `ps`:

```bash
# the user creates this in their OWN terminal, with an editor (not echo, which lands in shell history)
mkdir -p ~/.config/lsc && chmod 700 ~/.config/lsc
$EDITOR ~/.config/lsc/headers && chmod 600 ~/.config/lsc/headers
```

One line, exactly one `Bearer`:

```
Authorization: Bearer eyJ…
```

```bash
curl -sS -H @$HOME/.config/lsc/headers 'https://lsc-manager.sandbox.indeed.net/api/v1/...'
```

Never `-v`/`--trace` (they dump the header). Never `cat`/`grep` the file.

**Diagnosing a bad token without reading it.** Counts and non-secret claims only — a token's `iss`/`aud`/`exp`
are not the secret, the signature is:

```bash
# structure: exactly one Bearer, exactly 2 dots
grep -o 'Bearer' $F | wc -l ; tr -cd '.' < $F | wc -c
```

```python
# non-secret claims; never print the token
tok = open(F).read().strip().split('Bearer ', 1)[1].strip()
p = tok.split('.')[1]; p += '=' * (-len(p) % 4)
c = json.loads(base64.urlsafe_b64decode(p))
print(c.get('iss'), c.get('aud'), c.get('exp'))
```

## Preflight: check the token before any batch of work

Tokens last about an hour, so a long collection will die mid-run. Run this FIRST rather than discovering it on
request 40. It reports both the claimed expiry and a live probe, and prints nothing secret:

```bash
python3 - <<'EOF'
import base64, json, datetime, os, subprocess
F = os.path.expanduser(os.environ.get("LSC_HEADER_FILE", "~/.config/lsc/headers"))
tok = open(F).read().strip().split("Bearer ", 1)[1].strip()
p = tok.split(".")[1]; p += "=" * (-len(p) % 4)
c = json.loads(base64.urlsafe_b64decode(p))
mins = (datetime.datetime.fromtimestamp(c["exp"], datetime.timezone.utc)
        - datetime.datetime.now(datetime.timezone.utc)).total_seconds() / 60
code = subprocess.run(["curl","-sS","-o","/dev/null","-w","%{http_code}","-H",f"@{F}","--max-time","20",
    "https://lsc-manager.sandbox.indeed.net/api/v1/changes?page=0&size=1"], capture_output=True, text=True).stdout
print(f"claim exp : {'EXPIRED' if mins < 0 else f'{int(mins)} min left'}")
print(f"live probe: HTTP {code}  ->  {'OK' if code == '200' else 'NOT USABLE'}")
EOF
```

Check both lines, not just one. A valid `exp` with a non-200 means the token is well-formed but from the wrong
authorization server — see the error table below. Under ~10 minutes left, ask for a refresh before starting rather
than partway through.

## Endpoints

```
GET /changes/<change-id>/jobs?page=0&size=200
GET /changes/<change-id>/jobs/<job-id>/transcript?page=index
GET /changes/<change-id>/jobs/<job-id>/transcript?page=001
```

**`/jobs` returns JSON.** A paginated listing — `content[]`, `totalElements`, `lastPage`. Per job: `id`,
`repository`, `status`, `branchName`, `commitSha`, `steps[]`, `ciStatus`, `transcript`, `changeSummary`.

**`/transcript` returns HTML**, not JSON, despite the API path. A rendered viewer. Discover further pages by
grepping the index for `page=(\d{3})`.

## Two traps that will burn you

**`changeSummary` is not the transcript.** `transcript` in the jobs listing is a bare UUID pointer, and
`changeSummary.content` is a *separately generated LLM summary* with its own `sessionId`/`costUsd`/`generatedAt`.
It is lossy on exactly the things you want to scrape — it strips fenced blocks, delimiters, and literal headings.
If you are looking for structured output an agent emitted, **you must fetch the transcript**; concluding "the
agent never emitted it" from the summary is a category error.

**The repo name in a summary can be wrong.** At least one record's `changeSummary` self-declared a different repo
than its own `repository` field. Always key on `repository`.

## Extracting a structured block from a transcript

Agents are often prompted to emit a delimited block. Three things to handle:

1. **HTML entities and tags** — unescape, then strip tags.
2. **The prompt echo.** The transcript includes the prompt, so the block's *schema template* appears alongside
   any real answer. Filter on a placeholder string that only ever appears in the template.
3. **Duplicates.** The same block is served on both `?page=index` and `?page=NNN`. Dedupe on the serialized form.

```python
stripped = re.sub(r"<script.*?</script>|<style.*?</style>", "", page_html, flags=re.S)
for m in re.finditer(r"MARKER-BEGIN(.*?)MARKER-END", stripped, re.S):
    body = re.sub(r"<[^>]+>", "", html.unescape(m.group(1)))
    if TEMPLATE_PLACEHOLDER in body:
        continue
    obj = json.loads(re.search(r"\{.*\}", body, re.S).group(0))
```

Worked example: `images/spark` → `migrations/census/collect.py`.

## Pipeline behavior worth knowing

Steps run `clone → apply_prompts → commit → ci_wait → ci_fix`. Consequences:

- **LSC commits and pushes the worktree**, so a prompt telling the agent "do not commit" does not mean nothing
  gets committed. Anything left in the worktree — including a generated credential — can land on a branch.
- **`ci_fix` can revert the work.** If CI fails, that step may roll the migration back to get the branch green,
  leaving a near-empty diff on a job whose status still reads `SUCCESS`. A green job is not a migration.
- A job can fail at `commit` (no `commitSha`, no `ciStatus`) while the agent's own work succeeded.
