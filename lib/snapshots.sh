#!/usr/bin/env bash

create_snapshot() {
    section "Creating Btrfs Snapshot"

    "$SUDO_BIN" "$SNAPPER_BIN" create \
        --description "$SNAPSHOT_NAME"

    log "Snapshot created: $SNAPSHOT_NAME"
}
