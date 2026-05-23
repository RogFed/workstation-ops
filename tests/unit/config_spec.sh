#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)/helpers/testlib.sh"
source "$REPO_ROOT/lib/config.sh"

TEST_DIR=$(make_test_dir)
trap 'rm -rf "$TEST_DIR"' EXIT

cat > "$TEST_DIR/safe-update.conf" <<'EOF'
SAFE_UPDATE_DATA_DIR="/tmp/custom-safe-update"
ENABLE_NOTIFICATIONS=false
UPDATE_SNAPSHOT_RETENTION=9
EOF

SAFE_UPDATE_CONFIG_FILE="$TEST_DIR/safe-update.conf"
TIMESTAMP="2026-05-22-2100"
ISO_TIMESTAMP="2026-05-22T21:00:00-06:00"
init_config "$REPO_ROOT"

assert_eq "/tmp/custom-safe-update" "$SAFE_UPDATE_DATA_DIR" "Config file should override the runtime data dir"
assert_eq "false" "$ENABLE_NOTIFICATIONS" "Config file should override feature flags"
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
