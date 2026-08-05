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
mkdir -p "$home_dir/.config/aagent" "$home_dir/.factory" "$fake_bin" "$record_dir"
cp "$fake_provider" "$fake_bin/codex"
cp "$fake_provider" "$fake_bin/copilot"
cp "$fake_provider" "$fake_bin/agent"
cp "$fake_provider" "$fake_bin/goose"
cp "$fake_provider" "$fake_bin/droid"
chmod +x "$fake_bin/codex" "$fake_bin/copilot" "$fake_bin/agent" "$fake_bin/goose" "$fake_bin/droid"

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
    unset COPILOT_PROVIDER_BASE_URL COPILOT_PROVIDER_TYPE COPILOT_PROVIDER_API_KEY
    unset COPILOT_PROVIDER_BEARER_TOKEN COPILOT_PROVIDER_HEADERS COPILOT_MODEL
    unset COPILOT_PROVIDER_MODEL_ID COPILOT_PROVIDER_WIRE_MODEL COPILOT_GITHUB_TOKEN GH_TOKEN GITHUB_TOKEN
    unset CURSOR_API_KEY AAGENT_FAKE_CURSOR_STATUS_STDOUT AAGENT_FAKE_CURSOR_STATUS_STATUS
    unset GOOSE_PROVIDER GOOSE_PROVIDER__API_KEY OLLAMA_HOST CODEX_COMMAND CLAUDE_CODE_COMMAND CURSOR_AGENT_COMMAND
    unset FACTORY_API_KEY
    rm -f "$home_dir/.factory/settings.json" "$home_dir/.factory/settings.local.json"
    unset AAGENT_FAKE_INVOCATION_KIND AAGENT_FAKE_PROBE_STDOUT AAGENT_FAKE_PROBE_STDERR
    unset AAGENT_FAKE_PROBE_STATUS AAGENT_FAKE_PROBE_DELAY AAGENT_FAKE_PROBE_BYTES
    unset AAGENT_FAKE_VERSION_DELAY AAGENT_FAKE_VERSION_BYTES
    export AAGENT_FAKE_VERSION_STDOUT='codex-cli 1.2.3'
    export AAGENT_FAKE_VERSION_STATUS=0
    export AAGENT_FAKE_HELP_STDOUT='Usage: agent Start the Cursor Agent --print status'
    export AAGENT_FAKE_HELP_STATUS=0
    export AAGENT_FAKE_CURSOR_STATUS_STATUS=0
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
assert_contains "$doctor_output" "wrapper: aagent 0.1.1" "doctor omitted wrapper information"
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
export AAGENT_COPILOT_BIN="$fake_bin/copilot"
export COPILOT_GITHUB_TOKEN='seeded-secret-token'
export AAGENT_FAKE_VERSION_STDOUT='GitHub Copilot CLI 1.0.78'
run_wrapper "$test_dir/copilot-doctor" doctor copilot
assert_equals "$AAGENT_TEST_STATUS" 0 "Copilot doctor failed"
copilot_doctor_output="$(<"$test_dir/copilot-doctor.stdout")"
assert_contains "$copilot_doctor_output" "provider: copilot" "Copilot doctor omitted provider"
assert_contains "$copilot_doctor_output" "tier: tier2" "Copilot doctor omitted tier"
assert_contains "$copilot_doctor_output" "version: GitHub Copilot CLI 1.0.78" "Copilot doctor rejected the safe version"
assert_contains "$copilot_doctor_output" "authentication: ready" "Copilot doctor omitted authentication readiness"
assert_contains "$copilot_doctor_output" "funding: included_account" "Copilot doctor omitted funding"
assert_contains "$copilot_doctor_output" "command: copilot --prompt PROMPT --silent --no-ask-user" "Copilot doctor omitted command"
assert_contains "$copilot_doctor_output" "no allow-all or yolo" "Copilot doctor omitted safety caveat"
assert_equals "$(<"$record_dir/probe.count")" 1 "Copilot doctor ran more than its version probe"
[[ ! -e "$record_dir/run.count" ]] || fail "Copilot doctor launched a model"

clear_case
export AAGENT_CURSOR_BIN="$fake_bin/agent"
export AAGENT_FAKE_VERSION_STDOUT='2026.07.23-e383d2b'
export AAGENT_FAKE_CURSOR_STATUS_STDOUT='{"isAuthenticated":true,"hasAccessToken":true,"hasRefreshToken":true,"userInfo":{"email":"person@example.com","team":"Secret Org"},"message":"seeded-secret-token"}'
run_wrapper "$test_dir/cursor-providers" providers
assert_equals "$AAGENT_TEST_STATUS" 0 "Cursor providers inspection failed"
cursor_providers_output="$(<"$test_dir/cursor-providers.stdout")"
assert_contains "$cursor_providers_output" "cursor" "Cursor providers output omitted provider"
assert_contains "$cursor_providers_output" "included_account" "Cursor providers output omitted funding"
assert_not_contains "$cursor_providers_output" "person@example.com" "Cursor providers output leaked email"
assert_not_contains "$cursor_providers_output" "Secret Org" "Cursor providers output leaked team"
assert_not_contains "$cursor_providers_output" "seeded-secret-token" "Cursor providers output leaked status message"
assert_equals "$(<"$record_dir/probe.count")" 3 "Cursor providers probe count differs"

