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


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Merge settings fragments into a Claude Code settings file.")
    ap.add_argument("fragments", nargs="*", help="fragment JSON files, applied in the order given")
    ap.add_argument("--settings", required=True, help="path to the live settings.json")
    ap.add_argument("--state", required=True, help="path to the applied-state file")
    ap.add_argument("--dry-run", action="store_true", help="report what would change, write nothing")
    args = ap.parse_args(argv)

    settings_path, state_path = Path(args.settings), Path(args.state)
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
