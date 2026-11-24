# ⚔️ Phantom Blade Zero Fix for Linux

Install the fix and launch Phantom Blade Zero through GE-Proton with one command:

```bash
curl -fsSL https://raw.githubusercontent.com/Timmybread22/pbz-fix/main/install-pbz-fix.sh | bash
```

The installer downloads and validates the fix, backs up existing game files, installs it, verifies `PBZ.exe`, and launches the game through the newest installed GE-Proton version.

> **Requirements:** Linux, Steam with Phantom Blade Zero installed, GE-Proton installed in Steam's `compatibilitytools.d` directory, `curl`, and `unzip`. The installer searches `~/.local/share/Steam` and `~/.steam/steam`.

## Patch notes

See [CHANGELOG.md](CHANGELOG.md) for installer and release updates.

## Backups

Existing `platform/steam/PBZ.exe` and `platform/steam/steam_api64.dll` files are backed up to `~/pbz-backup-YYYYMMDD-HHMMSS`.

## Uninstall

Restore the backed-up files from the timestamped backup directory to the game's `PBZ` folder, preserving the `platform/steam/` structure. Files that did not exist before installation are not included in the backup.

## Support

Report problems in [repository issues](https://github.com/Timmybread22/pbz-fix/issues).
