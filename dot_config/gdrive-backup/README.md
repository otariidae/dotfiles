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

## OAuth branding URLs

Hosted on the verified personal domain (required for Google brand verification):

| Field | URL |
|---|---|
| Homepage | https://otariidae.com/apps/personal-backup/ |
| Privacy policy | https://otariidae.com/apps/personal-backup/privacy/ |
| Terms of service | https://otariidae.com/apps/personal-backup/terms/ |
| Authorized domain | `otariidae.com` |

Verify `otariidae.com` in [Google Search Console](https://search.google.com/search-console) with a Google account that is Owner/Editor on the Cloud project, then wait up to 24 hours before retrying brand verification.

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

Do not browse the backup via the NAS web UI as plaintext.

## Setup

1. Install tools and link units:

   ```bash
   bin/setup-gdrive-backup
   ```

2. Ensure rclone remotes `gdrive`, `nas`, and `nas-crypt` exist (OAuth / SMB / crypt). Secrets stay in `~/.config/rclone/rclone.conf` only — never in this repo. Prefer your own Google OAuth client with scope `drive.readonly`.

3. First sync:

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