clear_case
export AAGENT_CURSOR_BIN="$fake_bin/agent"
export AAGENT_FAKE_VERSION_STDOUT='2026.07.23-e383d2b'
export AAGENT_FAKE_CURSOR_STATUS_STDOUT='{"isAuthenticated":true,"hasAccessToken":true,"hasRefreshToken":true}'
run_wrapper "$test_dir/cursor-doctor" doctor cursor
assert_equals "$AAGENT_TEST_STATUS" 0 "Cursor doctor failed"
cursor_doctor_output="$(<"$test_dir/cursor-doctor.stdout")"
assert_contains "$cursor_doctor_output" "provider: cursor" "Cursor doctor omitted provider"
assert_contains "$cursor_doctor_output" "tier: tier2" "Cursor doctor omitted tier"
assert_contains "$cursor_doctor_output" "version: 2026.07.23-e383d2b" "Cursor doctor omitted safe version"
assert_contains "$cursor_doctor_output" "authentication: ready" "Cursor doctor omitted readiness"
assert_contains "$cursor_doctor_output" "funding: included_account" "Cursor doctor omitted funding"
assert_contains "$cursor_doctor_output" "command: agent --print --output-format text PROMPT" "Cursor doctor omitted command"
assert_contains "$cursor_doctor_output" "explicitly forces" "Cursor doctor omitted safety caveat"
assert_equals "$(<"$record_dir/probe.count")" 4 "Cursor doctor probe count differs"
[[ ! -e "$record_dir/run.count" ]] || fail "Cursor doctor launched a model"

clear_case
export AAGENT_GOOSE_BIN="$fake_bin/goose"
export GOOSE_PROVIDER='chatgpt_codex'
export AAGENT_FAKE_VERSION_STDOUT='1.45.0'
run_wrapper "$test_dir/goose-doctor" doctor goose
assert_equals "$AAGENT_TEST_STATUS" 0 "Goose doctor failed"
goose_doctor_output="$(<"$test_dir/goose-doctor.stdout")"
assert_contains "$goose_doctor_output" "provider: goose" "Goose doctor omitted provider"
assert_contains "$goose_doctor_output" "tier: tier2" "Goose doctor omitted tier"
assert_contains "$goose_doctor_output" "version: 1.45.0" "Goose doctor omitted safe version"
assert_contains "$goose_doctor_output" "authentication: ready" "Goose doctor omitted readiness"
assert_contains "$goose_doctor_output" "funding: included_account" "Goose doctor omitted inherited funding"
assert_contains "$goose_doctor_output" "command: goose run --text PROMPT" "Goose doctor omitted command"
assert_contains "$goose_doctor_output" "never enables auto approval" "Goose doctor omitted safety caveat"
assert_equals "$(<"$record_dir/probe.count")" 1 "Goose doctor ran more than its version probe"
grep -R -F 'arg.0.hex=2d2d76657273696f6e' "$record_dir"/goose.probe.*.record >/dev/null || \
    fail "Goose doctor ran an unexpected active probe"
[[ ! -e "$record_dir/run.count" ]] || fail "Goose doctor launched a model"

clear_case
export AAGENT_DROID_BIN="$fake_bin/droid"
export FACTORY_API_KEY='seeded-secret-token'
export AAGENT_FAKE_VERSION_STDOUT='0.188.0'
printf '%s' '{"model":"custom:remote-0","customModels":[{"baseUrl":"https://models.example.test/v1","apiKey":"seeded-secret-token","email":"person@example.com","organization":"Secret Org"}]}' >"$home_dir/.factory/settings.json"
run_wrapper "$test_dir/droid-doctor" doctor droid
assert_equals "$AAGENT_TEST_STATUS" 0 "Droid doctor failed"
droid_doctor_output="$(<"$test_dir/droid-doctor.stdout")"
assert_contains "$droid_doctor_output" "provider: droid" "Droid doctor omitted provider"
assert_contains "$droid_doctor_output" "tier: tier2" "Droid doctor omitted tier"
assert_contains "$droid_doctor_output" "version: 0.188.0" "Droid doctor omitted safe version"
assert_contains "$droid_doctor_output" "authentication: ready" "Droid doctor omitted readiness"
assert_contains "$droid_doctor_output" "funding: payg_byok" "Droid doctor omitted BYOK funding"
assert_contains "$droid_doctor_output" "command: droid exec PROMPT" "Droid doctor omitted command"
assert_contains "$droid_doctor_output" "Read-only autonomy by default" "Droid doctor omitted safety caveat"
assert_not_contains "$droid_doctor_output" "seeded-secret-token" "Droid doctor leaked API key"
assert_not_contains "$droid_doctor_output" "person@example.com" "Droid doctor leaked email"
assert_not_contains "$droid_doctor_output" "Secret Org" "Droid doctor leaked organization"
assert_equals "$(<"$record_dir/probe.count")" 1 "Droid doctor ran more than its version probe"
[[ ! -e "$record_dir/run.count" ]] || fail "Droid doctor launched a model"

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
oversized_version_provider="$fake_bin/oversized-version"
printf '%s\n' '#!/usr/bin/env bash' 'head -c 65537 /dev/zero' >"$oversized_version_provider"
chmod +x "$oversized_version_provider"
aagent_probe_version codex "$oversized_version_provider"
assert_equals "$AAGENT_VERSION_REASON" truncated "oversized version reason differs"
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
