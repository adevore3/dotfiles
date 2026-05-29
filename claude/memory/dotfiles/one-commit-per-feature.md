---
name: one-commit-per-feature
description: Squash a feature's WIP/fixup commits into a single commit before the user pushes
metadata:
  type: feedback
---

Deliver one commit per feature (or per cohesive set of features sharing a goal — judge by the goal, not by task count). Before handing off for push, squash the per-task and per-review-fixup commits that subagent-driven development produces into a single, well-described feature commit.

**Why:** The user wants clean, feature-level history, not the granular per-task/per-fix trail.

**How to apply:** When finishing a feature (the finishing-a-development-branch step), `git reset --soft <origin-base>` then make one feature commit. Only squash **unpushed** local commits — never rewrite already-pushed history (that caused a divergence/force-push earlier this project). Verify the squashed tree is identical to the pre-squash HEAD tree.
