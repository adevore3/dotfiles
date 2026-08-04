#!/usr/bin/env bash

# Thin wrappers over the coreutils/BSD-utils calls whose flags differ between Linux and macOS. Every helper
# here exists because a GNU-only spelling had already broken this repo on Darwin; keep new platform branching
# in this file rather than inlined at the call site, so there is one place to look and one place to test.
#
# Feature-probed (`--version`, which only the GNU builds answer) rather than branched on `uname -s`: that way
# a macOS host with Homebrew coreutils ahead of /usr/bin on PATH takes the GNU path, which is what it has.

source "${DOTFILES}/bash/functions/log_utils.sh"

# True when `date` is GNU coreutils, i.e. supports `-d`. BSD date exits non-zero on --version.
function date_is_gnu() { date --version >/dev/null 2>&1; }

# True when `sed` is GNU coreutils, i.e. rejects an argument to -i.
function sed_is_gnu() { sed --version >/dev/null 2>&1; }

# True when `stat` is GNU coreutils, i.e. supports -c.
function stat_is_gnu() { stat --version >/dev/null 2>&1; }

# date_from_epoch [-u] <epoch> [<strftime-format>]
#
# Format a Unix epoch. GNU spells the input `-d @N`, BSD spells it `-r N`. The format is given without the
# leading `+` and may be omitted for date's own default output.
#
# Examples:
#   date_from_epoch 1678255821
#   date_from_epoch -u 1678255821 '%Y-%m-%d %H:%M:%S'
function date_from_epoch() {
  local utc="no"
  if [[ "${1:-}" == "-u" ]]; then
    utc="yes"
    shift
  fi

  local epoch="${1:-}"
  local format="${2:-}"

  if [ -z "$epoch" ]; then
    log_error "date_from_epoch: no epoch given"
    return 1
  fi

  # Tolerate the GNU `@`-prefixed spelling so call sites can pass either.
  epoch="${epoch#@}"

  local -a args=()
  [ "$utc" = "yes" ] && args+=("-u")
  if date_is_gnu; then
    args+=("-d" "@${epoch}")
  else
    args+=("-r" "${epoch}")
  fi
  [ -n "$format" ] && args+=("+${format}")

  date "${args[@]}"
}

# epoch_from_datetime <datetime>
#
# Parse a date/datetime string to a Unix epoch. GNU date takes almost anything via `-d`; BSD date has no `-d`
# at all and its `-j -f <fmt>` demands the exact input format up front, so the BSD path tries the formats this
# repo actually feeds it and fails loudly if none match.
#
# A trailing UTC offset is honored on both platforms. BSD's `%z` rejects the `±HH:MM` colon form that ISO-8601
# and `modify_partition` both use, so the offset is normalized to `±HHMM` before parsing.
#
# Examples:
#   epoch_from_datetime 2023-07-18T05:01:42.550
#   epoch_from_datetime "2023-01-01"
#   epoch_from_datetime 2026-01-01T00:00:00-06:00
function epoch_from_datetime() {
  local datetime="${1:-}"

  if [ -z "$datetime" ]; then
    log_error "epoch_from_datetime: no datetime given"
    return 1
  fi

  # A bare epoch passes straight through, so callers can accept either spelling from the user. Checked ahead of
  # the GNU branch on purpose, so both platforms agree. 10+ digits only: an epoch has had ten digits since
  # 2001, while a shorter all-digit string is a compact date (20230308) and must fall through to be parsed.
  if [[ "$datetime" =~ ^@[0-9]+$ ]] || [[ "$datetime" =~ ^[0-9]{10,}$ ]]; then
    echo "${datetime#@}"
    return 0
  fi

  local epoch
  if date_is_gnu; then
    # Swallow GNU date's own "invalid date" diagnostic and report the failure the same way the BSD path below
    # does. Otherwise the only observable difference between the two platforms is the wording on stderr, and a
    # caller (or a test) that greps for the wrapper's message passes on one host and fails on the other.
    if ! epoch=$(date -d "$datetime" +%s 2>/dev/null); then
      log_error "epoch_from_datetime: could not parse '$datetime'"
      return 1
    fi
    echo "$epoch"
    return 0
  fi

  # Split any trailing UTC offset off first, so stripping fractional seconds below cannot eat it —
  # `${x%%.*}` on 2026-01-01T00:00:00.550-06:00 would otherwise take the offset with the milliseconds.
  # Held in a variable, not inline: bash 3.2 treats a quoted =~ operand as a literal string.
  local base="$datetime" offset="" offset_fmt=""
  local offset_re='^(.*)(Z|[+-][0-9][0-9]:?[0-9][0-9])$'
  if [[ "$base" =~ $offset_re ]]; then
    base="${BASH_REMATCH[1]}"
    offset="${BASH_REMATCH[2]}"
    # BSD's %z accepts ±HHMM only; the colon form ISO-8601 uses is rejected outright. Z is just +0000.
    if [ "$offset" = "Z" ]; then
      offset="+0000"
    else
      offset="${offset//:/}"
    fi
    offset_fmt="%z"
  fi

  # Drop fractional seconds so one format string covers both 2023-07-18T05:01:42 and 2023-07-18T05:01:42.550.
  base="${base%%.*}"

  # A date with no time component: BSD date fills the missing fields from *now*, where GNU uses midnight.
  # Pad to midnight explicitly so both platforms agree.
  case "$base" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])  base="${base}T00:00:00" ;;
    [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9])    base="${base}000000" ;;
    *:*)                                         ;;
    *)                                           base="${base} 00:00:00" ;;
  esac

  local cleaned="${base}${offset}"

  local fmt out
  for fmt in \
    "%Y-%m-%dT%H:%M:%S" \
    "%Y-%m-%d %H:%M:%S" \
    "%Y-%m-%dT%H:%M" \
    "%Y-%m-%d %H:%M" \
    "%Y%m%d%H%M%S" \
    "%Y%m%d_%H%M%S" \
    "%b %d %Y %H:%M:%S" \
    "%b %d, %Y %H:%M:%S" \
    "%m/%d/%Y %H:%M:%S"
  do
    # stderr is folded into stdout and the result required to be bare digits, because BSD date accepts a
    # *partial* match: given a format that consumes only a prefix it prints "Warning: Ignoring N extraneous
    # characters", emits an epoch for the prefix alone, and still exits 0. That silently discarded a trailing
    # offset and returned a zone-dependent answer where GNU returned the right one, and accepted outright
    # garbage besides. A clean full parse prints nothing but the epoch.
    out=$(date -j -f "${fmt}${offset_fmt}" "$cleaned" +%s 2>&1) || continue
    [[ "$out" =~ ^-?[0-9]+$ ]] || continue
    echo "$out"
    return 0
  done

  log_error "epoch_from_datetime: could not parse '$datetime' with any known format"
  return 1
}

