#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
aagent_script="$project_root/aagent.sh"
fake_provider="$project_root/tests/helpers/fake-provider.sh"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_equals() {
    [[ "$1" == "$2" ]] || fail "$3 (expected '$2', got '$1')"
}

assert_contains() {
    [[ "$1" == *"$2"* ]] || fail "$3 (missing '$2')"
}

assert_not_contains() {
    [[ "$1" != *"$2"* ]] || fail "$3 (unexpected '$2')"
}

test_dir="$(mktemp -d)"
original_path="$PATH"
trap 'export PATH="$original_path"; rm -rf "$test_dir"' EXIT

home_dir="$test_dir/home"
fake_bin="$test_dir/bin with spaces"
record_dir="$test_dir/records"
missing_dir="$test_dir/missing"
mkdir -p "$home_dir/.config/aagent" "$fake_bin" "$record_dir"
cp "$fake_provider" "$fake_bin/codex"
chmod +x "$fake_bin/codex"

export HOME="$home_dir"
export XDG_CONFIG_HOME="$home_dir/.config"
export PATH="$fake_bin:/usr/bin:/bin"
export AAGENT_FAKE_RECORD_DIR="$record_dir"
export AAGENT_FAKE_CODEX_APP_SERVER_STDOUT='{"id":1,"result":{"account":{"type":"chatgpt","planType":"pro"},"requiresOpenaiAuth":true}}'
export AAGENT_FAKE_CODEX_APP_SERVER_STATUS=0
export AAGENT_FAKE_VERSION_STDOUT='codex-cli 1.2.3'
export AAGENT_FAKE_VERSION_STATUS=0

provider_ids=(codex claude opencode copilot gemini cline goose aider qwen amp kimi droid crush vibe kiro cursor)
provider_overrides=(
    AAGENT_CODEX_BIN AAGENT_CLAUDE_BIN AAGENT_OPENCODE_BIN AAGENT_COPILOT_BIN
    AAGENT_GEMINI_BIN AAGENT_CLINE_BIN AAGENT_GOOSE_BIN AAGENT_AIDER_BIN
    AAGENT_QWEN_BIN AAGENT_AMP_BIN AAGENT_KIMI_BIN AAGENT_DROID_BIN
    AAGENT_CRUSH_BIN AAGENT_VIBE_BIN AAGENT_KIRO_BIN AAGENT_CURSOR_BIN
)

clear_case() {
    local name
    rm -rf "$record_dir"
    mkdir -p "$record_dir"
    for name in "${provider_overrides[@]}"; do
        export "$name=$missing_dir/$name"
    done
    unset AAGENT_PROVIDER AAGENT_AUTH_POLICY AAGENT_PRIORITY AAGENT_ALLOW_LOCAL
    unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL CODEX_API_KEY OPENAI_API_KEY AMP_API_KEY
    unset AAGENT_FAKE_VERSION_DELAY AAGENT_FAKE_VERSION_BYTES
    export AAGENT_FAKE_VERSION_STDOUT='codex-cli 1.2.3'
    export AAGENT_FAKE_VERSION_STATUS=0
}

run_wrapper() {
    local prefix="$1"
    shift
    set +e
    bash "$aagent_script" "$@" </dev/null >"$prefix.stdout" 2>"$prefix.stderr"
    AAGENT_TEST_STATUS=$?
    set -e
}

clear_case
run_wrapper "$test_dir/all-missing" providers
assert_equals "$AAGENT_TEST_STATUS" 0 "providers should succeed when all providers are missing"
actual_ids="$(awk 'NR > 1 { if (NR > 2) printf " "; printf "%s", $1 } END { printf "\n" }' \
    "$test_dir/all-missing.stdout")"
assert_equals "$actual_ids" "${provider_ids[*]}" "providers order differs from the registry"
assert_equals "$(wc -l < "$test_dir/all-missing.stdout" | tr -d ' ')" 17 "providers row count differs"
[[ ! -e "$record_dir/run.count" ]] || fail "providers launched a model"

clear_case
export AAGENT_CODEX_BIN="$fake_bin/codex"
run_wrapper "$test_dir/providers" providers
assert_equals "$AAGENT_TEST_STATUS" 0 "providers failed"
assert_contains "$(<"$test_dir/providers.stdout")" "codex      ready       included_confirmed    yes" \
    "providers did not expose the selected included account"
assert_equals "$(<"$record_dir/probe.count")" 1 "providers ran an unexpected number of passive probes"
[[ ! -e "$record_dir/run.count" ]] || fail "providers launched a model"

