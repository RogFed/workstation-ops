#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)/helpers/testlib.sh"

TEST_DIR=$(make_test_dir)
trap 'rm -rf "$TEST_DIR"' EXIT

MOCK_PATH=$(make_mock_bin "$TEST_DIR")
RUNTIME_BIN="$TEST_DIR/runtime-bin"
CALLS_DIR="$TEST_DIR/calls"
DATA_DIR="$TEST_DIR/data"
mkdir -p "$CALLS_DIR" "$RUNTIME_BIN"

cat > "$MOCK_PATH/paru" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    -Syu)
        printf 'paru -Syu\n' >> "$MOCK_CALLS_DIR/commands.log"
        if [[ "${MOCK_PARU_UPDATE_FAIL:-false}" == "true" ]]; then
            exit 3
        fi
        ;;
    *)
        echo "Unexpected paru invocation: $*" >&2
        exit 1
        ;;
esac
EOF

cat > "$MOCK_PATH/checkupdates" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${MOCK_CHECKUPDATES_ERROR:-}" ]]; then
    printf '%s\n' "$MOCK_CHECKUPDATES_ERROR" >&2
    exit 1
fi

if [[ -n "${MOCK_CHECKUPDATES_OUTPUT:-}" ]]; then
    printf '%s\n' "$MOCK_CHECKUPDATES_OUTPUT"
    exit 0
fi

exit "${MOCK_CHECKUPDATES_EXIT_CODE:-2}"
EOF

cat > "$MOCK_PATH/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'sudo %s\n' "$*" >> "$MOCK_CALLS_DIR/commands.log"
"$@"
EOF

cat > "$MOCK_PATH/snapper" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'snapper %s\n' "$*" >> "$MOCK_CALLS_DIR/commands.log"
if [[ "${MOCK_SNAPPER_FAIL:-false}" == "true" ]]; then
    exit 4
fi
if [[ -n "${MOCK_SNAPPER_OUTPUT:-}" ]]; then
    printf '%s\n' "$MOCK_SNAPPER_OUTPUT"
fi
EOF

cat > "$MOCK_PATH/notify-send" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'notify-send %s\n' "$*" >> "$MOCK_CALLS_DIR/commands.log"
if [[ "${MOCK_NOTIFY_SEND_FAIL:-false}" == "true" ]]; then
    exit 1
fi
EOF

chmod +x "$MOCK_PATH/paru" "$MOCK_PATH/checkupdates" "$MOCK_PATH/sudo" "$MOCK_PATH/snapper" "$MOCK_PATH/notify-send"

for runtime_cmd in bash cat chmod date dirname hostname mkdir mktemp mv rm tee uname; do
    ln -sf "$(command -v "$runtime_cmd")" "$RUNTIME_BIN/$runtime_cmd"
done

CANCELLED_UPDATES=$'linux-cachyos 1 -> 2\nfirefox 1 -> 2'
SUCCESS_UPDATES=$'linux-cachyos 1 -> 2\npipewire 1 -> 2'
CRITICAL_ONLY_UPDATES=$'linux-cachyos 1 -> 2'

run_safe_update() {
    local updates="$1"
    local input_text="$2"
    local timestamp="$3"

    MOCK_CHECKUPDATES_OUTPUT="$updates" \
    MOCK_CALLS_DIR="$CALLS_DIR" \
    SAFE_UPDATE_DATA_DIR="$DATA_DIR" \
    CHECKUPDATES_BIN="${CHECKUPDATES_BIN:-checkupdates}" \
    PARU_BIN="${PARU_BIN:-paru}" \
    MOCK_NOTIFY_SEND_FAIL="${MOCK_NOTIFY_SEND_FAIL:-false}" \
    MOCK_CHECKUPDATES_ERROR="${MOCK_CHECKUPDATES_ERROR:-}" \
    MOCK_CHECKUPDATES_EXIT_CODE="${MOCK_CHECKUPDATES_EXIT_CODE:-}" \
    MOCK_SNAPPER_FAIL="${MOCK_SNAPPER_FAIL:-false}" \
    MOCK_SNAPPER_OUTPUT="${MOCK_SNAPPER_OUTPUT:-Created snapshot 42}" \
    MOCK_PARU_UPDATE_FAIL="${MOCK_PARU_UPDATE_FAIL:-false}" \
    PATH="$MOCK_PATH:$PATH" \
    SAFE_UPDATE_HOSTNAME="cachyos-workstation" \
    SAFE_UPDATE_KERNEL_VERSION="6.15.1-cachyos" \
    SAFE_UPDATE_BOOTLOADER="limine" \
    SAFE_UPDATE_VERSION="0.2.3" \
    SAFE_UPDATE_START_EPOCH=100 \
    SAFE_UPDATE_NOW_EPOCH=148 \
    TIMESTAMP="$timestamp" \
    ISO_TIMESTAMP="2026-05-22T21:30:00-06:00" \
    bash "$REPO_ROOT/scripts/safe-update" <<< "$input_text"
}

