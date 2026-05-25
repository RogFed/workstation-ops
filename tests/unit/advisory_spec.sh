#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)/helpers/testlib.sh"
source "$REPO_ROOT/lib/utils.sh"
source "$REPO_ROOT/lib/risk.sh"

log() {
    :
}

warn() {
    :
}

source "$REPO_ROOT/lib/advisory.sh"
source "$REPO_ROOT/lib/archnews.sh"
source "$REPO_ROOT/lib/cachyos.sh"

ADVISORY_MAX_ITEMS=12
CACHE_DIR="$(make_test_dir)"
trap 'rm -rf "$CACHE_DIR"' EXIT

assert_eq "A & B" "$(html_entity_decode 'A &amp; B')" "HTML entity decoding should decode ampersands"

ARCH_FEED=$(cat <<'EOF'
<rss><channel>
<item>
  <title>Firefox will fail on launch</title>
  <link>https://archlinux.org/news/firefox-will-fail/</link>
  <description>Firefox users should review this advisory before updating.</description>
  <pubDate>Sat, 24 May 2026 12:00:00 +0000</pubDate>
</item>
</channel></rss>
EOF
)

CACHYOS_HTML=$(cat <<'EOF'
<ul>
  <li class="mb-12 md:mb-20">
    <a href="/category/release">release</a>
    <time datetime="2026-05-20T10:00:00+00:00"></time>
    <a href="/blog/may-2026-release">CachyOS May 2026 Release</a>
    <p class="grow text-muted dark:text-gray-400 text-lg">PipeWire improvements for CachyOS desktops.</p>
  </li>
</ul>
EOF
)

PARSED_ARCH_FILE="$CACHE_DIR/arch.json"
parse_arch_advisories "$ARCH_FEED" > "$PARSED_ARCH_FILE"
assert_json_expression "$PARSED_ARCH_FILE" 'length == 1'
assert_json_expression "$PARSED_ARCH_FILE" '.[0].title == "Firefox will fail on launch" and .[0].severity == "CRITICAL" and (.[0].related_packages | index("firefox")) != null'

PARSED_CACHYOS_FILE="$CACHE_DIR/cachyos.json"
parse_cachyos_advisories "$CACHYOS_HTML" > "$PARSED_CACHYOS_FILE"
assert_json_expression "$PARSED_CACHYOS_FILE" 'length == 1'
assert_json_expression "$PARSED_CACHYOS_FILE" '.[0].source == "cachyos" and .[0].category == "release" and (.[0].related_packages | index("pipewire")) != null'

analyze_updates $'firefox 1 -> 2'
ADVISORIES_JSON=$(cat "$PARSED_ARCH_FILE")
correlate_advisories

assert_eq "1" "$RELEVANT_ADVISORY_COUNT" "One advisory should correlate to the pending updates"
assert_eq "CRITICAL" "${PACKAGE_SEVERITY["firefox"]}" "Advisories should be able to escalate low-risk packages"
assert_eq "LOW" "${PACKAGE_BASE_SEVERITY["firefox"]}" "Base package severity should remain unchanged after advisory escalation"
assert_eq "1" "${PACKAGE_ADVISORY_MATCH_COUNT["firefox"]}" "Correlated advisories should increment the package match count"
assert_eq "true" "${PACKAGE_ESCALATED_BY_ADVISORY["firefox"]}" "Advisory escalation should be recorded"
assert_eq "false" "$MANUAL_INTERVENTION_REQUIRED" "This advisory should not require manual intervention"
assert_json_expression "$PARSED_ARCH_FILE" '.[0].keywords | index("firefox") != null'
RELEVANT_ADVISORIES_FILE="$CACHE_DIR/relevant-advisories.json"
ESCALATED_PACKAGES_FILE="$CACHE_DIR/escalated-packages.json"
printf '%s\n' "$RELEVANT_ADVISORIES_JSON" > "$RELEVANT_ADVISORIES_FILE"
printf '%s\n' "$ESCALATED_PACKAGES_JSON" > "$ESCALATED_PACKAGES_FILE"
assert_json_expression "$RELEVANT_ADVISORIES_FILE" '.[0].matched_packages == ["firefox"]'
assert_json_expression "$ESCALATED_PACKAGES_FILE" '.[0].name == "firefox" and .[0].target_severity == "CRITICAL"'
