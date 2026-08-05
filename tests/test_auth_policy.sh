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

assert_not_contains() {
    [[ "$1" != *"$2"* ]] || fail "$3 (unexpected '$2')"
}

assert_file_line() {
    grep -Fqx -- "$2" "$1" || fail "$3 (missing '$2')"
}

hex_string() {
    printf '%s' "$1" | od -An -v -tx1 | tr -d ' \n'
}

test_dir="$(mktemp -d)"
original_path="$PATH"
home_dir="$test_dir/home"
fake_bin="$test_dir/bin"
record_dir="$test_dir/records"
missing_dir="$test_dir/missing"
mkdir -p "$home_dir/.config/aagent" "$fake_bin" "$record_dir"
for provider in claude codex; do
    cp "$fake_provider" "$fake_bin/$provider"
    chmod +x "$fake_bin/$provider"
done

policy_environment_names=(
    AAGENT_AUTH_POLICY AAGENT_PROVIDER AAGENT_PRIORITY AAGENT_ALLOW_LOCAL
    AAGENT_CLAUDE_BIN AAGENT_CODEX_BIN
    AAGENT_OPENCODE_BIN AAGENT_COPILOT_BIN AAGENT_GEMINI_BIN AAGENT_AMP_BIN
    AAGENT_FAKE_PROVIDER AAGENT_FAKE_INVOCATION_KIND
    AAGENT_FAKE_ENV_PRESENCE AAGENT_FAKE_ENV_CAPTURE
    AAGENT_FAKE_PROBE_STDOUT AAGENT_FAKE_PROBE_STDERR AAGENT_FAKE_PROBE_STATUS
    AAGENT_FAKE_PROBE_DELAY AAGENT_FAKE_PROBE_BYTES
    AAGENT_FAKE_CLAUDE_STDOUT AAGENT_FAKE_CLAUDE_STDERR AAGENT_FAKE_CLAUDE_STATUS
    AAGENT_FAKE_CLAUDE_DELAY AAGENT_FAKE_CLAUDE_BYTES
    AAGENT_FAKE_CODEX_APP_SERVER_STDOUT AAGENT_FAKE_CODEX_APP_SERVER_STATUS
    AAGENT_FAKE_CODEX_APP_SERVER_STDERR AAGENT_FAKE_CODEX_APP_SERVER_DELAY
    AAGENT_FAKE_CODEX_APP_SERVER_BYTES
    AAGENT_FAKE_CODEX_LOGIN_STDERR AAGENT_FAKE_CODEX_LOGIN_STATUS
    AAGENT_FAKE_CODEX_LOGIN_STDOUT AAGENT_FAKE_CODEX_LOGIN_DELAY AAGENT_FAKE_CODEX_LOGIN_BYTES
    AAGENT_FAKE_RUN_STDOUT AAGENT_FAKE_RUN_STDERR AAGENT_FAKE_RUN_STATUS
    AAGENT_FAKE_RUN_DELAY ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN
    ANTHROPIC_BASE_URL ANTHROPIC_BEDROCK_BASE_URL ANTHROPIC_BEDROCK_MANTLE_BASE_URL
    ANTHROPIC_AWS_BASE_URL ANTHROPIC_VERTEX_BASE_URL ANTHROPIC_FOUNDRY_BASE_URL
    ANTHROPIC_FOUNDRY_RESOURCE ANTHROPIC_FOUNDRY_API_KEY AWS_BEARER_TOKEN_BEDROCK
    ANTHROPIC_CUSTOM_HEADERS CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_MANTLE
    CLAUDE_CODE_USE_VERTEX CLAUDE_CODE_USE_FOUNDRY CLAUDE_CODE_USE_ANTHROPIC_AWS
    CODEX_API_KEY OPENAI_API_KEY
)

cleanup() {
    export PATH="$original_path"
    rm -rf "$test_dir"
}
trap cleanup EXIT

export HOME="$home_dir"
export XDG_CONFIG_HOME="$home_dir/.config"
export PATH="$fake_bin:/usr/bin:/bin"
export AAGENT_FAKE_RECORD_DIR="$record_dir"