clear_case
export AAGENT_CODEX_BIN="$fake_bin/codex"
run_wrapper "$test_dir/doctor" doctor codex
assert_equals "$AAGENT_TEST_STATUS" 0 "provider-scoped doctor failed"
doctor_output="$(<"$test_dir/doctor.stdout")"
assert_contains "$doctor_output" "wrapper: aagent 0.1.0" "doctor omitted wrapper information"
assert_contains "$doctor_output" "platform:" "doctor omitted platform information"
assert_contains "$doctor_output" "configuration: not found" "doctor omitted configuration status"
assert_contains "$doctor_output" "selected provider: none" "scoped doctor unexpectedly ran global selection"
assert_contains "$doctor_output" "provider: codex" "scoped doctor omitted the requested provider"
assert_not_contains "$doctor_output" "provider: claude" "scoped doctor inspected an unrelated provider"
assert_contains "$doctor_output" "version: codex-cli 1.2.3" "doctor omitted a safe version"
assert_contains "$doctor_output" "authentication: ready" "doctor omitted authentication readiness"
assert_contains "$doctor_output" "command: codex exec PROMPT" "doctor omitted capabilities"
assert_contains "$doctor_output" "safety:" "doctor omitted the safety note"
assert_equals "$(<"$record_dir/probe.count")" 2 "scoped doctor should run one version and one status probe"
[[ ! -e "$record_dir/run.count" ]] || fail "doctor launched a model"

clear_case
run_wrapper "$test_dir/missing-doctor" doctor claude
assert_equals "$AAGENT_TEST_STATUS" 0 "known missing provider should be a doctor result"
assert_contains "$(<"$test_dir/missing-doctor.stdout")" "discovery: missing" \
    "known missing provider diagnosis is absent"
run_wrapper "$test_dir/unknown-doctor" doctor not-a-provider
assert_equals "$AAGENT_TEST_STATUS" 64 "unknown doctor provider should be a usage error"
assert_contains "$(<"$test_dir/unknown-doctor.stderr")" "aagent: unknown provider: not-a-provider" \
    "unknown doctor provider error differs"

clear_case
export AAGENT_CODEX_BIN="$fake_bin/codex"
export AAGENT_FAKE_VERSION_STDOUT='Secret Org 1.2.3'
run_wrapper "$test_dir/redacted-version" doctor codex
assert_equals "$AAGENT_TEST_STATUS" 0 "doctor failed for unsafe version output"
redacted_output="$(<"$test_dir/redacted-version.stdout")"
assert_contains "$redacted_output" "version: unknown" "unsafe version output was not discarded"
assert_contains "$redacted_output" "version status: unsafe_output" "unsafe version reason differs"
assert_not_contains "$redacted_output" "Secret Org" "doctor leaked organization data"

# Exercise the diagnostic supervisor directly so timeout, truncation, and
# provider errors cannot accidentally turn into visible subprocess output.
# shellcheck disable=SC1090
source "$aagent_script"
export AAGENT_FAKE_VERSION_STDOUT=""
export AAGENT_FAKE_VERSION_DELAY=4
aagent_probe_version codex "$fake_bin/codex"
assert_equals "$AAGENT_VERSION_RESULT" unknown "timed-out version should be unknown"
assert_equals "$AAGENT_VERSION_REASON" timeout "version timeout reason differs"
export AAGENT_FAKE_VERSION_DELAY=0
export AAGENT_FAKE_VERSION_BYTES=65537
aagent_probe_version codex "$fake_bin/codex"
assert_equals "$AAGENT_VERSION_REASON" truncated "oversized version reason differs"
unset AAGENT_FAKE_VERSION_BYTES
export AAGENT_FAKE_VERSION_STATUS=23
aagent_probe_version codex "$fake_bin/codex"
assert_equals "$AAGENT_VERSION_REASON" nonzero "nonzero version reason differs"
invalid_version_provider="$fake_bin/invalid-version"
# shellcheck disable=SC2016 # The generated fixture owns its argument expansion.
printf '%s\n' '#!/usr/bin/env bash' 'printf '\''\\377'\''' >"$invalid_version_provider"
chmod +x "$invalid_version_provider"
aagent_probe_version codex "$invalid_version_provider"
assert_equals "$AAGENT_VERSION_RESULT" unknown "invalid UTF-8 version should be unknown"
assert_equals "$AAGENT_VERSION_REASON" unsafe_output "invalid UTF-8 version reason differs"

clear_case
export AAGENT_CODEX_BIN="$fake_bin/codex"
run_wrapper "$test_dir/dry-run" --dry-run 'say hello'
assert_equals "$AAGENT_TEST_STATUS" 0 "dry-run failed"
assert_contains "$(<"$test_dir/dry-run.stdout")" "provider: codex" "dry-run did not resolve selection"
assert_contains "$(<"$test_dir/dry-run.stdout")" "stdin: argv" "dry-run did not resolve input mode"
[[ ! -e "$record_dir/run.count" ]] || fail "dry-run launched a model"

clear_case
run_wrapper "$test_dir/help" --help
run_wrapper "$test_dir/version" --version
[[ ! -e "$record_dir/probe.count" ]] || fail "help or version ran a provider probe"
[[ ! -e "$record_dir/run.count" ]] || fail "help or version launched a model"

printf 'Introspection Bash tests passed.\n'
