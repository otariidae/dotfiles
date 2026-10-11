# Backup roles and Google Drive → NAS

## Role split

| Layer | Source of truth | Backup target | Purpose |
|---|---|---|---|
| System restore | This machine (`/` + `/home/ohta`) | External HDD (Timeshift, rsync) | Roll back OS / package / config mistakes |
| Personal documents | Google Drive (health records, pay slips, ebooks, etc.; not source code) | NAS AS1102T (encrypted copy) | Survive Drive lockout, deletion, or outage |
| Source code | ghq / git remotes | Unchanged (remotes are the backup) | Code stays out of Drive |

**Do not**

- Point Timeshift at the NAS (restore would depend on the network)
- Treat Drive as a new offsite dump for arbitrary local trees (Drive is already the SoT for personal docs; we pull **Drive → NAS**)
- Put a second Drive mirror on the Timeshift HDD for now (keep that disk system-only)

Personal docs therefore live in two places: Drive (cloud) and encrypted NAS (separate box on the LAN). Timeshift is a separate axis for the OS.

## OAuth branding URLs (GitHub Pages)

After `docs/` is published via GitHub Pages:

| Field | URL |
|---|---|
| Homepage | https://otariidae.github.io/dotfiles/personal-backup/ |
| Privacy policy | https://otariidae.github.io/dotfiles/personal-backup/privacy/ |
| Terms of service | https://otariidae.github.io/dotfiles/personal-backup/terms/ |
| Authorized domain | `otariidae.github.io` |

## How the encrypted NAS copy is viewed

Files on the NAS look opaque over plain SMB. Browse them only through the crypt remote on this machine:

```bash
gdrive-backup-mount.sh
# then open ~/mnt/gdrive-backup (or MOUNT_POINT from config)
gdrive-backup-umount.sh
```

One-off:

```bash
rclone ls nas-crypt:gdrive
rclone copy nas-crypt:gdrive/some/path ./restore-tmp
```

The crypt passphrase lives in `~/.config/rclone/rclone.conf`. Store a copy in a password manager; without it the NAS copy is not recoverable.

Do not browse the backup via the NAS web UI as plaintext.

## Setup

1. Install tools and link units:

   ```bash
   bin/setup-gdrive-backup
   ```

2. The setup script creates `~/.config/gdrive-backup/config` from the example if needed, ensures rclone remotes `gdrive`, `nas`, and `nas-crypt` exist (interactive prompts for OAuth / SMB / crypt secrets), links systemd units, and enables the daily timer.

   Optional non-interactive secrets:

   ```bash
   export GDRIVE_BACKUP_SMB_PASSWORD='...'
   export GDRIVE_BACKUP_CRYPT_PASSWORD='...'
   export GDRIVE_BACKUP_CRYPT_PASSWORD2='...'
   bin/setup-gdrive-backup
   ```

   Google Drive needs a one-time browser OAuth (`rclone config reconnect gdrive:` if skipped). Prefer your own OAuth `client_id` with scope `drive.readonly`.

   rclone warns that its shared Google `client_id` is being retired during 2026. Create [your own client_id](https://rclone.org/drive/#making-your-own-client-id).

3. Secrets stay only in `~/.config/rclone/rclone.conf` (never in this repo).

4. First sync:

   ```bash
   gdrive-backup.sh --dry-run
   gdrive-backup.sh
   ```

## Operations

| Action | Command |
|---|---|
| Manual backup | `gdrive-backup.sh` |
| Dry-run | `gdrive-backup.sh --dry-run` |
| Timer status | `systemctl --user status gdrive-backup.timer` |
| Logs | `journalctl --user -u gdrive-backup.service -b` or `~/.local/state/gdrive-backup/` |
| Mount decrypted view | `gdrive-backup-mount.sh` |
| Unmount | `gdrive-backup-umount.sh` |

Default schedule: daily around 03:30 (`gdrive-backup.timer`).

## Remotes (expected names)

Configured under `~/.config/rclone/rclone.conf` (override names in `config` if needed):

1. `gdrive` — Google Drive (OAuth; prefer `drive.readonly`)
2. `nas` — SMB host `as1102t-d5f3.local` (share path starts with `kazuki/`)
3. `nas-crypt` — crypt overlay on `nas:kazuki/Backups/gdrive-crypt`

Sync destination path inside the crypt remote defaults to `gdrive`. Deletes on Drive are kept under `gdrive-trash/YYYYMMDD` via `--backup-dir`.
