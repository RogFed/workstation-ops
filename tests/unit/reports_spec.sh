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

write_report "success" "pre-update-2026-05-22-2115" "true"

assert_file_contains "$REPORT_FILE" '"status": "success"'
assert_file_contains "$REPORT_FILE" '"snapshot": "pre-update-2026-05-22-2115"'
assert_file_contains "$REPORT_FILE" '"critical_updates": ["linux-cachyos"]'
assert_file_contains "$REPORT_FILE" '"reboot_required": true'
assert_file_contains "$REPORT_FILE" '"arch_news_detected": true'
assert_file_contains "$REPORT_FILE" '"cachyos_news_detected": false'
