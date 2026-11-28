#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

export HOME="$TEST_ROOT/home"
export FIX_ZIP="$TEST_ROOT/fix.zip"
export TEST_STEAM_RUNNING="$TEST_ROOT/steam-running"
mkdir -p "$HOME/.local/share/Steam/steamapps/common/PBZ Game"

STEAM_ROOT="$HOME/.local/share/Steam"
GAME_DIR="$STEAM_ROOT/steamapps/common/PBZ Game"
INSTALL_DIR="$HOME/.local/share/pbz-fix"
CONFIG="$STEAM_ROOT/userdata/100/config/localconfig.vdf"
TEST_REVISION="0123456789abcdef0123456789abcdef01234567"

cat > "$STEAM_ROOT/steam" <<'EOF'
#!/usr/bin/env bash
[[ "${1:-}" == "-shutdown" ]] || exit 1
rm -f -- "$TEST_STEAM_RUNNING"
EOF
chmod +x "$STEAM_ROOT/steam"
touch "$TEST_STEAM_RUNNING"

cat > "$STEAM_ROOT/steamapps/appmanifest_4115450.acf" <<'EOF'
"AppState"
{
    "installdir" "PBZ Game"
}
EOF

mkdir -p "$(dirname "$CONFIG")"
cat > "$CONFIG" <<'EOF'
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
                }
            }
        }
    }
}
EOF

python3 - "$FIX_ZIP" <<'PY'
import stat
import sys
import zipfile

archive_path = sys.argv[1]
with zipfile.ZipFile(archive_path, "w") as archive:
    archive.writestr("steam/PBZ.exe", "original executable\n")
    executable = zipfile.ZipInfo("platform/steam/PBZ.exe")
    executable.create_system = 3
    executable.external_attr = (stat.S_IFREG | 0o755) << 16
    archive.writestr(
        executable,
        '#!/usr/bin/env bash\nprintf "%s\\0" "$@" > "$CAPTURE_ARGS"\n',
    )
PY

# shellcheck source=../install-pbz-fix.sh
source "$REPO_ROOT/install-pbz-fix.sh"

confirm_steam_shutdown() {
    SHUTDOWN_CONFIRMED=1
}

steam_is_running() {
    [[ -e "$TEST_STEAM_RUNNING" ]]
}

curl() {
    local url=""
    local output=""

    while (($#)); do
        case "$1" in
            --output)
                output="$2"
                shift 2
                ;;
            https://*)
                url="$1"
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    case "$url" in
        */commits/*)
            printf '{"sha":"%s"}\n' "$TEST_REVISION"
            ;;
        */install-pbz-fix.sh)
            cp "$REPO_ROOT/install-pbz-fix.sh" "$output"
            ;;
        */steam-launch-beta.sh)
            cp "$REPO_ROOT/steam-launch-beta.sh" "$output"
            ;;
        */steam-launch-config.py)
            cp "$REPO_ROOT/steam-launch-config.py" "$output"
            ;;
        *)
            printf 'Unexpected mocked curl URL: %s\n' "$url" >&2
            return 1
            ;;
    esac
}

setup_steam_launch

[[ "${SHUTDOWN_CONFIRMED:-0}" == 1 ]]
[[ ! -e "$TEST_STEAM_RUNNING" ]]
[[ -f "$GAME_DIR/platform/steam/PBZ.exe" ]]
[[ "$(cat "$GAME_DIR/.pbz-fix-install-revision")" == "$INSTALL_REVISION" ]]
[[ -x "$INSTALL_DIR/steam-launch-beta.sh" ]]

python3 - "$REPO_ROOT/steam-launch-config.py" "$CONFIG" "$INSTALL_DIR" <<'PY'
import importlib.util
import sys
from pathlib import Path

module_spec = importlib.util.spec_from_file_location("steam_launch_config", sys.argv[1])
config = importlib.util.module_from_spec(module_spec)
module_spec.loader.exec_module(config)
text = Path(sys.argv[2]).read_text(encoding="utf-8")
options = config.app_settings(text)[2]
expected = f'bash "{Path(sys.argv[3]).resolve()}/steam-launch-beta.sh" %command%'
assert len(options) == 1
assert options[0]["value"] == expected
PY

export CAPTURE_ARGS="$TEST_ROOT/captured-args"
bash "$INSTALL_DIR/steam-launch-beta.sh" \
    "$GAME_DIR/steam/PBZ.exe" \
    "argument with spaces" \
    "--custom=two words"

mapfile -d '' -t captured_args < "$CAPTURE_ARGS"
[[ "${#captured_args[@]}" == 2 ]]
[[ "${captured_args[0]}" == "argument with spaces" ]]
[[ "${captured_args[1]}" == "--custom=two words" ]]

python3 - "$REPO_ROOT" <<'PY'
import os
import pty
import select
import sys
import time

repo_root = sys.argv[1]
command = r'''
source "$1/install-pbz-fix.sh"
setup_steam_launch() { printf 'MOCK_SETUP_CALLED\n'; }
install_fix() { printf 'WRONG_INSTALL_FIX_CALLED\n'; }
show_menu
'''
child, terminal = pty.fork()
if child == 0:
    os.execlp("bash", "bash", "-c", command, "menu-option-test", repo_root)

output = bytearray()
os.write(terminal, b"1\n0\n")
deadline = time.monotonic() + 10
status = None
while time.monotonic() < deadline:
    ready, _, _ = select.select([terminal], [], [], 0.1)
    if ready:
        try:
            output.extend(os.read(terminal, 4096))
        except OSError:
            break
    result, child_status = os.waitpid(child, os.WNOHANG)
    if result == child:
        status = child_status
        break

if status is None:
    os.kill(child, 9)
    os.waitpid(child, 0)
    raise AssertionError("Menu test process timed out.")

while select.select([terminal], [], [], 0.1)[0]:
    try:
        chunk = os.read(terminal, 4096)
    except OSError:
        break
    if not chunk:
        break
    output.extend(chunk)
os.close(terminal)
assert os.waitstatus_to_exitcode(status) == 0
text = output.decode(errors="replace")
assert "1) Install/repair, check saves, and set up Steam launch" in text
assert "9) Undo Steam launch wrapper" in text
assert "10) Undo Steam launch wrapper" not in text
assert "9) Set up Steam launch wrapper" not in text
assert "MOCK_SETUP_CALLED" in text
assert "WRONG_INSTALL_FIX_CALLED" not in text
PY

printf 'Steam launch setup and wrapper tests passed.\n'
