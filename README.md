# ⚔️ PBZ-Fix

Interactive Linux terminal manager for the **Phantom Blade Zero** fix. Install or repair the fix, launch the game, restore backups, and create diagnostics from one menu.

## Install

Open a Linux terminal and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/Timmybread22/pbz-fix/4e270a7652832a4ab16ccc8fdced965507a6c6f9/install-pbz-fix.sh | bash
```

PBZ-Fix opens a numbered menu in the terminal. It is not a graphical app; keep the terminal open while using the menu. After launching the game, PBZ-Fix exits when the game closes.

### Menu options

1. **Install/repair** — Installs the fix if needed, then launches. If the installed files already verify, it skips reinstalling.
2. **Force reinstall** — Downloads and installs the fix again, then launches.
3. **Launch** — Starts the game without reinstalling.
4. **Launch with Proton logging** — Starts the game and asks Proton to write a debug log.
5. **Uninstall/restore** — Restores files from the original backup and removes files added by the fix.
6. **Diagnostic log** — Saves a system and install report to your Desktop.
7. **Status** — Shows Steam, game, GE-Proton, and fix status.

With no interactive terminal, the command defaults to installing/repairing and launching the game.

> **Requirements:** Linux, Steam with Phantom Blade Zero installed, GE-Proton in Steam's `compatibilitytools.d` directory, `curl`, and `unzip`. Steam is detected in `~/.local/share/Steam` or `~/.steam/steam`.

## Backups and uninstall

Before installing, PBZ-Fix backs up files it will replace to `~/pbz-backup-YYYYMMDD-HHMMSS`. The original restore point is retained during later reinstalls.

Choose **Uninstall/restore** from the menu to restore the original files. Older backups made before full-file tracking may contain only `PBZ.exe` and `steam_api64.dll`; the menu warns if it finds one. Steam's **Verify integrity of game files** can restore official files, but may not remove extra files left by an older fix.

## Logs and troubleshooting

Routine actions do not create log files. Choose **Diagnostic log** to save a report to the Desktop, or **Launch with Proton logging** to create `~/steam-4115450.log`. Review diagnostic reports before sharing; they include local file paths.

GE-Proton may print a ProtonFixes warning saying it is “probably running a unit test.” This comes from GE-Proton's game-fix detection when PBZ-Fix launches with `proton run`; it does not mean PBZ-Fix is running a test.

## Patch notes and support

See the [changelog](CHANGELOG.md) for updates. Report problems in [repository issues](https://github.com/Timmybread22/pbz-fix/issues).
