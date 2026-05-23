#!/usr/bin/env bash

REPORT_ERROR_MESSAGE=""

set_report_error() {
    REPORT_ERROR_MESSAGE="$1"
    printf '%s\n' "ERROR: $1" >&2
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
    if ! have_command jq; then
        set_report_error "Structured reports require jq"
        return 1
    fi

    if ! jq -e '
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
        (.reboot_required | type == "boolean") and
        (.update_result | type == "string") and
        (.duration_seconds | type == "number") and
        (.duration_seconds >= 0) and
        (.advisory_flags.arch_news_detected | type == "boolean") and
        (.advisory_flags.cachyos_news_detected | type == "boolean") and
        (.log_file | type == "string") and
        (.report_path | type == "string")
    ' "$1" > /dev/null; then
        set_report_error "Generated report failed validation: $1"
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
    mkdir -p "$report_dir"

    if [[ -e "$REPORT_FILE" ]]; then
        set_report_error "Refusing to overwrite existing report: $REPORT_FILE"
        return 1
    fi

    tmp_report_file=$(mktemp "$report_dir/.report-XXXXXX.tmp")
    chmod 600 "$tmp_report_file"

    if ! printf '%s\n' "$report_content" > "$tmp_report_file"; then
        set_report_error "Failed to stage structured report: $REPORT_FILE"
        rm -f "$tmp_report_file"
        return 1
    fi

    if ! validate_report "$tmp_report_file"; then
        rm -f "$tmp_report_file"
        return 1
    fi

    mv "$tmp_report_file" "$REPORT_FILE"
}

write_report() {
    local report_content

    if ! bool_is_true "$ENABLE_REPORTS"; then
        return 0
    fi

    REPORT_ERROR_MESSAGE=""

    if ! report_content=$(generate_report "$@"); then
        if [[ -z "$REPORT_ERROR_MESSAGE" ]]; then
            set_report_error "Failed to generate structured report"
        fi
        return 1
    fi

    save_report "$report_content"
}
