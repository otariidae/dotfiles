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
  local candidate_dir
  candidate="$(
    find "${HOME}/.local/share/mise/installs/rclone" \
      -type f -path '*/rclone-*/rclone' 2>/dev/null \
      | sort -V \
      | tail -1 || true
  )"
  if [[ -n "$candidate" && -x "$candidate" ]]; then
    candidate_dir="$(dirname "$candidate")"
    export PATH="${candidate_dir}:${PATH}"
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

gdrive_backup_encrypted_cred_path() {
  local name="$1"
  printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/credstore.encrypted/${name}"
}

# Read a credential: prefer $CREDENTIALS_DIRECTORY (systemd unit), else decrypt
# the user-encrypted file with systemd-creds (manual / interactive runs).
gdrive_backup_read_cred_value() {
  local name="$1"
  local cred_dir="${CREDENTIALS_DIRECTORY:-}"
  local enc_path plain

  if [[ -n "$cred_dir" && -d "$cred_dir" && -f "${cred_dir}/${name}" ]]; then
    plain="$(<"${cred_dir}/${name}")"
    plain="${plain//$'\n'/}"
    printf '%s' "$plain"
    return 0
  fi

  enc_path="$(gdrive_backup_encrypted_cred_path "$name")"
  if [[ ! -f "$enc_path" ]]; then
    return 1
  fi
  if ! command -v systemd-creds >/dev/null; then
    gdrive_backup_log "Missing systemd-creds to decrypt ${enc_path}"
    return 1
  fi
  plain="$(systemd-creds decrypt --user "$enc_path" -)"
  plain="${plain//$'\n'/}"
  printf '%s' "$plain"
}

gdrive_backup_export_obscured() {
  local env_name="$1"
  local plain="$2"
  local obscured
  obscured="$(printf '%s' "$plain" | rclone obscure -)"
  export "${env_name}=${obscured}"
}

# Load secrets from systemd $CREDENTIALS_DIRECTORY or encrypted credstore.
# Names:
#   gdrive_client_id, gdrive_client_secret
#   nas_pass
#   nas_crypt_password, nas_crypt_password2
#
# Passwords use backend envs (RCLONE_SMB_PASS / RCLONE_CRYPT_PASSWORD*), not
# RCLONE_CONFIG_<remote>_*: hyphenated remotes like nas-crypt do not reliably
# match RCLONE_CONFIG_NAS_CRYPT_* (rclone#8668-class issues).
gdrive_backup_load_systemd_credentials() {
  local gdrive_prefix
  local plain

  gdrive_prefix="$(gdrive_backup_remote_env_prefix "${GDRIVE_REMOTE:-gdrive}")"

  if plain="$(gdrive_backup_read_cred_value gdrive_client_id 2>/dev/null)"; then
    export "RCLONE_CONFIG_${gdrive_prefix}_CLIENT_ID=$plain"
  fi

  if plain="$(gdrive_backup_read_cred_value gdrive_client_secret 2>/dev/null)"; then
    export "RCLONE_CONFIG_${gdrive_prefix}_CLIENT_SECRET=$plain"
  fi

  if plain="$(gdrive_backup_read_cred_value nas_pass 2>/dev/null)"; then
    gdrive_backup_export_obscured RCLONE_SMB_PASS "$plain"
  fi

  if plain="$(gdrive_backup_read_cred_value nas_crypt_password 2>/dev/null)"; then
    gdrive_backup_export_obscured RCLONE_CRYPT_PASSWORD "$plain"
  fi

  if plain="$(gdrive_backup_read_cred_value nas_crypt_password2 2>/dev/null)"; then
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
