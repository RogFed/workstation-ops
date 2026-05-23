#!/usr/bin/env bash

write_report() {
    local status="$1"
    local snapshot_name="$2"
    local reboot_required="$3"
    local report_dir
    local tmp_report_file

    if ! bool_is_true "$ENABLE_REPORTS"; then
        return 0
    fi

    report_dir="${REPORT_DIR:-$(dirname "$REPORT_FILE")}"
    tmp_report_file=$(mktemp "$report_dir/.report-XXXXXX.tmp")
    chmod 600 "$tmp_report_file"

    if ! {
        printf '{\n'
        printf '  "timestamp": "%s",\n' "$(json_escape "$ISO_TIMESTAMP")"
        printf '  "status": "%s",\n' "$(json_escape "$status")"
        printf '  "snapshot": "%s",\n' "$(json_escape "$snapshot_name")"
        printf '  "log_file": "%s",\n' "$(json_escape "$LOG_FILE")"
        printf '  "report_version": 1,\n'
        printf '  "critical_updates": %s,\n' "$(json_array "${CRITICAL_PACKAGES[@]}")"
        printf '  "high_updates": %s,\n' "$(json_array "${HIGH_PACKAGES[@]}")"
        printf '  "medium_updates": %s,\n' "$(json_array "${MEDIUM_PACKAGES[@]}")"
        printf '  "low_updates": %s,\n' "$(json_array "${LOW_PACKAGES[@]}")"
        printf '  "reboot_required": %s,\n' "$(json_bool "$reboot_required")"
        printf '  "arch_news_detected": %s,\n' "$(json_bool "$ARCH_NEWS_DETECTED")"
        printf '  "cachyos_news_detected": %s,\n' "$(json_bool "$CACHYOS_NEWS_DETECTED")"
        printf '  "report_path": "%s"\n' "$(json_escape "$REPORT_FILE")"
        printf '}\n'
    } > "$tmp_report_file"; then
        rm -f "$tmp_report_file"
        return 1
    fi

    mv "$tmp_report_file" "$REPORT_FILE"
}
