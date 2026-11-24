# ⚔️ Phantom Blade Zero Fix for Linux

Run this one-liner to open the interactive menu:

```bash
curl -fsSL https://raw.githubusercontent.com/Timmybread22/pbz-fix/4e270a7652832a4ab16ccc8fdced965507a6c6f9/install-pbz-fix.sh | bash
```

Run it from a Linux terminal emulator. PBZ-Fix displays a numbered terminal menu and reads your selection there; it is not a graphical window. The terminal stays available for menu actions, and the manager exits after the game closes.

The menu can install/repair or force-reinstall the fix, launch the game, launch with Proton logging, restore original files to uninstall, create a diagnostic report, or show installation status. After any launch option, PBZ-Fix exits when the game closes. The first install backs up every file the fix will replace. Later install/repair selections verify those files and launch without downloading or reinstalling.

> **Requirements:** Linux, Steam with Phantom Blade Zero installed, GE-Proton installed in Steam's `compatibilitytools.d` directory, `curl`, and `unzip`. The installer searches `~/.local/share/Steam` and `~/.steam/steam`.

With no interactive terminal, the command automatically installs/updates the fix and launches the game. To force a fresh download and reinstall:

```bash
curl -fsSL https://raw.githubusercontent.com/Timmybread22/pbz-fix/4e270a7652832a4ab16ccc8fdced965507a6c6f9/install-pbz-fix.sh | FORCE_INSTALL=1 bash
```

For direct actions, pass `--force-install`, `--launch`, `--launch-log`, `--uninstall`, `--diagnostics`, or `--status` to the script.

## Patch notes

See [CHANGELOG.md](CHANGELOG.md) for installer and release updates.

## Backups

Files the fix replaces are backed up to `~/pbz-backup-YYYYMMDD-HHMMSS`.

## Uninstall

Choose **Uninstall/restore** from the menu to restore the original files and remove files that the fix added. The original backup is retained across reinstalls. Older backups made before the interactive installer may only contain `PBZ.exe` and `steam_api64.dll`; the script warns that other fix files may remain when restoring one of those backups.

## Logs

Routine actions do not create log files. Choose **Create diagnostic log on Desktop** to save a shareable system and install report. Choose **Launch game with Proton logging** to ask Proton to create `~/steam-4115450.log`. Diagnostic reports avoid environment variables and Proton log contents, but include local paths/usernames; review them before sharing.

GE-Proton may print `ProtonFixes ... Skipping fix execution. We are probably running a unit test.` This is a warning from GE-Proton's ProtonFixes component: its game-specific hooks expect Steam's `waitforexitandrun` launch verb, while PBZ-Fix uses the requested direct `proton run` launch. It does not mean PBZ-Fix is running a test, and it did not prevent the game from opening in the reported run.

## Support

Report problems in [repository issues](https://github.com/Timmybread22/pbz-fix/issues).
