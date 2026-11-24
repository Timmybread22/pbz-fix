#!/usr/bin/env bash
set -euo pipefail

# Phantom Blade Zero fix installer
APP_ID="4115450"
FIX_REPO="${FIX_REPO:-Timmybread22/pbz-fix}"
FIX_RELEASE="${FIX_RELEASE:-latest}"
FIX_ASSET="${FIX_ASSET:-Phantom.Blade.Zero.FIX.zip}"
FIX_ZIP="${FIX_ZIP:-}"

TEMP_DIR=""
STEAM_ROOT=""
GAME_DIR=""
PROTON=""

log() {
    printf '[PBZ Fix] %s\n' "$*"
}

fail() {
    printf '[PBZ Fix] ERROR: %s\n' "$*" >&2
    exit 1
}

cleanup() {
    if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
        rm -rf -- "$TEMP_DIR"
    fi
}

trap cleanup EXIT

require_command() {
    local command_name="$1"
    command -v "$command_name" >/dev/null 2>&1 ||
        fail "Required command '$command_name' was not found."
}

detect_steam() {
    local candidate

    for candidate in "$HOME/.local/share/Steam" "$HOME/.steam/steam"; do
        if [[ -d "$candidate" && -d "$candidate/steamapps" ]]; then
            STEAM_ROOT="$candidate"
            log "Using Steam installation: $STEAM_ROOT"
            return 0
        fi
    done

    return 1
}

manifest_install_dir() {
    local manifest="$1"
    awk -F '"' '
        tolower($2) == "installdir" {
            print $4
            exit
        }
    ' "$manifest"
}

find_game_directory() {
    local primary="$STEAM_ROOT/steamapps/common/PBZ"
    local manifest
    local manifest_dir
    local install_dir
    local game_candidate
    local -a manifests=()

    if [[ -d "$primary" ]]; then
        GAME_DIR="$primary"
        log "Found game directory: $GAME_DIR"
        return 0
    fi

    while IFS= read -r -d '' manifest; do
        manifests+=("$manifest")
    done < <(
        find "$STEAM_ROOT" \
            -type f \
            -name "appmanifest_${APP_ID}.acf" \
            -print0 2>/dev/null
    )

    for manifest in "${manifests[@]}"; do
        manifest_dir="$(dirname "$manifest")"
        install_dir="$(manifest_install_dir "$manifest")"

        if [[ -n "$install_dir" ]]; then
            game_candidate="$manifest_dir/common/$install_dir"
            if [[ -d "$game_candidate" ]]; then
                GAME_DIR="$game_candidate"
                log "Found game directory through app manifest: $GAME_DIR"
                return 0
            fi
        fi
    done

    return 1
}

find_newest_proton() {
    local compatibility_dir="$STEAM_ROOT/compatibilitytools.d"
    local directory
    local name
    local proton_candidate
    local major
    local minor
    local best_major=-1
    local best_minor=-1
    local candidate_name=""

    [[ -d "$compatibility_dir" ]] || return 1

    while IFS= read -r -d '' directory; do
        name="$(basename "$directory")"

        if [[ "$name" =~ ^GE-Proton([0-9]+)-([0-9]+)$ ]]; then
            major="${BASH_REMATCH[1]}"
            minor="${BASH_REMATCH[2]}"
        elif [[ "$name" =~ ^GE-Proton([0-9]+)-(.+)$ ]]; then
            major="${BASH_REMATCH[1]}"
            minor=0
        else
            continue
        fi

        proton_candidate="$directory/proton"
        [[ -x "$proton_candidate" ]] || continue

        if (( major > best_major )) ||
            (( major == best_major && minor > best_minor )) ||
            { (( major == best_major && minor == best_minor )) &&
              { [[ -z "$candidate_name" ]] ||
                [[ "$name" > "$candidate_name" ]]; }; }; then
            best_major="$major"
            best_minor="$minor"
            candidate_name="$name"
            PROTON="$proton_candidate"
        fi
    done < <(
        find "$compatibility_dir" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            -print0 2>/dev/null
    )

    [[ -n "$PROTON" ]]
}

download_fix() {
    if [[ -n "$FIX_ZIP" ]]; then
        [[ -f "$FIX_ZIP" ]] ||
            fail "The supplied FIX_ZIP does not exist: $FIX_ZIP"
        FIX_ZIP="$(cd "$(dirname "$FIX_ZIP")" && pwd)/$(basename "$FIX_ZIP")"
        log "Using fix archive: $FIX_ZIP"
        return 0
    fi

    TEMP_DIR="$(mktemp -d)"

    if command -v gh >/dev/null 2>&1; then
        if gh auth status >/dev/null 2>&1; then
            log "Downloading fix archive from GitHub..."
            gh release download "$FIX_RELEASE" \
                --repo "$FIX_REPO" \
                --pattern "$FIX_ASSET" \
                --dir "$TEMP_DIR" ||
                fail "Failed to download '$FIX_ASSET' from $FIX_REPO."

            FIX_ZIP="$TEMP_DIR/$FIX_ASSET"
            [[ -f "$FIX_ZIP" ]] ||
                fail "GitHub did not provide the downloaded fix archive."
            return 0
        fi
    fi

    if [[ "$FIX_RELEASE" == "latest" ]]; then
        require_command curl
        log "Downloading fix archive from GitHub..."
        curl --fail --location --retry 3 \
            "https://github.com/$FIX_REPO/releases/latest/download/$(
                printf '%s' "$FIX_ASSET" | sed 's/ /%20/g'
            )" \
            --output "$TEMP_DIR/$FIX_ASSET" ||
            fail "Failed to download the fix archive. For a private repository, authenticate with 'gh auth login'."

        FIX_ZIP="$TEMP_DIR/$FIX_ASSET"
        return 0
    fi

    fail "FIX_ZIP was not supplied and the GitHub CLI is unavailable or unauthenticated."
}

