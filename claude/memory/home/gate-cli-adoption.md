---
name: gate-cli-adoption
description: gatecli (hiroshim/gate-cli) is a gap-filler only; Glean goes through mcpc OAuth, not gatecli, and both gatecli unsafe and mcpc are permission-gated
metadata:
  node_type: memory
  type: project
  originSessionId: 4b802d1d-a405-416e-bb8c-abab433d26fe
  modified: 2026-10-07T22:58:27.813Z
---

`gatecli` (code.corp.indeed.com/hiroshim/gate-cli, `uv tool install`) is installed on the cloudvm. Evaluated
2026-10-07 as a replacement for the existing auth plumbing; the decision was **gap-filler, not replacement**.

- **Adopted:** services with no working local alternative — Proctor, IQL, Trino, Backstage, ARC, Decryptor. The
  `indeed-global` skills for these assume `mcpc`, which is not installed here, so they were broken on this machine.
  IQL/Trino need only `kinit`.
- **Not adopted:** Jira/Confluence (would be a third copy of the Atlassian token alongside the netrc and acli
  config), Sourcegraph (duplicates the token in `~/src-config.json`), GitLab (the `gitlab` skill already encodes
  traps gatecli's passthrough does not handle). `lsc` has no gatecli equivalent.
- **Glean does NOT go through gatecli.** gatecli's Glean wants an admin-issued `GLEAN_API_TOKEN`, and
  `app.glean.com/admin/...` is admin-only, so that path is closed. The working route is per-user OAuth through
  `mcpc` (`npm install -g @apify/mcpc@latest`, then `mcpc login https://indeed-be.glean.com/mcp/default`),
  installed and verified 2026-10-07. Installing `mcpc` also unblocks `using-datadog`, `using-proctor` and
  `querying-iql`, which had the same missing dependency.
- **`TFE_TOKEN` is derived, not copied.** `~/.localrc` exports it from the existing
  `~/.terraform.d/credentials.tfrc.json` via `jq`, so there is one store and it survives `terraform login`
  refreshes. gatecli's `load_dotenv(override=False)` means the env var beats the empty `.env` entry.
- **No skill references gatecli.** Adoption is manual per request until a skill is written.

**Why the split:** gatecli's value is collapsing agent permissions to two rules, not capability. Where hardened
tooling and a documented skill already exist, routing through gatecli adds a credential copy and a layer without
removing one.

**The rule is load-bearing, and is now applied** (2026-10-07). `safe`/`unsafe` is enforced only by the permission
config — under `defaultMode: auto` with no gatecli entry, `gatecli unsafe …` sails through and the design is inert.
`~/.claude/settings.json` now carries `Bash(gatecli safe|help|status|stats:*)` in `permissions.allow`, and
`Bash(gatecli unsafe:*)` in **both** `permissions.ask` and `autoMode.soft_deny`. Keep both — `ask` alone may not
survive auto mode. See [[permission-rules-match-a-literal-prefix]]: an env-var prefix like
`GITLAB_HOST=… gatecli safe …` matches no rule at all, which is why glab's global default host was set to
`code.corp.indeed.com` instead of prefixing each call.

**`mcpc` is gated bare, and it has to be.** Glean's MCP endpoint bundles `Slack_MCP_slack_send_message`,
`Asana_MCP_Interactive_delete_task` and Zoom writes behind the same `mcpc` command prefix, and the catalog is
server-side — it changes without notice. A per-tool allowlist is expressible (`mcpc @glean tools-call search …`:
flags may follow the session token) but **not enforceable**: `mcpc --timeout 15 @glean tools-call …` puts a flag
first and matches nothing, and `using-glean` tells agents to pass `--timeout 15`. So `Bash(mcpc:*)` sits in both
`permissions.ask` and `autoMode.soft_deny`, and every mcpc call prompts including reads. Do not "optimise" this
into a narrower rule — it would look protective and not be.

**Upstream:** `hiroshim/gate-cli!16` fixes credential files created through the caller's umask, argv secrets written
verbatim to `audit.log`, and the test suite writing the developer's real audit log. Not merged as of 2026-10-07.
Until it merges, a fresh `gatecli init` or a new `audit.log` is created group/world-readable again.