clear_case() {
    local name
    rm -rf "$record_dir"
    mkdir -p "$record_dir"
    rm -f "$home_dir/.config/aagent/config"
    for name in "${policy_environment_names[@]}"; do
        unset "$name" 2>/dev/null || true
    done
    export AAGENT_CLAUDE_BIN="$missing_dir/claude"
    export AAGENT_CODEX_BIN="$missing_dir/codex"
    export AAGENT_OPENCODE_BIN="$missing_dir/opencode"
    export AAGENT_COPILOT_BIN="$missing_dir/copilot"
    export AAGENT_GEMINI_BIN="$missing_dir/gemini"
    export AAGENT_AMP_BIN="$missing_dir/amp"
    export AAGENT_FAKE_ENV_PRESENCE="ANTHROPIC_API_KEY,ANTHROPIC_AUTH_TOKEN,ANTHROPIC_BASE_URL,ANTHROPIC_CUSTOM_HEADERS,CLAUDE_CODE_USE_BEDROCK,CLAUDE_CODE_USE_VERTEX,CLAUDE_CODE_USE_FOUNDRY,CODEX_API_KEY,OPENAI_API_KEY"
    export AAGENT_FAKE_ENV_CAPTURE="CODEX_API_KEY,OPENAI_API_KEY"
    export AAGENT_FAKE_RUN_STATUS=0
}

run_wrapper() {
    local prefix="$1"
    shift
    AAGENT_TEST_STATUS=0
    bash "$aagent_script" "$@" </dev/null >"$prefix.stdout" 2>"$prefix.stderr" || \
        AAGENT_TEST_STATUS=$?
    AAGENT_TEST_STDOUT="$(<"$prefix.stdout")"
    AAGENT_TEST_STDERR="$(<"$prefix.stderr")"
}

claude_subscription='{"loggedIn":true,"authMethod":"claude.ai","subscriptionType":"max","apiProvider":"claude.ai"}'
codex_subscription='{"id":1,"result":{"account":{"type":"chatgpt","planType":"pro"},"requiresOpenaiAuth":true}}'
codex_api='{"id":1,"result":{"account":{"type":"apiKey"},"requiresOpenaiAuth":true}}'
secret_anthropic="anthropic-phase9-secret"
secret_codex="codex-phase9-secret"
secret_openai="openai-phase9-secret"

# Projection itself must not mutate the wrapper process environment.
export ANTHROPIC_API_KEY="$secret_anthropic"
# shellcheck disable=SC2034 # Read indirectly by the sourced policy projector.
AAGENT_EFFECTIVE_AUTH_POLICY="prefer-included"
aagent_reset_probe_result claude
aagent_set_probe_result ready included_confirmed 3 "Claude Max" \
    claude_subscription_status auth_status success ANTHROPIC_API_KEY
aagent_project_probe_for_auth_policy claude
assert_equals "$ANTHROPIC_API_KEY" "$secret_anthropic" "probe projection mutated its process environment"
assert_equals "$AAGENT_AUTH_ENV_UNSET_NAME" ANTHROPIC_API_KEY "Claude projection omitted the wrong name"
unset ANTHROPIC_API_KEY

clear_case
export AAGENT_CLAUDE_BIN="$fake_bin/claude"
export AAGENT_FAKE_CLAUDE_STDOUT="$claude_subscription"
export ANTHROPIC_API_KEY="$secret_anthropic"
run_wrapper "$test_dir/claude-subscription" --provider claude "say hello"
assert_equals "$AAGENT_TEST_STATUS" 0 "Claude subscription launch failed"
assert_file_line "$record_dir/claude.run.1.record" "env.ANTHROPIC_API_KEY=absent" \
    "Claude child retained the shadowing API key"
assert_equals "$ANTHROPIC_API_KEY" "$secret_anthropic" "Claude success mutated the parent key"
assert_contains "$AAGENT_TEST_STDERR" \
    "using claude subscription; omitting ANTHROPIC_API_KEY from the child process" \
    "Claude adjustment notice differs"
assert_not_contains "$AAGENT_TEST_STDERR$AAGENT_TEST_STDOUT" "$secret_anthropic" \
    "Claude output leaked the API key"

