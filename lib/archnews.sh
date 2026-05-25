#!/usr/bin/env bash

fetch_arch_news() {
    fetch_advisory_source "$1"
}

xml_tag_value() {
    local line="$1"
    local tag="$2"
    line="${line#*<$tag>}"
    line="${line%%</$tag>*}"
    printf '%s' "$line"
}

parse_arch_advisories() {
    local feed_content="$1"
    local items=()
    local item
    local normalized
    local title
    local url
    local summary
    local published_at
    local count=0

    normalized=$(printf '%s' "$feed_content" | tr '\n' ' ' | sed 's#</item>#</item>\n#g')

    while IFS= read -r item; do
        [[ "$item" == *"<item>"* ]] || continue
        title=$(xml_tag_value "$item" "title")
        url=$(xml_tag_value "$item" "link")
        summary=$(xml_tag_value "$item" "description")
        published_at=$(xml_tag_value "$item" "pubDate")
        items+=("$(build_normalized_advisory_json "archlinux" "$title" "$url" "$published_at" "$summary" "news")")
        count=$((count + 1))
        if (( count >= ADVISORY_MAX_ITEMS )); then
            break
        fi
    done <<< "$normalized"

    if [[ "${#items[@]}" -eq 0 ]]; then
        printf '[]\n'
        return 0
    fi

    printf '%s\n' "${items[@]}" | jq -sc '.'
}
