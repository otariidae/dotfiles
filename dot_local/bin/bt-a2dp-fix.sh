#!/usr/bin/env bash
# Recover a Bluetooth headset from Audio Gateway / HFP after reconnect.
set -euo pipefail

readonly SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
# shellcheck source=../lib/bt-a2dp-fix/common.sh
source "${SCRIPT_DIR}/../lib/bt-a2dp-fix/common.sh"

bt_a2dp_fix_load_config

bt_a2dp_fix_log "start (current=$(bt_a2dp_fix_card_profile))"

for _attempt in $(seq 1 "$BT_MAX_ATTEMPTS"); do
  cur="$(bt_a2dp_fix_card_profile)"
  if [[ "$cur" == "$BT_TARGET_PROFILE" || "$cur" == "$BT_FALLBACK_PROFILE" ]]; then
    if sink="$(bt_a2dp_fix_default_sink)"; [[ -n "$sink" ]]; then
      pactl set-default-sink "$sink" 2>/dev/null || true
    fi
    bt_a2dp_fix_log "ok profile=$cur"
    exit 0
  fi

  bt_a2dp_fix_set_profile off
  sleep 2

  if bt_a2dp_fix_has_profile "$BT_TARGET_PROFILE"; then
    bt_a2dp_fix_set_profile "$BT_TARGET_PROFILE"
    sleep 2
    continue
  fi
  if bt_a2dp_fix_has_profile "$BT_FALLBACK_PROFILE"; then
    bt_a2dp_fix_set_profile "$BT_FALLBACK_PROFILE"
    sleep 2
    continue
  fi

  bluetoothctl disconnect "$BT_MAC" >/dev/null 2>&1 || true
  sleep 3
  bluetoothctl connect "$BT_MAC" >/dev/null 2>&1 || true
  sleep 5
done

bt_a2dp_fix_log "failed after ${BT_MAX_ATTEMPTS} attempts"
exit 1
