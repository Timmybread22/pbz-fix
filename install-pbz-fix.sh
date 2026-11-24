#!/usr/bin/env bash
set -euo pipefail

# Phantom Blade Zero fix installer
SCRIPT_VERSION="2.0"
APP_ID="4115450"
FIX_REPO="${FIX_REPO:-Timmybread22/pbz-fix}"
FIX_RELEASE="${FIX_RELEASE:-latest}"
FIX_ASSET="${FIX_ASSET:-Phantom.Blade.Zero.FIX.zip}"
FIX_ZIP="${FIX_ZIP:-}"
INSTALL_REVISION="3"

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
    TEMP_DIR=""
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
            local -a release_args=()
            if [[ "$FIX_RELEASE" != "latest" ]]; then
                release_args=("$FIX_RELEASE")
            fi

            log "Downloading fix archive from GitHub..."
            gh release download "${release_args[@]}" \
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
        if [[ "$entry" == /* || "$entry" == *"\\"* ]]; then
            fail "Fix ZIP contains an unsafe path: $entry"
        fi

        case "/$entry/" in
            *"/../"*)
                fail "Fix ZIP contains an unsafe path: $entry"
                ;;
        esac
    done

    printf '%s\n' "${entries[@]}" |
        grep -Eq '^steam(/|$)' ||
        fail "Fix ZIP is missing the steam/ folder."

    printf '%s\n' "${entries[@]}" |
        grep -Eq '^platform(/|$)' ||
        fail "Fix ZIP is missing the platform/ folder."
}

create_backups() {
    local extract_dir="$1"
    local timestamp
    local backup_dir
    local prior_backup
    local original_backup
    local backup_pointer="$GAME_DIR/.pbz-fix-original-backup"
    local backup_pointer_temp="$backup_pointer.tmp.$$"
    local source
    local destination

    prior_backup="$(latest_backup)"
    timestamp="$(date '+%Y%m%d-%H%M%S')"
    backup_dir="$HOME/pbz-backup-$timestamp"
    if ! mkdir -- "$backup_dir" 2>/dev/null; then
        backup_dir="$(mktemp -d "$HOME/pbz-backup-$timestamp-XXXXXX")" ||
            fail "Could not create a unique backup directory."
    fi

    (
        cd "$extract_dir"
        find steam platform -type f -print0 | sort -z
    ) > "$backup_dir/.pbz-fix-managed-files.nul" ||
        fail "Failed to record the fix files for uninstall."

    while IFS= read -r -d '' source; do
        if [[ -f "$GAME_DIR/$source" || -L "$GAME_DIR/$source" ]]; then
            destination="$backup_dir/$source"
            mkdir -p "$(dirname "$destination")"
            cp -a -- "$GAME_DIR/$source" "$destination"
            log "Backed up $GAME_DIR/$source"
        fi
    done < "$backup_dir/.pbz-fix-managed-files.nul"

    original_backup="$backup_dir"
    if [[ -r "$backup_pointer" ]]; then
        IFS= read -r original_backup < "$backup_pointer" || original_backup=""
    elif [[ -n "$prior_backup" && -d "$prior_backup" ]]; then
        original_backup="$prior_backup"
    fi

    case "$original_backup" in
        "$HOME"/pbz-backup-*)
            if [[ ! -d "$original_backup" ]]; then
                original_backup="$backup_dir"
            fi
            ;;
        *)
            original_backup="$backup_dir"
            ;;
    esac

    printf '%s\n' "$original_backup" > "$backup_pointer_temp"
    mv -- "$backup_pointer_temp" "$backup_pointer"
    log "Backup directory: $backup_dir"
    log "Original restore point: $original_backup"
}

extract_and_install() {
    if [[ -z "$TEMP_DIR" ]]; then
        TEMP_DIR="$(mktemp -d)"
    fi

    local extract_dir="$TEMP_DIR/extracted"
    mkdir -p "$extract_dir"

    unzip -q "$FIX_ZIP" -d "$extract_dir" ||
        fail "Failed to extract fix ZIP."

    [[ -d "$extract_dir/steam" ]] ||
        fail "Extracted archive is missing the steam/ folder."

    [[ -d "$extract_dir/platform" ]] ||
        fail "Extracted archive is missing the platform/ folder."

    create_backups "$extract_dir"

    mkdir -p "$GAME_DIR/steam" "$GAME_DIR/platform"

    cp -a -- "$extract_dir/steam/." "$GAME_DIR/steam/"
    cp -a -- "$extract_dir/platform/." "$GAME_DIR/platform/"
}

fix_is_installed() {
    local revision_file="$GAME_DIR/.pbz-fix-install-revision"
    local manifest_file="$GAME_DIR/.pbz-fix-files.sha256"
    local installed_revision

    [[ "${FORCE_INSTALL:-0}" != "1" ]] || return 1
    [[ -f "$revision_file" && -f "$manifest_file" ]] || return 1
    [[ -f "$GAME_DIR/platform/steam/PBZ.exe" ]] || return 1

    IFS= read -r installed_revision < "$revision_file" || return 1
    [[ "$installed_revision" == "$INSTALL_REVISION" ]] || return 1

    (cd "$GAME_DIR" && sha256sum --check --status "$manifest_file")
}

write_install_manifest() {
    local extract_dir="$1"
    local manifest_file="$GAME_DIR/.pbz-fix-files.sha256"
    local revision_file="$GAME_DIR/.pbz-fix-install-revision"
    local manifest_temp="$manifest_file.tmp.$$"
    local revision_temp="$revision_file.tmp.$$"
    local relative_path

    (
        cd "$GAME_DIR"
        while IFS= read -r -d '' relative_path; do
            sha256sum -- "$relative_path"
        done < <(
            cd "$extract_dir"
            find steam platform -type f -print0 | sort -z
        )
    ) > "$manifest_temp" ||
        fail "Failed to write the fix integrity manifest."

    [[ -s "$manifest_temp" ]] ||
        fail "The extracted fix contains no files to verify."

    printf '%s\n' "$INSTALL_REVISION" > "$revision_temp"
    mv -- "$manifest_temp" "$manifest_file"
    mv -- "$revision_temp" "$revision_file"
}

prepare_game() {
    if ! detect_steam; then
        fail "Steam could not be found."
    fi

    if ! find_game_directory; then
        fail "Phantom Blade Zero is not installed."
    fi
}

prepare_runtime() {
    prepare_game
    if ! find_newest_proton; then
        fail "No installed GE-Proton installation was found."
    fi

    log "Using GE-Proton: $PROTON"
}

launch_detected_game() {
    local executable="$GAME_DIR/platform/steam/PBZ.exe"
    local windows_path
    local launch_status=0

    [[ -f "$executable" ]] ||
        fail "Game executable not found: $executable"

    export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_ROOT"
    export STEAM_COMPAT_DATA_PATH="$STEAM_ROOT/steamapps/compatdata/$APP_ID"
    export SteamAppId="$APP_ID"
    export SteamGameId="$APP_ID"
    mkdir -p "$STEAM_COMPAT_DATA_PATH"

    cd "$GAME_DIR/platform/steam"
    windows_path="Z:${executable//\//\\}"

    if "$PROTON" run "$windows_path"; then
        log "Game exited successfully."
        return 0
    else
        launch_status=$?
    fi

    printf '%s\n' \
        "The game exited unexpectedly." \
        "To collect a Proton log, launch with PROTON_LOG=1 and inspect:" \
        "$HOME/steam-$APP_ID.log"
    return "$launch_status"
}

install_fix() {
    prepare_runtime

    if fix_is_installed; then
        log "Fix is already installed and verified; skipping download and installation."
    else
        log "Downloading or locating the fix archive..."
        download_fix

        log "Validating fix ZIP..."
        validate_zip
        log "Fix ZIP validation passed."

        log "Extracting, backing up, and installing fix..."
        extract_and_install

        [[ -f "$GAME_DIR/platform/steam/PBZ.exe" ]] ||
            fail "Post-install verification failed: $GAME_DIR/platform/steam/PBZ.exe does not exist."

        write_install_manifest "$TEMP_DIR/extracted"
        log "Post-install verification passed."
    fi

    launch_detected_game
    cleanup
}

force_install_fix() {
    FORCE_INSTALL=1 install_fix
}

launch_game() {
    prepare_runtime
    launch_detected_game
}

launch_game_with_log() {
    export PROTON_LOG=1
    log "Proton logging enabled for this launch."
    launch_game
}

latest_backup() {
    local -a backups=()

    while IFS= read -r -d '' backup; do
        backups+=("$backup")
    done < <(
        find "$HOME" \
            -maxdepth 1 \
            -mindepth 1 \
            -type d \
            -name 'pbz-backup-*' \
            -print0 |
            sort -z
    )

    if ((${#backups[@]} > 0)); then
        printf '%s' "${backups[${#backups[@]}-1]}"
    fi
}

confirm_action() {
    local prompt="$1"
    local answer

    [[ -r /dev/tty ]] ||
        fail "This action requires an interactive terminal."

    IFS= read -r -p "$prompt [y/N] " answer </dev/tty || return 1
    [[ "${answer,,}" == "y" || "${answer,,}" == "yes" ]]
}

uninstall_fix() {
    local backup_dir=""
    local backup_pointer
    local managed_list
    local relative_path
    local backup_file
    local game_file
    local -a fallback_files=(
        "platform/steam/PBZ.exe"
        "platform/steam/steam_api64.dll"
    )

    prepare_game
    backup_pointer="$GAME_DIR/.pbz-fix-original-backup"
    if [[ -r "$backup_pointer" ]]; then
        IFS= read -r backup_dir < "$backup_pointer" || backup_dir=""
        case "$backup_dir" in
            "$HOME"/pbz-backup-*)
                [[ -d "$backup_dir" ]] || backup_dir=""
                ;;
            *)
                backup_dir=""
                ;;
        esac
    fi

    if [[ -z "$backup_dir" ]]; then
        backup_dir="$(latest_backup)"
    fi

    [[ -n "$backup_dir" ]] ||
        fail "No PBZ backup directory was found under $HOME."

    log "Selected backup: $backup_dir"
    if ! confirm_action "Restore this backup and remove the fix files?"; then
        log "Uninstall cancelled."
        return 0
    fi

    managed_list="$backup_dir/.pbz-fix-managed-files.nul"
    if [[ -f "$managed_list" ]]; then
        while IFS= read -r -d '' relative_path; do
            if [[ "$relative_path" != steam/* &&
                  "$relative_path" != platform/* ]]; then
                fail "Backup contains an invalid managed path: $relative_path"
            fi

            backup_file="$backup_dir/$relative_path"
            game_file="$GAME_DIR/$relative_path"

            if [[ -f "$backup_file" || -L "$backup_file" ]]; then
                mkdir -p "$(dirname "$game_file")"
                cp -a -- "$backup_file" "$game_file"
                log "Restored $relative_path"
            elif [[ -f "$game_file" || -L "$game_file" ]]; then
                rm -f -- "$game_file"
                log "Removed fix-added file $relative_path"
            fi
        done < "$managed_list"
    else
        log "WARNING: This is a legacy backup; restoring only the files it contains."
        log "Other files added by the fix may remain in the game folder."
        for relative_path in "${fallback_files[@]}"; do
            backup_file="$backup_dir/$relative_path"
            if [[ -f "$backup_file" || -L "$backup_file" ]]; then
                game_file="$GAME_DIR/$relative_path"
                mkdir -p "$(dirname "$game_file")"
                cp -a -- "$backup_file" "$game_file"
                log "Restored $relative_path"
            fi
        done
    fi

    rm -f -- \
        "$GAME_DIR/.pbz-fix-install-revision" \
        "$GAME_DIR/.pbz-fix-files.sha256" \
        "$GAME_DIR/.pbz-fix-original-backup"
    log "Uninstall/restore completed. Backup retained at $backup_dir"
}

show_status() {
    printf 'PBZ-Fix version: %s\n' "$SCRIPT_VERSION"

    if detect_steam; then
        printf 'Steam: %s\n' "$STEAM_ROOT"
        if find_game_directory; then
            printf 'Game: %s\n' "$GAME_DIR"
            if fix_is_installed; then
                printf 'Fix: installed and verified\n'
            elif [[ -e "$GAME_DIR/.pbz-fix-install-revision" ]]; then
                printf 'Fix: marker found, but files need repair or reinstall\n'
            else
                printf 'Fix: not installed by this installer\n'
            fi
        else
            printf 'Game: not found\n'
        fi
    else
        printf 'Steam: not found in standard locations\n'
    fi

    if find_newest_proton; then
        printf 'GE-Proton: %s\n' "$PROTON"
    else
        printf 'GE-Proton: not found\n'
    fi

    local backup_dir
    backup_dir="$(latest_backup)"
    if [[ -n "$backup_dir" ]]; then
        printf 'Latest backup: %s\n' "$backup_dir"
    else
        printf 'Latest backup: none\n'
    fi
}

write_diagnostics() {
    local os_name="Unknown Linux"
    local backup_dir

    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        os_name="${PRETTY_NAME:-$os_name}"
    fi

    printf 'PBZ-Fix diagnostic report\n'
    printf 'Generated: %s\n' "$(date --iso-8601=seconds)"
    printf 'Script version: %s\n' "$SCRIPT_VERSION"
    printf 'OS: %s\n' "$os_name"
    printf 'Kernel: %s\n' "$(uname -sr)"
    printf 'Bash: %s\n' "$BASH_VERSION"
    printf 'User home: %s\n' "$HOME"
    printf 'GitHub CLI installed: %s\n' "$(command -v gh || printf 'no')"
    printf 'Curl installed: %s\n' "$(command -v curl || printf 'no')"
    printf 'Unzip installed: %s\n' "$(command -v unzip || printf 'no')"

    if detect_steam; then
        printf 'Steam root: %s\n' "$STEAM_ROOT"
        if find_game_directory; then
            printf 'Game directory: %s\n' "$GAME_DIR"
            if fix_is_installed; then
                printf 'Fix state: installed and verified\n'
            else
                printf 'Fix state: missing, changed, or requires reinstall\n'
            fi
        else
            printf 'Game directory: not found\n'
        fi
    else
        printf 'Steam root: not found\n'
    fi

    if find_newest_proton; then
        printf 'GE-Proton: %s\n' "$PROTON"
    else
        printf 'GE-Proton: not found\n'
    fi

    backup_dir="$(latest_backup)"
    printf 'Latest backup: %s\n' "${backup_dir:-none}"
    if [[ -f "$HOME/steam-$APP_ID.log" ]]; then
        printf 'Proton log: %s\n' "$HOME/steam-$APP_ID.log"
        stat -c 'Proton log modified: %y' "$HOME/steam-$APP_ID.log"
    else
        printf 'Proton log: not present\n'
    fi

    printf '\nDiagnostic logs do not include environment variables or Proton log contents.\n'
    printf 'Review local paths/usernames before sharing this file.\n'
}

print_banner() {
    cat <<'BANNER'
 ____  ____ ______      _____ _ _
|  _ \| __ )__  /      |  ___(_|_)
| |_) |  _ \ / / _____ | |_   | |
|  __/| |_) / /_|_____| |  _|  | |
|_|   |____/____|       |_|    |_|
                 PBZ-FIX
          PHANTOM BLADE ZERO TOOL
BANNER
    printf 'Version %s\n\n' "$SCRIPT_VERSION"
}

run_logged_action() {
    local action_name="$1"
    local log_file

    shift
    mkdir -p "$HOME/Desktop"
    log_file="$(
        mktemp --tmpdir="$HOME/Desktop" \
            "PBZ-fix-$(date '+%Y%m%d-%H%M%S')-XXXXXX.log"
    )"
    printf 'Action log: %s\n' "$log_file"

    exec 3>&1 4>&2
    exec > >(tee -a "$log_file") 2>&1
    log "Starting: $action_name"
    "$@"
    log "Completed: $action_name"
    exec 1>&3 2>&4
    exec 3>&- 4>&-
    printf 'Log saved to: %s\n' "$log_file"
}

show_menu() {
    local choice

    while true; do
        print_banner
        printf '%s\n' \
            "1) Install/repair fix and launch game" \
            "2) Force reinstall/update and launch" \
            "3) Launch game" \
            "4) Launch game with Proton logging" \
            "5) Uninstall/restore original files" \
            "6) Create diagnostic log on Desktop" \
            "7) Show installation status" \
            "0) Exit"

        if ! IFS= read -r -p $'\nSelect an option: ' choice </dev/tty; then
            log "Could not read menu selection."
            return 1
        fi

        case "$choice" in
            1) run_logged_action "Install/update and launch" install_fix ;;
            2) run_logged_action "Force reinstall/update and launch" force_install_fix ;;
            3) run_logged_action "Launch game" launch_game ;;
            4) run_logged_action "Launch with Proton logging" launch_game_with_log ;;
            5) run_logged_action "Uninstall/restore" uninstall_fix ;;
            6) run_logged_action "Diagnostic report" write_diagnostics ;;
            7) run_logged_action "Status report" show_status ;;
            0) log "Goodbye."; return 0 ;;
            *) log "Choose one of the listed options." ;;
        esac

        printf '\n'
    done
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
    require_command sha256sum
    require_command sort
    require_command tee

    case "${1:-}" in
        --install) run_logged_action "Install/update and launch" install_fix ;;
        --force-install) run_logged_action "Force reinstall/update and launch" force_install_fix ;;
        --launch) run_logged_action "Launch game" launch_game ;;
        --launch-log) run_logged_action "Launch with Proton logging" launch_game_with_log ;;
        --uninstall) run_logged_action "Uninstall/restore" uninstall_fix ;;
        --diagnostics) run_logged_action "Diagnostic report" write_diagnostics ;;
        --status) run_logged_action "Status report" show_status ;;
        --help|-h)
            printf 'Usage: %s [--install|--force-install|--launch|--launch-log|--uninstall|--diagnostics|--status]\n' "$0"
            printf 'With no option, show the interactive menu (or install when no terminal is available).\n'
            ;;
        "")
            if [[ -r /dev/tty ]]; then
                show_menu
            else
                log "No interactive terminal detected; installing and launching."
                run_logged_action "Install/update and launch" install_fix
            fi
            ;;
        *)
            fail "Unknown option: $1 (use --help for usage)."
            ;;
    esac
}

main "$@"
