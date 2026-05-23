#!/usr/bin/env bash

init_config() {
    local repo_root="$1"
    local env_data_dir_set="false"
    local env_data_dir=""
    local env_timestamp_set="false"
    local env_timestamp=""
    local env_iso_timestamp_set="false"
    local env_iso_timestamp=""

    REPO_ROOT="$repo_root"
    CONFIG_FILE="${SAFE_UPDATE_CONFIG_FILE:-$REPO_ROOT/config/safe-update.conf}"

    if [[ -v SAFE_UPDATE_DATA_DIR ]]; then
        env_data_dir_set="true"
        env_data_dir="$SAFE_UPDATE_DATA_DIR"
    fi

    if [[ -v TIMESTAMP ]]; then
        env_timestamp_set="true"
        env_timestamp="$TIMESTAMP"
    fi

    if [[ -v ISO_TIMESTAMP ]]; then
        env_iso_timestamp_set="true"
        env_iso_timestamp="$ISO_TIMESTAMP"
    fi

    SAFE_UPDATE_DATA_DIR="${SAFE_UPDATE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/safe-update}"
    SNAPSHOT_PREFIX="${SNAPSHOT_PREFIX:-pre-update}"
    ENABLE_NOTIFICATIONS="${ENABLE_NOTIFICATIONS:-true}"
    ENABLE_ARCH_NEWS="${ENABLE_ARCH_NEWS:-true}"
    ENABLE_CACHYOS_NEWS="${ENABLE_CACHYOS_NEWS:-true}"
    ENABLE_REPORTS="${ENABLE_REPORTS:-true}"
    TIMELINE_RETENTION="${TIMELINE_RETENTION:-6}"
    UPDATE_SNAPSHOT_RETENTION="${UPDATE_SNAPSHOT_RETENTION:-5}"
    ARCH_NEWS_DETECTED="${ARCH_NEWS_DETECTED:-false}"
    CACHYOS_NEWS_DETECTED="${CACHYOS_NEWS_DETECTED:-false}"
    PARU_BIN="${PARU_BIN:-paru}"
    NOTIFY_SEND_BIN="${NOTIFY_SEND_BIN:-notify-send}"
    SUDO_BIN="${SUDO_BIN:-sudo}"
    SNAPPER_BIN="${SNAPPER_BIN:-snapper}"

    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$CONFIG_FILE"
    fi

    if [[ "$env_data_dir_set" == "true" ]]; then
        SAFE_UPDATE_DATA_DIR="$env_data_dir"
    fi

    if [[ "$env_timestamp_set" == "true" ]]; then
        TIMESTAMP="$env_timestamp"
    fi

    if [[ "$env_iso_timestamp_set" == "true" ]]; then
        ISO_TIMESTAMP="$env_iso_timestamp"
    fi

    TIMESTAMP="${TIMESTAMP:-$(date +"%Y-%m-%d-%H%M")}"
    ISO_TIMESTAMP="${ISO_TIMESTAMP:-$(date --iso-8601=seconds)}"

    LOG_DIR="${LOG_DIR:-$SAFE_UPDATE_DATA_DIR/logs}"
    REPORT_DIR="${REPORT_DIR:-$SAFE_UPDATE_DATA_DIR/reports}"
    CACHE_DIR="${CACHE_DIR:-$SAFE_UPDATE_DATA_DIR/cache}"
    STATE_DIR="${STATE_DIR:-$SAFE_UPDATE_DATA_DIR/state}"

    LOG_FILE="${LOG_FILE:-$LOG_DIR/update-$TIMESTAMP.log}"
    REPORT_FILE="${REPORT_FILE:-$REPORT_DIR/report-$TIMESTAMP.json}"
    SNAPSHOT_NAME="${SNAPSHOT_NAME:-$SNAPSHOT_PREFIX-$TIMESTAMP}"
}
