---
name: vm-scheduled-autostop
description: "The AWS dev VM's \"unexpected shutdowns\" are a scheduled ~10h EC2 auto-stop, not crashes"
metadata: 
  node_type: memory
  type: project
  originSessionId: 68fc3c1f-34d3-4da7-ba74-9dfc84e0efc7
---

The user's AWS cloud VM appears to "unexpectedly shut down," but it is not crashing. The shutdown logs
(`journalctl -b -1`, `last -x`) show clean `systemd-poweroff` sequences with no panic/OOM and no local
`shutdown`/cron/systemd-timer initiating them — the poweroff comes from the AWS side (EC2 Stop responding to
ACPI). Multiple boots have *exactly* 10:00 uptime, the tell of a scheduled cost-control auto-stop on Indeed dev
instances (~10 hours of uptime, or after-hours). Exact schedule source (instance-scheduler tag vs SSM/Lambda)
was not confirmed — user declined to dig further on 2026-07-15.

**Why:** User assumed a reliability bug on the box; it's an infra policy off-box. Debugging the OS is the wrong lever.

**How to apply:** Don't chase kernel/hardware crash causes. If work-loss is the worry, note that Claude Code
transcripts persist continuously, so nothing is lost — use [[claude-resume-command]] (`claude_resume`) to
reconstruct/resume open sessions after a stop. To keep it up, the fix is an AWS-side scheduler/tag exemption,
not an OS change.
