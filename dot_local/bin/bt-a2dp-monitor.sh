#!/usr/bin/env bash
# Trigger bt-a2dp-fix when BlueZ reports that the configured device connected.
set -euo pipefail

readonly SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
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

bt_a2dp_monitor_trigger() {
  local reason="$1"

  sleep "$BT_PROFILE_GRACE"
  if ! bt_a2dp_monitor_is_connected; then
    return
  fi

  bt_a2dp_fix_log "trigger reason=$reason profile=$(bt_a2dp_fix_card_profile)"
  if ! systemctl --user start bt-a2dp-fix.service; then
    bt_a2dp_fix_log "recovery service failed"
  fi
}

if bt_a2dp_monitor_is_connected; then
  bt_a2dp_monitor_trigger startup
fi

bt_a2dp_fix_log "monitoring BlueZ connection events path=$BT_DEVICE_PATH"
LC_ALL=C gdbus monitor \
  --system \
  --dest org.bluez \
  --object-path "$BT_DEVICE_PATH" |
  while IFS= read -r event; do
    case "$event" in
      *org.bluez.Device1*"'Connected': <true>"*)
        bt_a2dp_monitor_trigger connected
        ;;
    esac
  done
