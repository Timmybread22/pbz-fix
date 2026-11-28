#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../install-pbz-fix.sh
source "$SCRIPT_DIR/install-pbz-fix.sh"

TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

HOME="$TEST_ROOT/home"
GAME_DIR="$TEST_ROOT/Steam library/PBZ"
EXTRACT_DIR="$TEST_ROOT/extracted"
mkdir -p \
    "$HOME/pbz-backup-99999999-999999" \
    "$GAME_DIR/steam" \
    "$GAME_DIR/platform" \
    "$EXTRACT_DIR/steam" \
    "$EXTRACT_DIR/platform"
printf 'unrelated restore point\n' > "$HOME/pbz-backup-99999999-999999/original"
printf 'installed file\n' > "$GAME_DIR/steam/mod.dll"
printf 'replacement file\n' > "$EXTRACT_DIR/steam/mod.dll"
printf 'replacement executable\n' > "$EXTRACT_DIR/platform/PBZ.exe"

create_backups "$EXTRACT_DIR" >/dev/null
backup_pointer="$GAME_DIR/.pbz-fix-original-backup"
IFS= read -r original_backup < "$backup_pointer"
[[ "$original_backup" != "$HOME/pbz-backup-99999999-999999" ]]
[[ -f "$original_backup/steam/mod.dll" ]]
[[ "$(cat "$original_backup/steam/mod.dll")" == "installed file" ]]

first_restore_point="$original_backup"
printf 'updated file\n' > "$GAME_DIR/steam/mod.dll"
create_backups "$EXTRACT_DIR" >/dev/null
IFS= read -r original_backup < "$backup_pointer"
[[ "$original_backup" == "$first_restore_point" ]]

printf 'Backup restore-point association tests passed.\n'
