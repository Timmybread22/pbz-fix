#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install-pbz-fix.sh
source "$SCRIPT_DIR/install-pbz-fix.sh"

main() {
    local index
    local executable_count=0
    local -a steam_command=("$@")

    check_requirements
    ((${#steam_command[@]} > 0)) ||
        fail "Steam's original launch command is missing. Add %command% after this script in Steam's launch options."

    prepare_game
    install_or_repair_fix
    prepare_save_link

    for index in "${!steam_command[@]}"; do
        case "${steam_command[$index]}" in
            steam/PBZ.exe|*/steam/PBZ.exe)
                steam_command[$index]="$GAME_DIR/platform/steam/PBZ.exe"
                executable_count=$((executable_count + 1))
                ;;
        esac
    done

    ((executable_count == 1)) ||
        fail "Expected one steam/PBZ.exe argument in Steam's original command; found $executable_count. The game was installed, but not launched."

    [[ -f "$GAME_DIR/platform/steam/PBZ.exe" ]] ||
        fail "The fixed game executable is missing: $GAME_DIR/platform/steam/PBZ.exe"

    log "Handing off to Steam's original launch command with the fixed executable."
    cleanup
    exec "${steam_command[@]}"
}

main "$@"