clear_case
export AAGENT_CLAUDE_BIN="$fake_bin/claude"
export AAGENT_CODEX_BIN="$fake_bin/codex"
export AAGENT_FAKE_CLAUDE_STDOUT="$claude_subscription"
export AAGENT_FAKE_CODEX_APP_SERVER_STDOUT="$codex_api"
export ANTHROPIC_API_KEY="$secret_anthropic"
run_wrapper "$test_dir/claude-shadow-selection" "say hello"
assert_contains "$AAGENT_TEST_STDERR" "using claude (included_confirmed, Claude Max;" \
    "Claude subscription shadow was ranked as metered"
assert_file_line "$record_dir/claude.run.1.record" "env.ANTHROPIC_API_KEY=absent" \
    "selected Claude subscription retained its API-key shadow"

clear_case
export AAGENT_CLAUDE_BIN="$fake_bin/claude"
export AAGENT_FAKE_CLAUDE_STDOUT="$claude_subscription"
export ANTHROPIC_API_KEY="$secret_anthropic"
run_wrapper "$test_dir/claude-native" --auth-policy native --provider claude "say hello"
assert_equals "$AAGENT_TEST_STATUS" 0 "native Claude launch failed"
assert_file_line "$record_dir/claude.run.1.record" "env.ANTHROPIC_API_KEY=present" \
    "native Claude changed the child environment"
assert_not_contains "$AAGENT_TEST_STDERR" "omitting ANTHROPIC_API_KEY" \
    "native Claude emitted an adjustment"

custom_route_cases=(
    ANTHROPIC_BASE_URL
    ANTHROPIC_AUTH_TOKEN
    ANTHROPIC_CUSTOM_HEADERS
    CLAUDE_CODE_USE_BEDROCK
    CLAUDE_CODE_USE_VERTEX
    CLAUDE_CODE_USE_FOUNDRY
)
for route_name in "${custom_route_cases[@]}"; do
    clear_case
    export AAGENT_CLAUDE_BIN="$fake_bin/claude"
    export AAGENT_FAKE_CLAUDE_STDOUT="$claude_subscription"
    export ANTHROPIC_API_KEY="$secret_anthropic"
    export "$route_name=organization-route"
    run_wrapper "$test_dir/claude-route-$route_name" "say hello"
    assert_equals "$AAGENT_TEST_STATUS" 0 "$route_name route launch failed"
    assert_file_line "$record_dir/claude.run.1.record" "env.ANTHROPIC_API_KEY=present" \
        "$route_name route lost the API key"
    assert_file_line "$record_dir/claude.run.1.record" "env.$route_name=present" \
        "$route_name route was not preserved"
    assert_contains "$AAGENT_TEST_STDERR" "using claude (unknown, Organization route; only eligible provider)" \
        "$route_name route was not classified unknown"
    assert_not_contains "$AAGENT_TEST_STDERR" "omitting ANTHROPIC_API_KEY" \
        "$route_name route triggered an unsafe adjustment"
done

clear_case
export AAGENT_CLAUDE_BIN="$fake_bin/claude"
export AAGENT_FAKE_CLAUDE_STDOUT='{"loggedIn":true,"authMethod":"oauth","subscriptionType":"max","apiProvider":"claude.ai","apiKeySource":"helper"}'
export ANTHROPIC_API_KEY="$secret_anthropic"
run_wrapper "$test_dir/claude-helper" "say hello"
assert_file_line "$record_dir/claude.run.1.record" "env.ANTHROPIC_API_KEY=present" \
    "Claude helper configuration lost the native API key"
assert_contains "$AAGENT_TEST_STDERR" "using claude (unknown, Bearer or helper; only eligible provider)" \
    "Claude helper configuration was not classified unknown"

clear_case
export AAGENT_CLAUDE_BIN="$fake_bin/claude"
export AAGENT_FAKE_CLAUDE_STATUS=23
export ANTHROPIC_API_KEY="$secret_anthropic"
run_wrapper "$test_dir/claude-probe-failure" --provider claude "say hello"
assert_equals "$AAGENT_TEST_STATUS" 0 "Claude probe-failure fallback failed"
assert_file_line "$record_dir/claude.run.1.record" "env.ANTHROPIC_API_KEY=present" \
    "probe failure stripped a credential"
