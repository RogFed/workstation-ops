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

make_test_dir() {
    mktemp -d
}

make_mock_bin() {
    local dir="$1"
    mkdir -p "$dir/bin"
    printf '%s/bin\n' "$dir"
}
