#!/usr/bin/env bash

declare -ag ADVISORY_SUMMARY_LINES=()
declare -ag RELEVANT_ADVISORY_TITLES=()
declare -Ag ADVISORY_FETCH_STATUS=()

ADVISORIES_JSON='[]'
RELEVANT_ADVISORIES_JSON='[]'
ESCALATED_PACKAGES_JSON='[]'
MANUAL_INTERVENTION_REQUIRED="false"
ADVISORY_COUNT=0
RELEVANT_ADVISORY_COUNT=0

reset_advisory_state() {
    ADVISORY_SUMMARY_LINES=()
    RELEVANT_ADVISORY_TITLES=()
    ADVISORY_FETCH_STATUS=()
    ADVISORIES_JSON='[]'
    RELEVANT_ADVISORIES_JSON='[]'
    ESCALATED_PACKAGES_JSON='[]'
    MANUAL_INTERVENTION_REQUIRED="false"
    ADVISORY_COUNT=0
    RELEVANT_ADVISORY_COUNT=0
    ARCH_NEWS_DETECTED="false"
    CACHYOS_NEWS_DETECTED="false"
}

advisory_support_available() {
    if have_command "${CURL_BIN:-curl}"; then
        return 0
    fi

    warn "Advisory fetch skipped: ${CURL_BIN:-curl} not found"
    return 1
}

advisory_cache_file() {
    printf '%s/%s-news.json\n' "$CACHE_DIR" "$1"
}

advisory_cache_is_fresh() {
    local cache_file="$1"
    local fetched_at_epoch
    local now_epoch

    [[ -f "$cache_file" ]] || return 1

    if ! fetched_at_epoch=$(jq -r '.fetched_at_epoch // 0' "$cache_file" 2> /dev/null); then
        return 1
    fi

    [[ "$fetched_at_epoch" =~ ^[0-9]+$ ]] || return 1

    now_epoch=$(current_epoch)
    (( now_epoch - fetched_at_epoch <= ADVISORY_CACHE_TTL_SECONDS ))
}

read_cached_advisories() {
    local cache_file="$1"

    if [[ ! -f "$cache_file" ]]; then
        printf '[]\n'
        return 0
    fi

    jq -c '.advisories // []' "$cache_file"
}

write_advisory_cache() {
    local source="$1"
    local url="$2"
    local advisories_json="$3"
    local cache_file
    local tmp_file

    cache_file=$(advisory_cache_file "$source")
    ensure_dir "$CACHE_DIR"

    if ! tmp_file=$(mktemp "$CACHE_DIR/.${source}-news-XXXXXX.tmp"); then
        warn "Advisory cache skipped: unable to create temporary cache file for $source"
        return 1
    fi

    if ! jq -n \
        --arg source "$source" \
        --arg url "$url" \
        --arg fetched_at "$ISO_TIMESTAMP" \
        --argjson fetched_at_epoch "$(current_epoch)" \
        --argjson ttl_seconds "${ADVISORY_CACHE_TTL_SECONDS:-21600}" \
        --argjson advisories "$advisories_json" \
        '{
            source: $source,
            url: $url,
            fetched_at: $fetched_at,
            fetched_at_epoch: $fetched_at_epoch,
            ttl_seconds: $ttl_seconds,
            advisories: $advisories
        }' > "$tmp_file"; then
        rm -f "$tmp_file"
        warn "Advisory cache skipped: unable to serialize cache for $source"
        return 1
    fi

    if ! mv "$tmp_file" "$cache_file"; then
        rm -f "$tmp_file"
        warn "Advisory cache skipped: unable to persist cache for $source"
        return 1
    fi
}

fetch_advisory_source() {
    "${CURL_BIN:-curl}" -fsSL --connect-timeout 5 --max-time 20 "$1"
}

