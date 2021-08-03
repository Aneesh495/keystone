#!/usr/bin/env bash
# Keystone Lifecycle Management Script
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

echo "================================================================"
echo "               KEYSTONE APPLICATION BOOTSTRAP                   "
echo "================================================================"

# Check if CommandBox is installed
if ! command -v box >/dev/null 2>&1; then
    echo "ERROR: CommandBox ('box') is required but not installed."
    echo "Install via: brew install commandbox"
    exit 1
fi

# Ensure native library is compiled
if [[ ! -f "$ROOT_DIR/lib/libkeystone_accel.dylib" && ! -f "$ROOT_DIR/lib/libkeystone_accel.so" ]]; then
    echo "Compiling native acceleration library..."
    make build-native || true
fi

# Start server via bin/keystone
echo "Starting Keystone Gateway..."
"$ROOT_DIR/bin/keystone" start

echo ""
echo "Verifying server health..."
"$ROOT_DIR/bin/keystone" health

echo ""
echo "Keystone is active:"
echo "  Control Plane:  http://127.0.0.1:8088"
echo "  REST API:       http://127.0.0.1:8088/api/v1"
echo "  Prometheus:     http://127.0.0.1:8088/api/v1/metrics"
echo "================================================================"
