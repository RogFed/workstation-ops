#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)/helpers/testlib.sh"

TEST_DIR=$(make_test_dir)
trap 'rm -rf "$TEST_DIR"' EXIT

MOCK_PATH=$(make_mock_bin "$TEST_DIR")
CALLS_DIR="$TEST_DIR/calls"
DATA_DIR="$TEST_DIR/data"
mkdir -p "$CALLS_DIR"

cat > "$MOCK_PATH/paru" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    -Qu)
        if [[ -n "${MOCK_PARU_EXIT_CODE:-}" ]]; then
            exit "$MOCK_PARU_EXIT_CODE"
        fi
        if [[ -n "${MOCK_PARU_ERROR:-}" ]]; then
            printf '%s\n' "$MOCK_PARU_ERROR" >&2
            exit 2
        fi
        printf '%s\n' "${MOCK_PARU_UPDATES:-}"
        ;;
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
EOF

cat > "$MOCK_PATH/notify-send" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'notify-send %s\n' "$*" >> "$MOCK_CALLS_DIR/commands.log"
if [[ "${MOCK_NOTIFY_SEND_FAIL:-false}" == "true" ]]; then
    exit 1
fi
EOF

chmod +x "$MOCK_PATH/paru" "$MOCK_PATH/sudo" "$MOCK_PATH/snapper" "$MOCK_PATH/notify-send"

run_safe_update() {
    local updates="$1"
    local input_text="$2"
    local timestamp="$3"

    MOCK_PARU_UPDATES="$updates" \
    MOCK_CALLS_DIR="$CALLS_DIR" \
    SAFE_UPDATE_DATA_DIR="$DATA_DIR" \
    MOCK_NOTIFY_SEND_FAIL="${MOCK_NOTIFY_SEND_FAIL:-false}" \
    MOCK_PARU_ERROR="${MOCK_PARU_ERROR:-}" \
    MOCK_PARU_EXIT_CODE="${MOCK_PARU_EXIT_CODE:-}" \
    MOCK_SNAPPER_FAIL="${MOCK_SNAPPER_FAIL:-false}" \
    MOCK_PARU_UPDATE_FAIL="${MOCK_PARU_UPDATE_FAIL:-false}" \
    PATH="$MOCK_PATH:$PATH" \
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

    MOCK_PARU_UPDATES="$updates" \
    MOCK_CALLS_DIR="$CALLS_DIR" \
    SAFE_UPDATE_DATA_DIR="$DATA_DIR" \
    MOCK_NOTIFY_SEND_FAIL="${MOCK_NOTIFY_SEND_FAIL:-false}" \
    MOCK_PARU_ERROR="${MOCK_PARU_ERROR:-}" \
    MOCK_PARU_EXIT_CODE="${MOCK_PARU_EXIT_CODE:-}" \
    MOCK_SNAPPER_FAIL="${MOCK_SNAPPER_FAIL:-false}" \
    MOCK_PARU_UPDATE_FAIL="${MOCK_PARU_UPDATE_FAIL:-false}" \
    PATH="$MOCK_PATH:$PATH" \
    TIMESTAMP="$timestamp" \
    ISO_TIMESTAMP="2026-05-22T21:30:00-06:00" \
    bash "$symlink_dir/safe-update" <<< "$input_text"
}

run_safe_update_expect_failure() {
    local updates="$1"
    local input_text="$2"
    local timestamp="$3"

    set +e
    MOCK_PARU_UPDATES="$updates" \
    MOCK_CALLS_DIR="$CALLS_DIR" \
    SAFE_UPDATE_DATA_DIR="$DATA_DIR" \
    MOCK_NOTIFY_SEND_FAIL="${MOCK_NOTIFY_SEND_FAIL:-false}" \
    MOCK_PARU_ERROR="${MOCK_PARU_ERROR:-}" \
    MOCK_PARU_EXIT_CODE="${MOCK_PARU_EXIT_CODE:-}" \
    MOCK_SNAPPER_FAIL="${MOCK_SNAPPER_FAIL:-false}" \
    MOCK_PARU_UPDATE_FAIL="${MOCK_PARU_UPDATE_FAIL:-false}" \
    PATH="$MOCK_PATH:$PATH" \
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

run_safe_update "" "" "2026-05-22-2130"
assert_file_contains "$DATA_DIR/reports/report-2026-05-22-2130.json" '"status": "no-updates"'

run_safe_update $'linux-cachyos 1 -> 2\nfirefox 1 -> 2' "n" "2026-05-22-2131"
assert_file_contains "$DATA_DIR/reports/report-2026-05-22-2131.json" '"status": "cancelled"'
assert_file_contains "$CALLS_DIR/commands.log" 'notify-send safe-update Critical updates detected'

run_safe_update $'linux-cachyos 1 -> 2\npipewire 1 -> 2' "y" "2026-05-22-2132"
assert_file_contains "$DATA_DIR/reports/report-2026-05-22-2132.json" '"status": "success"'
assert_file_contains "$DATA_DIR/reports/report-2026-05-22-2132.json" '"reboot_required": true'
assert_file_contains "$CALLS_DIR/commands.log" 'snapper create --description pre-update-2026-05-22-2132'
assert_file_contains "$CALLS_DIR/commands.log" 'paru -Syu'

run_safe_update_via_symlink "" "" "2026-05-22-2125"
assert_file_contains "$DATA_DIR/reports/report-2026-05-22-2125.json" '"status": "no-updates"'

MOCK_PARU_EXIT_CODE=1 run_safe_update "" "" "2026-05-22-2126"
assert_file_contains "$DATA_DIR/reports/report-2026-05-22-2126.json" '"status": "no-updates"'

MOCK_NOTIFY_SEND_FAIL=true run_safe_update $'linux-cachyos 1 -> 2' "n" "2026-05-22-2133"
assert_file_contains "$DATA_DIR/logs/update-2026-05-22-2133.log" 'Notification skipped: notify-send failed'

PARU_BIN=missing-paru run_safe_update_expect_failure "" "" "2026-05-22-2134"
assert_file_contains "$DATA_DIR/logs/update-2026-05-22-2134.log" 'ERROR: Missing required command: missing-paru'
assert_file_contains "$DATA_DIR/reports/report-2026-05-22-2134.json" '"status": "missing-prereqs"'

MOCK_PARU_ERROR='database unavailable' run_safe_update_expect_failure "" "" "2026-05-22-2135"
assert_file_contains "$DATA_DIR/logs/update-2026-05-22-2135.log" 'ERROR: Failed to query pending updates with paru -Qu'
assert_file_contains "$DATA_DIR/reports/report-2026-05-22-2135.json" '"status": "detect-failed"'

MOCK_SNAPPER_FAIL=true run_safe_update_expect_failure $'linux-cachyos 1 -> 2' "y" "2026-05-22-2136"
assert_file_contains "$DATA_DIR/reports/report-2026-05-22-2136.json" '"status": "snapshot-failed"'

MOCK_PARU_UPDATE_FAIL=true run_safe_update_expect_failure $'linux-cachyos 1 -> 2' "y" "2026-05-22-2137"
assert_file_contains "$DATA_DIR/reports/report-2026-05-22-2137.json" '"status": "update-failed"'
