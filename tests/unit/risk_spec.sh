#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)/helpers/testlib.sh"
source "$REPO_ROOT/lib/utils.sh"
source "$REPO_ROOT/lib/risk.sh"

REBOOT_UPDATES=$'linux 1 -> 2\nmesa 3 -> 4'
NON_REBOOT_UPDATES=$'firefox 1 -> 2\nripgrep 3 -> 4'
MIXED_UPDATES=$'linux-cachyos 1 -> 2\nmesa 3 -> 4\nplasma-desktop 1 -> 2\nwarp-terminal-bin 1 -> 2'

assert_eq "CRITICAL" "$(classify_package "linux-cachyos")" "linux-cachyos should be critical"
assert_eq "HIGH" "$(classify_package "mesa")" "mesa should be high risk"
assert_eq "HIGH" "$(classify_package "linux-firmware")" "linux-firmware should stay high risk rather than being treated as a kernel package"
assert_eq "MEDIUM" "$(classify_package "plasma-desktop")" "plasma should remain medium risk"
assert_eq "LOW" "$(classify_package "firefox")" "regular applications should be low risk"
assert_eq "true" "$(has_boot_impact "linux-cachyos")" "Kernel packages should be marked as boot-impacting"
assert_eq "true" "$(has_graphics_impact "mesa")" "mesa should be marked as graphics-impacting"
assert_eq "true" "$(is_core_system_package "mesa")" "mesa should be treated as core system impact"
assert_eq "true" "$(is_aur_package "warp-terminal-bin")" "AUR-like package suffixes should be tracked"
assert_eq "true" "$(updates_require_reboot "$REBOOT_UPDATES")" "Kernel updates should require a reboot"
assert_eq "false" "$(updates_require_reboot "$NON_REBOOT_UPDATES")" "User-space app updates should not require a reboot"
assert_eq "mesa|HIGH|false|false|true|true|false|false" "$(build_risk_metadata "mesa")" "Risk metadata should be structured and metadata-driven"

analyze_updates "$MIXED_UPDATES"

assert_eq "1" "${#CRITICAL_PACKAGES[@]}" "One critical package should be tracked"
assert_eq "1" "${#HIGH_PACKAGES[@]}" "One high-risk package should be tracked"
assert_eq "1" "${#MEDIUM_PACKAGES[@]}" "One medium-risk package should be tracked"
assert_eq "1" "${#LOW_PACKAGES[@]}" "One low-risk package should be tracked"
assert_eq "4" "${#RISK_PACKAGES[@]}" "Each update should produce structured risk metadata"
assert_eq "true" "$BOOT_CHAIN_CHANGED" "Kernel-family updates should flag boot chain changes"
assert_eq "true" "$GRAPHICS_STACK_CHANGED" "Mesa and Plasma updates should flag graphics stack changes"
assert_eq "true" "$CORE_SYSTEM_CHANGED" "Core system metadata should be tracked"
assert_eq "1" "$AUR_PACKAGE_COUNT" "AUR-like packages should be counted"
assert_eq "true" "${PACKAGE_AUR["warp-terminal-bin"]}" "Per-package AUR metadata should be stored"
assert_eq "true" "${PACKAGE_GRAPHICS_IMPACT["mesa"]}" "Per-package graphics metadata should be stored"
assert_eq "true" "${PACKAGE_BOOT_IMPACT["linux-cachyos"]}" "Per-package boot metadata should be stored"
assert_eq "true" "$REBOOT_REQUIRED" "Critical kernel-family updates should require a reboot"
assert_eq "LOW" "${PACKAGE_BASE_SEVERITY["warp-terminal-bin"]}" "Base severity should preserve the non-advisory classification"

promote_package_severity "warp-terminal-bin" "HIGH" "true"
rebuild_risk_indexes

assert_eq "HIGH" "${PACKAGE_SEVERITY["warp-terminal-bin"]}" "Advisories should be able to promote package severity"
assert_eq "1" "${PACKAGE_ADVISORY_MATCH_COUNT["warp-terminal-bin"]}" "Advisory match counts should be tracked per package"
assert_eq "true" "${PACKAGE_ESCALATED_BY_ADVISORY["warp-terminal-bin"]}" "Advisory-driven promotions should be recorded"
assert_eq "true" "${PACKAGE_MANUAL_INTERVENTION_REQUIRED["warp-terminal-bin"]}" "Manual intervention flags should be tracked per package"
assert_contains "manual-intervention" "$(format_risk_summary_line "warp-terminal-bin" "${PACKAGE_SEVERITY["warp-terminal-bin"]}" "${PACKAGE_REBOOT_REQUIRED["warp-terminal-bin"]}" "${PACKAGE_BOOT_IMPACT["warp-terminal-bin"]}" "${PACKAGE_GRAPHICS_IMPACT["warp-terminal-bin"]}" "${PACKAGE_CORE_SYSTEM_IMPACT["warp-terminal-bin"]}" "${PACKAGE_AUR["warp-terminal-bin"]}")" "Risk summaries should surface advisory manual intervention details"