run_safe_update_via_symlink() {
    local updates="$1"
    local input_text="$2"
    local timestamp="$3"
    local symlink_dir="$TEST_DIR/symlink-bin"

    mkdir -p "$symlink_dir"
    ln -sf "$REPO_ROOT/scripts/safe-update" "$symlink_dir/safe-update"

    MOCK_CHECKUPDATES_OUTPUT="$updates" \
    MOCK_CALLS_DIR="$CALLS_DIR" \
    SAFE_UPDATE_DATA_DIR="$DATA_DIR" \
    CHECKUPDATES_BIN="${CHECKUPDATES_BIN:-checkupdates}" \
    PARU_BIN="${PARU_BIN:-paru}" \
    MOCK_NOTIFY_SEND_FAIL="${MOCK_NOTIFY_SEND_FAIL:-false}" \
    MOCK_CHECKUPDATES_ERROR="${MOCK_CHECKUPDATES_ERROR:-}" \
    MOCK_CHECKUPDATES_EXIT_CODE="${MOCK_CHECKUPDATES_EXIT_CODE:-}" \
    MOCK_SNAPPER_FAIL="${MOCK_SNAPPER_FAIL:-false}" \
    MOCK_SNAPPER_OUTPUT="${MOCK_SNAPPER_OUTPUT:-Created snapshot 42}" \
    MOCK_PARU_UPDATE_FAIL="${MOCK_PARU_UPDATE_FAIL:-false}" \
    PATH="$MOCK_PATH:$PATH" \
    SAFE_UPDATE_HOSTNAME="cachyos-workstation" \
    SAFE_UPDATE_KERNEL_VERSION="6.15.1-cachyos" \
    SAFE_UPDATE_BOOTLOADER="limine" \
    SAFE_UPDATE_VERSION="0.2.3" \
    SAFE_UPDATE_START_EPOCH=100 \
    SAFE_UPDATE_NOW_EPOCH=148 \
    TIMESTAMP="$timestamp" \
    ISO_TIMESTAMP="2026-05-22T21:30:00-06:00" \
    bash "$symlink_dir/safe-update" <<< "$input_text"
}

run_safe_update_via_path() {
    local updates="$1"
    local input_text="$2"
    local timestamp="$3"
    local path_dir="$TEST_DIR/path-bin"

    mkdir -p "$path_dir"
    ln -sf "$REPO_ROOT/scripts/safe-update" "$path_dir/safe-update"

    MOCK_CHECKUPDATES_OUTPUT="$updates" \
    MOCK_CALLS_DIR="$CALLS_DIR" \
    SAFE_UPDATE_DATA_DIR="$DATA_DIR" \
    CHECKUPDATES_BIN="${CHECKUPDATES_BIN:-checkupdates}" \
    PARU_BIN="${PARU_BIN:-paru}" \
    MOCK_NOTIFY_SEND_FAIL="${MOCK_NOTIFY_SEND_FAIL:-false}" \
    MOCK_CHECKUPDATES_ERROR="${MOCK_CHECKUPDATES_ERROR:-}" \
    MOCK_CHECKUPDATES_EXIT_CODE="${MOCK_CHECKUPDATES_EXIT_CODE:-}" \
    MOCK_SNAPPER_FAIL="${MOCK_SNAPPER_FAIL:-false}" \
    MOCK_SNAPPER_OUTPUT="${MOCK_SNAPPER_OUTPUT:-Created snapshot 42}" \
    MOCK_PARU_UPDATE_FAIL="${MOCK_PARU_UPDATE_FAIL:-false}" \
    PATH="$path_dir:$MOCK_PATH:$PATH" \
    SAFE_UPDATE_HOSTNAME="cachyos-workstation" \
    SAFE_UPDATE_KERNEL_VERSION="6.15.1-cachyos" \
    SAFE_UPDATE_BOOTLOADER="limine" \
    SAFE_UPDATE_VERSION="0.2.3" \
    SAFE_UPDATE_START_EPOCH=100 \
    SAFE_UPDATE_NOW_EPOCH=148 \
    TIMESTAMP="$timestamp" \
    ISO_TIMESTAMP="2026-05-22T21:30:00-06:00" \
    bash -c 'safe-update' <<< "$input_text"
}

