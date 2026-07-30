---
name: gitlab
description: >-
  Driving GitLab through `glab` — reviewing and commenting on merge requests (prefer inline, line-anchored
  comments), replying in-thread, drafting MR descriptions, and querying the API without falling into its
  silent-failure traps. Use when reviewing, commenting on, or replying to a GitLab merge request, drafting an
  MR description, running `glab api` calls, or diagnosing a `glab` auth failure.
---

# Working with GitLab

## Instance context — read this first

Before your first `glab` call in a session, list `~/.claude/gitlab.d/`. If it holds files, **read them** — they carry
the host, auth details, and quirks for the GitLab instances this machine talks to.

If the directory is absent or empty, derive the host from the repo's git remote (`git remote -v`). **Never assume
`gitlab.com`** — `glab` will happily fall back to it and then fail as `Unauthenticated`, which reads like a broken token
rather than a wrong host.

## Voice

- Comments or replies directed at **other people** must use the `my-voice` skill so they read as Anton.
- MR **descriptions**, and replies to **CodeRabbit or any other AI/bot**, use your own voice, no `my-voice` needed.

**Why:** human-facing review conversation should sound like Anton; bot-facing and self-authored text doesn't need it.

Always draft the comment first and show it to Anton before posting; let him approve or edit.

## MR descriptions

State **what changed and why**, plus the verification/testing evidence. Keep out the author's open questions,
self-flagged debatable choices, and "reviewer, please look at X" invitations — a section like *"Two judgement calls
worth a look"* gets deleted. If something genuinely needs the reviewer's eyes, raise it as an inline comment on the
line it concerns.

**Why:** the description is the standing record of the change; a request for a second opinion is conversation, and it
belongs line-anchored where the reader can see the code it's about.

## Prefer inline comments

When feedback is specific to particular line(s) of code, post it as an **inline (line-anchored) discussion**, not a
general MR comment. General comments are for MR-wide points.

**Why:** an inline comment shows exactly which line it refers to, so the author doesn't have to guess.

## Always reply in the thread, not top-level

When responding to someone's comment (a reviewer's question, a CodeRabbit finding, a reply in an existing thread),
**always post into that comment's discussion thread**, not as a new top-level MR note. Only start a new top-level note
for a genuinely MR-wide point that isn't answering anyone.

**Why:** a top-level note is orphaned from the question it answers, the reader can't tell what it responds to, and it
breaks the back-and-forth. Reply in-thread whenever the target is a specific comment or discussion.

Reply to an existing discussion by POSTing to its `notes` sub-resource (get the `<discussion_id>` by fetching
`.../discussions`):

```bash
glab api --method POST "projects/<id>/merge_requests/<iid>/discussions/<discussion_id>/notes" \
  --header "Content-Type: application/json" --input /tmp/reply.json   # {"body": "..."}
```

- A general MR comment posted with `.../merge_requests/<iid>/notes` starts its OWN discussion; if you meant it as a
  reply, it lands orphaned. Use the `discussions/<discussion_id>/notes` form instead.
- Note the target thread may be a reviewer's *reply* to an earlier note (GitLab nests it under the discussion the
  original comment created, not under a new one), so resolve the `discussion_id` from the current `.../discussions`
  listing rather than assuming.
- Verify after posting: re-fetch the discussion and confirm your note is the last entry in that thread.

## Finding the project and MR from a URL

Anton usually pastes an MR link. Everything you need is in it:

```
https://<host>/<group>/<subgroup>/<repo>/-/merge_requests/577
        └host─┘└─── path_with_namespace ───┘                └ iid
```

URL-encode the whole namespace path as the project id — every `/` becomes `%2F`:

```bash
glab api "projects/<group>%2F<subgroup>%2F<repo>/merge_requests/577"
```

The numeric project id also works and is shorter for repeated calls; read it from `.id` on that response. Note the
**`iid`** (per-project, what the URL shows) is not the **`id`** (instance-wide); API paths under `projects/…` want the
`iid`.

## Creating an MR via glab

```bash
glab mr create --title "..." --description "$(cat /tmp/desc.md)" --no-editor --target-branch master
```

