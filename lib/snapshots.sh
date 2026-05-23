#!/usr/bin/env bash

SNAPSHOT_CREATED="false"
SNAPSHOT_ID=""

reset_snapshot_state() {
    SNAPSHOT_CREATED="false"
    SNAPSHOT_ID=""
}

create_snapshot() {
    section "Creating Btrfs Snapshot"
    reset_snapshot_state

    if ! "$SUDO_BIN" "$SNAPPER_BIN" create \
        --description "$SNAPSHOT_NAME"; then
        return 1
    fi

    SNAPSHOT_CREATED="true"
    log "Snapshot created: $SNAPSHOT_NAME"
}
