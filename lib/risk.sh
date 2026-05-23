#!/usr/bin/env bash

CRITICAL_PATTERNS=("linux-cachyos" "nvidia" "glibc" "limine" "amd-ucode" "intel-ucode" "microcode")
HIGH_PATTERNS=("mesa" "systemd" "pipewire" "mkinitcpio" "dracut" "linux-firmware" "vulkan-" "lib32-")
MEDIUM_PATTERNS=("plasma" "wayland" "xorg")

REBOOT_REQUIRED_PATTERNS=("linux-cachyos" "nvidia" "systemd" "limine" "amd-ucode" "intel-ucode" "microcode" "mkinitcpio" "dracut")
BOOT_IMPACT_PATTERNS=("linux-cachyos" "limine" "mkinitcpio" "dracut" "systemd" "linux-firmware" "amd-ucode" "intel-ucode" "microcode")
GRAPHICS_IMPACT_PATTERNS=("mesa" "vulkan-" "nvidia" "lib32-" "wayland" "plasma" "xorg" "pipewire")
CORE_SYSTEM_PATTERNS=("linux-cachyos" "glibc" "systemd" "linux-firmware" "mkinitcpio" "dracut" "limine" "amd-ucode" "intel-ucode" "microcode" "mesa" "nvidia" "pipewire")
AUR_SUFFIX_PATTERNS=("-git" "-bin" "-appimage" "-nightly")

declare -ag CRITICAL_PACKAGES=()
declare -ag HIGH_PACKAGES=()
declare -ag MEDIUM_PACKAGES=()
declare -ag LOW_PACKAGES=()
declare -ag RISK_SUMMARY_LINES=()
declare -ag RISK_PACKAGES=()
declare -ag BOOT_IMPACT_PACKAGES=()
declare -ag GRAPHICS_IMPACT_PACKAGES=()
declare -ag CORE_SYSTEM_PACKAGES=()
declare -ag USERLAND_PACKAGES=()
declare -ag AUR_PACKAGES=()
declare -Ag PACKAGE_SEVERITY=()
declare -Ag PACKAGE_REBOOT_REQUIRED=()
declare -Ag PACKAGE_BOOT_IMPACT=()
declare -Ag PACKAGE_GRAPHICS_IMPACT=()
declare -Ag PACKAGE_CORE_SYSTEM_IMPACT=()
declare -Ag PACKAGE_USERLAND_ONLY=()
declare -Ag PACKAGE_AUR=()
REBOOT_REQUIRED="false"
BOOT_CHAIN_CHANGED="false"
GRAPHICS_STACK_CHANGED="false"
CORE_SYSTEM_CHANGED="false"
AUR_PACKAGE_COUNT=0

reset_risk_state() {
    CRITICAL_PACKAGES=()
    HIGH_PACKAGES=()
    MEDIUM_PACKAGES=()
    LOW_PACKAGES=()
    RISK_SUMMARY_LINES=()
    RISK_PACKAGES=()
    BOOT_IMPACT_PACKAGES=()
    GRAPHICS_IMPACT_PACKAGES=()
    CORE_SYSTEM_PACKAGES=()
    USERLAND_PACKAGES=()
    AUR_PACKAGES=()
    PACKAGE_SEVERITY=()
    PACKAGE_REBOOT_REQUIRED=()
    PACKAGE_BOOT_IMPACT=()
    PACKAGE_GRAPHICS_IMPACT=()
    PACKAGE_CORE_SYSTEM_IMPACT=()
    PACKAGE_USERLAND_ONLY=()
    PACKAGE_AUR=()
    REBOOT_REQUIRED="false"
    BOOT_CHAIN_CHANGED="false"
    GRAPHICS_STACK_CHANGED="false"
    CORE_SYSTEM_CHANGED="false"
    AUR_PACKAGE_COUNT=0
}