- There is **no `--description-file`** flag; it errors with `Unknown flag`. Inline the file with
  `--description "$(cat file.md)"` and pass `--no-editor` so it doesn't block on `$EDITOR`.
- `--remove-source-branch` is **accepted and ignored** — no error, and the created MR reads
  `"remove_source_branch": null`. Set it afterwards with a JSON PUT, then read back
  **`force_remove_source_branch`**, not the key you set (`references/api-gotchas.md` §10):

```bash
printf '{"remove_source_branch": true}' > /tmp/mr.json
glab api --method PUT "projects/<id>/merge_requests/<iid>" \
  --header "Content-Type: application/json" --input /tmp/mr.json
glab api "projects/<id>/merge_requests/<iid>" | jq '.force_remove_source_branch'   # expect true
```

## Posting an inline comment via glab

`glab api --field body=...` does NOT attach a `position` object — the bracketed `position[...]` form fields get
dropped and it silently posts as a general comment (see `references/api-gotchas.md` §9 for why). You MUST send a JSON
body via `--input`:

```bash
# 1. get diff refs (base_sha, start_sha, head_sha)
glab api "projects/<id>/merge_requests/<iid>" | jq '.diff_refs'

# 2. build the note body as JSON
cat > /tmp/note.json <<JSON
{
  "body": "your comment",
  "position": {
    "position_type": "text",
    "base_sha": "<base_sha>", "start_sha": "<start_sha>", "head_sha": "<head_sha>",
    "new_path": "path/to/File.scala", "old_path": "path/to/File.scala",
    "new_line": 11
  }
}
JSON

# 3. post it
glab api --method POST "projects/<id>/merge_requests/<iid>/discussions" \
  --header "Content-Type: application/json" --input /tmp/note.json
```

- Anchor on `new_line` for added/context lines; use `old_line` (or both) for removed lines.
- Delete a wrong note: `glab api --method DELETE "projects/<id>/merge_requests/<iid>/notes/<note_id>"`.
- Always verify after posting: re-fetch the discussion and confirm `position.new_path`/`new_line` are set.

## Rules that keep you honest

GitLab's API fails quietly far more often than it errors. Each of these has produced a confident, wrong answer in
practice:

- **GitLab silently drops query parameters it doesn't understand.** It does not error, so a filter that does nothing
  returns plausible, wrong results. Before trusting a parameter you haven't used before, pass an absurd value
  (a far-future date, a nonsense branch) and confirm you get zero rows. `merged_after` is the notorious one — see
  `references/api-gotchas.md` §1.
- **Read back after every write — and read back the *right* key.** The dropped-`position` bug above is the same failure
  family: the request returns 201 and the result is wrong. Re-fetch and assert the field you cared about actually
  landed, remembering the field that reflects a write isn't always the field you set — `remove_source_branch` shows up
  as `force_remove_source_branch` (§10), so checking the obvious key reports failure on a write that worked.
- **Prefer `--input` with JSON over `--field` for any non-trivial write.** `--field` can only express flat string
  values; nested objects and booleans are dropped silently and the call still succeeds — inline-comment `position`
  (§9) and `remove_source_branch` (§10) are the same bug.
- **An empty result is not evidence of nothing.** A typo'd or renamed branch returns `200 []`, not a 404, so a wrong
  ref produces a clean, believable "nothing here" (§2b). When an empty answer would be surprising, validate the ref
  itself with an endpoint that *does* 404.
- **Pre-flight `glab auth status`** before a batch of writes, and read the host it reports. Discovering an expired token
  halfway through posting a review means reconstructing what did and didn't land.
- **`glab` outside a git repo is unauthenticated** — it infers the host from the current directory's git remote and
  falls back to `gitlab.com`. Pass `--hostname <host>` (or set `GITLAB_HOST`) whenever the cwd isn't the target repo
  (§6).
- **Retry transient failures once or twice** before reporting them. Connection resets against these endpoints are
  common and not meaningful; a 403/404 will never succeed on retry, so don't retry those.
- **Never present a partial result as complete.** If a call failed or a page cap was hit, say which and why.

## Reference

`references/api-gotchas.md` — GitLab/`glab` API behaviour verified by probing a live instance, each entry with the
evidence that revealed it. Read it before hand-rolling a query whose result you intend to trust.
