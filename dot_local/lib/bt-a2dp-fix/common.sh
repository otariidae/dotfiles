# Shared helpers for bt-a2dp-fix scripts.
# shellcheck shell=bash

bt_a2dp_fix_config_path() {
  printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/bt-a2dp-fix/config"
}

bt_a2dp_fix_load_config() {
  local config
  config="$(bt_a2dp_fix_config_path)"
  if [[ ! -f "$config" ]]; then
    printf 'Missing config: %s\n' "$config" >&2
    printf 'Copy config.example and set BT_MAC, then re-run setup.\n' >&2
    return 1
  fi

  # shellcheck source=/dev/null
  source "$config"

  : "${BT_MAC:?BT_MAC must be set in config}"
  : "${BT_TARGET_PROFILE:=a2dp-sink-sbc_xq}"
  : "${BT_FALLBACK_PROFILE:=a2dp-sink-sbc}"
  : "${BT_POLL_INTERVAL:=3}"
  : "${BT_FIX_COOLDOWN:=20}"
  : "${BT_MAX_ATTEMPTS:=6}"
  : "${BT_LOG_TAG:=bt-a2dp-fix}"

  BT_CARD="bluez_card.${BT_MAC//:/_}"
  BT_SINK_PREFIX="bluez_output.${BT_MAC//:/_}"
}

bt_a2dp_fix_log() {
  logger -t "$BT_LOG_TAG" "$*"
}

bt_a2dp_fix_card_profile() {
  pactl list cards 2>/dev/null | awk -v card="$BT_CARD" '
    $0 ~ card { active = 1; next }
    active && /^カード #|^Card #/ { exit }
    active && (/有効なプロフィール:/ || /Active Profile:/) {
      sub(/^[^:]*:[ \t]+/, "")
      print
      exit
    }
  '
}

bt_a2dp_fix_has_profile() {
  local profile="$1"
  pactl list cards 2>/dev/null | awk -v card="$BT_CARD" -v profile="$profile" '
    $0 ~ card { active = 1; next }
    active && /^カード #|^Card #/ { exit }
    active && $1 == profile ":" { found = 1; exit }
    END { exit(found ? 0 : 1) }
  '
}

bt_a2dp_fix_is_a2dp_profile() {
  case "$1" in
    a2dp-sink|a2dp-sink-*|a2dp_sink|a2dp_sink_*) return 0 ;;
    *) return 1 ;;
  esac
}

bt_a2dp_fix_default_sink() {
  pactl list sinks short 2>/dev/null | awk -v prefix="$BT_SINK_PREFIX" '
    $2 ~ "^" prefix { print $2; exit }
  '
}

bt_a2dp_fix_set_profile() {
  pactl set-card-profile "$BT_CARD" "$1" 2>/dev/null
}
