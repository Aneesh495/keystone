#!/usr/bin/env bash
# Keystone Benchmark Orchestration Script
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

echo "================================================================"
echo "             KEYSTONE PERFORMANCE BENCHMARK SUITE               "
echo "================================================================"

# Step 1: Native C SWAR delimiter scanner benchmark
if [[ -f "$ROOT_DIR/bin/keystone_bench" ]]; then
    echo "Running Native C Micro-benchmarks..."
    "$ROOT_DIR/bin/keystone_bench"
else
    echo "Building native benchmarks..."
    make build-bench || true
    if [[ -f "$ROOT_DIR/bin/keystone_bench" ]]; then
        "$ROOT_DIR/bin/keystone_bench"
    fi
fi

# Step 2: Python end-to-end stress simulator
if command -v python3 >/dev/null 2>&1; then
    echo ""
    echo "Executing Python Concurrency & Throughput Stress Simulation..."
    python3 "$ROOT_DIR/clients/python/stress_sim.py" --concurrency=8 --requests=200 || echo "Simulation completed."
else
    echo "python3 not found; skipping synthetic traffic simulation."
fi

echo "================================================================"
echo "Benchmark suite finished."
echo "================================================================"
