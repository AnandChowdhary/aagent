#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
aagent_script="$project_root/aagent.sh"
fake_provider="$project_root/tests/helpers/fake-provider.sh"

# shellcheck disable=SC1090
source "$aagent_script"

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

reset_fixture() {
    # shellcheck disable=SC2034 # Read by the sourced selector implementation.
    AAGENT_EFFECTIVE_PRIORITY="${1-}"
    # shellcheck disable=SC2034 # Read by the sourced selector implementation.
    AAGENT_EFFECTIVE_ALLOW_LOCAL="${2-false}"
    aagent_reset_selection
}

add_fixture() {
    local provider="$1" readiness="$2" funding="$3" confidence="$4"
    local popularity="$5" registry="$6" label="${7-Unknown}"
    aagent_add_selection_candidate \
        0 "$provider" "/fixture/$provider" "$readiness" "$funding" "$confidence" \
        "$label" fixture_probe "$popularity" "$registry"
}

assert_fixture_winner() {
    local expected_provider="$1" expected_reason="$2" message="$3"
    aagent_select_candidates || fail "$message (selection unexpectedly failed)"
    assert_equals \
        "${AAGENT_SELECTION_PROVIDER_IDS[$AAGENT_SELECTION_WINNER_INDEX]}" \
        "$expected_provider" \
        "$message"
    assert_equals "$AAGENT_SELECTION_REASON_CODE" "$expected_reason" "$message reason differs"
}

reset_fixture "" false
add_fixture codex unknown included_confirmed 4 1 1
add_fixture claude ready payg_byok 1 2 2
assert_fixture_winner claude readiness "readiness did not dominate later tuple fields"

