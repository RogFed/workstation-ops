#!/usr/bin/env bash

REPORT_ERROR_MESSAGE=""

set_report_error() {
    REPORT_ERROR_MESSAGE="$1"
}

prepare_report_file() {
    local report_dir="${REPORT_DIR:-$(dirname "$REPORT_FILE")}"
    local timestamp="${TIMESTAMP:-}"
    local default_report_file=""
    local disambiguator="${BASHPID:-$$}"
    local candidate=""
    local attempt=1

    if [[ -n "$timestamp" ]]; then
        default_report_file="$report_dir/report-$timestamp.json"
        candidate="$report_dir/report-$timestamp-$disambiguator.json"
    fi

    if [[ ! -e "$REPORT_FILE" ]]; then
        return 0
    fi

    if [[ "$REPORT_FILE" != "$default_report_file" ]]; then
        set_report_error "Refusing to overwrite existing report: $REPORT_FILE"
        return 1
    fi

    while [[ -e "$candidate" ]]; do
        candidate="$report_dir/report-$timestamp-$disambiguator-$attempt.json"
        attempt=$((attempt + 1))
    done

    REPORT_DIR="$report_dir"
    REPORT_FILE="$candidate"
}

json_array_from_args() {
    if [[ "$#" -eq 0 ]]; then
        printf '[]\n'
        return 0
    fi

    printf '%s\0' "$@" | jq -Rs 'split("\u0000")[:-1]'
}

json_string_or_null() {
    if [[ -n "${1:-}" ]]; then
        jq -Rn --arg value "$1" '$value'
    else
        printf 'null\n'
    fi
}

package_risk_metadata_json() {
    if [[ "${#RISK_PACKAGES[@]}" -eq 0 ]]; then
        printf '[]\n'
        return 0
    fi

    local package_json=()
    local pkg
    for pkg in "${RISK_PACKAGES[@]}"; do
        package_json+=("$(jq -cn \
            --arg name "$pkg" \
            --arg severity "${PACKAGE_SEVERITY[$pkg]:-LOW}" \
            --argjson reboot_required "$(json_bool "${PACKAGE_REBOOT_REQUIRED[$pkg]:-false}")" \
            --argjson boot_impact "$(json_bool "${PACKAGE_BOOT_IMPACT[$pkg]:-false}")" \
            --argjson graphics_impact "$(json_bool "${PACKAGE_GRAPHICS_IMPACT[$pkg]:-false}")" \
            --argjson core_system_impact "$(json_bool "${PACKAGE_CORE_SYSTEM_IMPACT[$pkg]:-false}")" \
            --argjson userland_only "$(json_bool "${PACKAGE_USERLAND_ONLY[$pkg]:-false}")" \
            --argjson aur_package "$(json_bool "${PACKAGE_AUR[$pkg]:-false}")" \
            '{
                name: $name,
                severity: $severity,
                reboot_required: $reboot_required,
                boot_impact: $boot_impact,
                graphics_impact: $graphics_impact,
                core_system_impact: $core_system_impact,
                userland_only: $userland_only,
                aur_package: $aur_package
            }')"
        )
    done

    printf '%s\n' "${package_json[@]}" | jq -s '.'
}

risk_summary_json() {
    jq -n \
        --argjson critical_package_count "${#CRITICAL_PACKAGES[@]}" \
        --argjson high_package_count "${#HIGH_PACKAGES[@]}" \
        --argjson medium_package_count "${#MEDIUM_PACKAGES[@]}" \
        --argjson low_package_count "${#LOW_PACKAGES[@]}" \
        --argjson graphics_stack_changed "$(json_bool "${GRAPHICS_STACK_CHANGED:-false}")" \
        --argjson boot_chain_changed "$(json_bool "${BOOT_CHAIN_CHANGED:-false}")" \
        --argjson core_system_changed "$(json_bool "${CORE_SYSTEM_CHANGED:-false}")" \
        --argjson reboot_required "$(json_bool "${REBOOT_REQUIRED:-false}")" \
        --argjson aur_package_count "${AUR_PACKAGE_COUNT:-0}" \
        '{
            critical_package_count: $critical_package_count,
            high_package_count: $high_package_count,
            medium_package_count: $medium_package_count,
            low_package_count: $low_package_count,
            graphics_stack_changed: $graphics_stack_changed,
            boot_chain_changed: $boot_chain_changed,
            core_system_changed: $core_system_changed,
            reboot_required: $reboot_required,
            aur_package_count: $aur_package_count
        }'
}

