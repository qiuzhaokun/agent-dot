#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
( cd "$ROOT" && swift build --product dot-hook >/dev/null )
BIN="$ROOT/.build/debug/dot-hook"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export AGENTDOT_STATE_DIR="$TMP"

emit() {
  "$BIN" emit < "$1" > "$TMP/stdout" 2> "$TMP/stderr"
  test ! -s "$TMP/stdout" || { echo "stdout not empty for $1"; cat "$TMP/stdout"; exit 1; }
}

assert_state() {
  local expr="$1"
  jq -e "$expr" "$TMP/sessions/abc123.json" > /dev/null
}

assert_no_secret() {
  if grep -qE 'secret|tool_input|tool_response|last_assistant_message' "$TMP/sessions/abc123.json"; then
    echo "sensitive field leaked into session JSON"
    cat "$TMP/sessions/abc123.json"
    exit 1
  fi
}

emit "$ROOT/Tests/Fixtures/session_start.json"
assert_state '.state == "idle"'
emit "$ROOT/Tests/Fixtures/user_prompt_submit.json"
assert_state '.state == "running" and .turn_started_at != null'
emit "$ROOT/Tests/Fixtures/pre_tool_use.json"
assert_state '.state == "running" and .current_tool == "Bash"'
emit "$ROOT/Tests/Fixtures/permission_request.json"
assert_state '.state == "waiting_permission" and .waiting_since != null'
assert_no_secret
emit "$ROOT/Tests/Fixtures/pre_tool_use.json"
assert_state '.state == "waiting_permission" and .waiting_since != null'
emit "$ROOT/Tests/Fixtures/post_tool_use.json"
assert_state '.state == "running" and .waiting_since == null and .current_tool == null'
assert_no_secret
emit "$ROOT/Tests/Fixtures/stop.json"
assert_state '.state == "done" and .turn_ended_at != null'
assert_no_secret
emit "$ROOT/Tests/Fixtures/session_end.json"
assert_state '.state == "ended"'
emit "$ROOT/Tests/Fixtures/session_start_resume.json"
assert_state '.state == "idle" and .waiting_since == null'

# Deny branch
emit "$ROOT/Tests/Fixtures/session_start.json"
emit "$ROOT/Tests/Fixtures/permission_request.json"
emit "$ROOT/Tests/Fixtures/permission_denied.json"
assert_state '.state == "running" and .waiting_since == null'

# Unknown event and malformed JSON must not crash or write to stdout
"$BIN" emit < "$ROOT/Tests/Fixtures/unknown_event.json" > "$TMP/stdout" 2>&1
test ! -s "$TMP/stdout"
echo '{not json' | "$BIN" emit > "$TMP/stdout" 2>&1
test ! -s "$TMP/stdout"

echo "simulate OK"
