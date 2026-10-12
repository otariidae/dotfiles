# shellcheck shell=bash
# Shared helpers for gdrive-backup scripts.

gdrive_backup_log() {
  printf '%s\n' "$*" >&2
}

gdrive_backup_load_config() {
  local config_path="${GDRIVE_BACKUP_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/gdrive-backup/config}"

  if [[ ! -f "$config_path" ]]; then
    gdrive_backup_log "Missing config: $config_path"
    gdrive_backup_log "Run: bin/setup-gdrive-backup"
    return 1
  fi

  # shellcheck source=/dev/null
  source "$config_path"

  : "${GDRIVE_REMOTE:=gdrive}"
  : "${NAS_REMOTE:=nas}"
  : "${CRYPT_REMOTE:=nas-crypt}"
  : "${CRYPT_GDRIVE_PATH:=gdrive}"
  : "${CRYPT_TRASH_PREFIX:=gdrive-trash}"
  : "${MOUNT_POINT:=${HOME}/mnt/gdrive-backup}"
  : "${RCLONE_CHECKERS:=4}"
  : "${RCLONE_TRANSFERS:=4}"
}

gdrive_backup_require_rclone() {
  # systemd user units may lack login-shell PATH; prefer mise shims.
  export PATH="${HOME}/.local/share/mise/shims:${HOME}/.local/bin:${PATH}"
  if command -v rclone >/dev/null; then
    return
  fi
  local candidate
  candidate="$(ls -1d "${HOME}/.local/share/mise/installs/rclone/"*/rclone-*/rclone 2>/dev/null | sort -V | tail -1 || true)"
  if [[ -n "$candidate" && -x "$candidate" ]]; then
    export PATH="$(dirname "$candidate"):${PATH}"
  fi
  if ! command -v rclone >/dev/null; then
    gdrive_backup_log "rclone not found. Install with mise (see dot_config/mise/config.toml) and re-login, or: mise install"
    return 1
  fi
}

gdrive_backup_remote_env_prefix() {
  # nas-crypt -> NAS_CRYPT (rclone maps '-' to '_' in RCLONE_CONFIG_* names)
  printf '%s' "$1" | tr '[:lower:]' '[:upper:]' | tr '-' '_'
}

gdrive_backup_cred_path() {
  local name="$1"
  local cred_dir="${CREDENTIALS_DIRECTORY:-}"
  local store_dir="${XDG_CONFIG_HOME:-$HOME/.config}/credstore"

  if [[ -n "$cred_dir" && -d "$cred_dir" && -f "${cred_dir}/${name}" ]]; then
    printf '%s\n' "${cred_dir}/${name}"
  elif [[ -f "${store_dir}/${name}" ]]; then
    printf '%s\n' "${store_dir}/${name}"
  fi
}

gdrive_backup_read_cred() {
  local path="$1"
  local value
  if [[ -z "$path" || ! -f "$path" ]]; then
    return 1
  fi
  value="$(<"$path")"
  value="${value//$'\n'/}"
  printf '%s' "$value"
}

gdrive_backup_export_obscured() {
  local env_name="$1"
  local plain="$2"
  local obscured
  obscured="$(printf '%s' "$plain" | rclone obscure -)"
  export "${env_name}=${obscured}"
}

# Load secrets from systemd $CREDENTIALS_DIRECTORY (or ~/.config/credstore fallback).
# Files (plaintext, mode 600):
#   gdrive_client_id, gdrive_client_secret
#   nas_pass
#   nas_crypt_password, nas_crypt_password2
#
# Passwords use backend envs (RCLONE_SMB_PASS / RCLONE_CRYPT_PASSWORD*), not
# RCLONE_CONFIG_<remote>_*: hyphenated remotes like nas-crypt do not reliably
# match RCLONE_CONFIG_NAS_CRYPT_* (rclone#8668-class issues).
gdrive_backup_load_systemd_credentials() {
  local gdrive_prefix
  local path plain

  gdrive_prefix="$(gdrive_backup_remote_env_prefix "${GDRIVE_REMOTE:-gdrive}")"

  path="$(gdrive_backup_cred_path gdrive_client_id || true)"
  if plain="$(gdrive_backup_read_cred "$path" 2>/dev/null)"; then
    export "RCLONE_CONFIG_${gdrive_prefix}_CLIENT_ID=$plain"
  fi

  path="$(gdrive_backup_cred_path gdrive_client_secret || true)"
  if plain="$(gdrive_backup_read_cred "$path" 2>/dev/null)"; then
    export "RCLONE_CONFIG_${gdrive_prefix}_CLIENT_SECRET=$plain"
  fi

  path="$(gdrive_backup_cred_path nas_pass || true)"
  if plain="$(gdrive_backup_read_cred "$path" 2>/dev/null)"; then
    gdrive_backup_export_obscured RCLONE_SMB_PASS "$plain"
  fi

  path="$(gdrive_backup_cred_path nas_crypt_password || true)"
  if plain="$(gdrive_backup_read_cred "$path" 2>/dev/null)"; then
    gdrive_backup_export_obscured RCLONE_CRYPT_PASSWORD "$plain"
  fi

  path="$(gdrive_backup_cred_path nas_crypt_password2 || true)"
  if plain="$(gdrive_backup_read_cred "$path" 2>/dev/null)"; then
    gdrive_backup_export_obscured RCLONE_CRYPT_PASSWORD2 "$plain"
  fi
}

gdrive_backup_require_remote() {
  local name="$1"
  if ! rclone listremotes 2>/dev/null | grep -qx "${name}:"; then
    gdrive_backup_log "rclone remote '${name}' not found. Run: bin/setup-gdrive-backup"
    return 1
  fi
}
