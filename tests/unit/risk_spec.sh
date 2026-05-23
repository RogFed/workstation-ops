#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)/helpers/testlib.sh"
source "$REPO_ROOT/lib/risk.sh"

assert_eq "CRITICAL" "$(classify_package "linux-cachyos")" "linux-cachyos should be critical"
assert_eq "HIGH" "$(classify_package "pipewire")" "pipewire should be high risk"
assert_eq "MEDIUM" "$(classify_package "plasma-desktop")" "plasma should remain medium risk"
assert_eq "LOW" "$(classify_package "firefox")" "regular applications should be low risk"
assert_eq "true" "$(updates_require_reboot $'linux 1 -> 2\nmesa 3 -> 4')" "Kernel updates should require a reboot"
assert_eq "false" "$(updates_require_reboot $'firefox 1 -> 2\nripgrep 3 -> 4')" "User-space app updates should not require a reboot"

analyze_updates $'linux-cachyos 1 -> 2\npipewire 1 -> 2\nplasma-desktop 1 -> 2\nfirefox 1 -> 2'

assert_eq "1" "${#CRITICAL_PACKAGES[@]}" "One critical package should be tracked"
assert_eq "1" "${#HIGH_PACKAGES[@]}" "One high-risk package should be tracked"
assert_eq "1" "${#MEDIUM_PACKAGES[@]}" "One medium-risk package should be tracked"
assert_eq "1" "${#LOW_PACKAGES[@]}" "One low-risk package should be tracked"
assert_eq "true" "$REBOOT_REQUIRED" "Critical kernel-family updates should require a reboot"
