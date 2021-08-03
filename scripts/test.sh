#!/usr/bin/env bash
# Keystone Automated Test Matrix Runner
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

echo "Executing Keystone automated test matrix..."
"$ROOT_DIR/bin/test_runner"