run_safe_update_expect_failure() {
    local updates="$1"
    local input_text="$2"
    local timestamp="$3"

    set +e
    MOCK_CHECKUPDATES_OUTPUT="$updates" \
    MOCK_CALLS_DIR="$CALLS_DIR" \
    SAFE_UPDATE_DATA_DIR="$DATA_DIR" \
    CHECKUPDATES_BIN="${CHECKUPDATES_BIN:-checkupdates}" \
    PARU_BIN="${PARU_BIN:-paru}" \
    MOCK_NOTIFY_SEND_FAIL="${MOCK_NOTIFY_SEND_FAIL:-false}" \
    MOCK_CHECKUPDATES_ERROR="${MOCK_CHECKUPDATES_ERROR:-}" \
    MOCK_CHECKUPDATES_EXIT_CODE="${MOCK_CHECKUPDATES_EXIT_CODE:-}" \
    MOCK_SNAPPER_FAIL="${MOCK_SNAPPER_FAIL:-false}" \
    MOCK_SNAPPER_OUTPUT="${MOCK_SNAPPER_OUTPUT:-Created snapshot 42}" \
    MOCK_PARU_UPDATE_FAIL="${MOCK_PARU_UPDATE_FAIL:-false}" \
    PATH="$MOCK_PATH:$PATH" \
    SAFE_UPDATE_HOSTNAME="cachyos-workstation" \
    SAFE_UPDATE_KERNEL_VERSION="6.15.1-cachyos" \
    SAFE_UPDATE_BOOTLOADER="limine" \
    SAFE_UPDATE_VERSION="0.2.3" \
    SAFE_UPDATE_START_EPOCH=100 \
    SAFE_UPDATE_NOW_EPOCH=148 \
    TIMESTAMP="$timestamp" \
    ISO_TIMESTAMP="2026-05-22T21:30:00-06:00" \
    bash "$REPO_ROOT/scripts/safe-update" <<< "$input_text"
    local exit_code=$?
    set -e

    if [[ "$exit_code" -eq 0 ]]; then
        fail "Expected safe-update to fail"
    fi

    return 0
}

run_safe_update_missing_jq_expect_failure() {
    local updates="$1"
    local input_text="$2"
    local timestamp="$3"

    set +e
    MOCK_PARU_UPDATES="$updates" \
    MOCK_CALLS_DIR="$CALLS_DIR" \
    SAFE_UPDATE_DATA_DIR="$DATA_DIR" \
    SAFE_UPDATE_HOSTNAME="cachyos-workstation" \
    SAFE_UPDATE_KERNEL_VERSION="6.15.1-cachyos" \
    SAFE_UPDATE_BOOTLOADER="limine" \
    SAFE_UPDATE_VERSION="0.2.3" \
    SAFE_UPDATE_START_EPOCH=100 \
    SAFE_UPDATE_NOW_EPOCH=148 \
    PATH="$RUNTIME_BIN:$MOCK_PATH" \
    TIMESTAMP="$timestamp" \
    ISO_TIMESTAMP="2026-05-22T21:30:00-06:00" \
    bash "$REPO_ROOT/scripts/safe-update" <<< "$input_text"
    local exit_code=$?
    set -e

    if [[ "$exit_code" -eq 0 ]]; then
        fail "Expected safe-update to fail without jq"
    fi

    return 0
}

run_safe_update "" "" "2026-05-22-2130"
assert_json_expression "$DATA_DIR/reports/report-2026-05-22-2130.json" '.update_result == "no-updates" and .snapshot.created == false and .duration_seconds == 48'

run_safe_update "$CANCELLED_UPDATES" "n" "2026-05-22-2131"
assert_json_expression "$DATA_DIR/reports/report-2026-05-22-2131.json" '.update_result == "cancelled" and .updates.critical == ["linux-cachyos"] and .updates.low == ["firefox"]'
assert_file_contains "$CALLS_DIR/commands.log" 'notify-send safe-update Critical updates detected'

