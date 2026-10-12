#!/usr/bin/env bash
# Unmount the decrypted Google Drive backup view.
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SCRIPT_PATH
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
readonly SCRIPT_DIR
# shellcheck source=../lib/gdrive-backup/common.sh
source "${SCRIPT_DIR}/../lib/gdrive-backup/common.sh"

gdrive_backup_load_config

if [[ ! -d "$MOUNT_POINT" ]]; then
  gdrive_backup_log "Mount point does not exist: $MOUNT_POINT"
  exit 0
fi

if ! mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
  gdrive_backup_log "Not mounted: $MOUNT_POINT"
  exit 0
fi

if command -v fusermount3 >/dev/null; then
  fusermount3 -u "$MOUNT_POINT"
elif command -v fusermount >/dev/null; then
  fusermount -u "$MOUNT_POINT"
else
  umount "$MOUNT_POINT"
fi

gdrive_backup_log "Unmounted: $MOUNT_POINT"
