#!/usr/bin/env bash

SNAPSHOT_CREATED="false"
SNAPSHOT_ID=""

reset_snapshot_state() {
    SNAPSHOT_CREATED="false"
    SNAPSHOT_ID=""
}

snapshot_id_from_output() {
    local output="${1:-}"

    if [[ "$output" =~ ([0-9]+)([^0-9]*)$ ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
    fi
}

create_snapshot() {
    local snapshot_output=""

    section "Creating Btrfs Snapshot"
    reset_snapshot_state

    if ! snapshot_output=$("$SUDO_BIN" "$SNAPPER_BIN" create \
        --description "$SNAPSHOT_NAME" 2>&1); then
        if [[ -n "$snapshot_output" ]]; then
            printf '%s\n' "$snapshot_output" | tee -a "$LOG_FILE" >&2
        fi
        return 1
    fi

    SNAPSHOT_CREATED="true"
    SNAPSHOT_ID=$(snapshot_id_from_output "$snapshot_output")
    log "Snapshot created: $SNAPSHOT_NAME"
    if [[ -n "$SNAPSHOT_ID" ]]; then
        log "Snapshot ID: $SNAPSHOT_ID"
    fi
}