load_or_refresh_advisories() {
    local source="$1"
    local url="$2"
    local fetch_fn="$3"
    local parse_fn="$4"
    local cache_file
    local raw_content
    local advisories_json

    cache_file=$(advisory_cache_file "$source")

    if advisory_cache_is_fresh "$cache_file"; then
        ADVISORY_FETCH_STATUS["$source"]="cache"
        read_cached_advisories "$cache_file"
        return 0
    fi

    if ! raw_content=$("$fetch_fn" "$url"); then
        warn "Advisory fetch failed for $source: $url"
        if [[ -f "$cache_file" ]]; then
            ADVISORY_FETCH_STATUS["$source"]="stale-cache"
            read_cached_advisories "$cache_file"
            return 0
        fi

        ADVISORY_FETCH_STATUS["$source"]="unavailable"
        printf '[]\n'
        return 0
    fi

    if ! advisories_json=$("$parse_fn" "$raw_content"); then
        warn "Advisory parse failed for $source"
        if [[ -f "$cache_file" ]]; then
            ADVISORY_FETCH_STATUS["$source"]="stale-cache"
            read_cached_advisories "$cache_file"
            return 0
        fi

        ADVISORY_FETCH_STATUS["$source"]="parse-failed"
        printf '[]\n'
        return 0
    fi

    write_advisory_cache "$source" "$url" "$advisories_json" > /dev/null || true
    ADVISORY_FETCH_STATUS["$source"]="network"
    printf '%s\n' "$advisories_json"
}

advisory_json_array_from_lines() {
    if [[ "$#" -eq 0 ]]; then
        printf '[]\n'
        return 0
    fi

    printf '%s\n' "$@" | jq -Rsc 'split("\n")[:-1]'
}

advisory_token_allowed() {
    case "$1" in
        ""|the|and|for|with|from|into|that|this|have|will|your|when|after|before|they|them|their|these|those|uses|using|user|users|package|packages|update|updates|upgrading|upgrade|arch|linux|archlinux|cachyos|news|blog|recent|release|manual|intervention|required|review|recommended|detected|system|systems|main|older|newer|open|modules|defaults|backend|support|switch|changes|change|series|version|stable|latest)
            return 1
            ;;
    esac

    [[ "$1" =~ [a-z] ]]
}

collect_unique_tokens() {
    local value="$1"
    local token
    local seen='|'
    local output=()

    while IFS= read -r token; do
        [[ -n "$token" ]] || continue
        advisory_token_allowed "$token" || continue
        if [[ "$seen" != *"|$token|"* ]]; then
            output+=("$token")
            seen="${seen}${token}|"
        fi
    done < <(printf '%s' "$value" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]+._-' '\n')

    if [[ "${#output[@]}" -eq 0 ]]; then
        return 0
    fi

    printf '%s\n' "${output[@]}"
}

extract_related_packages_json() {
    local title="$1"
    local summary="$2"
    local token
    local code_tokens=""
    local text_tokens=""
    local decoded_text

    decoded_text="$(html_entity_decode "$title"$'\n'"$summary")"
    while IFS= read -r token; do
        [[ -n "$token" ]] || continue
        code_tokens+="${token}"$'\n'
    done < <(printf '%s' "$decoded_text" \
        | grep -Eo '<code>[^<]+' 2> /dev/null \
        | sed 's/^<code>//')

    while IFS= read -r token; do
        [[ -n "$token" ]] || continue
        text_tokens+="${token}"$'\n'
    done < <(collect_unique_tokens "$title $summary")

    if [[ -n "$code_tokens$text_tokens" ]]; then
        printf '%s%s' "$code_tokens" "$text_tokens" | jq -Rsc 'split("\n")[:-1] | unique'
    else
        printf '[]\n'
    fi
}

extract_advisory_keywords_json() {
    local title="$1"
    local summary="$2"
    local keywords=""
    local token

    while IFS= read -r token; do
        [[ -n "$token" ]] || continue
        keywords+="${token}"$'\n'
    done < <(collect_unique_tokens "$title $summary")

    if [[ -n "$keywords" ]]; then
        printf '%s' "$keywords" | jq -Rsc 'split("\n")[:-1] | unique'
    else
        printf '[]\n'
    fi
}

advisory_has_phrase() {
    local haystack="$1"
    local phrase="$2"
    [[ "$haystack" == *"$phrase"* ]]
}

derive_advisory_manual_intervention() {
    local advisory_text
    advisory_text=$(lowercase "$1 $2")

    if advisory_has_phrase "$advisory_text" "manual intervention" \
        || advisory_has_phrase "$advisory_text" "intervention required" \
        || advisory_has_phrase "$advisory_text" "must run" \
        || advisory_has_phrase "$advisory_text" "must switch" \
        || advisory_has_phrase "$advisory_text" "after the upgrade" \
        || advisory_has_phrase "$advisory_text" "pacsave"; then
        printf 'true\n'
    else
        printf 'false\n'
    fi
}

