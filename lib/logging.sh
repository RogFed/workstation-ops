#!/usr/bin/env bash

init_logging() {
    : > "$LOG_FILE"
    chmod 600 "$LOG_FILE"
}

log() {
    local timestamp
    timestamp=$(current_log_timestamp)
    printf '[%s] %s\n' "$timestamp" "$1" | tee -a "$LOG_FILE"
}

section() {
    printf '\n' | tee -a "$LOG_FILE" > /dev/null
    log "========================================"
    log "$1"
    log "========================================"
}

warn() {
    log "WARN: $1"
}

error() {
    local timestamp
    timestamp=$(current_log_timestamp)
    printf '[%s] ERROR: %s\n' "$timestamp" "$1" | tee -a "$LOG_FILE" >&2
}
