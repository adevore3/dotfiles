# Verified on Linux; the secrets split now has a test — 2026-08-04

Your handoff is deleted. Everything in it passes here: `make test` 32/32 before my change, `make lint` exit 0,
`ssh_agent_link_test.sh` 21/21 including your two tty-guard assertions. Nothing to correct.

Agreed on skipping the positive tty case. A portable pty test would have to branch on util-linux vs BSD `script`
inside the test, which is the trap this repo already documents, and every real terminal exercises that path.
Wrong trade.

## One gap: the secrets line shipped untested

`if [ -r ~/.localrc.secrets ]; then source ~/.localrc.secrets; fi` is one line, but it is the line standing
between a host's credentials and a tracked file being linked over them — and the failure mode is silent.
`bash/functions/test/localrc_secrets_test.sh`, 6 assertions, both lines sed'd out of `bashrc` like your blocks:

```
✓ neither file present is a silent no-op
✓ ~/.localrc alone is sourced
✓ ~/.localrc.secrets alone is sourced
✓ both files are sourced together
✓ ~/.localrc.secrets is sourced last, so a secret overrides a tracked default
✓ an unreadable ~/.localrc.secrets is skipped without an error
```

The ordering one is the reason it exists. If the two lines ever get swapped, a tracked `localrc_<host>` default
would win over a real secret and the variable would still be *set* — just wrong. Nothing would look broken.

The last one pins `-r` rather than `-f`: an unreadable secrets file has to be skipped, not sourced into a
"Permission denied" on every new shell.

Every case runs against a throwaway `HOME` with dummy values. The real `~/.localrc` is never read, on either
host. Suite is 33 files now.

## cloudvm migration: done

The user ran it in their own terminal, so none of it touched a transcript, and split it rather than moving the
file wholesale: `GLAB_TOKEN`, `SLACK_WEBHOOK_URL` and `NTFY_TOPIC` are in `~/.localrc.secrets` (mode 600), while
`~/.localrc` keeps only the non-secret `DEVOPSCLOUD_ROOT`. Confirmed all four are live in a fresh login shell,
checking set-ness rather than values.

So the blocker is gone — `bash/localrc_Linux` is safe to add now. One thing to carry if you do: `~/.localrc` is
still a *real file*, so adding a candidate filename displaces it to `~/.localrc.pre-dotfiles`, which would cost
`DEVOPSCLOUD_ROOT`. Put that export in the tracked file at the same time. CLAUDE.md says this.

## Nothing open from me either

Your `ps -o ucomm=` catch is the good kind of near-miss: right-padded to `"ssh-agent       "`, it would have
compared false forever and the reuse guard would have silently never fired. Worth the line it got in CLAUDE.md.

Delete this file once read.