generate_report() {
    local update_result="$1"
    local snapshot_name="$2"
    local snapshot_created="$3"
    local reboot_required="$4"
    local version
    local hostname
    local kernel
    local bootloader
    local duration_seconds
    local critical_updates
    local high_updates
    local medium_updates
    local low_updates
    local snapshot_name_json
    local snapshot_id_json
    local risk_summary
    local package_risk_metadata

    if ! bool_is_true "$ENABLE_REPORTS"; then
        return 0
    fi

    if ! have_command jq; then
        set_report_error "Structured reports require jq"
        return 1
    fi

    version=$(safe_update_version)
    hostname=$(system_hostname)
    kernel=$(kernel_version)
    bootloader=$(detect_bootloader)
    duration_seconds=$(elapsed_seconds "${RUN_START_EPOCH:-0}")
    critical_updates=$(json_array_from_args "${CRITICAL_PACKAGES[@]}")
    high_updates=$(json_array_from_args "${HIGH_PACKAGES[@]}")
    medium_updates=$(json_array_from_args "${MEDIUM_PACKAGES[@]}")
    low_updates=$(json_array_from_args "${LOW_PACKAGES[@]}")
    snapshot_name_json=$(json_string_or_null "$snapshot_name")
    snapshot_id_json=$(json_string_or_null "${SNAPSHOT_ID:-}")
    risk_summary=$(risk_summary_json)
    package_risk_metadata=$(package_risk_metadata_json)

    jq -n \
        --arg version "$version" \
        --arg timestamp "$ISO_TIMESTAMP" \
        --arg hostname "$hostname" \
        --arg kernel_version "$kernel" \
        --arg bootloader "$bootloader" \
        --arg update_result "$update_result" \
        --arg log_file "$LOG_FILE" \
        --arg report_path "$REPORT_FILE" \
        --argjson snapshot_created "$(json_bool "$snapshot_created")" \
        --argjson snapshot_name "$snapshot_name_json" \
        --argjson snapshot_id "$snapshot_id_json" \
        --argjson critical_updates "$critical_updates" \
        --argjson high_updates "$high_updates" \
        --argjson medium_updates "$medium_updates" \
        --argjson low_updates "$low_updates" \
        --argjson risk_summary "$risk_summary" \
        --argjson package_risk_metadata "$package_risk_metadata" \
        --argjson reboot_required "$(json_bool "$reboot_required")" \
        --argjson arch_news_detected "$(json_bool "$ARCH_NEWS_DETECTED")" \
        --argjson cachyos_news_detected "$(json_bool "$CACHYOS_NEWS_DETECTED")" \
        --argjson duration_seconds "$duration_seconds" \
        '{
            version: $version,
            timestamp: $timestamp,
            hostname: $hostname,
            kernel_version: $kernel_version,
            bootloader: $bootloader,
            snapshot: {
                created: $snapshot_created,
                name: $snapshot_name,
                id: $snapshot_id
            },
            updates: {
                critical: $critical_updates,
                high: $high_updates,
                medium: $medium_updates,
                low: $low_updates
            },
            package_risk_metadata: $package_risk_metadata,
            risk_summary: $risk_summary,
            reboot_required: $reboot_required,
            update_result: $update_result,
            duration_seconds: $duration_seconds,
            advisory_flags: {
                arch_news_detected: $arch_news_detected,
                cachyos_news_detected: $cachyos_news_detected
            },
            log_file: $log_file,
            report_path: $report_path
        }'
}

