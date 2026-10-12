#!/usr/bin/env bash
# Sync Google Drive to encrypted NAS (rclone crypt).
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SCRIPT_PATH
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
readonly SCRIPT_DIR
# shellcheck source=../lib/gdrive-backup/common.sh
source "${SCRIPT_DIR}/../lib/gdrive-backup/common.sh"

dry_run=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=1 ;;
    -h | --help)
      printf 'Usage: %s [--dry-run]\n' "$(basename "$0")"
      exit 0
      ;;
    *)
      gdrive_backup_log "Unknown argument: $arg"
      exit 2
      ;;
  esac
done

gdrive_backup_load_config
gdrive_backup_require_rclone
gdrive_backup_load_systemd_credentials
gdrive_backup_require_remote "$GDRIVE_REMOTE"
gdrive_backup_require_remote "$CRYPT_REMOTE"

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/gdrive-backup"
mkdir -p "$state_dir"
stamp="$(date +%Y%m%d)"
log_file="${state_dir}/backup-$(date +%Y%m%d-%H%M%S).log"

src="${GDRIVE_REMOTE}:"
dst="${CRYPT_REMOTE}:${CRYPT_GDRIVE_PATH}"
backup_dir="${CRYPT_REMOTE}:${CRYPT_TRASH_PREFIX}/${stamp}"

cmd=(
  rclone sync "$src" "$dst"
  --backup-dir="$backup_dir"
  --drive-skip-dangling-shortcuts
  --checkers="$RCLONE_CHECKERS"
  --transfers="$RCLONE_TRANSFERS"
  --log-file="$log_file"
  --log-level=INFO
  --stats=30s
  --stats-one-line
)

if [[ "$dry_run" -eq 1 ]]; then
  cmd+=(--dry-run)
  gdrive_backup_log "Dry-run: ${src} -> ${dst} (backup-dir ${backup_dir})"
else
  gdrive_backup_log "Syncing: ${src} -> ${dst} (backup-dir ${backup_dir})"
fi

"${cmd[@]}"
gdrive_backup_log "Done. Log: $log_file"
