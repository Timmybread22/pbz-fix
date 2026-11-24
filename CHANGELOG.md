# Patch notes

## v1.0.0

Initial release.

- Added a one-command Linux installer.
- Added automatic fix download, ZIP validation, backups, installation, and post-install verification.
- Added automatic Steam and GE-Proton detection and game launch.

### Installer update — 2026-11-24

- Fixed downloading the latest release when the GitHub CLI is installed and authenticated.
- Pinned the README install command to this installer revision to avoid stale content served for the moving `main` URL.
- Added install verification so repeat runs launch the game without downloading or reinstalling the fix.
- Added `FORCE_INSTALL=1` to force a fresh install.
- Fixed temporary extraction when using a locally supplied archive.
- Added an interactive menu for install/update, launch, uninstall/restore, status, and diagnostics.
- Added per-action Desktop logs and an optional Proton debug-log launch.
- Backed up all files managed by the fix and added restore support.
- Preserved the original backup restore point across forced reinstalls.
- Added a force-reinstall menu action. Increment `INSTALL_REVISION` when publishing a changed fix archive so installed copies are refreshed.
- Launch actions now exit PBZ-Fix when the game closes instead of returning to the menu.
- Routine actions no longer create Desktop logs; diagnostic reports are saved only when requested.
- Documented the benign GE-Proton ProtonFixes warning seen with direct `proton run`.