validate_report() {
    local validation_error=""
    local validation_target="$1"

    if ! have_command jq; then
        set_report_error "Structured reports require jq"
        return 1
    fi

    if [[ -n "${REPORT_DIR:-}" && -n "${REPORT_FILE:-}" && "$1" == "$REPORT_DIR"/.report-* ]]; then
        validation_target="$REPORT_FILE"
    fi

    if ! validation_error=$({
        jq -e '
        (.version | type == "string") and
        (.timestamp | type == "string") and
        (.hostname | type == "string") and
        (.kernel_version | type == "string") and
        (.bootloader | type == "string") and
        (.snapshot | type == "object") and
        (.snapshot.created | type == "boolean") and
        ((.snapshot.name == null) or (.snapshot.name | type == "string")) and
        ((.snapshot.id == null) or (.snapshot.id | type == "string")) and
        (.updates | type == "object") and
        (.updates.critical | type == "array") and
        (.updates.high | type == "array") and
        (.updates.medium | type == "array") and
        (.updates.low | type == "array") and
        (.package_risk_metadata | type == "array") and
        (all(.package_risk_metadata[];
            (. | type == "object") and
            (.name | type == "string") and
            ((.severity == "CRITICAL") or (.severity == "HIGH") or (.severity == "MEDIUM") or (.severity == "LOW")) and
            (.reboot_required | type == "boolean") and
            (.boot_impact | type == "boolean") and
            (.graphics_impact | type == "boolean") and
            (.core_system_impact | type == "boolean") and
            (.userland_only | type == "boolean") and
            (.aur_package | type == "boolean")
        )) and
        (.risk_summary | type == "object") and
        (.risk_summary.critical_package_count | type == "number") and
        (.risk_summary.high_package_count | type == "number") and
        (.risk_summary.medium_package_count | type == "number") and
        (.risk_summary.low_package_count | type == "number") and
        (.risk_summary.graphics_stack_changed | type == "boolean") and
        (.risk_summary.boot_chain_changed | type == "boolean") and
        (.risk_summary.core_system_changed | type == "boolean") and
        (.risk_summary.reboot_required | type == "boolean") and
        (.risk_summary.aur_package_count | type == "number") and
        (.reboot_required | type == "boolean") and
        (.update_result | type == "string") and
        (.duration_seconds | type == "number") and
        (.duration_seconds >= 0) and
        (.advisory_flags.arch_news_detected | type == "boolean") and
        (.advisory_flags.cachyos_news_detected | type == "boolean") and
        (.log_file | type == "string") and
        (.report_path | type == "string")
    ' "$1" > /dev/null
    } 2>&1); then
        if [[ -n "$validation_error" ]]; then
            set_report_error "Generated report failed validation: $validation_target ($validation_error)"
        else
            set_report_error "Generated report failed validation: $validation_target"
        fi
        return 1
    fi
}

save_report() {
    local report_content="$1"
    local report_dir
    local tmp_report_file

    if ! bool_is_true "$ENABLE_REPORTS"; then
        return 0
    fi

    report_dir="$(dirname "$REPORT_FILE")"
    if ! mkdir -p "$report_dir"; then
        set_report_error "Failed to create report directory: $report_dir"
        return 1
    fi

    if [[ -e "$REPORT_FILE" ]]; then
        set_report_error "Refusing to overwrite existing report: $REPORT_FILE"
        return 1
    fi

    if ! tmp_report_file=$(mktemp "$report_dir/.report-XXXXXX.tmp"); then
        set_report_error "Failed to create temporary report file in: $report_dir"
        return 1
    fi

    if ! chmod 600 "$tmp_report_file"; then
        set_report_error "Failed to secure temporary report file: $tmp_report_file"
        rm -f "$tmp_report_file"
        return 1
    fi

    if ! printf '%s\n' "$report_content" > "$tmp_report_file"; then
        set_report_error "Failed to stage structured report: $REPORT_FILE"
        rm -f "$tmp_report_file"
        return 1
    fi

    if ! validate_report "$tmp_report_file"; then
        rm -f "$tmp_report_file"
        return 1
    fi

    if ! mv "$tmp_report_file" "$REPORT_FILE"; then
        set_report_error "Failed to persist structured report: $REPORT_FILE"
        rm -f "$tmp_report_file"
        return 1
    fi
}

write_report() {
    local report_content

    if ! bool_is_true "$ENABLE_REPORTS"; then
        return 0
    fi

    REPORT_ERROR_MESSAGE=""

    if ! prepare_report_file; then
        return 1
    fi

    if ! report_content=$(generate_report "$@"); then
        if [[ -z "$REPORT_ERROR_MESSAGE" ]]; then
            set_report_error "Failed to generate structured report"
        fi
        return 1
    fi

    save_report "$report_content"
}
