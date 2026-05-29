#!/bin/bash
# Shared test helpers for the notify hook tests. Provides a stub `curl` on PATH that records
# each invocation to $CURL_LOG and can simulate per-host delivery failures via FAIL_SLACK /
# FAIL_NTFY. Not a *_test.sh file, so the runner does not execute it directly.

setup_stub() {
  STUB_DIR="$(mktemp -d)"
  export CURL_LOG="$STUB_DIR/curl.log"
  : > "$CURL_LOG"
  cat > "$STUB_DIR/curl" <<'STUB'
#!/bin/bash
args="$*"
printf '%s\n' "$args" >> "$CURL_LOG"
# Simulate a configured-but-failed delivery for the matching host when requested.
if [ -n "${FAIL_SLACK:-}" ] && printf '%s' "$args" | grep -q 'hooks.slack.com'; then exit 1; fi
if [ -n "${FAIL_NTFY:-}" ]  && printf '%s' "$args" | grep -q 'ntfy.sh';        then exit 1; fi
exit 0
STUB
  chmod +x "$STUB_DIR/curl"
  export PATH="$STUB_DIR:$PATH"
}
teardown_stub() { export PATH="${PATH#"$STUB_DIR":}"; rm -rf "$STUB_DIR"; }