derive_advisory_severity() {
    local source="$1"
    local title="$2"
    local summary="$3"
    local category="${4:-}"
    local advisory_text

    advisory_text=$(lowercase "$title $summary $category")

    if bool_is_true "$(derive_advisory_manual_intervention "$title" "$summary")"; then
        printf 'HIGH\n'
        return 0
    fi

    if advisory_has_phrase "$advisory_text" "drops support" \
        || advisory_has_phrase "$advisory_text" "broken graphical" \
        || advisory_has_phrase "$advisory_text" "will fail"; then
        printf 'CRITICAL\n'
        return 0
    fi

    if advisory_has_phrase "$advisory_text" "drops" \
        || advisory_has_phrase "$advisory_text" "migration" \
        || advisory_has_phrase "$advisory_text" "transition" \
        || advisory_has_phrase "$advisory_text" "rebuild" \
        || advisory_has_phrase "$advisory_text" "compatibility"; then
        printf 'HIGH\n'
        return 0
    fi

    if advisory_has_phrase "$advisory_text" "nvidia" \
        || advisory_has_phrase "$advisory_text" "kernel" \
        || advisory_has_phrase "$advisory_text" "scheduler" \
        || advisory_has_phrase "$advisory_text" "wayland" \
        || advisory_has_phrase "$advisory_text" "systemd" \
        || advisory_has_phrase "$advisory_text" "bootloader" \
        || advisory_has_phrase "$advisory_text" "mkinitcpio" \
        || advisory_has_phrase "$advisory_text" "dracut"; then
        printf 'MEDIUM\n'
        return 0
    fi

    if [[ "$source" == "cachyos" && "$category" == "release" ]]; then
        printf 'LOW\n'
    else
        printf 'INFO\n'
    fi
}

build_normalized_advisory_json() {
    local source="$1"
    local title="$2"
    local url="$3"
    local published_at="$4"
    local summary="$5"
    local category="${6:-}"
    local severity
    local manual_intervention
    local keywords_json
    local related_packages_json

    title=$(normalize_whitespace "$(html_entity_decode "$title")")
    summary=$(normalize_whitespace "$(html_entity_decode "$summary")")
    severity=$(derive_advisory_severity "$source" "$title" "$summary" "$category")
    manual_intervention=$(derive_advisory_manual_intervention "$title" "$summary")
    keywords_json=$(extract_advisory_keywords_json "$title" "$summary")
    related_packages_json=$(extract_related_packages_json "$title" "$summary")

    jq -cn \
        --arg source "$source" \
        --arg title "$title" \
        --arg url "$url" \
        --arg published_at "$published_at" \
        --arg summary "$summary" \
        --arg category "$category" \
        --arg severity "$severity" \
        --argjson manual_intervention "$(json_bool "$manual_intervention")" \
        --argjson related_packages "$related_packages_json" \
        --argjson keywords "$keywords_json" \
        '{
            source: $source,
            title: $title,
            url: $url,
            published_at: $published_at,
            summary: $summary,
            category: $category,
            severity: $severity,
            manual_intervention: $manual_intervention,
            related_packages: $related_packages,
            keywords: $keywords
        }'
}

package_correlation_aliases() {
    local pkg
    local alias
    local seen='|'
    local aliases=()

    pkg=$(lowercase "$1")
    aliases+=("$pkg")

    IFS='-' read -r -a parts <<< "$pkg"
    for alias in "${parts[@]}"; do
        case "$alias" in
            ""|bin|git|open|dkms|lts|lib32|qt5|qt6|python3)
                continue
                ;;
        esac
        if [[ "${#alias}" -lt 4 ]]; then
            continue
        fi
        aliases+=("$alias")
    done

    if bool_is_true "$(is_kernel_package "$pkg")"; then
        aliases+=("kernel" "scheduler")
    fi

    case "$pkg" in
        *nvidia*)
            aliases+=("nvidia")
            ;;
        *limine*|*mkinitcpio*|*dracut*)
            aliases+=("bootloader" "initramfs")
            ;;
        *systemd*)
            aliases+=("systemd")
            ;;
        *pipewire*)
            aliases+=("audio" "pipewire")
            ;;
        *mesa*|*vulkan*|*wayland*|*plasma*|*xorg*)
            aliases+=("graphics")
            ;;
    esac

    for alias in "${aliases[@]}"; do
        [[ -n "$alias" ]] || continue
        if [[ "$seen" != *"|$alias|"* ]]; then
            printf '%s\n' "$alias"
            seen="${seen}${alias}|"
        fi
    done
}

