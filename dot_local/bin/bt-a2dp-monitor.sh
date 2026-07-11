#!/usr/bin/env bash
# Poll a Bluetooth device and trigger bt-a2dp-fix when not on A2DP playback.
set -euo pipefail

readonly SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
# shellcheck source=../lib/bt-a2dp-fix/common.sh
source "${SCRIPT_DIR}/../lib/bt-a2dp-fix/common.sh"

bt_a2dp_fix_load_config

last_fix=0
connected_since=0

while true; do
  now="$(date +%s)"
  if LC_ALL=C bluetoothctl info "$BT_MAC" 2>/dev/null | grep -q 'Connected: yes'; then
    if (( connected_since == 0 )); then
      connected_since=$now
    fi

    prof="$(bt_a2dp_fix_card_profile)"
    needs_fix=false
    if [[ -n "$prof" ]]; then
      if ! bt_a2dp_fix_is_a2dp_profile "$prof"; then
        needs_fix=true
      fi
    elif (( now - connected_since >= BT_PROFILE_GRACE )); then
      needs_fix=true
    fi

    if "$needs_fix"; then
      if (( now - last_fix >= BT_FIX_COOLDOWN )); then
        last_fix=$now
        bt_a2dp_fix_log "trigger profile=${prof:-missing}"
        if ! systemctl --user start bt-a2dp-fix.service; then
          bt_a2dp_fix_log "recovery service failed"
        fi
      fi
    fi
  else
    connected_since=0
  fi
  sleep "$BT_POLL_INTERVAL"
done
