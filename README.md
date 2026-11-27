# ⚔️ PBZ-Fix

Interactive Linux terminal manager for the **Phantom Blade Zero** fix. Install or repair the fix, launch the game, fix the save-file location after the first save, restore backups, and create diagnostics from one menu.

## Install

Open a Linux terminal and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/Timmybread22/pbz-fix/d98e850e5c55211302c11b5f77c8b9f89686eb89/install-pbz-fix.sh | bash
```

PBZ-Fix opens a numbered menu in the terminal. It is not a graphical app; keep the terminal open while using the menu. After launching the game, PBZ-Fix exits when the game closes.

### Menu options

1. **Install/repair fix** — Installs the fix if needed and returns to the menu without starting the game. Run PBZ-Fix again after your first save and choose option 2.
2. **Fix save-file location** — Run only after the game has created its first save. Makes backups and links misplaced saves without launching the game.
3. **Force reinstall** — Downloads and installs the fix again without launching the game.
4. **Launch** — Starts the game without reinstalling.
5. **Launch with Proton logging** — Starts the game and asks Proton to write a debug log.
6. **Uninstall/restore** — Restores files from the original backup and removes files added by the fix.
7. **Diagnostic log** — Saves a system and install report to your Desktop.
8. **Status** — Shows Steam, game, GE-Proton, and fix status.
9. **Undo save-folder link** — Restores the save-folder layout from before the link was made.

> **Requirements:** Linux, Steam with Phantom Blade Zero installed, `curl`, and `unzip`. GE-Proton in Steam's `compatibilitytools.d` directory is required only for PBZ-Fix's Launch options; you can also start the game directly through Steam. Steam is detected in `~/.local/share/Steam` or `~/.steam/steam`.

After installing, choose **Launch** from the menu or start the game through Steam. Once you have created your first save, close the game, run PBZ-Fix again, and choose option 2.

## Backups and uninstall

Before installing, PBZ-Fix backs up files it will replace to `~/pbz-backup-YYYYMMDD-HHMMSS`. The original restore point is retained during later reinstalls.

Choose **Uninstall/restore** from the menu to restore the original files. Older backups made before full-file tracking may contain only `PBZ.exe` and `steam_api64.dll`; the menu warns if it finds one. Steam's **Verify integrity of game files** can restore official files, but may not remove extra files left by an older fix.

After the first game save exists, run PBZ-Fix again and choose **Fix save-file location** (or run `install-pbz-fix.sh --fix-save-link`). It checks Steam's active account and all game libraries, including microSD installs. If saves are in a different Steam ID folder, it copies each existing source and expected folder to `~/pbz-save-backup-*`, moves the old expected folder aside, and links the expected folder to the saves. It verifies readable files through the link and never merges over or deletes existing saves. Steam IDs are read locally and are not printed in status or diagnostics. Choose **Undo save-folder link** (or run `install-pbz-fix.sh --undo-save-link`) to restore the original folder layout; the safety copy is retained. The script verifies filesystem access but cannot confirm that a cloud upload has completed.

## Logs and troubleshooting

Routine actions do not create log files. Choose **Diagnostic log** to save a report to the Desktop, or **Launch with Proton logging** to create `~/steam-4115450.log`. Review diagnostic reports before sharing; they include local file paths.

GE-Proton may print a ProtonFixes warning saying it is “probably running a unit test.” This comes from GE-Proton's game-fix detection when PBZ-Fix launches with `proton run`; it does not mean PBZ-Fix is running a test.

## Patch notes and support

See the [changelog](CHANGELOG.md) for updates. Report problems in [repository issues](https://github.com/Timmybread22/pbz-fix/issues).
