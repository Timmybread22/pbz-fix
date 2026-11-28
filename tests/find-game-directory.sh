#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../install-pbz-fix.sh
source "$SCRIPT_DIR/install-pbz-fix.sh"

TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

STEAM_ROOT="$TEST_ROOT/Steam"
LIBRARY_ROOT="$TEST_ROOT/Removable Drive"
mkdir -p \
    "$STEAM_ROOT/steamapps/common/PBZ" \
    "$LIBRARY_ROOT/steamapps/common/PBZ"

cat > "$STEAM_ROOT/steamapps/libraryfolders.vdf" <<EOF
"libraryfolders"
{
    "0"
    {
        "path" "$STEAM_ROOT"
    }
    "1"
    {
        "path" "$LIBRARY_ROOT"
    }
    "2"
    {
        "path" "relative/library"
    }
}
EOF

find_game_directory >/dev/null
[[ "$GAME_DIR" == "$STEAM_ROOT/steamapps/common/PBZ" ]]

rmdir "$STEAM_ROOT/steamapps/common/PBZ"
find_game_directory >/dev/null
[[ "$GAME_DIR" == "$LIBRARY_ROOT/steamapps/common/PBZ" ]]

rm -rf -- "$LIBRARY_ROOT/steamapps/common/PBZ"
mkdir -p "$LIBRARY_ROOT/steamapps/common/PBZ Install"
cat > "$LIBRARY_ROOT/steamapps/appmanifest_${APP_ID}.acf" <<'EOF'
"AppState"
{
    "installdir" "PBZ Install"
}
EOF

mkdir -p "$STEAM_ROOT/steamapps/common/PBZ"
find_game_directory >/dev/null
[[ "$GAME_DIR" == "$LIBRARY_ROOT/steamapps/common/PBZ Install" ]]

cat > "$LIBRARY_ROOT/steamapps/appmanifest_${APP_ID}.acf" <<'EOF'
"AppState"
{
    "installdir" "../outside"
}
EOF
mkdir -p "$LIBRARY_ROOT/steamapps/outside"
if find_game_directory >/dev/null; then
    printf 'Unsafe app manifest path was accepted: %s\n' "$GAME_DIR" >&2
    exit 1
fi

printf 'Steam library discovery tests passed.\n'
