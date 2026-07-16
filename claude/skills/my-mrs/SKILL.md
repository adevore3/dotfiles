---
name: my-mrs
description: >-
  How Anton wants MR/PR comments handled: prefer inline (line-anchored) comments for line-specific
  feedback, whose voice to use, and the glab recipe for posting inline. Use when reviewing, commenting
  on, or replying to a GitLab/GitHub merge request or pull request, or drafting an MR description.
---

# Working on merge requests

## Voice

- Comments or replies directed at **other people** must use the `my-voice` skill so they read as Anton.
- MR **descriptions**, and replies to **CodeRabbit or any other AI/bot**, use your own voice, no `my-voice` needed.

**Why:** human-facing review conversation should sound like Anton; bot-facing and self-authored text doesn't need it.

Always draft the comment first and show it to Anton before posting; let him approve or edit.

## Prefer inline comments

When feedback is specific to particular line(s) of code, post it as an **inline (line-anchored) discussion**, not a
general MR comment. General comments are for MR-wide points.

**Why:** an inline comment shows exactly which line it refers to, so the author doesn't have to guess.

## Posting an inline comment via glab

`glab api --field body=...` does NOT attach a `position` object, the bracketed `position[...]` form fields get
dropped and it silently posts as a general comment (verify: fetch the note back, `position` will be `null`). You MUST
send a JSON body via `--input`:

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
- Project id + MR iid: `glab api "projects/<group>%2F<repo>/merge_requests/<iid>"` (URL-encode the slash; the numeric
  project id also works, e.g. spark-hivesupport = 36256).
- Delete a wrong note: `glab api --method DELETE "projects/<id>/merge_requests/<iid>/notes/<note_id>"`.
- Always verify after posting: re-fetch the discussion and confirm `position.new_path`/`new_line` are set.
