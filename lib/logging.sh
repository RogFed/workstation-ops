#!/usr/bin/env bash

init_logging() {
    : > "$LOG_FILE"
}

log() {
    printf '%s\n' "$1" | tee -a "$LOG_FILE"
}

section() {
    echo
    log "========================================"
    log "$1"
    log "========================================"
}

warn() {
    log "⚠ $1"
}

error() {
    printf '%s\n' "ERROR: $1" | tee -a "$LOG_FILE" >&2
}
