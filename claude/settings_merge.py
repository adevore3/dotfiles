#!/usr/bin/env python3
"""Merge tracked settings fragments into ~/.claude/settings.json without owning the file.

Three processes write that file: Claude Code itself (/config, /model, the auto-mode environment survey),
setup-ai4dp (its hooks, the marketplace registration, the plugins it installs), and this script. None of
them owns it. Each merges in the keys it declares and leaves the rest alone — so this script must never
write the file wholesale, and must never re-assert a preference the user changed in the UI.

A fragment is a JSON object with two optional blocks:

    {"merge": {...}, "seed": {...}}

  merge - keys this repo owns. Fragment wins on conflict, and an entry dropped from the fragment is
          removed from the live file on the next run (reconciled against the state file).
  seed  - keys applied only when absent from the live file. This is how harness-written preferences
          (theme, model, editorMode, permissions.defaultMode, ...) land on a fresh machine without
          ./install reverting whatever was last changed in /config.

See claude/specs/2026-10-12-claude-settings-fragments-design.md for the reasoning.
"""

import argparse
import json
import os
import sys
import tempfile
from pathlib import Path
from typing import Any

# Identity of a hooks[] group: the tuple of commands it runs. Each group we declare holds exactly one
# command, so this both dedupes our own entries and leaves anyone else's group untouched.
def _hook_identity(group: Any) -> Any:
    if isinstance(group, dict) and isinstance(group.get("hooks"), list):
        commands = tuple(h.get("command") for h in group["hooks"] if isinstance(h, dict))
        if any(c is not None for c in commands):
            return ("hook", group.get("matcher"), commands)
    return ("value", json.dumps(group, sort_keys=True))


def _union_lists(base: list, incoming: list) -> list:
    """Append items from incoming that base does not already hold, preserving base's order."""
    seen = {_hook_identity(item) for item in base}
    out = list(base)
    for item in incoming:
        key = _hook_identity(item)
        if key not in seen:
            seen.add(key)
            out.append(item)
    return out


def _deep_merge(base: Any, incoming: Any) -> Any:
    """Merge incoming over base. Dicts recurse, lists union, scalars are replaced."""
    if isinstance(base, dict) and isinstance(incoming, dict):
        out = dict(base)
        for key, value in incoming.items():
            out[key] = _deep_merge(out[key], value) if key in out else value
        return out
    if isinstance(base, list) and isinstance(incoming, list):
        return _union_lists(base, incoming)
    return incoming


def _seed(base: Any, incoming: Any) -> Any:
    """Like _deep_merge, but never replaces a value that is already present."""
    if isinstance(base, dict) and isinstance(incoming, dict):
        out = dict(base)
        for key, value in incoming.items():
            out[key] = _seed(out[key], value) if key in out else value
        return out
    return base


_MISSING = object()


def _withdraw(live: Any, applied: Any, desired: Any) -> Any:
    """Remove from `live` what we applied last time and no longer declare.

    Only entries recorded in `applied` are eligible, so a rule added by hand through /permissions is
    never deleted — without that record there is no way to tell a dropped fragment entry from a
    hand-added one, since both are simply "in live, not in the fragment".
    """
    if isinstance(applied, dict):
        if not isinstance(live, dict):
            return live
        out = dict(live)
        for key, applied_value in applied.items():
            if key not in out:
                continue
            sub_desired = desired.get(key, _MISSING) if isinstance(desired, dict) else _MISSING
            if sub_desired is _MISSING and not isinstance(applied_value, (dict, list)):
                # A scalar we applied and no longer declare: drop it, unless the user has changed it.
                if out[key] == applied_value:
                    del out[key]
                continue
            pruned = _withdraw(out[key], applied_value, {} if sub_desired is _MISSING else sub_desired)
            # An emptied container is noise in the settings file, so prune it rather than leave {} or [].
            if isinstance(pruned, (dict, list)) and not pruned:
                del out[key]
            else:
                out[key] = pruned
        return out

    if isinstance(applied, list):
        if not isinstance(live, list):
            return live
        keep = {_hook_identity(item) for item in (desired if isinstance(desired, list) else [])}
        drop = {_hook_identity(item) for item in applied} - keep
        return [item for item in live if _hook_identity(item) not in drop]

    return live