advisory_matches_package() {
    local pkg="$1"
    local corpus="$2"
    local alias

    while IFS= read -r alias; do
        [[ -n "$alias" ]] || continue
        if [[ "$corpus" == *"$alias"* ]]; then
            return 0
        fi
    done < <(package_correlation_aliases "$pkg")

    return 1
}

advisory_severity_to_package_severity() {
    case "$1" in
        CRITICAL)
            printf 'CRITICAL\n'
            ;;
        HIGH)
            printf 'HIGH\n'
            ;;
        MEDIUM)
            printf 'MEDIUM\n'
            ;;
        *)
            printf 'LOW\n'
            ;;
    esac
}

record_escalated_package() {
    local pkg="$1"
    local advisory_title="$2"
    local target_severity="$3"
    local manual_intervention="$4"

    ESCALATED_PACKAGES_JSON=$(jq -c \
        --arg pkg "$pkg" \
        --arg advisory_title "$advisory_title" \
        --arg target_severity "$target_severity" \
        --argjson manual_intervention "$(json_bool "$manual_intervention")" \
        '
        . += [{
            name: $pkg,
            target_severity: $target_severity,
            advisory_title: $advisory_title,
            manual_intervention: $manual_intervention
        }]
        | unique_by(.name + "|" + .advisory_title)
        ' <<< "$ESCALATED_PACKAGES_JSON")
}

correlate_advisories() {
    local advisory_b64
    local title
    local source
    local severity
    local manual_intervention
    local summary
    local url
    local published_at
    local category
    local corpus
    local matched_packages=()
    local pkg
    local matched_packages_json
    local relevant
    local package_target_severity
    local relevant_object

    RELEVANT_ADVISORIES_JSON='[]'
    ESCALATED_PACKAGES_JSON='[]'
    MANUAL_INTERVENTION_REQUIRED="false"

    while IFS= read -r advisory_b64; do
        [[ -n "$advisory_b64" ]] || continue
        title=$(printf '%s' "$advisory_b64" | base64 -d | jq -r '.title')
        source=$(printf '%s' "$advisory_b64" | base64 -d | jq -r '.source')
        severity=$(printf '%s' "$advisory_b64" | base64 -d | jq -r '.severity')
        manual_intervention=$(printf '%s' "$advisory_b64" | base64 -d | jq -r '.manual_intervention')
        summary=$(printf '%s' "$advisory_b64" | base64 -d | jq -r '.summary')
        url=$(printf '%s' "$advisory_b64" | base64 -d | jq -r '.url')
        published_at=$(printf '%s' "$advisory_b64" | base64 -d | jq -r '.published_at')
        category=$(printf '%s' "$advisory_b64" | base64 -d | jq -r '.category')
        corpus=$(lowercase "$title $summary $(printf '%s' "$advisory_b64" | base64 -d | jq -r '.keywords[]?, .related_packages[]?')")
        matched_packages=()

        for pkg in "${RISK_PACKAGES[@]}"; do
            if advisory_matches_package "$pkg" "$corpus"; then
                matched_packages+=("$pkg")
            fi
        done

        if [[ "${#matched_packages[@]}" -eq 0 ]]; then
            continue
        fi

        matched_packages_json=$(advisory_json_array_from_lines "${matched_packages[@]}")
        relevant_object=$(jq -cn \
            --arg source "$source" \
            --arg title "$title" \
            --arg url "$url" \
            --arg published_at "$published_at" \
            --arg summary "$summary" \
            --arg category "$category" \
            --arg severity "$severity" \
            --argjson manual_intervention "$(json_bool "$manual_intervention")" \
            --argjson matched_packages "$matched_packages_json" \
            --argjson related_packages "$(printf '%s' "$advisory_b64" | base64 -d | jq -c '.related_packages')" \
            --argjson keywords "$(printf '%s' "$advisory_b64" | base64 -d | jq -c '.keywords')" \
            '{
                source: $source,
                title: $title,
                url: $url,
                published_at: $published_at,
                summary: $summary,
                category: $category,
                severity: $severity,
                manual_intervention: $manual_intervention,
                related_packages: $related_packages,
                keywords: $keywords,
                matched_packages: $matched_packages
            }')

        RELEVANT_ADVISORIES_JSON=$(jq -c --argjson advisory "$relevant_object" '. + [$advisory]' <<< "$RELEVANT_ADVISORIES_JSON")
        RELEVANT_ADVISORY_TITLES+=("$title")

        for pkg in "${matched_packages[@]}"; do
            package_target_severity=$(advisory_severity_to_package_severity "$severity")
            if bool_is_true "$manual_intervention" && (( $(severity_rank "$package_target_severity") < $(severity_rank "HIGH") )); then
                package_target_severity="HIGH"
            fi
            if promote_package_severity "$pkg" "$package_target_severity" "$manual_intervention"; then
                record_escalated_package "$pkg" "$title" "$package_target_severity" "$manual_intervention"
            fi
        done

        if bool_is_true "$manual_intervention"; then
            MANUAL_INTERVENTION_REQUIRED="true"
        fi

        case "$source" in
            archlinux)
                ARCH_NEWS_DETECTED="true"
                ;;
            cachyos)
                CACHYOS_NEWS_DETECTED="true"
                ;;
        esac
    done < <(jq -r '.[] | @base64' <<< "$ADVISORIES_JSON")

    rebuild_risk_indexes
    RELEVANT_ADVISORIES_JSON=$(jq -c 'unique_by(.source + "|" + .title)' <<< "$RELEVANT_ADVISORIES_JSON")
    ESCALATED_PACKAGES_JSON=$(jq -c 'unique_by(.name + "|" + .advisory_title)' <<< "$ESCALATED_PACKAGES_JSON")
    RELEVANT_ADVISORY_COUNT=$(jq -r 'length' <<< "$RELEVANT_ADVISORIES_JSON")
}

