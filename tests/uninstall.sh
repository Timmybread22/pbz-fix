#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

export PYTHONDONTWRITEBYTECODE=1
mkdir -p "$TEST_ROOT/bin"
export PATH="$TEST_ROOT/bin:$PATH"
export TEST_STEAM_RUNNING="$TEST_ROOT/steam-running"
export TEST_EVENTS="$TEST_ROOT/events"

cat > "$TEST_ROOT/bin/steam" <<'EOF'
#!/usr/bin/env bash
[[ "${1:-}" == "-shutdown" ]] || exit 1
printf 'shutdown\n' >> "$TEST_EVENTS"
rm -f -- "$TEST_STEAM_RUNNING"
EOF
chmod +x "$TEST_ROOT/bin/steam"

# shellcheck source=../install-pbz-fix.sh
source "$REPO_ROOT/install-pbz-fix.sh"

steam_is_running() {
    [[ -e "$TEST_STEAM_RUNNING" ]]
}

make_fixture() {
    export HOME="$TEST_ROOT/$1"
    local game="$HOME/.local/share/Steam/steamapps/common/PBZ"
    local extract="$HOME/extracted"
    mkdir -p "$game/steam" "$extract/steam" "$extract/platform/steam"
    printf 'original\n' > "$game/steam/existing.dll"
    printf 'replacement\n' > "$extract/steam/existing.dll"
    printf 'added\n' > "$extract/platform/steam/PBZ.exe"
    GAME_DIR="$game"
    create_backups "$extract" >/dev/null
    printf 'patched\n' > "$game/steam/existing.dll"
    mkdir -p "$game/platform/steam"
    printf 'added\n' > "$game/platform/steam/PBZ.exe"
    printf '3\n' > "$game/.pbz-fix-install-revision"
    : > "$TEST_EVENTS"
    touch "$TEST_STEAM_RUNNING"
}

write_wrapper_config() {
    local install_dir="$HOME/.local/share/pbz-fix"
    local config="$HOME/.local/share/Steam/userdata/100/config/localconfig.vdf"
    mkdir -p "$install_dir" "$(dirname "$config")"
    cp "$REPO_ROOT/steam-launch-config.py" "$install_dir/steam-launch-config.py"
    cat > "$config" <<'EOF'
"UserLocalConfigStore"
{
    "Software"
    {
        "Valve"
        {
            "Steam"
            {
                "apps"
                {
                    "4115450"
                    {
                        "LaunchOptions" "bash ~/pbz-fix-beta/steam-launch-beta.sh %command%"
                        "Other" "keep"
                    }
                }
            }
        }
    }
}
EOF
}

assert_unwrapped() {
    python3 - "$REPO_ROOT/steam-launch-config.py" \
        "$HOME/.local/share/Steam/userdata/100/config/localconfig.vdf" <<'PY'
import importlib.util
import sys
from pathlib import Path

spec = importlib.util.spec_from_file_location("config", sys.argv[1])
config = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config)
text = Path(sys.argv[2]).read_text(encoding="utf-8")
assert config.app_settings(text)[2][0]["value"] == ""
assert '"Other" "keep"' in text
PY
}

make_fixture with-backup
write_wrapper_config
python3 "$HOME/.local/share/pbz-fix/steam-launch-config.py" setup \
    --steam-root "$HOME/.local/share/Steam" \
    --install-dir "$HOME/.local/share/pbz-fix"
main --uninstall
[[ ! -e "$TEST_STEAM_RUNNING" ]]
[[ "$(cat "$TEST_EVENTS")" == "shutdown" ]]
[[ "$(cat "$GAME_DIR/steam/existing.dll")" == "original" ]]
[[ ! -e "$GAME_DIR/platform/steam/PBZ.exe" ]]
[[ ! -e "$HOME/.local/share/pbz-fix/steam-launch-backup.json" ]]
assert_unwrapped

make_fixture unrelated-backup
write_wrapper_config
config="$HOME/.local/share/Steam/userdata/100/config/localconfig.vdf"
sed 's|bash ~/pbz-fix-beta/steam-launch-beta.sh %command%|MANGOHUD=1 %command%|' \
    "$config" > "$config.tmp"
mv "$config.tmp" "$config"
python3 - "$HOME/.local/share/pbz-fix/steam-launch-config.py" \
    "$HOME/.local/share/Steam" "$HOME/.local/share/pbz-fix" <<'PY'
import importlib.util
import sys