def merge(live: dict, fragments: list[dict], state: dict) -> tuple[dict, dict]:
    """Return (next_settings, next_state). Pure; all file IO lives in main()."""
    desired: dict = {}
    for fragment in fragments:
        desired = _deep_merge(desired, fragment.get("merge") or {})

    nxt = _withdraw(dict(live), state, desired)
    nxt = _deep_merge(nxt, desired)

    for fragment in fragments:
        nxt = _seed(nxt, fragment.get("seed") or {})

    return nxt, desired


# --- drift reporting -------------------------------------------------------------------------------
#
# The merge never removes something it did not apply, which is what protects a rule added by hand
# through /permissions. The cost is that such entries accumulate invisibly. Drift reporting is the
# other half: it names everything in the live file that no fragment accounts for, so it can be
# reconciled into one deliberately. It only ever reports — nothing here writes a fragment.

# Keys and hook commands owned by someone else. Reporting these would bury the real signal.
#   seed keys  - deliberately the user's, via /config
#   marketplace/plugins/hooks below - setup-ai4dp merges these in unattended
_FOREIGN_KEYS = frozenset({
    "extraKnownMarketplaces", "enabledPlugins", "theme", "model", "editorMode", "verbose",
    "autoCompactEnabled", "attribution", "statusLine", "skipAutoPermissionPrompt",
    "skipDangerousModePermissionPrompt", "effortLevel", "modelSettings", "fastMode",
})
_FOREIGN_HOOK_MARKERS = ("session-logging-hooks", "marketplace-instrumentation-hooks")

# Shapes that make an entry sensitive. Deliberately short; the default is private, so this list only
# needs to catch what is obviously sensitive, not everything that is.
_SENSITIVE = (
    r"\b\d{12}\b",                                   # AWS account id
    r"netrc|credentials|\.pem\b|secret|token|headers",  # credential material
    r"assume-role|_role\b|Role\b",                   # IAM / service roles
    r"tfstate|workspace|--profile",                  # deployment targets
)

# Rules safe to call public. This has to be an explicit list of tools, not a pattern: no shape
# distinguishes `Bash(npm test:*)` from `Bash(some-internal-wrapper deploy:*)` — both are lowercase
# words with a space — and that indistinguishability is exactly the uncertainty that must fall private.
# Add a tool here only when its name discloses nothing about where you work.
_GENERIC_TOOLS = frozenset({
    "ls", "cd", "cat", "head", "tail", "find", "grep", "rg", "jq", "git", "npm", "pytest",
    "./gradlew", "go", "make", "shellcheck", "python3", "python", "sed", "awk", "wc", "diff",
    "mkdir", "cp", "mv", "touch", "echo", "printf", "test", "which", "env", "node", "yarn", "pnpm",
})
_BARE_TOOLS = frozenset({"Read", "Glob", "Grep", "Edit", "Write"})


class Drift:
    """One live entry that no fragment accounts for."""

    def __init__(self, path: str, value: Any):
        self.path, self.value = path, value

    def __repr__(self) -> str:  # makes a failing assertion readable
        return f"Drift({self.path!r}, {self.value!r})"

    def __eq__(self, other: Any) -> bool:
        return isinstance(other, Drift) and (self.path, self.value) == (other.path, other.value)


def classify(value: Any) -> str:
    """Suggest which fragment an entry belongs in. Defaults to private when uncertain."""
    import re

    text = value if isinstance(value, str) else json.dumps(value)
    if any(re.search(p, text) for p in _SENSITIVE):
        return "private"
    if text in _BARE_TOOLS:
        return "public"
    # The tool name is everything up to the first colon, space, or closing paren: `Bash(ls:*)` -> `ls`,
    # `Bash(npm test:*)` -> `npm`, `Bash(./gradlew:*)` -> `./gradlew`.
    match = re.match(r"^Bash\(([^\s:)]+)", text)
    if match and match.group(1) in _GENERIC_TOOLS:
        return "public"
    return "private"


def _is_foreign_hook(group: Any) -> bool:
    if not isinstance(group, dict):
        return False
    commands = [h.get("command", "") for h in group.get("hooks", []) if isinstance(h, dict)]
    return any(marker in c for c in commands for marker in _FOREIGN_HOOK_MARKERS)


