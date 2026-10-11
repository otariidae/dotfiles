#!/usr/bin/env bash
# Mount the encrypted NAS Google Drive backup as a decrypted folder.
set -euo pipefail

readonly SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
# shellcheck source=../lib/gdrive-backup/common.sh
source "${SCRIPT_DIR}/../lib/gdrive-backup/common.sh"

gdrive_backup_load_config
gdrive_backup_require_rclone
gdrive_backup_require_remote "$CRYPT_REMOTE"

if ! command -v fusermount3 >/dev/null && ! command -v fusermount >/dev/null; then
  gdrive_backup_log "fusermount3/fusermount not found (install fuse3)"
  exit 1
fi

mkdir -p "$MOUNT_POINT"

if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
  gdrive_backup_log "Already mounted: $MOUNT_POINT"
  exit 0
fi

if ! rclone lsd "${CRYPT_REMOTE}:${CRYPT_GDRIVE_PATH}" >/dev/null 2>&1; then
  gdrive_backup_log "Nothing under ${CRYPT_REMOTE}:${CRYPT_GDRIVE_PATH} yet. Run gdrive-backup.sh first."
  exit 1
fi

rclone mount \
  "${CRYPT_REMOTE}:${CRYPT_GDRIVE_PATH}" \
  "$MOUNT_POINT" \
  --daemon \
  --vfs-cache-mode=writes \
  --dir-cache-time=5m

gdrive_backup_log "Mounted decrypted backup at: $MOUNT_POINT"
gdrive_backup_log "Unmount with: gdrive-backup-umount.sh"