validate_zip() {
    [[ -r "$FIX_ZIP" ]] ||
        fail "Fix ZIP is not readable: $FIX_ZIP"

    [[ -s "$FIX_ZIP" ]] ||
        fail "Fix ZIP is empty: $FIX_ZIP"

    unzip -t "$FIX_ZIP" >/dev/null 2>&1 ||
        fail "Fix ZIP validation failed: $FIX_ZIP"

    local -a entries=()
    local entry

    mapfile -t entries < <(unzip -Z1 "$FIX_ZIP" 2>/dev/null)

    for entry in "${entries[@]}"; do
        if [[ "$entry" == /* ||
              "$entry" == "../"* ||
              "$entry" == *"/../"* ||
              "$entry" == *"\\"* ]]; then
            fail "Fix ZIP contains an unsafe path: $entry"
        fi
    done

    printf '%s\n' "${entries[@]}" |
        grep -Eq '^steam(/|$)' ||
        fail "Fix ZIP is missing the steam/ folder."

    printf '%s\n' "${entries[@]}" |
        grep -Eq '^platform(/|$)' ||
        fail "Fix ZIP is missing the platform/ folder."
}

create_backups() {
    local timestamp
    local backup_dir
    local source
    local destination
    local -a files=(
        "platform/steam/PBZ.exe"
        "platform/steam/steam_api64.dll"
    )

    timestamp="$(date '+%Y%m%d-%H%M%S')"
    backup_dir="$HOME/pbz-backup-$timestamp"
    mkdir -p "$backup_dir"

    for source in "${files[@]}"; do
        if [[ -f "$GAME_DIR/$source" ]]; then
            destination="$backup_dir/$source"
            mkdir -p "$(dirname "$destination")"
            cp -a -- "$GAME_DIR/$source" "$destination"
            log "Backed up $GAME_DIR/$source"
        else
            log "Original file not present; skipping backup: $GAME_DIR/$source"
        fi
    done

    log "Backup directory: $backup_dir"
}

extract_and_install() {
    local extract_dir="$TEMP_DIR/extracted"
    mkdir -p "$extract_dir"

    unzip -q "$FIX_ZIP" -d "$extract_dir" ||
        fail "Failed to extract fix ZIP."

    [[ -d "$extract_dir/steam" ]] ||
        fail "Extracted archive is missing the steam/ folder."

    [[ -d "$extract_dir/platform" ]] ||
        fail "Extracted archive is missing the platform/ folder."

    mkdir -p "$GAME_DIR/steam" "$GAME_DIR/platform"

    cp -a -- "$extract_dir/steam/." "$GAME_DIR/steam/"
    cp -a -- "$extract_dir/platform/." "$GAME_DIR/platform/"
}

main() {
    require_command unzip
    require_command find
    require_command cp
    require_command mkdir
    require_command sed
    require_command awk
    require_command grep
    require_command mktemp
    require_command date

    if ! detect_steam; then
        fail "Steam could not be found."
    fi

    if ! find_game_directory; then
        fail "Phantom Blade Zero is not installed."
    fi

    if ! find_newest_proton; then
        fail "No installed GE-Proton installation was found."
    fi

    log "Using GE-Proton: $PROTON"

    log "Downloading or locating the fix archive..."
    download_fix

    log "Validating fix ZIP..."
    validate_zip
    log "Fix ZIP validation passed."

    log "Creating backups..."
    create_backups

    log "Extracting and installing fix..."
    extract_and_install

    local executable="$GAME_DIR/platform/steam/PBZ.exe"

    [[ -f "$executable" ]] ||
        fail "Post-install verification failed: $executable does not exist."

    log "Post-install verification passed."

    export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_ROOT"
    export STEAM_COMPAT_DATA_PATH="$STEAM_ROOT/steamapps/compatdata/$APP_ID"
    export SteamAppId="$APP_ID"
    export SteamGameId="$APP_ID"

    mkdir -p "$STEAM_COMPAT_DATA_PATH"

    cd "$GAME_DIR/platform/steam"

    local windows_path
    windows_path="Z:${executable//\//\\}"

    local launch_status
    set +e
    "$PROTON" run "$windows_path"
    launch_status=$?
    set -e

    if (( launch_status != 0)); then
        printf '%s\n' \
            "The game exited unexpectedly." \
            "Try rerunning with:" \
            "PROTON_LOG=1" \
            "Then inspect:" \
            "~/steam-4115450.log"
        exit "$launch_status"
    fi

    log "Success: Phantom Blade Zero fix was installed and launched."
}

main "$@"