# utc_offset_colon [<epoch>] — the local UTC offset as ±HH:MM, i.e. GNU's `%:z`. Defaults to now.
#
# BSD date has no `%:z`: it emits the literal string ":z" and *exits 0*, so a call site asking for it gets
# corrupt output rather than an error. Built from `%z`, which both platforms spell the same way.
function utc_offset_colon() {
  local epoch="${1:-}"
  local raw

  if [ -n "$epoch" ]; then
    raw=$(date_from_epoch "$epoch" '%z') || return 1
  else
    raw=$(date +%z) || return 1
  fi

  if [[ ! "$raw" =~ ^[+-][0-9][0-9][0-9][0-9]$ ]]; then
    log_error "utc_offset_colon: unexpected %z output '$raw'"
    return 1
  fi

  printf '%s:%s\n' "${raw%??}" "${raw#???}"
}

# date_shift <datetime> <adjustment> [<strftime-format>]
#
# Shift a datetime by a calendar amount. The adjustment is "<sign><count> <unit>" — "+1 month", "-3 days",
# "+2y". The format is given without the leading `+` and may be omitted for date's own default output.
#
# Calendar arithmetic, not epoch arithmetic: a month is not a fixed number of seconds, so this deliberately is
# not epoch_from_datetime plus multiplication. GNU spells it `date -d "<datetime> + 1 month"`; BSD has no `-d`
# at all and spells the adjustment `-v+1m`, one letter per unit — note `m` is month there while `M` is minute,
# which is exactly the kind of thing to get wrong once. The BSD path resolves the base through
# epoch_from_datetime rather than repeating its `-j -f` format probing, then lets `-r` seed the clock that `-v`
# adjusts.
#
# One caveat worth knowing before relying on this: the platforms disagree on month-end overflow, starting at day
# 29. From 2026-01-29, GNU's "+1 month" normalizes forward into March while BSD's -v+1m clamps to the last day of
# February. Avoid month arithmetic on days 29–31, or pin the day yourself.
#
# The base may carry a trailing ±HH:MM offset on either platform; epoch_from_datetime normalizes it for BSD.
#
# Examples:
#   date_shift '2026-01-01T00:00:00' '+1 month' '%Y-%m-%dT%H:%M:%S'
#   date_shift "$start" '-3 days'
function date_shift() {
  local datetime="${1:-}"
  local adjustment="${2:-}"
  local format="${3:-}"

  if [ -z "$datetime" ] || [ -z "$adjustment" ]; then
    log_error "date_shift: usage: date_shift <datetime> <adjustment> [<strftime-format>]"
    return 1
  fi

  # Held in a variable, not inline: bash 3.2 treats a quoted =~ operand as a literal string.
  local adjustment_re='^([+-])([0-9]+)[[:space:]]*([A-Za-z]+)$'
  if [[ ! "$adjustment" =~ $adjustment_re ]]; then
    log_error "date_shift: cannot parse adjustment '$adjustment'; expected something like '+1 month' or '-3 days'"
    return 1
  fi
  local sign="${BASH_REMATCH[1]}"
  local count="${BASH_REMATCH[2]}"
  local unit="${BASH_REMATCH[3]}"

  # Normalize to a singular word GNU understands, and to BSD's single letter.
  local bsd_unit
  case "$(printf '%s' "$unit" | tr '[:upper:]' '[:lower:]')" in
    y|year|years)         unit=year;   bsd_unit=y ;;
    mon|month|months)     unit=month;  bsd_unit=m ;;
    w|week|weeks)         unit=week;   bsd_unit=w ;;
    d|day|days)           unit=day;    bsd_unit=d ;;
    h|hour|hours)         unit=hour;   bsd_unit=H ;;
    min|minute|minutes)   unit=minute; bsd_unit=M ;;
    s|sec|second|seconds) unit=second; bsd_unit=S ;;
    *)
      log_error "date_shift: unknown unit '$unit'; expected year, month, week, day, hour, minute or second"
      return 1
      ;;
  esac

  local -a args=()
  if date_is_gnu; then
    # Never hand GNU a signed count. Directly after a time, `+1` is parsed as a *timezone offset* rather than a
    # relative amount, so "<date> +1 month" silently becomes "<date> at +01:00, plus one month" and "<date> - 1
    # month" reads as -01:00 and then *adds* a month — the wrong direction, with no error. Unsigned plus GNU's
    # own `ago` keyword is unambiguous whether or not the base already carries an offset.
    if [ "$sign" = "-" ]; then
      args+=("-d" "$datetime $count $unit ago")
    else
      args+=("-d" "$datetime $count $unit")
    fi
  else
    local epoch
    epoch=$(epoch_from_datetime "$datetime") || return 1
    args+=("-j" "-v${sign}${count}${bsd_unit}" "-r" "$epoch")
  fi
  [ -n "$format" ] && args+=("+${format}")

  local shifted
  if ! shifted=$(date "${args[@]}" 2>/dev/null); then
    log_error "date_shift: could not shift '$datetime' by '$sign$count $unit'"
    return 1
  fi
  echo "$shifted"
}

