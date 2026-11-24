# ⚔️ Phantom Blade Zero Fix for Linux

Install the fix on the first run; later runs verify the installed files and launch the game without downloading or reinstalling:

```bash
curl -fsSL https://raw.githubusercontent.com/Timmybread22/pbz-fix/5fcd1ff5caa5f70f40c6070bd9314bb7546d1889/install-pbz-fix.sh | bash
```

The installer downloads and validates the fix, backs up existing game files, installs it, verifies `PBZ.exe`, and launches the game through the newest installed GE-Proton version.

> **Requirements:** Linux, Steam with Phantom Blade Zero installed, GE-Proton installed in Steam's `compatibilitytools.d` directory, `curl`, and `unzip`. The installer searches `~/.local/share/Steam` and `~/.steam/steam`.

To force a fresh download and reinstall:

```bash
curl -fsSL https://raw.githubusercontent.com/Timmybread22/pbz-fix/5fcd1ff5caa5f70f40c6070bd9314bb7546d1889/install-pbz-fix.sh | FORCE_INSTALL=1 bash
```

## Patch notes

See [CHANGELOG.md](CHANGELOG.md) for installer and release updates.

## Backups

Existing `platform/steam/PBZ.exe` and `platform/steam/steam_api64.dll` files are backed up to `~/pbz-backup-YYYYMMDD-HHMMSS`.

## Uninstall

Restore the backed-up files from the timestamped backup directory to the game's `PBZ` folder, preserving the `platform/steam/` structure. Remove `.pbz-fix-install-revision` and `.pbz-fix-files.sha256` from the game folder to clear the install marker. Files that did not exist before installation are not included in the backup.

## Support

Report problems in [repository issues](https://github.com/Timmybread22/pbz-fix/issues).
