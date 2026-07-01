#!/usr/bin/env bash
# Poll a Bluetooth device and trigger bt-a2dp-fix when not on A2DP playback.
set -euo pipefail

readonly SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
# shellcheck source=../lib/bt-a2dp-fix/common.sh
source "${SCRIPT_DIR}/../lib/bt-a2dp-fix/common.sh"

bt_a2dp_fix_load_config

last_fix=0

while true; do
  if bluetoothctl info "$BT_MAC" 2>/dev/null | grep -q 'Connected: yes'; then
    prof="$(bt_a2dp_fix_card_profile)"
    if [[ -n "$prof" ]] && ! bt_a2dp_fix_is_a2dp_profile "$prof"; then
      now="$(date +%s)"
      if (( now - last_fix >= BT_FIX_COOLDOWN )); then
        last_fix=$now
        systemctl --user start bt-a2dp-fix.service
      fi
    fi
  fi
  sleep "$BT_POLL_INTERVAL"
done
