# ⚔️ Phantom Blade Zero Fix for Linux

Install the fix and launch Phantom Blade Zero through GE-Proton with one command.

## Install

First, make sure you can access this private GitHub repository and have authenticated GitHub CLI (`gh`). Then run:

```bash
gh repo clone Timmybread22/pbz-fix "$HOME/pbz-fix" && "$HOME/pbz-fix/install-pbz-fix.sh"
```

The installer downloads the latest fix archive from this repository's release, checks the ZIP, backs up the original game files, installs the fix, verifies `PBZ.exe`, and launches it through the newest installed GE-Proton version.

> **Requirements:** Linux, Steam with Phantom Blade Zero installed, GE-Proton installed in Steam's `compatibilitytools.d` directory, `gh` authenticated with access to this private repository, and `unzip`.
>
> The installer searches the standard Steam locations `~/.local/share/Steam` and `~/.steam/steam`.

## Backups

Before installing, the script backs up any existing `platform/steam/PBZ.exe` and `platform/steam/steam_api64.dll` files to a timestamped directory named `~/pbz-backup-YYYYMMDD-HHMMSS`.

## Uninstall

To restore the original files, copy the backed-up files from the timestamped backup directory into the game's `PBZ` folder, preserving the `platform/steam/` directory structure. Files that did not exist before installation are not included in the backup.

## Support

Report problems or ask for help in the [repository issues](https://github.com/Timmybread22/pbz-fix/issues).
