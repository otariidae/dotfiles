#!/usr/bin/env bash
# Recover a Bluetooth headset from Audio Gateway / HFP after reconnect.
set -euo pipefail

readonly SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
# shellcheck source=../lib/bt-a2dp-fix/common.sh
source "${SCRIPT_DIR}/../lib/bt-a2dp-fix/common.sh"

bt_a2dp_fix_load_config

readonly BT_A2DP_SINK_UUID="0000110b-0000-1000-8000-00805f9b34fb"
readonly BT_A2DP_SOURCE_UUID="0000110a-0000-1000-8000-00805f9b34fb"

bt_a2dp_fix_bluez_profile_call() {
  local method="$1"
  local uuid="$2"
  local output

  if output="$(
    busctl call \
      org.bluez \
      "$BT_DEVICE_PATH" \
      org.bluez.Device1 \
      "$method" \
      s \
      "$uuid" 2>&1
  )"; then
    return
  fi

  bt_a2dp_fix_log "$method failed: $output"
  return 1
}

bt_a2dp_fix_switch_bluez_to_a2dp_sink() {
  # A connected A2DP Source occupies the shared AVDTP session and makes the
  # desired Sink connection fail with "Device or resource busy".
  bt_a2dp_fix_bluez_profile_call DisconnectProfile "$BT_A2DP_SOURCE_UUID" || true
  sleep 1
  bt_a2dp_fix_bluez_profile_call ConnectProfile "$BT_A2DP_SINK_UUID"
}

bt_a2dp_fix_select_available_profile() {
  local profile

  for profile in "$BT_TARGET_PROFILE" "$BT_FALLBACK_PROFILE"; do
    if bt_a2dp_fix_has_profile "$profile"; then
      bt_a2dp_fix_set_profile "$profile"
      return
    fi
  done

  return 1
}

bt_a2dp_fix_wait_and_select_profile() {
  local _wait

  for _wait in $(seq 1 10); do
    if bt_a2dp_fix_select_available_profile; then
      return
    fi
    sleep 0.5
  done

  return 1
}

bt_a2dp_fix_finish_if_healthy() {
  local cur
  local sink

  cur="$(bt_a2dp_fix_card_profile)"
  if [[ "$cur" == "$BT_TARGET_PROFILE" || "$cur" == "$BT_FALLBACK_PROFILE" ]]; then
    if sink="$(bt_a2dp_fix_default_sink)" && [[ -n "$sink" ]]; then
      LC_ALL=C pactl set-default-sink "$sink" 2>/dev/null || true
    fi
    bt_a2dp_fix_log "ok profile=$cur"
    return
  fi

  return 1
}

bt_a2dp_fix_wait_for_healthy_profile() {
  local _wait

  for _wait in $(seq 1 10); do
    if bt_a2dp_fix_finish_if_healthy; then
      return
    fi
    sleep 0.5
  done

  return 1
}

bt_a2dp_fix_log "start (current=$(bt_a2dp_fix_card_profile))"

if bt_a2dp_fix_finish_if_healthy; then
  exit 0
fi

bt_a2dp_fix_set_profile off || true
sleep 2

if bt_a2dp_fix_select_available_profile &&
  bt_a2dp_fix_wait_for_healthy_profile; then
  exit 0
fi

bt_a2dp_fix_log "replacing A2DP source with sink profile"
if bt_a2dp_fix_switch_bluez_to_a2dp_sink &&
  bt_a2dp_fix_wait_and_select_profile &&
  bt_a2dp_fix_wait_for_healthy_profile; then
  exit 0
fi

bt_a2dp_fix_log "A2DP sink unavailable; reconnecting device"
bluetoothctl disconnect "$BT_MAC" >/dev/null 2>&1 || true
sleep 3
bluetoothctl connect "$BT_MAC" >/dev/null 2>&1 || true
sleep 2

if bt_a2dp_fix_finish_if_healthy; then
  exit 0
fi

bt_a2dp_fix_switch_bluez_to_a2dp_sink || true
if bt_a2dp_fix_wait_and_select_profile &&
  bt_a2dp_fix_wait_for_healthy_profile; then
  exit 0
fi

bt_a2dp_fix_log "failed after targeted recovery and one reconnect"
exit 1