def drift(live: dict, states: list[dict]) -> list[Drift]:
    """Return live entries that no state file accounts for and no other writer owns."""
    accounted: dict = {}
    for state in states:
        accounted = _deep_merge(accounted, state)

    found: list[Drift] = []

    def walk(live_node: Any, known: Any, path: str) -> None:
        if isinstance(live_node, dict):
            for key, value in live_node.items():
                if not path and key in _FOREIGN_KEYS:
                    continue
                sub = known.get(key) if isinstance(known, dict) else None
                walk(value, sub, f"{path}.{key}" if path else key)
        elif isinstance(live_node, list):
            known_ids = {_hook_identity(i) for i in known} if isinstance(known, list) else set()
            for item in live_node:
                if _hook_identity(item) in known_ids or _is_foreign_hook(item):
                    continue
                found.append(Drift(path, item))

    walk(live, accounted, "")
    return found


def _load(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text() or "{}")
    except ValueError as exc:
        raise SystemExit(f"[ERROR] {path} is not valid JSON: {exc}")
    if not isinstance(data, dict):
        raise SystemExit(f"[ERROR] {path} does not hold a JSON object")
    return data


def _write_atomic(path: Path, data: dict) -> None:
    """Write via temp-file-plus-rename. Note this replaces a symlink at `path` with a real file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=f".{path.name}.")
    try:
        with os.fdopen(fd, "w") as fh:
            json.dump(data, fh, indent=2)
            fh.write("\n")
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise


def _report_drift(settings_path: Path, state_paths: list[Path]) -> int:
    """Print live entries no fragment accounts for. Always exits 0: this is a notice, not a failure."""
    found = drift(_load(settings_path), [_load(p) for p in state_paths if p.exists()])
    if not found:
        return 0

    print(f"\n[WARN] {len(found)} setting(s) in {settings_path} are not in any fragment.", file=sys.stderr)
    print("       A session or the UI added them, so ./install cannot reproduce them on another", file=sys.stderr)
    print("       machine and they are not under review. Move each into a fragment to adopt it,", file=sys.stderr)
    print("       or delete it from the settings file to drop it.", file=sys.stderr)
    print("       Suggested destination defaults to private: a wrong private guess costs nothing,", file=sys.stderr)
    print("       a wrong public one is permanent in git history. Confirm each one yourself.", file=sys.stderr)
    for item in found:
        text = item.value if isinstance(item.value, str) else json.dumps(item.value)
        print(f"       [{classify(item.value):>7}] {item.path}: {text[:100]}", file=sys.stderr)
    return 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Merge settings fragments into a Claude Code settings file.")
    ap.add_argument("fragments", nargs="*", help="fragment JSON files, applied in the order given")
    ap.add_argument("--settings", required=True, help="path to the live settings.json")
    ap.add_argument("--state", required=True, action="append",
                    help="applied-state file; repeat in --report-drift mode to cover every fragment set")
    ap.add_argument("--dry-run", action="store_true", help="report what would change, write nothing")
    ap.add_argument("--report-drift", action="store_true",
                    help="report live entries no fragment accounts for, and write nothing")
    args = ap.parse_args(argv)

    if args.report_drift:
        return _report_drift(Path(args.settings), [Path(p) for p in args.state])

    if len(args.state) != 1:
        raise SystemExit("[ERROR] --state may only be given once when merging")

    settings_path, state_path = Path(args.settings), Path(args.state[0])
    fragments = [_load(Path(p)) for p in args.fragments]
    if not fragments:
        return 0

    # A fragment blanked by accident must not wipe the live settings, so declaring nothing is treated as
    # a misconfiguration rather than as "remove everything". To retire a fragment, delete the file.
    if not any((f.get("merge") or f.get("seed")) for f in fragments):
        print(f"[ERROR] every fragment is empty; {settings_path} left unchanged", file=sys.stderr)
        return 1

    live, state = _load(settings_path), _load(state_path)
    nxt, next_state = merge(live=live, fragments=fragments, state=state)

    if not isinstance(nxt, dict):
        print(f"[ERROR] merge produced invalid settings; {settings_path} left unchanged", file=sys.stderr)
        return 1

    if nxt == live:
        print(f"[INFO] {settings_path} already current")
    elif args.dry_run:
        print(f"[INFO] would update {settings_path}")
    else:
        _write_atomic(settings_path, nxt)
        print(f"[INFO] merged {len(fragments)} fragment(s) into {settings_path}")

    if not args.dry_run:
        _write_atomic(state_path, next_state)
    return 0


if __name__ == "__main__":
    sys.exit(main())