spec = importlib.util.spec_from_file_location("config", sys.argv[1])
config = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config)
config.setup_launch_options(sys.argv[2], sys.argv[3])
PY
main --uninstall
grep -q 'MANGOHUD=1 %command%' "$config"
[[ "$(cat "$GAME_DIR/steam/existing.dll")" == "original" ]]

make_fixture without-backup
write_wrapper_config
config="$HOME/.local/share/Steam/userdata/100/config/localconfig.vdf"
sed 's/steam-launch-beta.sh/steam-launch.sh/' "$config" > "$config.tmp"
mv "$config.tmp" "$config"
main --uninstall
[[ ! -e "$TEST_STEAM_RUNNING" ]]
[[ "$(cat "$GAME_DIR/steam/existing.dll")" == "original" ]]
assert_unwrapped

make_fixture no-setup
main --uninstall
[[ ! -e "$TEST_STEAM_RUNNING" ]]
[[ "$(cat "$GAME_DIR/steam/existing.dll")" == "original" ]]

make_fixture custom-wrapper
write_wrapper_config
config="$HOME/.local/share/Steam/userdata/100/config/localconfig.vdf"
sed 's/steam-launch-beta.sh %command%/steam-launch-beta.sh --custom %command%/' \
    "$config" > "$config.tmp"
mv "$config.tmp" "$config"
if output="$(main --uninstall 2>&1)"; then
    printf 'Customized wrapper should require manual removal.\n' >&2
    exit 1
fi
[[ "$output" == *"requires manual removal"* ]]
[[ "$(cat "$GAME_DIR/steam/existing.dll")" == "patched" ]]
[[ -e "$GAME_DIR/.pbz-fix-original-backup" ]]

make_fixture missing-helper
write_wrapper_config
rm "$HOME/.local/share/pbz-fix/steam-launch-config.py"
if output="$(main --uninstall 2>&1)"; then
    printf 'Missing wrapper helper should stop uninstall.\n' >&2
    exit 1
fi
[[ "$output" == *"Steam launch helper is missing"* ]]
[[ "$(cat "$GAME_DIR/steam/existing.dll")" == "patched" ]]

make_fixture bad-backup
write_wrapper_config
printf 'invalid json\n' > "$HOME/.local/share/pbz-fix/steam-launch-backup.json"
if output="$(main --uninstall 2>&1)"; then
    printf 'Invalid Steam backup should stop uninstall.\n' >&2
    exit 1
fi
[[ "$output" == *"Could not restore the Steam launch configuration."* ]]
[[ "$(cat "$GAME_DIR/steam/existing.dll")" == "patched" ]]

make_fixture steam-restarts
if output="$(
    checks=0
    steam_is_running() {
        checks=$((checks + 1))
        if ((checks == 4)); then
            touch "$TEST_STEAM_RUNNING"
        fi
        [[ -e "$TEST_STEAM_RUNNING" ]]
    }
    main --uninstall 2>&1
)"; then
    printf 'A Steam restart should stop uninstall.\n' >&2
    exit 1
fi
[[ "$output" == *"Steam restarted."* ]]
[[ "$(cat "$GAME_DIR/steam/existing.dll")" == "patched" ]]
[[ -e "$GAME_DIR/.pbz-fix-original-backup" ]]

python3 - "$REPO_ROOT" <<'PY'
import os
import pty
import select
import signal
import sys
import time

child, terminal = pty.fork()
if child == 0:
    os.execlp(
        "bash", "bash", "-c",
        'source "$1/install-pbz-fix.sh"; uninstall_fix() { echo MENU_UNINSTALL; }; show_menu',
        "menu-uninstall-test", sys.argv[1],
    )
output = bytearray()
os.write(terminal, b"5\n0\n")
status = None
deadline = time.monotonic() + 10
try:
    while time.monotonic() < deadline:
        ready, _, _ = select.select([terminal], [], [], 0.1)
        if ready:
            try:
                output.extend(os.read(terminal, 4096))
            except OSError:
                pass
        result, child_status = os.waitpid(child, os.WNOHANG)
        if result == child:
            status = child_status
            break
    if status is None:
        os.kill(child, signal.SIGKILL)
        os.waitpid(child, 0)
        raise AssertionError(f"Uninstall menu test timed out: {output!r}")
    while select.select([terminal], [], [], 0.1)[0]:
        try:
            chunk = os.read(terminal, 4096)
        except OSError:
            break
        if not chunk:
            break
        output.extend(chunk)
    assert os.waitstatus_to_exitcode(status) == 0, output
    assert b"MENU_UNINSTALL" in output, output
finally:
    os.close(terminal)
PY

printf 'Uninstall shutdown and wrapper tests passed.\n'
