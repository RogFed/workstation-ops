#!/usr/bin/env bash

validate_runtime_path() {
    local name="$1"
    local value="$2"

    if [[ -z "$value" || "$value" == "/" ]]; then
        printf '%s\n' "ERROR: $name must not be empty or /" >&2
        return 1
    fi
}

init_config() {
    local repo_root="$1"
    local env_data_dir_set="false"
    local env_data_dir=""
    local env_checkupdates_bin_set="false"
    local env_checkupdates_bin=""
    local env_paru_bin_set="false"
    local env_paru_bin=""
    local env_timestamp_set="false"
    local env_timestamp=""
    local env_iso_timestamp_set="false"
    local env_iso_timestamp=""

    REPO_ROOT="$repo_root"
    CONFIG_FILE="${SAFE_UPDATE_CONFIG_FILE:-$REPO_ROOT/config/safe-update.conf}"

    if [[ -v SAFE_UPDATE_DATA_DIR && -n "$SAFE_UPDATE_DATA_DIR" ]]; then
        env_data_dir_set="true"
        env_data_dir="$SAFE_UPDATE_DATA_DIR"
    fi

    if [[ -v CHECKUPDATES_BIN && -n "$CHECKUPDATES_BIN" ]]; then
        env_checkupdates_bin_set="true"
        env_checkupdates_bin="$CHECKUPDATES_BIN"
    fi

    if [[ -v PARU_BIN && -n "$PARU_BIN" ]]; then
        env_paru_bin_set="true"
        env_paru_bin="$PARU_BIN"
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
    CHECKUPDATES_BIN="${CHECKUPDATES_BIN:-checkupdates}"
    PARU_BIN="${PARU_BIN:-paru}"
    NOTIFY_SEND_BIN="${NOTIFY_SEND_BIN:-notify-send}"
    SUDO_BIN="${SUDO_BIN:-sudo}"
    SNAPPER_BIN="${SNAPPER_BIN:-snapper}"

    if [[ -f "$CONFIG_FILE" ]]; then
        # The config file is sourced as shell code, so it must come from a trusted location.
        # shellcheck disable=SC1090
        source "$CONFIG_FILE"
    fi

    if [[ "$env_data_dir_set" == "true" ]]; then
        SAFE_UPDATE_DATA_DIR="$env_data_dir"
    fi

    if [[ "$env_checkupdates_bin_set" == "true" ]]; then
        CHECKUPDATES_BIN="$env_checkupdates_bin"
    fi

    if [[ "$env_paru_bin_set" == "true" ]]; then
        PARU_BIN="$env_paru_bin"
    fi

    if [[ "$env_timestamp_set" == "true" ]]; then
        TIMESTAMP="$env_timestamp"
    fi

    if [[ "$env_iso_timestamp_set" == "true" ]]; then
        ISO_TIMESTAMP="$env_iso_timestamp"
    fi

    SAFE_UPDATE_DATA_DIR="${SAFE_UPDATE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/safe-update}"
    TIMESTAMP="${TIMESTAMP:-$(date +"%Y-%m-%dT%H%M%S")}"
    ISO_TIMESTAMP="${ISO_TIMESTAMP:-$(date --iso-8601=seconds)}"

    LOG_DIR="${LOG_DIR:-$SAFE_UPDATE_DATA_DIR/logs}"
    REPORT_DIR="${REPORT_DIR:-$SAFE_UPDATE_DATA_DIR/reports}"
    CACHE_DIR="${CACHE_DIR:-$SAFE_UPDATE_DATA_DIR/cache}"
    STATE_DIR="${STATE_DIR:-$SAFE_UPDATE_DATA_DIR/state}"

    LOG_FILE="${LOG_FILE:-$LOG_DIR/update-$TIMESTAMP.log}"
    REPORT_FILE="${REPORT_FILE:-$REPORT_DIR/report-$TIMESTAMP.json}"
    LOG_DIR="$(dirname "$LOG_FILE")"
    REPORT_DIR="$(dirname "$REPORT_FILE")"
    SNAPSHOT_NAME="${SNAPSHOT_NAME:-$SNAPSHOT_PREFIX-$TIMESTAMP}"

    validate_runtime_path "SAFE_UPDATE_DATA_DIR" "$SAFE_UPDATE_DATA_DIR" || return 1
    validate_runtime_path "LOG_DIR" "$LOG_DIR" || return 1
    validate_runtime_path "REPORT_DIR" "$REPORT_DIR" || return 1
    validate_runtime_path "CACHE_DIR" "$CACHE_DIR" || return 1
    validate_runtime_path "STATE_DIR" "$STATE_DIR" || return 1
}
