# ⚔️ PBZ-Fix

Interactive Linux terminal manager for the **Phantom Blade Zero** fix. Install or repair the fix, launch the game, fix the save-file location after the first save, restore backups, and create diagnostics from one menu.

## Install

Open a Linux terminal and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/Timmybread22/pbz-fix/main/install-pbz-fix.sh | bash
```

PBZ-Fix opens a numbered menu in the terminal. It is not a graphical app; keep the terminal open while using the menu. After launching the game, PBZ-Fix exits when the game closes.

When piped into Bash, the installer checks its version against `main` and runs the latest commit's installer if the versions differ. If the check fails, it continues with the downloaded version; set `PBZ_FIX_NO_UPDATE=1` on the Bash command to skip the check. Installer changes must bump `SCRIPT_VERSION` for this check to detect them.

### Menu options

1. **Install/repair, check saves, and set up Steam launch** — Closes Steam, applies or verifies the fix, checks for misplaced saves, and configures the launch wrapper in one run. Run it again after your first save; it does not start the game.
2. **Force reinstall/update** — Downloads and installs the fix again, then checks for misplaced saves.
3. **Launch** — Starts the game without reinstalling.
4. **Launch with Proton logging** — Starts the game and asks Proton to write a debug log.
5. **Uninstall/restore** — Closes Steam, restores backed-up Steam configuration, removes the PBZ launch wrapper, and restores original game files.
6. **Diagnostic log** — Saves a system and install report to your Desktop.
7. **Status** — Shows Steam, game, GE-Proton, and fix status.
8. **Undo save-folder link** — Restores the save-folder layout from before the link was made.
9. **Undo Steam launch wrapper** — Restores the previous Steam launch options.

> **Requirements:** Linux, Steam with Phantom Blade Zero installed, `curl`, `unzip`, `python3`, and `pgrep`. Steam is detected in `~/.local/share/Steam` or `~/.steam/steam`; game installs in additional libraries listed in Steam's `libraryfolders.vdf` are supported. The app manifest determines the active install location; the conventional `common/PBZ` path is used only if no manifest exists. GE-Proton in `compatibilitytools.d` is required for the normal direct-launch options; the Steam launch wrapper uses the compatibility tool selected in Steam.

After installing, choose **Launch** from the menu or start the game through Steam. Once you have created your first save, close the game and run PBZ-Fix again; option 1 will check and repair the save location if needed, while keeping the Steam launch wrapper configured.

### Steam launch wrapper

Run this one-line command from a terminal to set up Steam's launch option:

```bash
curl -fsSL https://raw.githubusercontent.com/Timmybread22/pbz-fix/main/install-pbz-fix.sh | bash -s -- --setup-steam-launch
```

The installer shuts Steam down cleanly, then applies or verifies the fix and configures the launch option in the same run. Save and close any running game before starting. If Steam cannot be shut down, close it completely by hand and retry. It downloads `install-pbz-fix.sh`, `steam-launch.sh`, and the config helper into `~/.local/share/pbz-fix/`, all from the same resolved commit. It backs up each affected `localconfig.vdf` before setting this launch option:

```text
bash "/home/deck/.local/share/pbz-fix/steam-launch.sh" %command%
```

The wrapper verifies or installs the fix, redirects Steam's `steam/PBZ.exe` executable argument to `platform/steam/PBZ.exe`, and hands Steam its original command and arguments. Steam continues using its selected compatibility tool. Arguments and paths containing spaces are preserved. Setup replaces existing launch options automatically and backs up each config before changing it; undo restores the original backup. To undo the setup, run:

```bash
curl -fsSL https://raw.githubusercontent.com/Timmybread22/pbz-fix/main/install-pbz-fix.sh | bash -s -- --undo-steam-launch
```

Undo restores the backed-up Steam config files and removes the launch-option change. The downloaded scripts and backups remain in `~/.local/share/pbz-fix/`.

## Backups and uninstall

Before installing, PBZ-Fix backs up files it will replace to `~/pbz-backup-YYYYMMDD-HHMMSS`. Each game directory tracks its own original restore point across reinstalls; backups from another Steam library or game copy are never selected as a fallback.

Choose **Uninstall/restore** from the menu to restore the original files and backed-up Steam configuration, including launch options, and remove any standard PBZ launch wrapper. Customized PBZ launch options may need manual removal before uninstall. Older backups made before full-file tracking may contain only `PBZ.exe` and `steam_api64.dll`; the menu warns if it finds one. Steam's **Verify integrity of game files** can restore official files, but may not remove extra files left by an older fix.

After the first game save exists, run PBZ-Fix again and choose **Install/repair, check saves, and set up Steam launch** (or run `install-pbz-fix.sh --fix-save-link` to repair saves without checking the fix installation). It checks Steam's active account and all game libraries, including microSD installs. If saves are in a different Steam ID folder, it copies each existing source and expected folder to `~/pbz-save-backup-*`, moves the old expected folder aside, and links the expected folder to the saves. It verifies readable files through the link and never merges over or deletes existing saves. Steam IDs are read locally and are not printed in status or diagnostics. Choose **Undo save-folder link** (or run `install-pbz-fix.sh --undo-save-link`) to restore the original folder layout; the safety copy is retained. The script verifies filesystem access but cannot confirm that a cloud upload has completed.

## Logs and troubleshooting

Routine actions do not create log files. Choose **Diagnostic log** to save a report to the Desktop, or **Launch with Proton logging** to create `~/steam-4115450.log`. Review diagnostic reports before sharing; they include local file paths.

GE-Proton may print a ProtonFixes warning saying it is “probably running a unit test.” This comes from GE-Proton's game-fix detection when PBZ-Fix launches with `proton run`; it does not mean PBZ-Fix is running a test.

## Patch notes and support

See the [changelog](CHANGELOG.md) for updates. Report problems in [repository issues](https://github.com/Timmybread22/pbz-fix/issues).
