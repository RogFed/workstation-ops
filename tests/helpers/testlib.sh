#!/usr/bin/env bash

set -euo pipefail

TEST_HELPER_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$TEST_HELPER_DIR/../.." && pwd)

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Expected '$expected' but got '$actual'}"

    [[ "$expected" == "$actual" ]] || fail "$message"
}

assert_contains() {
    local needle="$1"
    local haystack="$2"
    local message="${3:-Expected output to contain '$needle'}"

    [[ "$haystack" == *"$needle"* ]] || fail "$message"
}

assert_file_contains() {
    local file="$1"
    local needle="$2"

    [[ -f "$file" ]] || fail "Expected file to exist: $file"
    grep -F -- "$needle" "$file" > /dev/null || fail "Expected $file to contain: $needle"
}

require_jq() {
    command -v jq > /dev/null 2>&1 || fail "jq is required for JSON-based test assertions"
}

assert_json_expression() {
    local file="$1"
    local expression="$2"
    local message="${3:-Expected $file to satisfy jq expression: $expression}"

    [[ -f "$file" ]] || fail "Expected file to exist: $file"
    require_jq
    jq -e "$expression" "$file" > /dev/null || fail "$message"
}

assert_json_value() {
    local file="$1"
    local expression="$2"
    local expected="$3"
    local actual

    [[ -f "$file" ]] || fail "Expected file to exist: $file"
    require_jq
    actual=$(jq -r "$expression" "$file") || fail "Expected jq expression to succeed: $expression"
    [[ "$actual" == "$expected" ]] || fail "Expected $file expression $expression to equal '$expected' but got '$actual'"
}

make_test_dir() {
    mktemp -d
}

make_mock_bin() {
    local dir="$1"
    mkdir -p "$dir/bin"
    printf '%s/bin\n' "$dir"
}
