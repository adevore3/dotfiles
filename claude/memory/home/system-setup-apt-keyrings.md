---
name: system-setup-apt-keyrings
description: "system-setup \"Add apt repository for Kubernetes\" failure is really stale GitHub CLI / Chrome keyrings; its own key refresh doesn't fix it"
metadata:
  node_type: memory
  type: project
  originSessionId: 689552e3-995f-4427-9cdb-66da7bdfe723
  modified: 2026-10-05T22:04:31.891Z
---

When `system-setup` fails at `common : Add apt repository for Kubernetes` with "Failed to update apt cache", the cause is
`NO_PUBKEY` on other repos (seen 2026-10-05: GitHub CLI `5612B36462313325`, Chrome subkey `FD533C07C264648F`). Run
`sudo apt-get update` to see which.

system-setup's "Updating and checking for missing GPG keys" step writes `/usr/share/keyrings/<keyid>.gpg` in keybox
format, which apt can't read, and no sources file references those paths. Fix: export them into the `signed-by=` path
from the `.list` file, e.g.
`gpg --no-default-keyring --keyring /usr/share/keyrings/<id>.gpg --export | sudo tee <signed-by path>`.

Also: system-setup must run in a real terminal, not via the `!` prefix (Ansible needs blocking stdio + sudo prompt).
Its `docker_prune` task has a 60s timeout; if it times out, pre-run the equivalent `docker * prune --filter
until=720h` by CLI.