assert_equals "$ANTHROPIC_API_KEY" "$secret_anthropic" "probe failure mutated the parent key"

clear_case
export AAGENT_CODEX_BIN="$fake_bin/codex"
export AAGENT_FAKE_CODEX_APP_SERVER_STDOUT="$codex_subscription"
export CODEX_API_KEY="$secret_codex"
run_wrapper "$test_dir/codex-subscription" --provider codex "say hello"
assert_equals "$AAGENT_TEST_STATUS" 0 "Codex subscription launch failed"
assert_file_line "$record_dir/codex.run.1.record" "env.CODEX_API_KEY=absent" \
    "Codex child retained the shadowing API key"
assert_equals "$CODEX_API_KEY" "$secret_codex" "Codex success mutated the parent key"
assert_contains "$AAGENT_TEST_STDERR" \
    "using codex ChatGPT account; omitting CODEX_API_KEY from the child process" \
    "Codex adjustment notice differs"
assert_not_contains "$AAGENT_TEST_STDERR$AAGENT_TEST_STDOUT" "$secret_codex" \
    "Codex output leaked the API key"

clear_case
export AAGENT_CLAUDE_BIN="$fake_bin/claude"
export AAGENT_CODEX_BIN="$fake_bin/codex"
export AAGENT_FAKE_CLAUDE_STDOUT='{"loggedIn":true,"authMethod":"api_key","apiProvider":"console"}'
export AAGENT_FAKE_CODEX_APP_SERVER_STDOUT="$codex_subscription"
export CODEX_API_KEY="$secret_codex"
run_wrapper "$test_dir/codex-shadow-selection" "say hello"
assert_contains "$AAGENT_TEST_STDERR" "using codex (included_confirmed, ChatGPT Pro;" \
    "Codex account shadow was ranked as metered"
assert_file_line "$record_dir/codex.run.1.record" "env.CODEX_API_KEY=absent" \
    "selected Codex account retained its API-key shadow"

clear_case
export AAGENT_CODEX_BIN="$fake_bin/codex"
export AAGENT_FAKE_CODEX_APP_SERVER_STDOUT="$codex_subscription"
export CODEX_API_KEY="$secret_codex"
run_wrapper "$test_dir/codex-native" --auth-policy native --provider codex "say hello"
assert_file_line "$record_dir/codex.run.1.record" "env.CODEX_API_KEY=present" \
    "native Codex changed the child environment"
assert_not_contains "$AAGENT_TEST_STDERR" "omitting CODEX_API_KEY" \
    "native Codex emitted an adjustment"

clear_case
export AAGENT_CODEX_BIN="$fake_bin/codex"
export AAGENT_FAKE_CODEX_APP_SERVER_STDOUT="$codex_api"
export OPENAI_API_KEY="$secret_openai"
run_wrapper "$test_dir/codex-map" --provider codex "say hello"
assert_equals "$AAGENT_TEST_STATUS" 0 "Codex metered mapping failed"
assert_file_line "$record_dir/codex.run.1.record" "env.CODEX_API_KEY=present" \
    "Codex metered child lacks CODEX_API_KEY"
assert_file_line "$record_dir/codex.run.1.record" \
    "env.CODEX_API_KEY.hex=$(hex_string "$secret_openai")" \
    "Codex metered mapping changed the value"
assert_equals "$OPENAI_API_KEY" "$secret_openai" "Codex mapping mutated the parent key"
assert_contains "$AAGENT_TEST_STDERR" \
    "mapping OPENAI_API_KEY to CODEX_API_KEY for the child process" \
    "Codex mapping notice differs"
assert_not_contains "$AAGENT_TEST_STDERR$AAGENT_TEST_STDOUT" "$secret_openai" \
    "Codex mapping output leaked the API key"

clear_case
export AAGENT_CODEX_BIN="$fake_bin/codex"
export AAGENT_FAKE_CODEX_APP_SERVER_STDOUT="$codex_api"
export OPENAI_API_KEY="$secret_openai"
run_wrapper "$test_dir/codex-map-dry" --dry-run --provider codex "say hello"
assert_equals "$AAGENT_TEST_STATUS" 0 "Codex mapping dry-run failed"
assert_contains "$AAGENT_TEST_STDOUT" "set environment: CODEX_API_KEY" \
    "Codex dry-run omitted the set variable name"
