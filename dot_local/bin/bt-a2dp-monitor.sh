#!/usr/bin/env bash
# Trigger bt-a2dp-fix when BlueZ reports that the configured device connected.
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SCRIPT_PATH
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
readonly SCRIPT_DIR
# shellcheck source=../lib/bt-a2dp-fix/common.sh
source "${SCRIPT_DIR}/../lib/bt-a2dp-fix/common.sh"

bt_a2dp_fix_load_config

bt_a2dp_monitor_is_connected() {
  [[ "$(
    busctl get-property \
      org.bluez \
      "$BT_DEVICE_PATH" \
      org.bluez.Device1 \
      Connected 2>/dev/null
  )" == "b true" ]]
}

bt_a2dp_monitor_cooldown_until=0

bt_a2dp_monitor_trigger() {
  local reason="$1"
  local profile
  local now

  now="$(date +%s)"
  if ((now < bt_a2dp_monitor_cooldown_until)); then
    bt_a2dp_fix_log "suppress retrigger reason=$reason"
    return
  fi

  sleep "$BT_PROFILE_GRACE"
  if ! bt_a2dp_monitor_is_connected; then
    return
  fi

  profile="$(bt_a2dp_fix_card_profile)"
  if bt_a2dp_fix_is_a2dp_profile "$profile"; then
    return
  fi

  bt_a2dp_fix_log "trigger reason=$reason profile=${profile:-missing}"
  if ! systemctl --user start bt-a2dp-fix.service; then
    bt_a2dp_fix_log "recovery service failed"
  fi
  # The recovery connect emits another Connected signal. Acting on it
  # immediately starts a second disconnect cycle.
  bt_a2dp_monitor_cooldown_until="$(($(date +%s) + 20))"
}

if bt_a2dp_monitor_is_connected; then
  bt_a2dp_monitor_trigger startup
fi

bt_a2dp_fix_log "monitoring BlueZ connection events path=$BT_DEVICE_PATH"
while IFS= read -r event; do
  case "$event" in
    *org.bluez.Device1*"'Connected': <true>"*)
      bt_a2dp_monitor_trigger connected
      ;;
  esac
done < <(
  LC_ALL=C gdbus monitor \
    --system \
    --dest org.bluez \
    --object-path "$BT_DEVICE_PATH"
)
