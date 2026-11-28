#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
output="$(cat "$SCRIPT_DIR/install-pbz-fix.sh" | bash -s -- --help)"

grep -q '^Usage:' <<<"$output"
printf 'Piped installer invocation test passed.\n'
