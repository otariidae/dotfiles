#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
readonly FIX_SCRIPT="$REPO_ROOT/dot_local/bin/bt-a2dp-fix.sh"
readonly MONITOR_SCRIPT="$REPO_ROOT/dot_local/bin/bt-a2dp-monitor.sh"
readonly TEST_MAC="84:AC:60:30:CF:32"
readonly TARGET_PROFILE="a2dp-sink-sbc_xq"

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/bin" "$test_dir/config/bt-a2dp-fix"
export PATH="$test_dir/bin:$PATH"
export XDG_CONFIG_HOME="$test_dir/config"
export BT_TEST_LOG="$test_dir/commands.log"
export BT_TEST_STATE="$test_dir/profile"
export BT_TEST_CONNECTED="$test_dir/connected"
export BT_TEST_MODE=targeted_success

cat >"$test_dir/config/bt-a2dp-fix/config" <<EOF
BT_MAC='$TEST_MAC'
BT_ADAPTER='hci0'
BT_TARGET_PROFILE='$TARGET_PROFILE'
BT_FALLBACK_PROFILE='a2dp-sink-sbc'
BT_PROFILE_GRACE=0
BT_LOG_TAG='bt-a2dp-fix-test'
EOF

cat >"$test_dir/bin/mock-command" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

command_name="$(basename "$0")"
printf '%s %s\n' "$command_name" "$*" >>"$BT_TEST_LOG"

case "$command_name" in
  pactl)
    case "${1:-} ${2:-}" in
      "list cards")
        profile="$(<"$BT_TEST_STATE")"
        printf 'Card #1\n'
        printf '    Name: bluez_card.84_AC_60_30_CF_32\n'
        printf '    Profiles:\n'
        case "$profile" in
          a2dp-sink-sbc_xq|a2dp-sink-sbc)
            printf '        a2dp-sink-sbc_xq: Test profile\n'
            printf '        a2dp-sink-sbc: Test fallback\n'
            ;;
          audio-gateway)
            printf '        audio-gateway: Wrong direction\n'
            ;;
        esac
        printf '    Active Profile: %s\n' "$profile"
        ;;
      "list sinks")
        printf '1\tbluez_output.84_AC_60_30_CF_32.1\tmodule-bluez5-device.c\n'
        ;;
      "set-card-profile "*)
        printf '%s\n' "$3" >"$BT_TEST_STATE"
        ;;
      "set-default-sink "*)
        ;;
      *)
        printf 'Unexpected pactl arguments: %s\n' "$*" >&2
        exit 2
        ;;
    esac
    ;;
  busctl)
    case "${1:-}" in
      get-property)
        if [[ "$(<"$BT_TEST_CONNECTED")" == true ]]; then
          printf 'b true\n'
        else
          printf 'b false\n'
        fi
        ;;
      call)
        method="${5:-}"
        case "$method" in
          DisconnectProfile)
            ;;
          ConnectProfile)
            if [[ "$BT_TEST_MODE" == targeted_success ]]; then
              printf 'a2dp-sink-sbc_xq\n' >"$BT_TEST_STATE"
            else
              exit 1
            fi
            ;;
          *)
            printf 'Unexpected busctl method: %s\n' "$method" >&2
            exit 2
            ;;
        esac
        ;;
      *)
        printf 'Unexpected busctl arguments: %s\n' "$*" >&2
        exit 2
        ;;
    esac
    ;;
  bluetoothctl)
    case "${1:-}" in
      disconnect)
        printf 'false\n' >"$BT_TEST_CONNECTED"
        ;;
      connect)
        printf 'true\n' >"$BT_TEST_CONNECTED"
        if [[ "$BT_TEST_MODE" == reconnect_success ]]; then
          printf 'a2dp-sink-sbc_xq\n' >"$BT_TEST_STATE"
        else
          printf 'audio-gateway\n' >"$BT_TEST_STATE"
        fi
        ;;
    esac
    ;;
  systemctl)
    printf 'a2dp-sink-sbc_xq\n' >"$BT_TEST_STATE"
    ;;
  gdbus)
    printf "/org/bluez/hci0/dev_84_AC_60_30_CF_32: "
    printf "org.freedesktop.DBus.Properties.PropertiesChanged "
    printf "('org.bluez.Device1', {'Connected': <true>}, @as [])\n"
    ;;
  logger|sleep)
    ;;
  *)
    printf 'Unexpected mock command: %s\n' "$command_name" >&2
    exit 2
    ;;
esac
EOF
chmod +x "$test_dir/bin/mock-command"
for command_name in bluetoothctl busctl gdbus logger pactl sleep systemctl; do
  ln -s mock-command "$test_dir/bin/$command_name"
done

fail() {
  printf 'not ok - %s\n' "$*" >&2
  exit 1
}

assert_count() {
  local expected="$1"
  local pattern="$2"
  local actual

  actual="$(awk -v pattern="$pattern" '$0 ~ pattern { count++ } END { print count + 0 }' "$BT_TEST_LOG")"
  [[ "$actual" == "$expected" ]] ||
    fail "expected $expected matches for '$pattern', got $actual"
}

reset_case() {
  local profile="$1"
  local mode="$2"

  : >"$BT_TEST_LOG"
  printf '%s\n' "$profile" >"$BT_TEST_STATE"
  printf 'true\n' >"$BT_TEST_CONNECTED"
  export BT_TEST_MODE="$mode"
}

run_success_case() {
  local name="$1"

  "$FIX_SCRIPT" || fail "$name should succeed"
  printf 'ok - %s\n' "$name"
}

reset_case "$TARGET_PROFILE" targeted_success
run_success_case "healthy profile is a no-op"
assert_count 0 '^busctl call '
assert_count 0 '^bluetoothctl disconnect '

reset_case audio-gateway targeted_success
run_success_case "source profile is replaced without reconnect"
assert_count 1 'DisconnectProfile'
assert_count 1 'ConnectProfile'
assert_count 0 '^bluetoothctl disconnect '

reset_case audio-gateway reconnect_success
run_success_case "failed profile switch falls back to one reconnect"
assert_count 1 '^bluetoothctl disconnect '
assert_count 1 '^bluetoothctl connect '

reset_case audio-gateway fail
if "$FIX_SCRIPT"; then
  fail "complete recovery failure should return non-zero"
fi
assert_count 1 '^bluetoothctl disconnect '
assert_count 1 '^bluetoothctl connect '
printf 'ok - complete failure is bounded\n'

reset_case "$TARGET_PROFILE" targeted_success
"$MONITOR_SCRIPT" || fail "healthy monitor event should complete"
assert_count 0 '^systemctl '
printf 'ok - healthy connection events are suppressed\n'

reset_case audio-gateway targeted_success
"$MONITOR_SCRIPT" || fail "unhealthy monitor event should complete"
assert_count 1 '^systemctl '
printf 'ok - unhealthy connection triggers recovery once\n'

printf 'all bluetooth A2DP tests passed\n'
