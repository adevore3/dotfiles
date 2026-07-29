# GitLab / `glab` API behaviour worth knowing

Every entry here was found by probing a **live GitLab instance**, not by reading docs, and each is recorded with the
evidence that revealed it. They were verified against a self-managed GitLab 18.x in July 2026; instance-specific details
(host, version) live in `~/.claude/gitlab.d/`. Re-probe an entry if results ever stop matching it.

The theme: **this API prefers a plausible answer over an error.** Almost every item below produces output that looks
correct.

## 1. `merged_after` / `merged_before` are silently ignored

The single most dangerous trap. On both the global and project-level merge request endpoints, these parameters are
accepted and **have no effect**:

```
$ glab api "merge_requests?scope=all&state=merged&merged_after=2030-01-01T00:00:00Z&author_username=someone"
# -> 20 results, all merged in 2026
```

GitLab ignores unrecognised query parameters rather than erroring, so a report built on `merged_after` looks fine and is
quietly wrong.

**What to do instead:** query with `updated_after`, which *is* honoured, then filter `merged_at` yourself.

The obvious justification for that over-fetch — "an MR merged in-window always has `updated_at >= merged_at`, so the
result is a complete superset" — is **false**. Of 1298 merged MRs sampled across one group, 66 had `updated_at`
*earlier* than `merged_at`, by up to 529 ms. An MR merged a fraction of a second after the window opened can therefore
be missed by an exact-boundary query. Subtract a small margin (60s is plenty) from the window start when building
`updated_after`; the extra rows get dropped by the local filter and the output doesn't change.

**Generalise this.** Any parameter you haven't personally confirmed may be doing nothing. Confirm one by passing an
absurd value and checking for zero rows.

## 2. Parameters that *are* honoured

Confirmed by passing an absurd future date and checking for zero rows:

| Parameter | Endpoint | Honoured |
|---|---|---|
| `updated_after` | merge requests | yes |
| `created_after` | merge requests | yes |
| `merged_after` | merge requests | **NO** |
| `target_branch` | merge requests | yes |
| `since` / `until` | repository commits | yes |
| `first_parent` | repository commits | yes |

## 2b. A nonexistent branch is not an error

Both of these return **HTTP 200 with `[]`**, not a 404:

```
projects/<id>/merge_requests?state=merged&target_branch=develop   -> []
projects/<id>/repository/commits?ref_name=develop                 -> []
```

So a typo'd or renamed branch produces a clean, warning-free, entirely believable "nothing here". Validate the ref with
`projects/:id/repository/branches/:name`, which *does* 404, before trusting an empty result.

For the same reason, prefer filtering `target_branch` locally over filtering it in the query: an MR merged into some
other branch can then be counted and reported rather than silently dropped. Real case — one repo merged three MRs into
`trino`, `snowflake` and `trino-snowflake`, branches that never merge into `main`, so a server-side filter made that work
permanently invisible.

## 3. The default branch is not always `main`

Plenty of repos still default to `master`. Hardcoding `main` returns an empty commit list with **no error**, which reads
as "nothing shipped". Always read `default_branch` from `GET /projects/:id`.

## 4. Commit timestamps carry per-commit UTC offsets

```
created_at = 2026-07-13T22:20:21.000-05:00
created_at = 2026-07-13T19:31:01.000-07:00
```

Two commits, two different offsets, because the offset comes from each author's machine. String-slicing the date, or
comparing naive datetimes, misplaces commits near window edges by up to a day. Always parse timezone-aware.

This also means a commit's `committed_date` and its MR's `merged_at` can look hours apart while describing the same
moment.

## 5. `glab api --paginate` emits concatenated JSON arrays

Not one merged array — `[...][...][...]`, one per page. A single `json.loads` fails with
`Extra data: line 1 column 290807`. Decode the stream in a loop with `JSONDecoder.raw_decode`, or pipe through
`jq -s 'add'` in the shell.

## 6. `glab` outside a git repo is unauthenticated

```
$ cd /tmp && glab api version
ERROR  Unauthenticated.
```

`glab` infers the host from the git remote of the current directory. With no remote it falls back to `gitlab.com`, where
there is no token — so this reads as a broken token when it's really a wrong host. Fix: pass `--hostname <host>`, and set
`GITLAB_HOST` too if you're shelling out repeatedly. This matters any time a script runs from whatever directory the user
happens to be in.

## 7. Group project listings include shared projects

`GET /groups/<group>/projects?include_subgroups=true` also returns projects *shared into* the group from another
namespace — e.g. an `other-namespace/external-repo-poc` showing up under a group it doesn't belong to. Keep only projects
whose `path_with_namespace` starts with the group prefix if you want "everything in this group" to mean what it looks
like.

## 8. Detecting merges that bypassed an MR

`first_parent=true` walks only the mainline, collapsing each MR merge into one entry. What remains on the mainline is
either an MR merge commit, an MR squash commit, or a direct push.

Attribution order:

1. Match against `merge_commit_sha`, `squash_commit_sha` and `sha` of the MRs you already fetched.
2. For anything left over, ask `GET /projects/:id/repository/commits/:sha/merge_requests` — this catches commits
   belonging to an MR merged *outside* your window.
3. Only if that returns no merged MR is it a genuine direct push.

Skipping step 2 over-reports direct pushes. Verified on a repo where the merge commit resolved to `!3 merged`, while a
`[Backstage] New repository created from template` root commit resolved to `[]` — correctly a direct push.

Consecutive direct pushes can be linked as a range: `{web_url}/-/compare/{first_parent_of_oldest}...{newest}`. A root
commit has no parent, so link the commit itself instead.

## 9. `glab api --field` silently drops a nested `position` object

Posting an inline (line-anchored) MR comment needs a nested `position` object. The bracketed form-field syntax does not
survive:

```bash
glab api --method POST ".../discussions" --field body=... --field 'position[new_line]=11'   # position is dropped
```

The request succeeds, the note is created, and `position` comes back **`null`** — it posted as a general MR comment. No
error, no warning. Send a JSON body with `--input` instead (recipe in `SKILL.md`), and re-fetch the note to confirm
`position.new_path` / `new_line` are set.

Same family as §1: the API discards what it doesn't recognise and returns success.
