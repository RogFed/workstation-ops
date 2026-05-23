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
    if [[ -z "${1:-}" || "$1" == "/" ]]; then
        printf '%s\n' "ERROR: Refusing to create invalid directory path: ${1:-<empty>}" >&2
        return 1
    fi

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

current_epoch() {
    if [[ -n "${SAFE_UPDATE_NOW_EPOCH:-}" ]]; then
        printf '%s\n' "$SAFE_UPDATE_NOW_EPOCH"
    else
        date +%s
    fi
}

current_log_timestamp() {
    if [[ -n "${SAFE_UPDATE_LOG_TIMESTAMP:-}" ]]; then
        printf '%s\n' "$SAFE_UPDATE_LOG_TIMESTAMP"
    else
        date +"%Y-%m-%dT%H:%M:%S%z"
    fi
}

elapsed_seconds() {
    local start="${1:-0}"
    local end="${2:-$(current_epoch)}"

    if [[ ! "$start" =~ ^[0-9]+$ || ! "$end" =~ ^[0-9]+$ ]]; then
        printf '0\n'
        return 0
    fi

    if (( end < start )); then
        printf '0\n'
        return 0
    fi

    printf '%s\n' "$((end - start))"
}

safe_update_version() {
    if [[ -n "${SAFE_UPDATE_VERSION:-}" ]]; then
        printf '%s\n' "$SAFE_UPDATE_VERSION"
        return 0
    fi

    if [[ -n "${REPO_ROOT:-}" && -f "$REPO_ROOT/VERSION" ]]; then
        tr -d '\n' < "$REPO_ROOT/VERSION"
        printf '\n'
        return 0
    fi

    printf 'unknown\n'
}

system_hostname() {
    if [[ -n "${SAFE_UPDATE_HOSTNAME:-}" ]]; then
        printf '%s\n' "$SAFE_UPDATE_HOSTNAME"
    elif have_command hostname; then
        hostname
    else
        uname -n
    fi
}

kernel_version() {
    if [[ -n "${SAFE_UPDATE_KERNEL_VERSION:-}" ]]; then
        printf '%s\n' "$SAFE_UPDATE_KERNEL_VERSION"
    else
        uname -r
    fi
}

detect_bootloader() {
    if [[ -n "${SAFE_UPDATE_BOOTLOADER:-}" ]]; then
        printf '%s\n' "$SAFE_UPDATE_BOOTLOADER"
    elif [[ -f /boot/limine.conf || -f /boot/EFI/BOOT/limine.conf || -f /efi/limine.conf || -f /efi/EFI/BOOT/limine.conf ]]; then
        printf 'limine\n'
    elif have_command bootctl && bootctl is-installed > /dev/null 2>&1; then
        printf 'systemd-boot\n'
    elif [[ -f /boot/grub/grub.cfg || -d /boot/grub ]]; then
        printf 'grub\n'
    else
        printf 'unknown\n'
    fi
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
