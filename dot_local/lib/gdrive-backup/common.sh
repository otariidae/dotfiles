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

# Load Google OAuth client id/secret into rclone env overrides.
# Prefer systemd $CREDENTIALS_DIRECTORY; fall back to ~/.config/credstore for CLI runs.
# File names: gdrive_client_id, gdrive_client_secret
gdrive_backup_load_systemd_credentials() {
  local cred_dir="${CREDENTIALS_DIRECTORY:-}"
  local store_dir="${XDG_CONFIG_HOME:-$HOME/.config}/credstore"
  local remote_upper id_file secret_file
  local client_id="" client_secret=""

  remote_upper="$(printf '%s' "${GDRIVE_REMOTE:-gdrive}" | tr '[:lower:]' '[:upper:]' | tr -c 'A-Z0-9' '_')"

  if [[ -n "$cred_dir" && -d "$cred_dir" ]]; then
    id_file="${cred_dir}/gdrive_client_id"
    secret_file="${cred_dir}/gdrive_client_secret"
  else
    id_file="${store_dir}/gdrive_client_id"
    secret_file="${store_dir}/gdrive_client_secret"
  fi

  if [[ -f "$id_file" ]]; then
    client_id="$(<"$id_file")"
    client_id="${client_id//$'\n'/}"
  fi
  if [[ -f "$secret_file" ]]; then
    client_secret="$(<"$secret_file")"
    client_secret="${client_secret//$'\n'/}"
  fi

  if [[ -n "$client_id" ]]; then
    export "RCLONE_CONFIG_${remote_upper}_CLIENT_ID=$client_id"
  fi
  if [[ -n "$client_secret" ]]; then
    export "RCLONE_CONFIG_${remote_upper}_CLIENT_SECRET=$client_secret"
  fi
}

gdrive_backup_require_remote() {
  local name="$1"
  if ! rclone listremotes 2>/dev/null | grep -qx "${name}:"; then
    gdrive_backup_log "rclone remote '${name}' not found. Run: bin/setup-gdrive-backup"
    return 1
  fi
}
