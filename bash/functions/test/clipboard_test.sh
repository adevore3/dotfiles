#!/bin/bash

source "${DOTFILES}/bash/functions/log_utils.sh"
source "${DOTFILES}/bash/functions/test/test_utils.sh"
source "${DOTFILES}/bash/functions/clipboard/save_to_clipboard.func"
source "${DOTFILES}/bash/functions/clipboard/save_to_tmux_clipboard.func"
source "${DOTFILES}/bash/functions/clipboard/save_to_all_clipboards.func"

test_save_to_clipboard_help_flag() {
    local result=$(save_to_clipboard --help)
    assert_contains "SYNOPSIS" "$result" "save_to_clipboard --help should show usage"
}

test_save_to_tmux_clipboard_help_flag() {
    # Set TMUX vars to bypass the early tmux session check
    local TMUX="fake" TMUX_PANE="fake"
    local result=$(save_to_tmux_clipboard --help)
    assert_contains "SYNOPSIS" "$result" "save_to_tmux_clipboard --help should show usage"
}

test_save_to_all_clipboards_help_flag() {
    local result=$(save_to_all_clipboards --help)
    assert_contains "SYNOPSIS" "$result" "save_to_all_clipboards --help should show usage"
}

# --- _system_clipboard_command resolution ---
#
# Only one of pbcopy/wl-copy/xclip exists on any given host, so the other branches are unreachable in a plain
# unit test. These run the resolver under a synthetic PATH holding stub executables instead, which is the only
# way to assert the Linux ordering from a mac (and the macOS branch from Linux).
#
# PATH deliberately excludes the real bin dirs, so the resolver cannot see the host's actual clipboard tool.

# Echoes the resolver's output for a PATH containing exactly the named stub tools.
# Usage: resolve_with <wayland-display-value> <tool>...
resolve_with() {
    local wayland="$1"; shift
    local stub_bin tool result
    stub_bin="$(mktemp -d)"
    for tool in "$@"; do
        printf '#!/bin/sh\nexit 0\n' > "$stub_bin/$tool"
        chmod +x "$stub_bin/$tool"
    done
    # A subshell so the doctored PATH/WAYLAND_DISPLAY cannot leak into later assertions.
    result=$(
        PATH="$stub_bin" WAYLAND_DISPLAY="$wayland" \
            "$BASH" -c 'source "'"${DOTFILES}"'/bash/functions/clipboard/save_to_clipboard.func" >/dev/null 2>&1
                     _system_clipboard_command'
    )
    rm -rf "$stub_bin"
    echo "$result"
}

test_resolver_prefers_pbcopy() {
    # A mac with Homebrew xclip installed must still get the native tool.
    assert_equals "pbcopy" "$(resolve_with '' pbcopy xclip)" \
        "resolver prefers pbcopy over xclip"
    assert_equals "pbcopy" "$(resolve_with 'wayland-0' pbcopy wl-copy xclip)" \
        "resolver prefers pbcopy even inside a Wayland session"
}

test_resolver_prefers_wl_copy_in_wayland_session() {
    assert_equals "wl-copy" "$(resolve_with 'wayland-0' wl-copy xclip)" \
        "resolver prefers wl-copy over xclip when WAYLAND_DISPLAY is set"
}

test_resolver_falls_back_to_xclip_on_x11() {
    # wl-copy is commonly installed on X11 boxes, where it cannot connect to a compositor. Unset
    # WAYLAND_DISPLAY must therefore mean xclip, not wl-copy.
    assert_equals "xclip -selection c" "$(resolve_with '' wl-copy xclip)" \
        "resolver falls back to xclip when WAYLAND_DISPLAY is unset"
    assert_equals "xclip -selection c" "$(resolve_with '' xclip)" \
        "resolver returns xclip when it is the only tool"
}

test_resolver_last_resort_wl_copy() {
    # No WAYLAND_DISPLAY and no xclip: trying wl-copy beats reporting no clipboard at all.
    assert_equals "wl-copy" "$(resolve_with '' wl-copy)" \
        "resolver uses wl-copy as a last resort when xclip is absent"
}

test_resolver_empty_when_nothing_available() {
    assert_equals "" "$(resolve_with '' )" \
        "resolver prints nothing when no clipboard tool exists"
}

test_clipboard_write_word_splits_the_command() {
    # The resolver returns a command *string*, so clipboard_write must expand it unquoted. Quoted, bash would
    # hunt for one executable literally named "xclip -selection c". A stub that reports its own argv proves
    # which happened, and that stdin reaches it.
    local stub_bin result
    stub_bin="$(mktemp -d)"
    cat > "$stub_bin/xclip" <<'STUB'
#!/bin/sh
printf 'argv=[%s] ' "$@"
printf 'stdin=[%s]' "$(/bin/cat)"
STUB
    chmod +x "$stub_bin/xclip"
    result=$(
        printf 'payload' | PATH="$stub_bin:/bin" WAYLAND_DISPLAY="" \
            "$BASH" -c 'source "'"${DOTFILES}"'/bash/functions/clipboard/save_to_clipboard.func" >/dev/null 2>&1
                     clipboard_write'
    )
    rm -rf "$stub_bin"
    assert_equals "argv=[-selection] argv=[c] stdin=[payload]" "$result" \
        "clipboard_write word-splits the resolved command and passes stdin through"
}