funding_classes=(included_confirmed included_account prepaid_credits local payg_byok unknown)
for ((class_index = 0; class_index < ${#funding_classes[@]} - 1; class_index++)); do
    reset_fixture "" true
    add_fixture higher ready "${funding_classes[$class_index]}" 4 16 16
    add_fixture lower ready "${funding_classes[$((class_index + 1))]}" 4 1 1
    assert_fixture_winner higher funding_class \
        "funding order differs for ${funding_classes[$class_index]}"
done

reset_fixture "" false
add_fixture local-provider ready local 4 1 1
add_fixture api-provider ready payg_byok 4 2 2
assert_fixture_winner api-provider only_candidate "local candidate was not gated"
assert_equals "${AAGENT_SELECTION_EXCLUSIONS[0]}" local_not_allowed "local exclusion differs"

reset_fixture "" true
add_fixture local-provider ready local 1 16 16
add_fixture api-provider ready payg_byok 4 1 1
assert_fixture_winner local-provider funding_class "allowed local funding rank differs"

reset_fixture "" false
add_fixture codex ready included_confirmed 4 16 16
add_fixture claude ready included_confirmed 3 1 1
assert_fixture_winner codex authentication_confidence "confidence tie-break differs"

reset_fixture "lower,higher" false
add_fixture higher ready included_account 4 16 16
add_fixture lower ready payg_byok 4 1 1
assert_fixture_winner higher funding_class "priority crossed the funding boundary"

reset_fixture "lower,higher" false
add_fixture higher ready included_account 4 16 16
add_fixture lower ready included_account 3 1 1
assert_fixture_winner higher authentication_confidence "priority crossed the confidence boundary"

reset_fixture "claude,codex" false
add_fixture codex ready included_confirmed 4 1 1
add_fixture claude ready included_confirmed 4 16 16
assert_fixture_winner claude configured_priority "configured priority did not break an exact cost tie"
assert_equals "$AAGENT_SELECTION_REASON_DISPLAY" "configured priority #1" "priority display differs"

reset_fixture "claude" false
add_fixture codex ready included_confirmed 4 1 1
add_fixture claude ready included_confirmed 4 16 16
assert_fixture_winner claude configured_priority "listed provider did not outrank an unlisted tie"

reset_fixture "" false
add_fixture codex ready included_account 4 1 16
add_fixture claude ready included_account 4 2 1
assert_fixture_winner codex popularity_prior "frozen popularity prior differs"
assert_equals "$AAGENT_SELECTION_REASON_DISPLAY" "popularity #1" "popularity display differs"

reset_fixture "" false
add_fixture first ready unknown 0 5 1
add_fixture second ready unknown 0 5 2
assert_fixture_winner first stable_registry_order "registry order did not break the final tie"

reset_fixture "" false
add_fixture unusable-provider unusable included_confirmed 4 1 1
add_fixture unknown-provider unknown unknown 0 16 16
assert_fixture_winner unknown-provider only_candidate "unknown last-resort candidate was excluded"
assert_equals "${AAGENT_SELECTION_EXCLUSIONS[0]}" unusable_authentication "unusable exclusion differs"

reset_fixture "" false
add_fixture unusable-provider unusable included_confirmed 4 1 1
add_fixture local-provider ready local 4 2 2
if aagent_select_candidates; then
    fail "empty eligible candidate set unexpectedly selected a provider"
else
    assert_equals "$?" "$AAGENT_EXIT_UNAVAILABLE" "empty candidate status differs"
fi

test_dir="$(mktemp -d)"
original_path="$PATH"
selection_environment_names=(
    HOME XDG_CONFIG_HOME AAGENT_PROVIDER AAGENT_AUTH_POLICY AAGENT_PRIORITY AAGENT_ALLOW_LOCAL
    AAGENT_CLAUDE_BIN AAGENT_CODEX_BIN AAGENT_OPENCODE_BIN AAGENT_COPILOT_BIN
    AAGENT_GEMINI_BIN AAGENT_AMP_BIN
    AAGENT_FAKE_RECORD_DIR AAGENT_FAKE_INVOCATION_KIND AAGENT_FAKE_PROVIDER
    AAGENT_FAKE_ENV_PRESENCE AAGENT_FAKE_ENV_CAPTURE AAGENT_FAKE_PROBE_STDOUT AAGENT_FAKE_PROBE_STDERR
    AAGENT_FAKE_PROBE_STATUS AAGENT_FAKE_PROBE_DELAY AAGENT_FAKE_PROBE_BYTES
    AAGENT_FAKE_CLAUDE_STDOUT AAGENT_FAKE_CLAUDE_STDERR AAGENT_FAKE_CLAUDE_STATUS
    AAGENT_FAKE_CODEX_APP_SERVER_STDOUT AAGENT_FAKE_CODEX_APP_SERVER_STDERR
    AAGENT_FAKE_CODEX_APP_SERVER_STATUS AAGENT_FAKE_CODEX_LOGIN_STDERR
    AAGENT_FAKE_CODEX_LOGIN_STATUS AAGENT_FAKE_OPENCODE_STDOUT AAGENT_FAKE_OPENCODE_STATUS
    AAGENT_FAKE_RUN_STDOUT AAGENT_FAKE_RUN_STDERR AAGENT_FAKE_RUN_STATUS
    ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL
    ANTHROPIC_BEDROCK_BASE_URL ANTHROPIC_BEDROCK_MANTLE_BASE_URL ANTHROPIC_AWS_BASE_URL
    ANTHROPIC_VERTEX_BASE_URL ANTHROPIC_FOUNDRY_BASE_URL ANTHROPIC_FOUNDRY_RESOURCE
    ANTHROPIC_FOUNDRY_API_KEY AWS_BEARER_TOKEN_BEDROCK ANTHROPIC_CUSTOM_HEADERS
    CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_MANTLE CLAUDE_CODE_USE_VERTEX
    CLAUDE_CODE_USE_FOUNDRY CLAUDE_CODE_USE_ANTHROPIC_AWS
    CODEX_API_KEY OPENAI_API_KEY AMP_API_KEY \
    COPILOT_PROVIDER_BASE_URL COPILOT_PROVIDER_TYPE COPILOT_PROVIDER_API_KEY \
    COPILOT_PROVIDER_BEARER_TOKEN COPILOT_PROVIDER_HEADERS COPILOT_MODEL \
    COPILOT_PROVIDER_MODEL_ID COPILOT_PROVIDER_WIRE_MODEL \
    COPILOT_GITHUB_TOKEN GH_TOKEN GITHUB_TOKEN
)

cleanup_selection_test() {
    export PATH="$original_path"
    rm -rf "$test_dir"
}
trap cleanup_selection_test EXIT

home_dir="$test_dir/home"
fake_bin="$test_dir/bin"
record_dir="$test_dir/records"
missing_dir="$test_dir/missing"
mkdir -p "$home_dir/.config/aagent" "$home_dir/.gemini" "$fake_bin" "$record_dir"
for provider in claude codex opencode copilot amp gemini; do
    cp "$fake_provider" "$fake_bin/$provider"
    chmod +x "$fake_bin/$provider"
done

export HOME="$home_dir"
export XDG_CONFIG_HOME="$home_dir/.config"
export PATH="$fake_bin:/usr/bin:/bin"
export AAGENT_FAKE_RECORD_DIR="$record_dir"

clear_selection_case() {
    local name
    rm -rf "$record_dir"
    mkdir -p "$record_dir"
    rm -f "$home_dir/.gemini/settings.json" "$home_dir/.config/aagent/config"
    for name in "${selection_environment_names[@]}"; do
        case "$name" in
            HOME|XDG_CONFIG_HOME|AAGENT_FAKE_RECORD_DIR) ;;
            *) unset "$name" 2>/dev/null || true ;;
        esac
    done
    export PATH="$fake_bin:/usr/bin:/bin"
    export AAGENT_CLAUDE_BIN="$missing_dir/claude"
    export AAGENT_CODEX_BIN="$missing_dir/codex"
    export AAGENT_OPENCODE_BIN="$missing_dir/opencode"
    export AAGENT_COPILOT_BIN="$missing_dir/copilot"
    export AAGENT_GEMINI_BIN="$missing_dir/gemini"
    export AAGENT_AMP_BIN="$missing_dir/amp"
    export AAGENT_FAKE_RUN_STDOUT="provider-output"
    export AAGENT_FAKE_RUN_STATUS=0
}

run_wrapper() {
    local output_prefix="$1"
    shift
    set +e
    bash "$aagent_script" "$@" </dev/null >"$output_prefix.stdout" 2>"$output_prefix.stderr"
    AAGENT_TEST_STATUS=$?
    set -e
}

clear_selection_case
export AAGENT_CLAUDE_BIN="$fake_bin/claude"
export AAGENT_CODEX_BIN="$fake_bin/codex"
export AAGENT_FAKE_CLAUDE_STDOUT='{"loggedIn":true,"authMethod":"claude.ai","subscriptionType":"max","apiProvider":"claude.ai"}'
export AAGENT_FAKE_CODEX_APP_SERVER_STDOUT='{"id":1,"result":{"account":{"type":"apiKey"},"requiresOpenaiAuth":true}}'
run_wrapper "$test_dir/claude-included" "say hello"
assert_equals "$AAGENT_TEST_STATUS" 0 "Claude included scenario failed"
find "$record_dir" -name 'claude.run.*.record' -print -quit | grep -q . || \
    fail "Claude subscription did not beat API-only Codex"
assert_contains "$(<"$test_dir/claude-included.stderr")" \
    "using claude (included_confirmed, Claude Max; higher funding class (included_confirmed))" \
    "Claude selection notice differs"

clear_selection_case
export AAGENT_CLAUDE_BIN="$fake_bin/claude"
export AAGENT_CODEX_BIN="$fake_bin/codex"
export AAGENT_FAKE_CLAUDE_STDOUT='{"loggedIn":true,"authMethod":"api_key","apiProvider":"console","apiKeySource":"environment"}'
export AAGENT_FAKE_CODEX_APP_SERVER_STDOUT='{"id":1,"result":{"account":{"type":"chatgpt","planType":"pro"},"requiresOpenaiAuth":true}}'
run_wrapper "$test_dir/codex-included" "say hello"
assert_equals "$AAGENT_TEST_STATUS" 0 "Codex included scenario failed"
find "$record_dir" -name 'codex.run.*.record' -print -quit | grep -q . || \
    fail "ChatGPT Codex did not beat API-only Claude"
assert_contains "$(<"$test_dir/codex-included.stderr")" \
    "using codex (included_confirmed, ChatGPT Pro; higher funding class (included_confirmed))" \
    "Codex selection notice differs"

clear_selection_case
export AAGENT_COPILOT_BIN="$fake_bin/copilot"
export AAGENT_CODEX_BIN="$fake_bin/codex"
export COPILOT_GITHUB_TOKEN='seeded-secret-token'
export AAGENT_FAKE_CODEX_APP_SERVER_STDOUT='{"id":1,"result":{"account":{"type":"apiKey"},"requiresOpenaiAuth":true}}'
run_wrapper "$test_dir/copilot-included" "say hello"
assert_equals "$AAGENT_TEST_STATUS" 0 "Copilot included-account scenario failed"
find "$record_dir" -name 'copilot.run.*.record' -print -quit | grep -q . || \
    fail "GitHub-account Copilot did not beat API-only Codex"
assert_contains "$(<"$test_dir/copilot-included.stderr")" \
    "using copilot (included_account, GitHub account; higher funding class (included_account))" \
    "Copilot selection notice differs"

clear_selection_case
export AAGENT_COPILOT_BIN="$fake_bin/copilot"
export AAGENT_CODEX_BIN="$fake_bin/codex"
export COPILOT_GITHUB_TOKEN='seeded-secret-token'
export AAGENT_FAKE_CODEX_APP_SERVER_STDOUT='{"id":1,"result":{"account":{"type":"chatgpt","planType":"pro"},"requiresOpenaiAuth":true}}'
run_wrapper "$test_dir/codex-beats-copilot" "say hello"
assert_equals "$AAGENT_TEST_STATUS" 0 "Codex versus Copilot scenario failed"
find "$record_dir" -name 'codex.run.*.record' -print -quit | grep -q . || \
    fail "ChatGPT Pro did not beat GitHub-account Copilot"

clear_selection_case
export AAGENT_COPILOT_BIN="$fake_bin/copilot"
export COPILOT_PROVIDER_BASE_URL='https://models.example.test/v1'
export COPILOT_PROVIDER_API_KEY='seeded-secret-token'
export COPILOT_GITHUB_TOKEN='seeded-secret-token'
run_wrapper "$test_dir/copilot-byok-precedence" "say hello"
assert_equals "$AAGENT_TEST_STATUS" 0 "Copilot BYOK precedence scenario failed"
assert_contains "$(<"$test_dir/copilot-byok-precedence.stderr")" \
    "using copilot (payg_byok, Copilot BYOK" \
    "Copilot BYOK did not take precedence over GitHub token evidence"

clear_selection_case
export AAGENT_COPILOT_BIN="$fake_bin/copilot"
export COPILOT_PROVIDER_BASE_URL='http://localhost:11434/v1'
run_wrapper "$test_dir/copilot-local-blocked" "say hello"
assert_equals "$AAGENT_TEST_STATUS" "$AAGENT_EXIT_UNAVAILABLE" "Copilot local route bypassed allow-local"
[[ ! -e "$record_dir/run.count" ]] || fail "blocked Copilot local route received the prompt"
run_wrapper "$test_dir/copilot-local-allowed" --allow-local true "say hello"
assert_equals "$AAGENT_TEST_STATUS" 0 "allowed Copilot local route failed"
find "$record_dir" -name 'copilot.run.*.record' -print -quit | grep -q . || \
    fail "allowed Copilot local route did not run"

clear_selection_case
export AAGENT_COPILOT_BIN="$fake_bin/copilot"
run_wrapper "$test_dir/copilot-unknown" "say hello"
assert_equals "$AAGENT_TEST_STATUS" 0 "Copilot unknown last-resort scenario failed"
find "$record_dir" -name 'copilot.run.*.record' -print -quit | grep -q . || \
    fail "Copilot unknown evidence was not retained as a last resort"

clear_selection_case
export AAGENT_CLAUDE_BIN="$fake_bin/claude"
export AAGENT_CODEX_BIN="$fake_bin/codex"
export AAGENT_FAKE_CLAUDE_STDOUT='{"loggedIn":true,"authMethod":"api_key","apiProvider":"console"}'
export AAGENT_FAKE_CODEX_APP_SERVER_STDOUT='{"id":1,"result":{"account":{"type":"apiKey"},"requiresOpenaiAuth":true}}'
run_wrapper "$test_dir/metered" "say hello"
assert_equals "$AAGENT_TEST_STATUS" 0 "metered fallback scenario failed"
find "$record_dir" -name 'codex.run.*.record' -print -quit | grep -q . || fail "best metered candidate was not selected"
assert_contains "$(<"$test_dir/metered.stderr")" \
    "using codex (payg_byok, OpenAI API; authentication confidence 4)" \
    "metered fallback notice differs"

clear_selection_case
export AAGENT_CLAUDE_BIN="$fake_bin/claude"
export AAGENT_OPENCODE_BIN="$fake_bin/opencode"
export AAGENT_FAKE_CLAUDE_STDOUT='{"loggedIn":false}'
export AAGENT_FAKE_OPENCODE_STDOUT='No credentials found'
run_wrapper "$test_dir/unknown" "say hello"
assert_equals "$AAGENT_TEST_STATUS" 0 "unknown fallback scenario failed"
find "$record_dir" -name 'opencode.run.*.record' -print -quit | grep -q . || \
    fail "unknown candidate was not retained as a last resort"

clear_selection_case
export AAGENT_CLAUDE_BIN="$fake_bin/claude"
export AAGENT_FAKE_CLAUDE_STDOUT='{"loggedIn":false}'
run_wrapper "$test_dir/all-unusable" "say hello"
assert_equals "$AAGENT_TEST_STATUS" "$AAGENT_EXIT_UNAVAILABLE" "all-unusable status differs"
assert_contains "$(<"$test_dir/all-unusable.stderr")" \
    "no installed provider is eligible for automatic selection" \
    "all-unusable guidance differs"
[[ ! -e "$record_dir/run.count" ]] || fail "known-unusable provider received the prompt"

clear_selection_case
run_wrapper "$test_dir/empty" "say hello"
assert_equals "$AAGENT_TEST_STATUS" "$AAGENT_EXIT_UNAVAILABLE" "empty automatic selection status differs"
assert_contains "$(<"$test_dir/empty.stderr")" "no supported coding agent is installed" \
    "empty automatic selection guidance differs"
[[ ! -e "$record_dir/run.count" ]] || fail "empty automatic selection launched a provider"

clear_selection_case
export AAGENT_CLAUDE_BIN="$fake_bin/claude"
export AAGENT_CODEX_BIN="$fake_bin/codex"
export AAGENT_FAKE_CLAUDE_STDOUT='{"loggedIn":true,"authMethod":"claude.ai","subscriptionType":"pro","apiProvider":"claude.ai"}'
export AAGENT_FAKE_CODEX_APP_SERVER_STDOUT='probe-must-not-run'
run_wrapper "$test_dir/explicit" --provider claude "say hello"
assert_equals "$AAGENT_TEST_STATUS" 0 "explicit provider failed"
assert_equals "$(tr -d '\r\n' < "$record_dir/probe.count")" 1 \
    "explicit provider probed more than its selected auth policy"
[[ ! -e "$record_dir/codex.probe.1.record" ]] || fail "explicit provider probed an unselected provider"
find "$record_dir" -name 'claude.run.*.record' -print -quit | grep -q . || fail "explicit provider did not run"

clear_selection_case
run_wrapper "$test_dir/missing-explicit" --provider copilot "say hello"
assert_equals "$AAGENT_TEST_STATUS" "$AAGENT_EXIT_UNAVAILABLE" "known missing provider status differs"
run_wrapper "$test_dir/unknown-explicit" --provider not-a-provider "say hello"
assert_equals "$AAGENT_TEST_STATUS" "$AAGENT_EXIT_USAGE" "unknown provider status differs"

clear_selection_case
export AAGENT_CLAUDE_BIN="$fake_bin/claude"
export AAGENT_FAKE_CLAUDE_STDOUT='{"loggedIn":true,"authMethod":"claude.ai","subscriptionType":"pro","apiProvider":"claude.ai"}'
export AAGENT_FAKE_RUN_STDERR='provider diagnostic'
run_wrapper "$test_dir/quiet" --quiet "say hello"
assert_equals "$AAGENT_TEST_STATUS" 0 "quiet selection failed"
assert_equals "$(<"$test_dir/quiet.stderr")" "provider diagnostic" "quiet suppressed or added the wrong stderr"

clear_selection_case
export AAGENT_CLAUDE_BIN="$fake_bin/claude"
export AAGENT_CODEX_BIN="$fake_bin/codex"
export AAGENT_FAKE_CLAUDE_STDOUT='{"loggedIn":true,"authMethod":"claude.ai","subscriptionType":"max","apiProvider":"claude.ai"}'
export AAGENT_FAKE_CODEX_APP_SERVER_STDOUT='{"id":1,"result":{"account":{"type":"apiKey"},"requiresOpenaiAuth":true}}'
printf '%s\n' '{"last":"codex","quota":"exhausted"}' >"$home_dir/.config/aagent/usage.json"
run_wrapper "$test_dir/history-one" "say hello"
rm -rf "$record_dir"
mkdir -p "$record_dir"
printf '%s\n' '{"last":"claude","quota":"full"}' >"$home_dir/.config/aagent/usage.json"
run_wrapper "$test_dir/history-two" "say hello"
assert_equals "$AAGENT_TEST_STATUS" 0 "repeated deterministic selection failed"
assert_contains "$(<"$test_dir/history-one.stderr")" "using claude" "history changed first selection"
assert_contains "$(<"$test_dir/history-two.stderr")" "using claude" "history or quota changed repeated selection"

printf 'Selection Bash tests passed.\n'
