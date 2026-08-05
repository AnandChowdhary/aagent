#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
aagent_script="$project_root/aagent.sh"
fake_provider="$project_root/tests/helpers/fake-provider.sh"

# shellcheck disable=SC1090
source "$aagent_script"

fail() {
    printf 'FAIL: discovery: %s\n' "$1" >&2
    exit 1
}

assert_equals() {
    local actual="$1"
    local expected="$2"
    local message="$3"
    [[ "$actual" == "$expected" ]] || fail "$message (expected '$expected', got '$actual')"
}

assert_contains() {
    local actual="$1"
    local expected="$2"
    local message="$3"
    [[ "$actual" == *"$expected"* ]] || fail "$message"
}

adapter_index() {
    aagent_get_adapter_index "$1" || fail "adapter is absent from registry: $1"
}

status_for() {
    local index
    index="$(adapter_index "$1")"
    printf '%s\n' "${AAGENT_DISCOVERY_STATUSES[$index]}"
}

path_for() {
    local index
    index="$(adapter_index "$1")"
    printf '%s\n' "${AAGENT_DISCOVERY_PATHS[$index]}"
}

reason_for() {
    local index
    index="$(adapter_index "$1")"
    printf '%s\n' "${AAGENT_DISCOVERY_REASONS[$index]}"
}

test_dir="$(mktemp -d)"
original_path="$PATH"

cleanup() {
    export PATH="$original_path"
    rm -rf "$test_dir"
}
trap cleanup EXIT

fake_bin="$test_dir/bin"
record_dir="$test_dir/records"
override_dir="$test_dir/override paths 🌍"
mkdir -p "$fake_bin" "$record_dir" "$override_dir"

for provider in codex claude copilot agent; do
    cp "$fake_provider" "$fake_bin/$provider"
    chmod +x "$fake_bin/$provider"
done

symlink_supported=0
if ln -s "$fake_bin/codex" "$fake_bin/opencode" 2>/dev/null; then
    symlink_supported=1
fi

override_executable="$override_dir/gemini executable 🌍"
leading_executable="$override_dir/-leading-agent"
non_executable="$override_dir/not-executable"
invalid_directory="$override_dir/not-an-executable-directory"
broken_link="$override_dir/broken-opencode"
cp "$fake_provider" "$override_executable"
cp "$fake_provider" "$leading_executable"
cp "$fake_provider" "$non_executable"
chmod +x "$override_executable" "$leading_executable"
chmod -x "$non_executable" 2>/dev/null || true
mkdir -p "$invalid_directory"
broken_supported=0
if ln -s "$override_dir/missing-target" "$broken_link" 2>/dev/null; then
    broken_supported=1
fi

unset AAGENT_CODEX_BIN AAGENT_CLAUDE_BIN AAGENT_OPENCODE_BIN AAGENT_COPILOT_BIN
unset AAGENT_GEMINI_BIN AAGENT_CLINE_BIN AAGENT_GOOSE_BIN AAGENT_AIDER_BIN
unset AAGENT_QWEN_BIN AAGENT_AMP_BIN AAGENT_KIMI_BIN AAGENT_DROID_BIN
unset AAGENT_CRUSH_BIN AAGENT_VIBE_BIN AAGENT_KIRO_BIN AAGENT_CURSOR_BIN

aagent_initialize_registry
assert_equals "${#AAGENT_ADAPTER_IDS[@]}" "16" "registry size differs"
expected_order="codex,claude,opencode,copilot,gemini,cline,goose,aider,qwen,amp,kimi,droid,crush,vibe,kiro,cursor"
actual_order=""
for id in "${AAGENT_ADAPTER_IDS[@]}"; do
    actual_order+="${actual_order:+,}$id"
done
assert_equals "$actual_order" "$expected_order" "registry order differs"
assert_equals "$AAGENT_POPULARITY_SNAPSHOT" "2026-08-04" "popularity snapshot differs"