test_clipboard_write_reads_file_arguments() {
    # `xclipf` used to be `xclip -sel clip`, which copies the contents of any FILE arguments; clipboard_write
    # has to keep that. It cannot just forward the arguments, because only xclip reads them as paths -- pbcopy
    # rejects file arguments outright and wl-copy would copy the *path text*. So cat has to do the reading.
    local stub_bin result file_a file_b
    stub_bin="$(mktemp -d)"
    cat > "$stub_bin/xclip" <<'STUB'
#!/bin/sh
printf 'stdin=[%s]' "$(/bin/cat)"
STUB
    chmod +x "$stub_bin/xclip"
    file_a="$stub_bin/a.txt"; printf 'alpha' > "$file_a"
    file_b="$stub_bin/b.txt"; printf 'beta' > "$file_b"
    result=$(
        PATH="$stub_bin:/bin" WAYLAND_DISPLAY="" \
            "$BASH" -c 'source "'"${DOTFILES}"'/bash/functions/clipboard/save_to_clipboard.func" >/dev/null 2>&1
                     clipboard_write "$1" "$2"' _ "$file_a" "$file_b" < /dev/null
    )
    rm -rf "$stub_bin"
    assert_equals "stdin=[alphabeta]" "$result" \
        "clipboard_write copies the contents of FILE arguments"
}

test_clipboard_write_reports_an_unreadable_file() {
    # The dangerous failure is a silent one: reading nothing, copying nothing, and still exiting 0 wipes the
    # clipboard while looking like it worked.
    local stub_bin output status
    stub_bin="$(mktemp -d)"
    printf '#!/bin/sh\nexit 0\n' > "$stub_bin/xclip"
    chmod +x "$stub_bin/xclip"
    output=$(
        PATH="$stub_bin:/bin" WAYLAND_DISPLAY="" \
            "$BASH" -c 'source "'"${DOTFILES}"'/bash/functions/clipboard/save_to_clipboard.func" >/dev/null 2>&1
                     clipboard_write "$1"' _ "$stub_bin/absent.txt" < /dev/null 2>&1
    )
    status=$?
    rm -rf "$stub_bin"
    assert_equals "1" "$status" "clipboard_write exits nonzero when a FILE argument cannot be read"
    assert_contains "absent.txt" "$output" "clipboard_write names the file it could not read"
}

test_clipboard_write_leaves_the_clipboard_alone_on_a_bad_file() {
    # The whole point of checking up front: a half-read `cat a.txt absent.txt | xclip` still copies "alpha"
    # over whatever was on the clipboard. The stub records that it ran at all, so the assertion is that the
    # clipboard tool was never reached.
    local stub_bin status file_a
    stub_bin="$(mktemp -d)"
    printf '#!/bin/sh\ntouch "%s/ran"\n' "$stub_bin" > "$stub_bin/xclip"
    chmod +x "$stub_bin/xclip"
    file_a="$stub_bin/a.txt"; printf 'alpha' > "$file_a"
    PATH="$stub_bin:/bin" WAYLAND_DISPLAY="" \
        "$BASH" -c 'source "'"${DOTFILES}"'/bash/functions/clipboard/save_to_clipboard.func" >/dev/null 2>&1
                 clipboard_write "$1" "$2"' _ "$file_a" "$stub_bin/absent.txt" < /dev/null > /dev/null 2>&1
    status=$?
    assert_equals "1" "$status" "clipboard_write fails when one of several files is unreadable"
    assert_equals "no" "$([ -e "$stub_bin/ran" ] && echo yes || echo no)" \
        "clipboard_write does not run the clipboard tool when a file is unreadable"
    rm -rf "$stub_bin"
}

test_clipboard_write_rejects_a_directory() {
    local stub_bin output status
    stub_bin="$(mktemp -d)"
    printf '#!/bin/sh\nexit 0\n' > "$stub_bin/xclip"
    chmod +x "$stub_bin/xclip"
    mkdir "$stub_bin/adir"
    output=$(
        PATH="$stub_bin:/bin" WAYLAND_DISPLAY="" \
            "$BASH" -c 'source "'"${DOTFILES}"'/bash/functions/clipboard/save_to_clipboard.func" >/dev/null 2>&1
                     clipboard_write "$1"' _ "$stub_bin/adir" < /dev/null 2>&1
    )
    status=$?
    rm -rf "$stub_bin"
    assert_equals "1" "$status" "clipboard_write exits nonzero on a directory argument"
    assert_contains "is a directory" "$output" "clipboard_write says why a directory was rejected"
}