build_advisory_summary() {
    local summary_lines=()
    local title
    local source
    local severity
    local manual_intervention
    local matched
    local source_label

    ADVISORY_SUMMARY_LINES=()

    if [[ "$(jq -r 'length' <<< "$RELEVANT_ADVISORIES_JSON")" -eq 0 ]]; then
        log "No relevant ecosystem advisories detected for pending updates"
        return 0
    fi

    log "Relevant ecosystem advisories detected:"

    while IFS= read -r advisory_b64; do
        [[ -n "$advisory_b64" ]] || continue
        title=$(printf '%s' "$advisory_b64" | base64 -d | jq -r '.title')
        source=$(printf '%s' "$advisory_b64" | base64 -d | jq -r '.source')
        severity=$(printf '%s' "$advisory_b64" | base64 -d | jq -r '.severity')
        manual_intervention=$(printf '%s' "$advisory_b64" | base64 -d | jq -r '.manual_intervention')
        matched=$(printf '%s' "$advisory_b64" | base64 -d | jq -r '.matched_packages | join(", ")')

        case "$source" in
            archlinux)
                source_label="Arch Linux"
                ;;
            cachyos)
                source_label="CachyOS"
                ;;
            *)
                source_label="$source"
                ;;
        esac

        if bool_is_true "$manual_intervention"; then
            ADVISORY_SUMMARY_LINES+=("$source_label [$severity] $title -> $matched (manual intervention)")
        else
            ADVISORY_SUMMARY_LINES+=("$source_label [$severity] $title -> $matched")
        fi
    done < <(jq -r '.[] | @base64' <<< "$RELEVANT_ADVISORIES_JSON")

    printf '%s\n' "${ADVISORY_SUMMARY_LINES[@]}" | while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        log "$line"
    done
}

collect_advisories() {
    local arch_advisories='[]'
    local cachyos_advisories='[]'

    reset_advisory_state

    if ! bool_is_true "$ENABLE_ARCH_NEWS" && ! bool_is_true "$ENABLE_CACHYOS_NEWS"; then
        return 0
    fi

    if ! advisory_support_available; then
        return 0
    fi

    if bool_is_true "$ENABLE_ARCH_NEWS"; then
        arch_advisories=$(load_or_refresh_advisories "archlinux" "$ARCH_NEWS_URL" fetch_arch_news parse_arch_advisories)
    fi

    if bool_is_true "$ENABLE_CACHYOS_NEWS"; then
        cachyos_advisories=$(load_or_refresh_advisories "cachyos" "$CACHYOS_NEWS_URL" fetch_cachyos_news parse_cachyos_advisories)
    fi

    ADVISORIES_JSON=$(jq -c -s 'add' <<< "$arch_advisories"$'\n'"$cachyos_advisories")
    ADVISORY_COUNT=$(jq -r 'length' <<< "$ADVISORIES_JSON")
    correlate_advisories
}
