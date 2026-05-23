#!/usr/bin/env bash

bool_is_true() {
    case "${1:-false}" in
        true|TRUE|True|1|yes|YES|Yes|on|ON|On)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

is_yes() {
    [[ "${1:-}" =~ ^[Yy]$ ]]
}

ensure_dir() {
    mkdir -p "$1"
}

ensure_runtime_dirs() {
    ensure_dir "$LOG_DIR"
    ensure_dir "$REPORT_DIR"
    ensure_dir "$CACHE_DIR"
    ensure_dir "$STATE_DIR"
}

have_command() {
    command -v "$1" > /dev/null 2>&1
}

json_escape() {
    local value="${1:-}"
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/\\n}
    value=${value//$'\r'/\\r}
    value=${value//$'\t'/\\t}
    printf '%s' "$value"
}

json_array() {
    local first=1
    local item

    printf '['
    for item in "$@"; do
        if [[ "$first" -eq 0 ]]; then
            printf ', '
        fi
        printf '"%s"' "$(json_escape "$item")"
        first=0
    done
    printf ']'
}

json_bool() {
    if bool_is_true "${1:-false}"; then
        printf 'true'
    else
        printf 'false'
    fi
}