codex_index="$(adapter_index codex)"
copilot_index="$(adapter_index copilot)"
amp_index="$(adapter_index amp)"
cursor_index="$(adapter_index cursor)"
assert_equals "${AAGENT_ADAPTER_TIERS[$codex_index]}" "tier1" "Codex tier differs"
assert_equals "${AAGENT_ADAPTER_COMMANDS[$codex_index]}" "codex exec PROMPT" "Codex command differs"
assert_equals "${AAGENT_ADAPTER_TIERS[$copilot_index]}" "tier2" "Copilot tier differs"
assert_equals "${AAGENT_ADAPTER_COMMANDS[$copilot_index]}" "copilot --prompt PROMPT --silent --no-ask-user" "Copilot command differs"
assert_equals "${AAGENT_ADAPTER_MODELS[$copilot_index]}" "--model" "Copilot model capability differs"
assert_equals "${AAGENT_ADAPTER_STRUCTURED[$copilot_index]}" "jsonl" "Copilot structured-output capability differs"
assert_contains "${AAGENT_ADAPTER_SAFETY[$copilot_index]}" "no allow-all or yolo" "Copilot safety metadata differs"
assert_equals "${AAGENT_ADAPTER_PROBES[$copilot_index]}" "environment precedence only" "Copilot probe metadata differs"
assert_equals "${AAGENT_ADAPTER_MODELS[$amp_index]}" "none" "Amp model capability differs"
assert_equals "${AAGENT_ADAPTER_EXECUTABLES[$cursor_index]}" "agent" "Cursor executable differs"
assert_equals "${AAGENT_ADAPTER_TIERS[$cursor_index]}" "planned" "Cursor tier differs"

gemini() {
    printf 'this function must not be discovered\n'
}

export AAGENT_FAKE_RECORD_DIR="$record_dir"
export PATH="$fake_bin"
aagent_discover_adapters
export PATH="$original_path"

assert_equals "$(status_for codex)" "installed" "Codex PATH status differs"
assert_equals "$(status_for claude)" "installed" "Claude PATH status differs"
if (( symlink_supported )); then
    assert_equals "$(status_for opencode)" "installed" "OpenCode symlink status differs"
else
    assert_equals "$(status_for opencode)" "missing" "OpenCode missing status differs"
fi
assert_equals "$(status_for gemini)" "missing" "a shell function was accepted as Gemini"
assert_equals "$(status_for amp)" "missing" "Amp missing status differs"
assert_equals "$(status_for copilot)" "installed" "installed Copilot status differs"
assert_equals "$(status_for cursor)" "unsupported" "installed planned Cursor status differs"
assert_equals "$(path_for cursor)" "$fake_bin/agent" "Cursor path collides with aagent"
assert_equals "$(reason_for cursor)" "adapter planned; executable found" "Cursor planned reason differs"

export AAGENT_CODEX_BIN="$leading_executable"
export AAGENT_CLAUDE_BIN="$aagent_script"
export AAGENT_GEMINI_BIN="$override_executable"
export AAGENT_AMP_BIN="$invalid_directory"
if (( broken_supported )); then
    export AAGENT_OPENCODE_BIN="$broken_link"
fi

export PATH="$fake_bin"
aagent_discover_adapters
export PATH="$original_path"

assert_equals "$(status_for codex)" "installed" "leading-dash override was rejected"
assert_equals "$(path_for codex)" "$leading_executable" "leading-dash override path differs"
assert_equals "$(status_for claude)" "missing" "wrapper recursion was accepted"
assert_equals "$(reason_for claude)" "resolved target is the aagent wrapper" "wrapper recursion reason differs"
assert_equals "$(status_for gemini)" "installed" "Unicode/spaced override was rejected"
assert_equals "$(path_for gemini)" "$override_executable" "Unicode/spaced override path differs"
assert_equals "$(status_for amp)" "missing" "directory override was accepted"
assert_equals "$(reason_for amp)" "invalid executable override: AAGENT_AMP_BIN" "invalid override reason differs"
if [[ ! -x "$non_executable" ]]; then
    export AAGENT_AMP_BIN="$non_executable"
    export PATH="$fake_bin"
    aagent_discover_adapters
    export PATH="$original_path"
    assert_equals "$(status_for amp)" "missing" "non-executable override was accepted"
fi
if (( broken_supported )); then
    assert_equals "$(status_for opencode)" "missing" "broken override symlink was accepted"
fi

[[ ! -e "$record_dir/run.count" ]] || fail "discovery executed a provider run"
[[ ! -e "$record_dir/probe.count" ]] || fail "discovery executed an authentication probe"
if grep -Eq 'curl|wget' "$aagent_script"; then
    fail "runtime runner contains a network popularity lookup"
fi

printf 'Discovery Bash tests passed.\n'
