#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

mkdir -p "$TEST_ROOT/bin"
export PATH="$TEST_ROOT/bin:$PATH"
export FAKE_CALLS="$TEST_ROOT/calls"
export FAKE_REMOTE="$TEST_ROOT/remote-installer.sh"
export FAKE_MODE="success"
: > "$FAKE_CALLS"

cat > "$TEST_ROOT/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
url=""
output=""
while (($#)); do
    case "$1" in
        https://*) url="$1"; shift ;;
        --output) output="$2"; shift 2 ;;
        *) shift ;;
    esac
done
printf '%s\n' "$url" >> "$FAKE_CALLS"
case "$url" in
    https://api.github.com/repos/Timmybread22/pbz-fix/commits/main)
        [[ "$FAKE_MODE" != "api-fail" ]] || exit 1
        printf '{"sha":"0123456789abcdef0123456789abcdef01234567"}\n'
        ;;
    https://raw.githubusercontent.com/Timmybread22/pbz-fix/0123456789abcdef0123456789abcdef01234567/install-pbz-fix.sh)
        [[ "$FAKE_MODE" != "download-fail" ]] || exit 1
        cp "$FAKE_REMOTE" "$output"
        ;;
    *) printf 'Unexpected URL: %s\n' "$url" >&2; exit 1 ;;
esac
EOF
chmod +x "$TEST_ROOT/bin/curl"

sed 's/^SCRIPT_VERSION="2.15"$/SCRIPT_VERSION="2.16"/' \
    "$SCRIPT_DIR/install-pbz-fix.sh" > "$FAKE_REMOTE"
output="$(cat "$SCRIPT_DIR/install-pbz-fix.sh" | bash -s -- --help)"
grep -q 'Running installer version 2.16' <<<"$output"
grep -q '^Usage:' <<<"$output"
[[ "$(wc -l < "$FAKE_CALLS")" -eq 2 ]]

: > "$FAKE_CALLS"
if output="$(cat "$SCRIPT_DIR/install-pbz-fix.sh" | bash -s -- --unexpected 2>&1)"; then
    printf 'Unknown option should fail after re-execution.\n' >&2
    exit 1
fi
grep -q 'Unknown option: --unexpected' <<<"$output"
[[ "$(wc -l < "$FAKE_CALLS")" -eq 2 ]]

cp "$SCRIPT_DIR/install-pbz-fix.sh" "$FAKE_REMOTE"
: > "$FAKE_CALLS"
output="$(cat "$SCRIPT_DIR/install-pbz-fix.sh" | bash -s -- --help)"
grep -q '^Usage:' <<<"$output"
[[ "$output" != *"Running installer version"* ]]
[[ "$(wc -l < "$FAKE_CALLS")" -eq 2 ]]

for FAKE_MODE in api-fail download-fail; do
    export FAKE_MODE
    : > "$FAKE_CALLS"
    output="$(cat "$SCRIPT_DIR/install-pbz-fix.sh" | bash -s -- --help)"
    grep -q 'continuing with version 2.15' <<<"$output"
    grep -q '^Usage:' <<<"$output"
done
export FAKE_MODE="success"

printf 'SCRIPT_VERSION="2.16"\nif\n' > "$FAKE_REMOTE"
output="$(cat "$SCRIPT_DIR/install-pbz-fix.sh" | bash -s -- --help)"
grep -q 'Update download failed; continuing with version 2.15' <<<"$output"
grep -q '^Usage:' <<<"$output"

printf 'SCRIPT_VERSION="invalid"\n' > "$FAKE_REMOTE"
output="$(cat "$SCRIPT_DIR/install-pbz-fix.sh" | bash -s -- --help)"
grep -q 'Update version invalid; continuing with version 2.15' <<<"$output"
grep -q '^Usage:' <<<"$output"

cat > "$FAKE_REMOTE" <<'EOF'
#!/usr/bin/env bash
SCRIPT_VERSION="2.16"
printf 'Refresh terminal prompt: '
IFS= read -r answer </dev/tty
printf 'TTY=%s ARG=%s GUARD=%s\n' "$answer" "$1" "${PBZ_FIX_REEXEC:-}"
EOF
python3 - "$SCRIPT_DIR/install-pbz-fix.sh" <<'PY'
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
        'cat "$1" | bash -s -- "argument with spaces"',
        "refresh-test", sys.argv[1],
    )
output = bytearray()
answered = False
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
        if b"Refresh terminal prompt:" in output and not answered:
            os.write(terminal, b"confirmed\n")
            answered = True
        result, child_status = os.waitpid(child, os.WNOHANG)
        if result == child:
            status = child_status
            break
    if status is None:
        os.kill(child, signal.SIGKILL)
        os.waitpid(child, 0)
        raise AssertionError(f"Refresh terminal test timed out: {output!r}")
    while select.select([terminal], [], [], 0.1)[0]:
        try:
            chunk = os.read(terminal, 4096)
        except OSError:
            break
        if not chunk:
            break
        output.extend(chunk)
    assert os.waitstatus_to_exitcode(status) == 0, output
    assert b"TTY=confirmed ARG=argument with spaces GUARD=1" in output, output
finally:
    os.close(terminal)
PY

: > "$FAKE_CALLS"
output="$(cat "$SCRIPT_DIR/install-pbz-fix.sh" | PBZ_FIX_NO_UPDATE=1 bash -s -- --help)"
grep -q '^Usage:' <<<"$output"
[[ ! -s "$FAKE_CALLS" ]]
output="$(cat "$SCRIPT_DIR/install-pbz-fix.sh" | PBZ_FIX_REEXEC=1 bash -s -- --help)"
grep -q '^Usage:' <<<"$output"
[[ ! -s "$FAKE_CALLS" ]]
output="$(bash "$SCRIPT_DIR/install-pbz-fix.sh" --help)"
grep -q '^Usage:' <<<"$output"
[[ ! -s "$FAKE_CALLS" ]]

printf 'Piped installer invocation test passed.\n'
