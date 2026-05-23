#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)/helpers/testlib.sh"
source "$REPO_ROOT/lib/utils.sh"
source "$REPO_ROOT/lib/risk.sh"
source "$REPO_ROOT/lib/reports.sh"

TEST_DIR=$(make_test_dir)
trap 'rm -rf "$TEST_DIR"' EXIT

ENABLE_REPORTS=true
ISO_TIMESTAMP="2026-05-22T21:15:00-06:00"
LOG_FILE="$TEST_DIR/update.log"
REPORT_FILE="$TEST_DIR/report.json"
ARCH_NEWS_DETECTED=yes
CACHYOS_NEWS_DETECTED=0
RUN_START_EPOCH=100
SAFE_UPDATE_NOW_EPOCH=148
SAFE_UPDATE_HOSTNAME="cachyos-workstation"
SAFE_UPDATE_KERNEL_VERSION="6.15.1-cachyos"
SAFE_UPDATE_BOOTLOADER="limine"
SAFE_UPDATE_VERSION="0.2.2"
SNAPSHOT_ID="42"
TEST_UPDATES=$'linux-cachyos 1 -> 2\nmesa 1 -> 2\nplasma-desktop 1 -> 2\nwarp-terminal-bin 1 -> 2'

analyze_updates "$TEST_UPDATES"

write_report "success" "pre-update-2026-05-22T211500" "true" "true"

assert_json_expression "$REPORT_FILE" '.version == "0.2.2"'
assert_json_expression "$REPORT_FILE" '.timestamp == "2026-05-22T21:15:00-06:00"'
assert_json_expression "$REPORT_FILE" '.hostname == "cachyos-workstation"'
assert_json_expression "$REPORT_FILE" '.kernel_version == "6.15.1-cachyos"'
assert_json_expression "$REPORT_FILE" '.bootloader == "limine"'
assert_json_expression "$REPORT_FILE" '.snapshot.created == true'
assert_json_expression "$REPORT_FILE" '.snapshot.name == "pre-update-2026-05-22T211500"'
assert_json_expression "$REPORT_FILE" '.snapshot.id == "42"'
assert_json_expression "$REPORT_FILE" '.updates.critical == ["linux-cachyos"]'
assert_json_expression "$REPORT_FILE" '.updates.high == ["mesa"]'
assert_json_expression "$REPORT_FILE" '.updates.medium == ["plasma-desktop"]'
assert_json_expression "$REPORT_FILE" '.updates.low == ["warp-terminal-bin"]'
assert_json_expression "$REPORT_FILE" '.package_risk_metadata | length == 4'
assert_json_expression "$REPORT_FILE" '.package_risk_metadata[] | select(.name == "mesa" and .severity == "HIGH" and .graphics_impact == true and .core_system_impact == true)'
assert_json_expression "$REPORT_FILE" '.package_risk_metadata[] | select(.name == "warp-terminal-bin" and .aur_package == true and .userland_only == true)'
assert_json_expression "$REPORT_FILE" '.risk_summary.critical_package_count == 1'
assert_json_expression "$REPORT_FILE" '.risk_summary.high_package_count == 1'
assert_json_expression "$REPORT_FILE" '.risk_summary.medium_package_count == 1'
assert_json_expression "$REPORT_FILE" '.risk_summary.low_package_count == 1'
assert_json_expression "$REPORT_FILE" '.risk_summary.graphics_stack_changed == true'
assert_json_expression "$REPORT_FILE" '.risk_summary.boot_chain_changed == true'
assert_json_expression "$REPORT_FILE" '.risk_summary.core_system_changed == true'
assert_json_expression "$REPORT_FILE" '.risk_summary.aur_package_count == 1'
assert_json_expression "$REPORT_FILE" '.risk_summary.reboot_required == true'
assert_json_expression "$REPORT_FILE" '.reboot_required == true'
assert_json_expression "$REPORT_FILE" '.update_result == "success"'
assert_json_expression "$REPORT_FILE" '.duration_seconds == 48'
assert_json_expression "$REPORT_FILE" '.advisory_flags.arch_news_detected == true'
assert_json_expression "$REPORT_FILE" '.advisory_flags.cachyos_news_detected == false'
assert_json_value "$REPORT_FILE" '.report_path' "$REPORT_FILE"
assert_json_value "$REPORT_FILE" '.log_file' "$LOG_FILE"

printf '{}\n' > "$TEST_DIR/invalid-report.json"
set +e
validate_report "$TEST_DIR/invalid-report.json"
invalid_status=$?
set -e
assert_eq "1" "$invalid_status" "validate_report should reject incomplete reports"

jq -n '{
  version: "0.2.2",
  timestamp: "2026-05-22T21:15:00-06:00",
  hostname: "cachyos-workstation",
  kernel_version: "6.15.1-cachyos",
  bootloader: "limine",
  snapshot: { created: true, name: "pre-update-2026-05-22T211500", id: "42" },
  updates: { critical: ["linux-cachyos"], high: ["mesa"], medium: ["plasma-desktop"], low: ["warp-terminal-bin"] },
  package_risk_metadata: [{
    severity: "SEVERE",
    reboot_required: true,
    boot_impact: true,
    graphics_impact: false,
    core_system_impact: true,
    userland_only: false,
    aur_package: false
  }],
  risk_summary: {
    critical_package_count: 1,
    high_package_count: 1,
    medium_package_count: 1,
    low_package_count: 1,
    graphics_stack_changed: true,
    boot_chain_changed: true,
    core_system_changed: true,
    reboot_required: true,
    aur_package_count: 1
  },
  reboot_required: true,
  update_result: "success",
  duration_seconds: 48,
  advisory_flags: { arch_news_detected: true, cachyos_news_detected: false },
  log_file: "/tmp/update.log",
  report_path: "/tmp/report.json"
}' > "$TEST_DIR/invalid-package-risk-report.json"
set +e
validate_report "$TEST_DIR/invalid-package-risk-report.json"
invalid_package_status=$?
set -e
assert_eq "1" "$invalid_package_status" "validate_report should reject invalid package risk metadata entries"

REPORT_FILE="$TEST_DIR/not-a-directory/report.json"
printf 'blocking file\n' > "$TEST_DIR/not-a-directory"
set +e
write_report "success" "pre-update-2026-05-22T211500" "true" "true"
write_status=$?
set -e
assert_eq "1" "$write_status" "write_report should return a handled failure when the report directory cannot be created"
assert_eq "Failed to create report directory: $TEST_DIR/not-a-directory" "$REPORT_ERROR_MESSAGE" "write_report should store a useful report directory error"

REPORT_DIR="$TEST_DIR/collision-reports"
TIMESTAMP="2026-05-22T211500"
REPORT_FILE="$REPORT_DIR/report-2026-05-22T211500.json"
mkdir -p "$REPORT_DIR"
printf 'existing report\n' > "$REPORT_FILE"
set +e
write_report "success" "pre-update-2026-05-22T211500" "true" "true"
collision_status=$?
set -e
assert_eq "0" "$collision_status" "write_report should disambiguate default report names on collision"
[[ "$REPORT_FILE" =~ ^$TEST_DIR/collision-reports/report-2026-05-22T211500-[0-9-]+\.json$ ]] || fail "write_report should add a suffix when the default report path collides"
[[ -f "$REPORT_FILE" ]] || fail "write_report should persist the disambiguated report file"
