#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
agent_script="${project_root}/agent.sh"
install_script="${project_root}/install.sh"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

help_output="$(bash "$agent_script" --help)"
[[ "$help_output" == *"Run any CLI coding agent with a single command."* ]] || fail "help is missing the description"
[[ "$help_output" == *"Usage:"* ]] || fail "help is missing usage"
[[ "$help_output" == *"--help"* ]] || fail "help is missing the help option"

short_help_output="$(bash "$agent_script" -h)"
[[ "$short_help_output" == "$help_output" ]] || fail "-h and --help output differ"

default_output="$(bash "$agent_script")"
[[ "$default_output" == "$help_output" ]] || fail "running without arguments should show help"

unknown_output="$(mktemp)"
if bash "$agent_script" --unknown >"$unknown_output" 2>&1; then
    fail "unknown arguments should return a non-zero status"
fi
grep -q "unknown argument: --unknown" "$unknown_output" || fail "unknown argument error is missing"
rm -f "$unknown_output"

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
AGENT_SOURCE="$agent_script" INSTALL_DIR="$test_dir/bin" bash "$install_script" >/dev/null

installed_help_output="$("$test_dir/bin/agent" --help)"
[[ "$installed_help_output" == "$help_output" ]] || fail "installed executable help differs"

printf 'All Bash tests passed.\n'
