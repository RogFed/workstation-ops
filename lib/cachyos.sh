#!/usr/bin/env bash

fetch_cachyos_news() {
    fetch_advisory_source "$1"
}

parse_cachyos_advisories() {
    local html_content="$1"
    local normalized
    local items=()
    local entry
    local published_at
    local category
    local title
    local url
    local summary
    local count=0

    normalized=$(printf '%s' "$html_content" | tr '\n' ' ' | sed 's#</li><li class="mb-12 md:mb-20">#</li>\n<li class="mb-12 md:mb-20">#g')

    while IFS= read -r entry; do
        [[ "$entry" == *'href="/blog/'* ]] || continue

        published_at=$(printf '%s' "$entry" | sed -n 's#.*<time datetime="\([^"]*\)".*#\1#p')
        category=$(printf '%s' "$entry" | sed -n 's#.*href="/category/\([^"]*\)".*#\1#p')
        title=$(printf '%s' "$entry" | sed -n 's#.*href="/blog/[^"]*">[[:space:]]*\([^<][^<]*\)[[:space:]]*</a>.*#\1#p')
        url=$(printf '%s' "$entry" | sed -n 's#.*href="\(/blog/[^"]*\)".*#https://cachyos.org\1#p')
        summary=$(printf '%s' "$entry" | sed -n 's#.*<p class="grow text-muted dark:text-gray-400 text-lg">\([^<]*\)</p>.*#\1#p')

        [[ -n "$title" && -n "$url" ]] || continue

        items+=("$(build_normalized_advisory_json "cachyos" "$title" "$url" "$published_at" "$summary" "$category")")
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
