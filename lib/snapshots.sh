#!/usr/bin/env bash

create_snapshot() {
    section "Creating Btrfs Snapshot"

    if ! "$SUDO_BIN" "$SNAPPER_BIN" create \
        --description "$SNAPSHOT_NAME"; then
        return 1
    fi

    log "Snapshot created: $SNAPSHOT_NAME"
}