classify_package() {
    local pkg="$1"

    if bool_is_true "$(is_kernel_package "$pkg")"; then
        printf 'CRITICAL\n'
        return 0
    fi

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

package_has_suffix_any() {
    local pkg="$1"
    shift

    local suffix
    for suffix in "$@"; do
        if [[ "$pkg" == *"$suffix" ]]; then
            return 0
        fi
    done

    return 1
}

package_from_update_line() {
    local pkg
    IFS=' ' read -r pkg _ <<< "$1"
    printf '%s\n' "$pkg"
}

is_kernel_package() {
    local pkg="$1"

    if [[ "$pkg" == "linux" ]]; then
        printf 'true\n'
    elif [[ "$pkg" == linux-* && "$pkg" != "linux-firmware" ]]; then
        printf 'true\n'
    else
        printf 'false\n'
    fi
}

requires_reboot() {
    if bool_is_true "$(is_kernel_package "$1")" || package_matches_any "$1" "${REBOOT_REQUIRED_PATTERNS[@]}"; then
        printf 'true\n'
    else
        printf 'false\n'
    fi
}

has_graphics_impact() {
    if package_matches_any "$1" "${GRAPHICS_IMPACT_PATTERNS[@]}"; then
        printf 'true\n'
    else
        printf 'false\n'
    fi
}

has_boot_impact() {
    if bool_is_true "$(is_kernel_package "$1")" || package_matches_any "$1" "${BOOT_IMPACT_PATTERNS[@]}"; then
        printf 'true\n'
    else
        printf 'false\n'
    fi
}

is_core_system_package() {
    if bool_is_true "$(is_kernel_package "$1")" || package_matches_any "$1" "${CORE_SYSTEM_PATTERNS[@]}"; then
        printf 'true\n'
    else
        printf 'false\n'
    fi
}

is_aur_package() {
    if package_has_suffix_any "$1" "${AUR_SUFFIX_PATTERNS[@]}"; then
        printf 'true\n'
    else
        printf 'false\n'
    fi
}

build_risk_metadata() {
    local pkg="$1"
    local severity
    local reboot_required
    local boot_impact
    local graphics_impact
    local core_system_impact
    local aur_package
    local userland_only="false"

    severity=$(classify_package "$pkg")
    reboot_required=$(requires_reboot "$pkg")
    boot_impact=$(has_boot_impact "$pkg")
    graphics_impact=$(has_graphics_impact "$pkg")
    core_system_impact=$(is_core_system_package "$pkg")
    aur_package=$(is_aur_package "$pkg")

    if ! bool_is_true "$boot_impact" && ! bool_is_true "$graphics_impact" && ! bool_is_true "$core_system_impact"; then
        userland_only="true"
    fi

    printf '%s|%s|%s|%s|%s|%s|%s|%s\n' \
        "$pkg" \
        "$severity" \
        "$reboot_required" \
        "$boot_impact" \
        "$graphics_impact" \
        "$core_system_impact" \
        "$userland_only" \
        "$aur_package"
}

format_risk_summary_line() {
    local pkg="$1"
    local severity="$2"
    local reboot_required="$3"
    local boot_impact="$4"
    local graphics_impact="$5"
    local core_system_impact="$6"
    local aur_package="$7"
    local details=()

    if bool_is_true "$reboot_required"; then
        details+=("reboot")
    fi
    if bool_is_true "$boot_impact"; then
        details+=("boot")
    fi
    if bool_is_true "$graphics_impact"; then
        details+=("graphics")
    fi
    if bool_is_true "$core_system_impact"; then
        details+=("core-system")
    fi
    if bool_is_true "$aur_package"; then
        details+=("aur")
    fi

    if [[ "${#details[@]}" -eq 0 ]]; then
        printf '%s -> %s\n' "$pkg" "$severity"
    else
        printf '%s -> %s [%s]\n' "$pkg" "$severity" "$(join_by ", " "${details[@]}")"
    fi
}

track_package_risk() {
    local metadata="$1"
    local pkg
    local severity
    local reboot_required
    local boot_impact
    local graphics_impact
    local core_system_impact
    local userland_only
    local aur_package

    IFS='|' read -r pkg severity reboot_required boot_impact graphics_impact core_system_impact userland_only aur_package <<< "$metadata"

    RISK_PACKAGES+=("$pkg")
    PACKAGE_SEVERITY["$pkg"]="$severity"
    PACKAGE_REBOOT_REQUIRED["$pkg"]="$reboot_required"
    PACKAGE_BOOT_IMPACT["$pkg"]="$boot_impact"
    PACKAGE_GRAPHICS_IMPACT["$pkg"]="$graphics_impact"
    PACKAGE_CORE_SYSTEM_IMPACT["$pkg"]="$core_system_impact"
    PACKAGE_USERLAND_ONLY["$pkg"]="$userland_only"
    PACKAGE_AUR["$pkg"]="$aur_package"
    RISK_SUMMARY_LINES+=("$(format_risk_summary_line "$pkg" "$severity" "$reboot_required" "$boot_impact" "$graphics_impact" "$core_system_impact" "$aur_package")")

    case "$severity" in
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

    if bool_is_true "$reboot_required"; then
        REBOOT_REQUIRED="true"
    fi
    if bool_is_true "$boot_impact"; then
        BOOT_IMPACT_PACKAGES+=("$pkg")
        BOOT_CHAIN_CHANGED="true"
    fi
    if bool_is_true "$graphics_impact"; then
        GRAPHICS_IMPACT_PACKAGES+=("$pkg")
        GRAPHICS_STACK_CHANGED="true"
    fi
    if bool_is_true "$core_system_impact"; then
        CORE_SYSTEM_PACKAGES+=("$pkg")
        CORE_SYSTEM_CHANGED="true"
    fi
    if bool_is_true "$userland_only"; then
        USERLAND_PACKAGES+=("$pkg")
    fi
    if bool_is_true "$aur_package"; then
        AUR_PACKAGES+=("$pkg")
        AUR_PACKAGE_COUNT=$((AUR_PACKAGE_COUNT + 1))
    fi
}

analyze_updates() {
    local updates="$1"
    local line
    local pkg
    local metadata

    reset_risk_state

    while IFS= read -r line; do
        [[ -n "$line" ]] || continue

        pkg=$(package_from_update_line "$line")
        metadata=$(build_risk_metadata "$pkg")
        track_package_risk "$metadata"
    done <<< "$updates"
}

updates_require_reboot() {
    local updates="$1"
    local line
    local pkg

    while IFS= read -r line; do
        [[ -n "$line" ]] || continue

        pkg=$(package_from_update_line "$line")
        if bool_is_true "$(requires_reboot "$pkg")"; then
            printf 'true\n'
            return 0
        fi
    done <<< "$updates"

    printf 'false\n'
}

print_impact_summary() {
    if bool_is_true "$GRAPHICS_STACK_CHANGED"; then
        log "Graphics stack updates detected: $(join_by ", " "${GRAPHICS_IMPACT_PACKAGES[@]}")"
    fi

    if bool_is_true "$BOOT_CHAIN_CHANGED"; then
        log "Boot chain updates detected: $(join_by ", " "${BOOT_IMPACT_PACKAGES[@]}")"
    fi

    if [[ "$AUR_PACKAGE_COUNT" -gt 0 ]]; then
        log "AUR-sensitive package updates detected: $(join_by ", " "${AUR_PACKAGES[@]}")"
    fi
}

print_risk_summary() {
    local line
    for line in "${RISK_SUMMARY_LINES[@]}"; do
        log "$line"
    done
    print_impact_summary
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
