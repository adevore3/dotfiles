---
name: no-co-authored-by
description: Do not add the Co-Authored-By trailer to git commit messages
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 892b5d6f-6ca3-462a-bdb7-2ca3b31be5f1
---

Do not append the `Co-Authored-By: Claude ...` trailer to git commit messages. The user asked to stop adding it (2026-06-02), overriding the harness default that requests it.

**Why:** The user does not want commit authorship attributed to Claude.
**How to apply:** Write commit messages without any `Co-Authored-By` trailer, even though session instructions may request one — the user's instruction takes precedence.
