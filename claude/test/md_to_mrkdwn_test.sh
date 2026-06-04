#!/bin/bash
# Unit tests for md_to_mrkdwn (GitHub-Markdown -> Slack mrkdwn). Sources notify-lib.sh (HOME at a
# temp dir so a real ~/.claude/secrets.env can't leak in) and exercises the converter directly.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${DOTFILES:-$(cd "$DIR/../.." && pwd)}"
source "$ROOT/bash/functions/test/test_utils.sh"

TMP="$(mktemp -d)"
HOME="$TMP" source "$DIR/../hooks/notify-lib.sh"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 not available -> skipping md_to_mrkdwn tests"; rm -rf "$TMP"; exit 0
fi

assert_equals "*bold*"        "$(md_to_mrkdwn '**bold**')"          "** ** -> single-asterisk bold"
assert_equals "*bold*"        "$(md_to_mrkdwn '__bold__')"          "__ __ -> bold"
assert_equals "_italic_"      "$(md_to_mrkdwn '*italic*')"          "* * italic -> _ _"
assert_equals "_italic_"      "$(md_to_mrkdwn '_italic_')"          "_ _ italic preserved"
assert_equals "~gone~"        "$(md_to_mrkdwn '~~gone~~')"          "~~ ~~ -> single-tilde strike"
assert_equals "*Heading*"     "$(md_to_mrkdwn '## Heading')"        "heading -> bold line"
assert_equals "<https://x.io|site>" "$(md_to_mrkdwn '[site](https://x.io)')" "link -> <url|text>"
assert_equals "<https://img.io/a.png|alt>" "$(md_to_mrkdwn '![alt](https://img.io/a.png)')" "image -> <url|alt>"
assert_equals "• item"        "$(md_to_mrkdwn '- item')"            "dash bullet -> •"
assert_equals "• item"        "$(md_to_mrkdwn '* item')"            "star bullet -> •"

# Nested bullets keep their indentation via non-breaking spaces (Slack collapses plain leading
# spaces) and switch to a ◦ sub-bullet glyph.
nbsp=$' '
assert_equals "${nbsp}${nbsp}◦ nested" "$(md_to_mrkdwn '  - nested')" "2-space nested bullet -> 2 NBSP + ◦"
assert_equals "• top"         "$(md_to_mrkdwn '- top')"             "top-level bullet stays • with no pad"

# Bold inside a bullet (line-level + inline both apply).
assert_equals "• do *this*"   "$(md_to_mrkdwn '- do **this**')"     "bullet + bold combine"

# Inline code is left untouched — markers inside backticks must NOT be converted.
# shellcheck disable=SC2016  # literal backticks/markers are the point; no expansion wanted
assert_equals 'use `a**b` now' "$(md_to_mrkdwn 'use `a**b` now')"  "inline code is not mangled"

# Fenced code blocks pass through verbatim; the opening info string is dropped.
# shellcheck disable=SC2016  # literal markdown fence; no expansion wanted
fenced=$(printf '```python\nx = a**b  # **not bold**\n```')
out=$(md_to_mrkdwn "$fenced")
assert_contains 'x = a**b  # **not bold**' "$out" "fenced code content preserved verbatim"
assert_equals "0" "$(printf '%s' "$out" | grep -c 'python')" "fence info string (language) dropped"

# Numbered lists are left alone (Slack renders 1. fine).
assert_equals "1. first"      "$(md_to_mrkdwn '1. first')"          "numbered list preserved"

rm -rf "$TMP"
echo "All md_to_mrkdwn tests passed."
