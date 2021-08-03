#!/usr/bin/env bash
# Keystone Full Verification & Quality Assurance Suite
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

echo "================================================================"
echo "          KEYSTONE COMPREHENSIVE VERIFICATION SUITE             "
echo "================================================================"

PASSED=0
FAILED=0

check_step() {
    local name="$1"
    shift
    echo -n "Checking: $name ... "
    if "$@"; then
        echo "[OK]"
        PASSED=$((PASSED + 1))
    else
        echo "[FAILED]"
        FAILED=$((FAILED + 1))
    fi
}

# 1. Verify Git commit count >= 53
verify_commit_count() {
    local count
    count=$(git rev-list --count HEAD)
    if [[ "$count" -ge 53 ]]; then
        return 0
    else
        echo "Commit count $count is below requirement (minimum 53)."
        return 1
    fi
}
check_step "Git commit count >= 53" verify_commit_count

# 2. Verify zero em dashes in source files, docs, and git commit history
verify_no_em_dashes() {
    # Check for Unicode em dash character (hex e2 80 94)
    local em_dash
    em_dash="$(printf '\xe2\x80\x94')"

    local dash_matches
    dash_matches=$(git grep -i -I -n "$em_dash" || true)
    if [[ -n "$dash_matches" ]]; then
        echo "Found disallowed em dash in files:"
        echo "$dash_matches"
        return 1
    fi

    # Check git commit messages for em dashes
    local commit_matches
    commit_matches=$(git log --format="%s" | grep "$em_dash" || true)
    if [[ -n "$commit_matches" ]]; then
        echo "Found disallowed em dash in commit messages:"
        echo "$commit_matches"
        return 1
    fi

    return 0
}
check_step "Zero em dashes in codebase and commit messages" verify_no_em_dashes

# 3. Verify server health check endpoint
verify_health_endpoint() {
    local resp
    resp=$(curl -s "http://127.0.0.1:8088/api/v1/health" || true)
    if [[ "$resp" == *"UP"* || "$resp" == *"status"* ]]; then
        return 0
    else
        echo "Health endpoint response unexpected: $resp"
        return 1
    fi
}
check_step "Keystone HTTP health check endpoint" verify_health_endpoint

# 4. Verify full automated test matrix (100% test pass)
verify_test_suite() {
    local test_out
    test_out=$("$ROOT_DIR/bin/test_runner")
    if [[ "$test_out" == *"ALL TEST SUITES PASSED CLEANLY"* ]]; then
        return 0
    else
        echo "$test_out"
        return 1
    fi
}
check_step "Full automated test matrix (100% pass)" verify_test_suite

# 5. Verify native C acceleration library presence
verify_native_lib() {
    if [[ -f "$ROOT_DIR/lib/libkeystone_accel.dylib" || -f "$ROOT_DIR/lib/libkeystone_accel.so" || \
          -f "$ROOT_DIR/native/lib/libkeystone_accel.dylib" || -f "$ROOT_DIR/native/lib/libkeystone_accel.so" ]]; then
        return 0
    else
        echo "Native library not found in lib/ or native/lib/"
        return 1
    fi
}
check_step "Native C acceleration library compiled" verify_native_lib

echo ""
echo "================================================================"
echo "VERIFICATION SUMMARY: $PASSED passed, $FAILED failed."
echo "================================================================"

if [[ "$FAILED" -gt 0 ]]; then
    exit 1
fi
