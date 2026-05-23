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