# file_mtime_epoch <file> — modification time as a Unix epoch. GNU: `stat -c %Y`, BSD: `stat -f %m`.
function file_mtime_epoch() {
  local file="${1:-}"

  if [ -z "$file" ]; then
    log_error "file_mtime_epoch: no file given"
    return 1
  fi

  if stat_is_gnu; then
    stat -c %Y "$file"
  else
    stat -f %m "$file"
  fi
}

# sed_in_place <expression> <file>...
#
# Edit files in place. BSD sed requires an argument to -i (empty means "no backup") while GNU sed rejects a
# separate argument, so the two spellings cannot be shared. Always uses -E for extended regex: GNU's -r is
# not accepted by BSD, but both understand -E.
function sed_in_place() {
  local expression="${1:-}"
  shift

  if [ -z "$expression" ] || [ $# -eq 0 ]; then
    log_error "sed_in_place: usage: sed_in_place <expression> <file>..."
    return 1
  fi

  if sed_is_gnu; then
    sed -i -E "$expression" "$@"
  else
    sed -i '' -E "$expression" "$@"
  fi
}

# open_target <path-or-url> — hand a file or URL to the desktop's default handler.
#
# xdg-open is checked first on purpose: macOS has no xdg-open, while Linux may well have an unrelated `open`
# from util-linux that opens a virtual console.
function open_target() {
  local target="${1:-}"

  if [ -z "$target" ]; then
    log_error "open_target: no target given"
    return 1
  fi

  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$target" >/dev/null 2>&1
  elif command -v open >/dev/null 2>&1; then
    open "$target" >/dev/null 2>&1
  else
    log_error "open_target: neither xdg-open nor open is available"
    return 1
  fi
}

export -f date_is_gnu
export -f sed_is_gnu
export -f stat_is_gnu
export -f date_from_epoch
export -f epoch_from_datetime
export -f utc_offset_colon
export -f date_shift
export -f file_mtime_epoch
export -f sed_in_place
export -f open_target