run_safe_update "$SUCCESS_UPDATES" "y" "2026-05-22-2132"
assert_json_expression "$DATA_DIR/reports/report-2026-05-22-2132.json" '.version == "0.2.3" and .hostname == "cachyos-workstation" and .kernel_version == "6.15.1-cachyos" and .bootloader == "limine"'
assert_json_expression "$DATA_DIR/reports/report-2026-05-22-2132.json" '.update_result == "success" and .reboot_required == true and .snapshot.created == true and .snapshot.name == "pre-update-2026-05-22-2132" and .snapshot.id == "42"'
assert_json_expression "$DATA_DIR/reports/report-2026-05-22-2132.json" '.updates.critical == ["linux-cachyos"] and .updates.high == ["pipewire"]'
assert_json_expression "$DATA_DIR/reports/report-2026-05-22-2132.json" '.risk_summary.critical_package_count == 1 and .risk_summary.high_package_count == 1 and .risk_summary.graphics_stack_changed == true and .risk_summary.boot_chain_changed == true and .risk_summary.reboot_required == true'
assert_json_expression "$DATA_DIR/reports/report-2026-05-22-2132.json" '.package_risk_metadata[] | select(.name == "pipewire" and .graphics_impact == true and .severity == "HIGH")'
assert_file_contains "$CALLS_DIR/commands.log" 'snapper create --description pre-update-2026-05-22-2132'
assert_file_contains "$CALLS_DIR/commands.log" 'paru -Syu'
assert_file_contains "$DATA_DIR/logs/update-2026-05-22-2132.log" 'Graphics stack updates detected: pipewire'
assert_file_contains "$DATA_DIR/logs/update-2026-05-22-2132.log" 'Boot chain updates detected: linux-cachyos'

run_safe_update_via_symlink "" "" "2026-05-22-2125"
assert_json_expression "$DATA_DIR/reports/report-2026-05-22-2125.json" '.update_result == "no-updates"'

run_safe_update_via_path "" "" "2026-05-22-2124"
assert_json_expression "$DATA_DIR/reports/report-2026-05-22-2124.json" '.update_result == "no-updates"'

MOCK_CHECKUPDATES_EXIT_CODE=2 run_safe_update "" "" "2026-05-22-2126"
assert_json_expression "$DATA_DIR/reports/report-2026-05-22-2126.json" '.update_result == "no-updates"'

run_safe_update "$CRITICAL_ONLY_UPDATES" "n" "2026-05-22-2127"
assert_json_expression "$DATA_DIR/reports/report-2026-05-22-2127.json" '.update_result == "cancelled" and .updates.critical == ["linux-cachyos"]'

MOCK_NOTIFY_SEND_FAIL=true run_safe_update "$CRITICAL_ONLY_UPDATES" "n" "2026-05-22-2133"
assert_file_contains "$DATA_DIR/logs/update-2026-05-22-2133.log" 'Notification skipped: notify-send failed'

run_safe_update_missing_jq_expect_failure "" "" "2026-05-22-2138"
assert_file_contains "$DATA_DIR/logs/update-2026-05-22-2138.log" 'ERROR: Missing required command for structured reports: jq'
[[ ! -f "$DATA_DIR/reports/report-2026-05-22-2138.json" ]] || fail "Report should not be written when jq is missing"

CHECKUPDATES_BIN=missing-checkupdates
run_safe_update_expect_failure "" "" "2026-05-22-2134"
unset CHECKUPDATES_BIN
assert_file_contains "$DATA_DIR/logs/update-2026-05-22-2134.log" 'ERROR: Missing required command: missing-checkupdates'
assert_json_expression "$DATA_DIR/reports/report-2026-05-22-2134.json" '.update_result == "missing-prereqs"'

PARU_BIN=missing-paru
run_safe_update_expect_failure "" "" "2026-05-22-2139"
unset PARU_BIN
assert_file_contains "$DATA_DIR/logs/update-2026-05-22-2139.log" 'ERROR: Missing required command: missing-paru'
assert_json_expression "$DATA_DIR/reports/report-2026-05-22-2139.json" '.update_result == "missing-prereqs"'

MOCK_CHECKUPDATES_ERROR='cannot fetch updates' run_safe_update_expect_failure "" "" "2026-05-22-2135"
assert_file_contains "$DATA_DIR/logs/update-2026-05-22-2135.log" 'ERROR: Failed to query pending updates with checkupdates'
assert_json_expression "$DATA_DIR/reports/report-2026-05-22-2135.json" '.update_result == "detect-failed"'

MOCK_SNAPPER_FAIL=true run_safe_update_expect_failure "$CRITICAL_ONLY_UPDATES" "y" "2026-05-22-2136"
assert_json_expression "$DATA_DIR/reports/report-2026-05-22-2136.json" '.update_result == "snapshot-failed" and .snapshot.created == false and .snapshot.name == "pre-update-2026-05-22-2136"'

MOCK_PARU_UPDATE_FAIL=true run_safe_update_expect_failure "$CRITICAL_ONLY_UPDATES" "y" "2026-05-22-2137"
assert_json_expression "$DATA_DIR/reports/report-2026-05-22-2137.json" '.update_result == "update-failed" and .snapshot.created == true'