assert_not_contains "$AAGENT_TEST_STDOUT$AAGENT_TEST_STDERR" "$secret_openai" \
    "Codex dry-run leaked the mapped value"
[[ ! -e "$record_dir/run.count" ]] || fail "Codex dry-run launched a provider"
assert_equals "$OPENAI_API_KEY" "$secret_openai" "dry-run mutated the parent key"

clear_case
export AAGENT_CODEX_BIN="$fake_bin/codex"
export AAGENT_FAKE_CODEX_APP_SERVER_STATUS=23
export AAGENT_FAKE_CODEX_LOGIN_STATUS=23
export OPENAI_API_KEY="$secret_openai"
run_wrapper "$test_dir/codex-native-openai" --auth-policy native "say hello"
assert_equals "$AAGENT_TEST_STATUS" 0 "native Codex unknown fallback failed"
assert_file_line "$record_dir/codex.run.1.record" "env.CODEX_API_KEY=absent" \
    "native Codex mapped OPENAI_API_KEY"
assert_contains "$AAGENT_TEST_STDERR" "using codex (unknown; only eligible provider)" \
    "native Codex did not classify the untouched path unknown"

clear_case
export AAGENT_CODEX_BIN="$fake_bin/codex"
export AAGENT_FAKE_CODEX_APP_SERVER_STDOUT='{"id":1,"result":{"account":null,"requiresOpenaiAuth":false}}'
export OPENAI_API_KEY="$secret_openai"
run_wrapper "$test_dir/codex-custom" "say hello"
assert_file_line "$record_dir/codex.run.1.record" "env.CODEX_API_KEY=absent" \
    "custom Codex provider received an unsafe API-key mapping"
assert_contains "$AAGENT_TEST_STDERR" "using codex (unknown, Custom provider; only eligible provider)" \
    "custom Codex provider was not classified unknown"

clear_case
export AAGENT_CLAUDE_BIN="$fake_bin/claude"
export AAGENT_FAKE_CLAUDE_STDOUT="$claude_subscription"
export AAGENT_FAKE_RUN_STATUS=23
export ANTHROPIC_API_KEY="$secret_anthropic"
run_wrapper "$test_dir/provider-failure" --provider claude "say hello"
assert_equals "$AAGENT_TEST_STATUS" 23 "provider failure status was remapped"
assert_equals "$ANTHROPIC_API_KEY" "$secret_anthropic" "provider failure mutated the parent key"

clear_case
export AAGENT_CLAUDE_BIN="$fake_bin/claude"
export AAGENT_FAKE_CLAUDE_STDOUT="$claude_subscription"
export AAGENT_FAKE_RUN_STDERR="provider diagnostic"
export ANTHROPIC_API_KEY="$secret_anthropic"
run_wrapper "$test_dir/quiet" --quiet --provider claude "say hello"
assert_equals "$AAGENT_TEST_STDERR" "provider diagnostic" "quiet did not suppress auth notices"

clear_case
export AAGENT_CLAUDE_BIN="$fake_bin/claude"
export AAGENT_FAKE_CLAUDE_STDOUT="$claude_subscription"
export AAGENT_FAKE_RUN_DELAY=30
export ANTHROPIC_API_KEY="$secret_anthropic"
bash "$aagent_script" --quiet --provider claude "say hello" \
    >"$test_dir/interruption.stdout" 2>"$test_dir/interruption.stderr" &
wrapper_pid=$!
for _ in {1..300}; do
    [[ -f "$record_dir/claude.run.1.record" ]] && break
    sleep 0.01
done
[[ -f "$record_dir/claude.run.1.record" ]] || fail "interruption provider did not start"
kill -TERM "$wrapper_pid"
set +e
wait "$wrapper_pid"
interruption_status=$?
set -e
assert_equals "$interruption_status" 143 "interruption status differs"
assert_equals "$ANTHROPIC_API_KEY" "$secret_anthropic" "interruption mutated the parent key"

printf 'Authentication policy Bash tests passed.\n'