test_save_to_clipboard_copies_and_prints_file_arguments() {
    # A bare `save_to_clipboard <file>` used to match nothing and return 0 having copied and printed nothing,
    # even though the SYNOPSIS advertises FILE arguments.
    local stub_bin result file_a
    stub_bin="$(mktemp -d)"
    cat > "$stub_bin/xclip" <<'STUB'
#!/bin/sh
printf 'clipboard=[%s]' "$(/bin/cat)" >> "$STUB_OUT"
STUB
    chmod +x "$stub_bin/xclip"
    file_a="$stub_bin/a.txt"; printf 'alpha' > "$file_a"
    result=$(
        STUB_OUT="$stub_bin/out" PATH="$stub_bin:/bin" WAYLAND_DISPLAY="" \
            "$BASH" -c 'source "'"${DOTFILES}"'/bash/functions/clipboard/save_to_clipboard.func" >/dev/null 2>&1
                     save_to_clipboard "$1"' _ "$file_a" < /dev/null
    )
    # The clipboard write happens in a process substitution, so it can still be in flight when tee exits
    local waited=0
    while [ ! -s "$stub_bin/out" ] && [ "$waited" -lt 50 ]; do sleep 0.1; waited=$((waited + 1)); done
    assert_equals "alpha" "$result" "save_to_clipboard prints the contents of a FILE argument"
    assert_equals "clipboard=[alpha]" "$(cat "$stub_bin/out" 2>/dev/null)" \
        "save_to_clipboard copies the contents of a FILE argument"
    rm -rf "$stub_bin"
}

test_save_to_clipboard_quiet_copies_file_arguments() {
    # -q with a file used to copy the empty string -- wiping the clipboard -- because it called
    # clipboard_write with no arguments and read an empty stdin instead.
    local stub_bin result file_a
    stub_bin="$(mktemp -d)"
    cat > "$stub_bin/xclip" <<'STUB'
#!/bin/sh
printf 'clipboard=[%s]' "$(/bin/cat)"
STUB
    chmod +x "$stub_bin/xclip"
    file_a="$stub_bin/a.txt"; printf 'alpha' > "$file_a"
    result=$(
        PATH="$stub_bin:/bin" WAYLAND_DISPLAY="" \
            "$BASH" -c 'source "'"${DOTFILES}"'/bash/functions/clipboard/save_to_clipboard.func" >/dev/null 2>&1
                     save_to_clipboard -q "$1"' _ "$file_a" < /dev/null
    )
    rm -rf "$stub_bin"
    assert_equals "clipboard=[alpha]" "$result" "save_to_clipboard -q copies the FILE argument, not empty stdin"
}

test_save_to_clipboard_still_reads_stdin() {
    # The restructured option loop must not disturb the no-argument path
    local stub_bin result
    stub_bin="$(mktemp -d)"
    cat > "$stub_bin/xclip" <<'STUB'
#!/bin/sh
printf 'clipboard=[%s]' "$(/bin/cat)" >> "$STUB_OUT"
STUB
    chmod +x "$stub_bin/xclip"
    result=$(
        printf 'payload' | STUB_OUT="$stub_bin/out" PATH="$stub_bin:/bin" WAYLAND_DISPLAY="" \
            "$BASH" -c 'source "'"${DOTFILES}"'/bash/functions/clipboard/save_to_clipboard.func" >/dev/null 2>&1
                     save_to_clipboard'
    )
    local waited=0
    while [ ! -s "$stub_bin/out" ] && [ "$waited" -lt 50 ]; do sleep 0.1; waited=$((waited + 1)); done
    assert_equals "payload" "$result" "save_to_clipboard still echoes stdin"
    assert_equals "clipboard=[payload]" "$(cat "$stub_bin/out" 2>/dev/null)" \
        "save_to_clipboard still copies stdin"
    rm -rf "$stub_bin"
}

test_clipboard_write_fails_without_a_clipboard() {
    local output status empty_bin
    empty_bin="$(mktemp -d)"
    output=$(printf x | PATH="$empty_bin" \
        "$BASH" -c 'source "'"${DOTFILES}"'/bash/functions/clipboard/save_to_clipboard.func" >/dev/null 2>&1
                 clipboard_write' 2>&1)
    status=$?
    rmdir "$empty_bin"
    assert_equals "1" "$status" "clipboard_write exits 1 when no clipboard tool exists"
    assert_contains "no clipboard command found" "$output" "clipboard_write warns when no clipboard tool exists"
}

test_save_to_clipboard_help_flag
test_save_to_tmux_clipboard_help_flag
test_save_to_all_clipboards_help_flag
test_resolver_prefers_pbcopy
test_resolver_prefers_wl_copy_in_wayland_session
test_resolver_falls_back_to_xclip_on_x11
test_resolver_last_resort_wl_copy
test_resolver_empty_when_nothing_available
test_clipboard_write_word_splits_the_command
test_clipboard_write_reads_file_arguments
test_clipboard_write_reports_an_unreadable_file
test_clipboard_write_leaves_the_clipboard_alone_on_a_bad_file
test_clipboard_write_rejects_a_directory
test_save_to_clipboard_copies_and_prints_file_arguments
test_save_to_clipboard_quiet_copies_file_arguments
test_save_to_clipboard_still_reads_stdin
test_clipboard_write_fails_without_a_clipboard

echo "All clipboard tests passed!"
