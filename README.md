# ⚔️ PBZ-Fix

Terminal manager for the **Phantom Blade Zero** fix on Linux and Steam Deck.

## Install

On Steam Deck, switch to Desktop Mode and open Konsole. Save and close any running game, then run:

```bash
curl -fsSL https://raw.githubusercontent.com/Timmybread22/pbz-fix/main/install-pbz-fix.sh | bash
```

Choose **1**. PBZ-Fix closes Steam automatically, installs or verifies the fix, checks saves, and sets up the Steam launch wrapper. There are no y/N confirmations. Restart Steam to play. After your first save, close the game and run option 1 again to check the save location.

The piped installer checks `main` for a different version and runs it when available. If the check fails, it continues with the downloaded version; an older cached script without this check cannot update itself. To skip the check:

```bash
curl -fsSL https://raw.githubusercontent.com/Timmybread22/pbz-fix/main/install-pbz-fix.sh | PBZ_FIX_NO_UPDATE=1 bash
```

**Requirements:** Linux, Steam with the game installed, `curl`, `unzip`, `python3`, and `pgrep`. Additional Steam libraries and microSD installs are supported. Menu options 2–4 require GE-Proton in Steam's `compatibilitytools.d`; Steam launches use the compatibility tool selected in Steam.

## Menu

1. **Install/repair and set up Steam launch** — Close Steam, install or verify the fix, check saves, and set up the wrapper.
2. **Force reinstall/update** — Reinstall the fix and check saves; does not close Steam or set up the wrapper.
3. **Launch** — Launch directly with GE-Proton.
4. **Launch with Proton logging** — Launch directly and write a Proton log.
5. **Uninstall/restore** — Close Steam, restore backed-up Steam configuration, remove the PBZ wrapper, and restore game files.
6. **Diagnostic log** — Save a report to the Desktop.
7. **Status** — Show Steam, game, fix, GE-Proton, and backup status.
8. **Undo save-folder link** — Restore the previous save-folder layout.
9. **Undo Steam launch wrapper** — Close Steam and restore backed-up Steam configuration.
0. **Exit**.

## Steam launch and direct commands

Setup installs `steam-launch.sh` and its helpers in `~/.local/share/pbz-fix/` from one resolved commit. It replaces existing launch options automatically. The launch option is equivalent to:

```text
bash "$HOME/.local/share/pbz-fix/steam-launch.sh" %command%
```

The saved option contains the resolved absolute path (for example, `/home/deck/...`). The wrapper verifies or installs the fix, checks saves, and redirects Steam's game executable while preserving Steam's command and arguments.

To run setup without the menu:

```bash
curl -fsSL https://raw.githubusercontent.com/Timmybread22/pbz-fix/main/install-pbz-fix.sh | bash -s -- --setup-steam-launch
```

Replace `--setup-steam-launch` with `--undo-steam-launch` to undo the wrapper, or `--uninstall` to uninstall. These actions also close Steam automatically. If Steam will not close, close it manually and retry.

## Backups and recovery

- **Game files:** `~/pbz-backup-*`; uninstall uses the original restore point linked to that game directory. Legacy backups may not remove every added file.
- **Steam configuration:** `~/.local/share/pbz-fix/backups/`; setup backs up each affected `localconfig.vdf` before changing it. Undo and uninstall restore the **entire original file**, not just launch options, so later Steam settings in that file may be overwritten. Backup files and downloaded scripts remain. A customized PBZ wrapper may need manual removal before uninstall.
- **Saves:** `~/pbz-save-backup-*`; save repair backs up existing folders before linking and does not merge or delete saves. Option 8 undoes the link; the backup remains. PBZ-Fix cannot verify cloud uploads.

## Troubleshooting

Option 6 writes a diagnostic report to the Desktop; review its local paths before sharing. Option 4 writes `~/steam-4115450.log`. A GE-Proton ProtonFixes warning about “probably running a unit test” is benign.

See the [changelog](CHANGELOG.md) or report problems in [repository issues](https://github.com/Timmybread22/pbz-fix/issues).
