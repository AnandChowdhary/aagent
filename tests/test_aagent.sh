#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
aagent_script="${project_root}/aagent.sh"
install_script="${project_root}/install.sh"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

help_output="$(bash "$aagent_script" --help)"
[[ "$help_output" == *"Run any CLI coding agent with a single command."* ]] || fail "help is missing the description"
[[ "$help_output" == *"Usage:"* ]] || fail "help is missing usage"
[[ "$help_output" == *"--help"* ]] || fail "help is missing the help option"

short_help_output="$(bash "$aagent_script" -h)"
[[ "$short_help_output" == "$help_output" ]] || fail "-h and --help output differ"

default_output="$(bash "$aagent_script")"
[[ "$default_output" == "$help_output" ]] || fail "running without arguments should show help"

unknown_output="$(mktemp)"
if bash "$aagent_script" --unknown >"$unknown_output" 2>&1; then
    fail "unknown arguments should return a non-zero status"
fi
grep -q "unknown argument: --unknown" "$unknown_output" || fail "unknown argument error is missing"
rm -f "$unknown_output"

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
AAGENT_SOURCE="$aagent_script" INSTALL_DIR="$test_dir/bin" bash "$install_script" >/dev/null

installed_help_output="$("$test_dir/bin/aagent" --help)"
[[ "$installed_help_output" == "$help_output" ]] || fail "installed executable help differs"

printf 'All Bash tests passed.\n'
