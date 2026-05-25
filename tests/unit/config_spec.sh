#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)/helpers/testlib.sh"
source "$REPO_ROOT/lib/config.sh"

TEST_DIR=$(make_test_dir)
trap 'rm -rf "$TEST_DIR"' EXIT

cat > "$TEST_DIR/safe-update.conf" <<'EOF'
SAFE_UPDATE_DATA_DIR="/tmp/custom-safe-update"
ENABLE_NOTIFICATIONS=false
ARCH_NEWS_URL="https://example.test/arch.xml"
ADVISORY_CACHE_TTL_SECONDS=900
UPDATE_SNAPSHOT_RETENTION=9
EOF

SAFE_UPDATE_CONFIG_FILE="$TEST_DIR/safe-update.conf"
TIMESTAMP="2026-05-22-2100"
ISO_TIMESTAMP="2026-05-22T21:00:00-06:00"
init_config "$REPO_ROOT"

assert_eq "/tmp/custom-safe-update" "$SAFE_UPDATE_DATA_DIR" "Config file should override the runtime data dir"
assert_eq "false" "$ENABLE_NOTIFICATIONS" "Config file should override feature flags"
assert_eq "https://example.test/arch.xml" "$ARCH_NEWS_URL" "Config file should override advisory feed URLs"
assert_eq "900" "$ADVISORY_CACHE_TTL_SECONDS" "Config file should override advisory cache settings"
assert_eq "9" "$UPDATE_SNAPSHOT_RETENTION" "Config file should override retention values"
assert_eq "/tmp/custom-safe-update/logs/update-2026-05-22-2100.log" "$LOG_FILE" "Derived log path should follow the configured data dir"
assert_eq "/tmp/custom-safe-update/logs" "$LOG_DIR" "LOG_DIR should match the derived log file directory"

SAFE_UPDATE_DATA_DIR=""
LOG_DIR=""
REPORT_DIR=""
CACHE_DIR=""
STATE_DIR=""
LOG_FILE=""
REPORT_FILE=""
SNAPSHOT_NAME=""
init_config "$REPO_ROOT"

assert_eq "/tmp/custom-safe-update" "$SAFE_UPDATE_DATA_DIR" "An empty SAFE_UPDATE_DATA_DIR env var should not override config/defaults"
assert_eq "/tmp/custom-safe-update/logs/update-2026-05-22-2100.log" "$LOG_FILE" "Derived log path should ignore an empty SAFE_UPDATE_DATA_DIR env var"

ENABLE_ARCH_NEWS=false
ARCH_NEWS_URL="https://override.test/arch.xml"
init_config "$REPO_ROOT"

assert_eq "false" "$ENABLE_ARCH_NEWS" "Environment variables should override config-provided advisory feature flags"
assert_eq "https://override.test/arch.xml" "$ARCH_NEWS_URL" "Environment variables should override config-provided advisory URLs"

cat > "$TEST_DIR/custom-paths.conf" <<'EOF'
SAFE_UPDATE_DATA_DIR="/tmp/ignored-by-custom-files"
LOG_FILE="/tmp/safe-update-custom/logs/custom.log"
REPORT_FILE="/tmp/safe-update-custom/reports/custom.json"
EOF

SAFE_UPDATE_CONFIG_FILE="$TEST_DIR/custom-paths.conf"
SAFE_UPDATE_DATA_DIR=""
LOG_DIR=""
REPORT_DIR=""
CACHE_DIR=""
STATE_DIR=""
LOG_FILE=""
REPORT_FILE=""
SNAPSHOT_NAME=""
init_config "$REPO_ROOT"

assert_eq "/tmp/safe-update-custom/logs/custom.log" "$LOG_FILE" "Custom LOG_FILE should be preserved"
assert_eq "/tmp/safe-update-custom/logs" "$LOG_DIR" "LOG_DIR should follow dirname(LOG_FILE)"
assert_eq "/tmp/safe-update-custom/reports/custom.json" "$REPORT_FILE" "Custom REPORT_FILE should be preserved"
assert_eq "/tmp/safe-update-custom/reports" "$REPORT_DIR" "REPORT_DIR should follow dirname(REPORT_FILE)"

cat > "$TEST_DIR/default-patterns.conf" <<'EOF'
SAFE_UPDATE_DATA_DIR="/tmp/default-pattern-safe-update"
EOF

SAFE_UPDATE_CONFIG_FILE="$TEST_DIR/default-patterns.conf"
unset TIMESTAMP
unset ISO_TIMESTAMP
SAFE_UPDATE_DATA_DIR=""
LOG_DIR=""
REPORT_DIR=""
CACHE_DIR=""
STATE_DIR=""
LOG_FILE=""
REPORT_FILE=""
SNAPSHOT_NAME=""
init_config "$REPO_ROOT"

[[ "$LOG_FILE" =~ ^/tmp/default-pattern-safe-update/logs/update-[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{6}\.log$ ]] || fail "Default LOG_FILE should use sortable timestamps"
[[ "$REPORT_FILE" =~ ^/tmp/default-pattern-safe-update/reports/report-[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{6}\.json$ ]] || fail "Default REPORT_FILE should use sortable timestamps"

cat > "$TEST_DIR/invalid-cache.conf" <<'EOF'
SAFE_UPDATE_DATA_DIR="/tmp/valid-safe-update"
CACHE_DIR="/"
EOF

SAFE_UPDATE_CONFIG_FILE="$TEST_DIR/invalid-cache.conf"
SAFE_UPDATE_DATA_DIR=""
LOG_DIR=""
REPORT_DIR=""
CACHE_DIR=""
STATE_DIR=""
LOG_FILE=""
REPORT_FILE=""
SNAPSHOT_NAME=""
CONFIG_ERROR_OUTPUT="$TEST_DIR/config-error.out"

set +e
init_config "$REPO_ROOT" > "$CONFIG_ERROR_OUTPUT" 2>&1
config_status=$?
set -e

assert_eq "1" "$config_status" "init_config should fail for invalid CACHE_DIR"
assert_file_contains "$CONFIG_ERROR_OUTPUT" 'ERROR: CACHE_DIR must not be empty or /'
