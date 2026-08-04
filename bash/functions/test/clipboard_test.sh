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
test_clipboard_write_fails_without_a_clipboard

echo "All clipboard tests passed!"
