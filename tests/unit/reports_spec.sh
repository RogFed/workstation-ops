#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)/helpers/testlib.sh"
source "$REPO_ROOT/lib/utils.sh"
source "$REPO_ROOT/lib/reports.sh"

TEST_DIR=$(make_test_dir)
trap 'rm -rf "$TEST_DIR"' EXIT

ENABLE_REPORTS=true
ISO_TIMESTAMP="2026-05-22T21:15:00-06:00"
LOG_FILE="$TEST_DIR/update.log"
REPORT_FILE="$TEST_DIR/report.json"
ARCH_NEWS_DETECTED=yes
CACHYOS_NEWS_DETECTED=0
CRITICAL_PACKAGES=("linux-cachyos")
HIGH_PACKAGES=("pipewire")
MEDIUM_PACKAGES=("plasma-desktop")
LOW_PACKAGES=("firefox")
RUN_START_EPOCH=100
SAFE_UPDATE_NOW_EPOCH=148
SAFE_UPDATE_HOSTNAME="cachyos-workstation"
SAFE_UPDATE_KERNEL_VERSION="6.15.1-cachyos"
SAFE_UPDATE_BOOTLOADER="limine"
SAFE_UPDATE_VERSION="0.2.1"
SNAPSHOT_ID="42"

write_report "success" "pre-update-2026-05-22T211500" "true" "true"

assert_json_expression "$REPORT_FILE" '.version == "0.2.1"'
assert_json_expression "$REPORT_FILE" '.timestamp == "2026-05-22T21:15:00-06:00"'
assert_json_expression "$REPORT_FILE" '.hostname == "cachyos-workstation"'
assert_json_expression "$REPORT_FILE" '.kernel_version == "6.15.1-cachyos"'
assert_json_expression "$REPORT_FILE" '.bootloader == "limine"'
assert_json_expression "$REPORT_FILE" '.snapshot.created == true'
assert_json_expression "$REPORT_FILE" '.snapshot.name == "pre-update-2026-05-22T211500"'
assert_json_expression "$REPORT_FILE" '.snapshot.id == "42"'
assert_json_expression "$REPORT_FILE" '.updates.critical == ["linux-cachyos"]'
assert_json_expression "$REPORT_FILE" '.updates.high == ["pipewire"]'
assert_json_expression "$REPORT_FILE" '.updates.medium == ["plasma-desktop"]'
assert_json_expression "$REPORT_FILE" '.updates.low == ["firefox"]'
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

REPORT_FILE="$TEST_DIR/not-a-directory/report.json"
printf 'blocking file\n' > "$TEST_DIR/not-a-directory"
set +e
write_report "success" "pre-update-2026-05-22T211500" "true" "true"
write_status=$?
set -e
assert_eq "1" "$write_status" "write_report should return a handled failure when the report directory cannot be created"
assert_eq "Failed to create report directory: $TEST_DIR/not-a-directory" "$REPORT_ERROR_MESSAGE" "write_report should store a useful report directory error"
