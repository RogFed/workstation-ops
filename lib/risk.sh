#!/usr/bin/env bash

CRITICAL_PATTERNS=(
    "linux"
    "linux-cachyos"
    "nvidia"
    "glibc"
    "limine"
)

HIGH_PATTERNS=(
    "mesa"
    "systemd"
    "pipewire"
)

MEDIUM_PATTERNS=(
    "plasma"
)

REBOOT_PATTERNS=(
    "linux"
    "linux-cachyos"
    "nvidia"
    "systemd"
    "limine"
)

declare -ag CRITICAL_PACKAGES=()
declare -ag HIGH_PACKAGES=()
declare -ag MEDIUM_PACKAGES=()
declare -ag LOW_PACKAGES=()
declare -ag RISK_SUMMARY_LINES=()
REBOOT_REQUIRED="false"

reset_risk_state() {
    CRITICAL_PACKAGES=()
    HIGH_PACKAGES=()
    MEDIUM_PACKAGES=()
    LOW_PACKAGES=()
    RISK_SUMMARY_LINES=()
    REBOOT_REQUIRED="false"
}

classify_package() {
    local pkg="$1"

    if package_matches_any "$pkg" "${CRITICAL_PATTERNS[@]}"; then
        printf 'CRITICAL\n'
        return 0
    fi

    if package_matches_any "$pkg" "${HIGH_PATTERNS[@]}"; then
        printf 'HIGH\n'
        return 0
    fi

    if package_matches_any "$pkg" "${MEDIUM_PATTERNS[@]}"; then
        printf 'MEDIUM\n'
        return 0
    fi

    printf 'LOW\n'
}

package_matches_any() {
    local pkg="$1"
    shift

    local pattern
    for pattern in "$@"; do
        if [[ "$pkg" == *"$pattern"* ]]; then
            return 0
        fi
    done

    return 1
}

package_from_update_line() {
    awk '{print $1}' <<< "$1"
}

track_package_risk() {
    local pkg="$1"
    local risk="$2"

    RISK_SUMMARY_LINES+=("$pkg -> $risk")

    case "$risk" in
        CRITICAL)
            CRITICAL_PACKAGES+=("$pkg")
            ;;
        HIGH)
            HIGH_PACKAGES+=("$pkg")
            ;;
        MEDIUM)
            MEDIUM_PACKAGES+=("$pkg")
            ;;
        *)
            LOW_PACKAGES+=("$pkg")
            ;;
    esac
}

analyze_updates() {
    local updates="$1"
    local line
    local pkg
    local risk

    reset_risk_state

    while IFS= read -r line; do
        [[ -n "$line" ]] || continue

        pkg=$(package_from_update_line "$line")
        risk=$(classify_package "$pkg")
        track_package_risk "$pkg" "$risk"
    done <<< "$updates"

    REBOOT_REQUIRED=$(updates_require_reboot "$updates")
}

updates_require_reboot() {
    local updates="$1"
    local line
    local pkg

    while IFS= read -r line; do
        [[ -n "$line" ]] || continue

        pkg=$(package_from_update_line "$line")
        if package_matches_any "$pkg" "${REBOOT_PATTERNS[@]}"; then
            printf 'true\n'
            return 0
        fi
    done <<< "$updates"

    printf 'false\n'
}

print_risk_summary() {
    local line
    for line in "${RISK_SUMMARY_LINES[@]}"; do
        log "$line"
    done
}

risk_bucket_has_entries() {
    case "$1" in
        CRITICAL)
            [[ "${#CRITICAL_PACKAGES[@]}" -gt 0 ]]
            ;;
        HIGH)
            [[ "${#HIGH_PACKAGES[@]}" -gt 0 ]]
            ;;
        MEDIUM)
            [[ "${#MEDIUM_PACKAGES[@]}" -gt 0 ]]
            ;;
        LOW)
            [[ "${#LOW_PACKAGES[@]}" -gt 0 ]]
            ;;
        *)
            return 1
            ;;
    esac
}
