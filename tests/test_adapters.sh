#!/usr/bin/env bash
# shellcheck disable=SC2034

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
aagent_script="$project_root/aagent.sh"
fake_provider="$project_root/tests/helpers/fake-provider.sh"

# shellcheck disable=SC1090
source "$aagent_script"

fail() {
    printf 'FAIL: adapters: %s\n' "$1" >&2
    exit 1
}

assert_equals() {
    local actual="$1"
    local expected="$2"
    local message="$3"
    [[ "$actual" == "$expected" ]] || fail "$message (expected '$expected', got '$actual')"
}

assert_contains() {
    local value="$1"
    local expected="$2"
    local message="$3"
    [[ "$value" == *"$expected"* ]] || fail "$message"
}

assert_file_line() {
    local file="$1"
    local expected="$2"
    local message="$3"
    grep -Fqx "$expected" "$file" || fail "$message"
}

hex_string() {
    printf '%s' "$1" | od -An -v -tx1 | tr -d ' \n'
}

assert_record() {
    local record="$1"
    local expected_stdin="$2"
    shift 2
    local expected_arguments=()
    if (( $# > 0 )); then
        expected_arguments=("$@")
    fi

    [[ -f "$record" ]] || fail "provider record is missing: $record"
    assert_file_line "$record" "argc=${#expected_arguments[@]}" "provider argument count differs"
    local index
    for ((index = 0; index < ${#expected_arguments[@]}; index++)); do
        assert_file_line \
            "$record" \
            "arg.$index.hex=$(hex_string "${expected_arguments[$index]}")" \
            "provider argument $index differs"
    done
    assert_file_line "$record" "stdin.hex=$(hex_string "$expected_stdin")" "provider stdin differs"
}

run_cli() {
    local tag="$1"
    local stdin_mode="$2"
    local stdin_data="$3"
    shift 3

    RUN_STDOUT="$test_dir/$tag.stdout"
    RUN_STDERR="$test_dir/$tag.stderr"
    RUN_STATUS=0
    set +e
    if [[ "$stdin_mode" == "data" ]]; then
        printf '%s' "$stdin_data" | bash "$aagent_script" "$@" >"$RUN_STDOUT" 2>"$RUN_STDERR"
        RUN_STATUS=$?
    else
        bash "$aagent_script" "$@" </dev/null >"$RUN_STDOUT" 2>"$RUN_STDERR"
        RUN_STATUS=$?
    fi
    set -e
}

model_for() {
    case "$1" in
        claude) printf 'claude-model\n' ;;
        codex) printf 'codex-model\n' ;;
        opencode) printf 'provider/model\n' ;;
        copilot) printf 'copilot-model\n' ;;
        gemini) printf 'gemini-model\n' ;;
        amp) printf '\n' ;;
    esac
}

display_name_for() {
    case "$1" in
        claude) printf 'Claude Code\n' ;;
        codex) printf 'Codex CLI\n' ;;
        opencode) printf 'OpenCode\n' ;;
        copilot) printf 'GitHub Copilot CLI\n' ;;
        amp) printf 'Amp\n' ;;
        gemini) printf 'Gemini CLI\n' ;;
    esac
}

prompt_arguments_for() {
    local provider="$1"
    local prompt="$2"
    local model="$3"
    EXPECTED_ARGUMENTS=()
    case "$provider" in
        claude)
            EXPECTED_ARGUMENTS=("--print" "$prompt" "--model" "$model" "--native-flag" "-leading-value")
            ;;
        codex)
            EXPECTED_ARGUMENTS=("exec" "--model" "$model" "--native-flag" "-leading-value" "$prompt")
            ;;
        opencode)
            EXPECTED_ARGUMENTS=("run" "--model" "$model" "--native-flag" "-leading-value" "$prompt")
            ;;
        copilot)
            EXPECTED_ARGUMENTS=("--prompt" "$prompt" "--silent" "--no-ask-user" "--model" "$model" "--native-flag" "-leading-value")
            ;;
        amp)
            EXPECTED_ARGUMENTS=("--execute" "$prompt" "--native-flag" "-leading-value")
            ;;
        gemini)
            EXPECTED_ARGUMENTS=("--model" "$model" "--native-flag" "-leading-value" "--prompt" "$prompt")
            ;;
    esac
}

stdin_arguments_for() {
    local provider="$1"
    local stdin_data="$2"
    EXPECTED_STDIN="$stdin_data"
    case "$provider" in
        claude) EXPECTED_ARGUMENTS=("--print") ;;
        codex) EXPECTED_ARGUMENTS=("exec" "-") ;;
        opencode)
            EXPECTED_ARGUMENTS=("run" "$stdin_data")
            EXPECTED_STDIN=""
            ;;
        copilot)
            EXPECTED_ARGUMENTS=("--prompt" "$stdin_data" "--silent" "--no-ask-user")
            EXPECTED_STDIN=""
            ;;
        amp) EXPECTED_ARGUMENTS=("--execute") ;;
        gemini) EXPECTED_ARGUMENTS=() ;;
    esac
}

both_arguments_for() {
    local provider="$1"
    local prompt="$2"
    local stdin_data="$3"
    EXPECTED_STDIN="$stdin_data"
    case "$provider" in
        claude) EXPECTED_ARGUMENTS=("--print" "$prompt") ;;
        codex) EXPECTED_ARGUMENTS=("exec" "$prompt") ;;
        opencode)
            EXPECTED_ARGUMENTS=("run" "$prompt"$'\n\n--- stdin context ---\n'"$stdin_data")
            EXPECTED_STDIN=""
            ;;
        copilot)
            EXPECTED_ARGUMENTS=("--prompt" "$prompt"$'\n\n--- stdin context ---\n'"$stdin_data" "--silent" "--no-ask-user")
            EXPECTED_STDIN=""
            ;;
        amp) EXPECTED_ARGUMENTS=("--execute" "$prompt") ;;
        gemini) EXPECTED_ARGUMENTS=("--prompt" "$prompt") ;;
    esac
}

test_dir="$(mktemp -d)"
original_home="${HOME-}"
original_path="$PATH"

cleanup() {
    export HOME="$original_home"
    export PATH="$original_path"
    rm -rf "$test_dir"
}
trap cleanup EXIT

export HOME="$test_dir/home"
fake_bin="$test_dir/bin"
work_dir="$test_dir/working directory 🌍"
mkdir -p "$HOME" "$fake_bin" "$work_dir"
expected_work_dir="$(cd "$work_dir" && pwd -P)"

adapter_environment_names=(
    AAGENT_PROVIDER AAGENT_AUTH_POLICY AAGENT_PRIORITY AAGENT_ALLOW_LOCAL
    AAGENT_CLAUDE_BIN AAGENT_CODEX_BIN AAGENT_OPENCODE_BIN AAGENT_COPILOT_BIN
    AAGENT_AMP_BIN AAGENT_GEMINI_BIN
    AAGENT_FAKE_INVOCATION_KIND AAGENT_FAKE_PROBE_STDOUT AAGENT_FAKE_PROBE_STDERR
    AAGENT_FAKE_PROBE_STATUS AAGENT_FAKE_PROBE_DELAY AAGENT_FAKE_PROBE_BYTES
    AAGENT_FAKE_CLAUDE_STDOUT AAGENT_FAKE_CLAUDE_STDERR AAGENT_FAKE_CLAUDE_STATUS
    AAGENT_FAKE_CODEX_APP_SERVER_STDOUT AAGENT_FAKE_CODEX_APP_SERVER_STDERR
    AAGENT_FAKE_CODEX_APP_SERVER_STATUS AAGENT_FAKE_CODEX_LOGIN_STDOUT
    AAGENT_FAKE_CODEX_LOGIN_STDERR AAGENT_FAKE_CODEX_LOGIN_STATUS
    ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL
    CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_VERTEX CLAUDE_CODE_USE_FOUNDRY
    CODEX_API_KEY OPENAI_API_KEY COPILOT_PROVIDER_BASE_URL COPILOT_PROVIDER_TYPE
    COPILOT_PROVIDER_API_KEY COPILOT_PROVIDER_BEARER_TOKEN COPILOT_PROVIDER_HEADERS
    COPILOT_MODEL COPILOT_PROVIDER_MODEL_ID COPILOT_PROVIDER_WIRE_MODEL
    COPILOT_GITHUB_TOKEN GH_TOKEN GITHUB_TOKEN
)
for environment_name in "${adapter_environment_names[@]}"; do
    unset "$environment_name" 2>/dev/null || true
done

providers=(claude codex opencode copilot amp gemini)
for provider in "${providers[@]}"; do
    cp "$fake_provider" "$fake_bin/$provider"
    chmod +x "$fake_bin/$provider"
done
export PATH="$fake_bin:$original_path"
prompt=$'fix the "quoted" issue 🌍\nand keep formatting'
stdin_payload=$'stdin only\nsecond line\n\n'
both_prompt=$'review this change\ncarefully'
both_stdin=$'diff --git a/file b/file\n+new line\n'

aagent_initialize_registry

for provider in "${providers[@]}"; do
    record_dir="$test_dir/records-$provider"
    mkdir -p "$record_dir"
    export AAGENT_FAKE_RECORD_DIR="$record_dir"
    export AAGENT_FAKE_PROVIDER="$provider"
    export AAGENT_FAKE_RUN_STDOUT="provider-stdout-$provider"
    export AAGENT_FAKE_RUN_STDERR="provider-stderr-$provider"
    export AAGENT_FAKE_RUN_STATUS="0"
    export AAGENT_FAKE_CLAUDE_STDOUT='{"loggedIn":true,"authMethod":"claude.ai","subscriptionType":"max","apiProvider":"claude.ai"}'
    export AAGENT_FAKE_CODEX_APP_SERVER_STDOUT='{"id":1,"result":{"account":{"type":"apiKey"},"requiresOpenaiAuth":true}}'

    model="$(model_for "$provider")"
    display_name="$(display_name_for "$provider")"
    prompt_arguments_for "$provider" "$prompt" "$model"
    prompt_cli=("-P" "$provider" "-C" "$work_dir")
    if [[ -n "$model" ]]; then
        prompt_cli+=("-m" "$model")
    fi
    prompt_cli+=("$prompt" "--" "--native-flag" "-leading-value")

    run_cli "$provider-prompt" closed "" "${prompt_cli[@]}"
    assert_equals "$RUN_STATUS" "0" "$provider prompt launch failed"
    assert_equals "$(cat "$RUN_STDOUT")" "provider-stdout-$provider" "$provider stdout differs"
    assert_equals \
        "$(cat "$RUN_STDERR")" \
        $'aagent: selected '"$display_name"$' via explicit --provider\n'"provider-stderr-$provider" \
        "$provider wrapper/provider stderr differs"
    assert_record \
        "$record_dir/$provider.run.1.record" \
        "" \
        "${EXPECTED_ARGUMENTS[@]+"${EXPECTED_ARGUMENTS[@]}"}"
    assert_file_line \
        "$record_dir/$provider.run.1.record" \
        "cwd.hex=$(hex_string "$expected_work_dir")" \
        "$provider cwd differs"

    export AAGENT_FAKE_RUN_STDOUT=""
    export AAGENT_FAKE_RUN_STDERR=""
    stdin_arguments_for "$provider" "$stdin_payload"
    run_cli "$provider-stdin" data "$stdin_payload" "-P" "$provider" "-C" "$work_dir"
    assert_equals "$RUN_STATUS" "0" "$provider stdin-only launch failed"
    assert_record \
        "$record_dir/$provider.run.2.record" \
        "$EXPECTED_STDIN" \
        "${EXPECTED_ARGUMENTS[@]+"${EXPECTED_ARGUMENTS[@]}"}"

    both_arguments_for "$provider" "$both_prompt" "$both_stdin"
    run_cli "$provider-both" data "$both_stdin" "-P" "$provider" "-C" "$work_dir" "$both_prompt"
    assert_equals "$RUN_STATUS" "0" "$provider prompt-plus-stdin launch failed"
    assert_record \
        "$record_dir/$provider.run.3.record" \
        "$EXPECTED_STDIN" \
        "${EXPECTED_ARGUMENTS[@]+"${EXPECTED_ARGUMENTS[@]}"}"

    export AAGENT_FAKE_RUN_STDOUT="quiet-stdout-$provider"
    export AAGENT_FAKE_RUN_STDERR="quiet-stderr-$provider"
    export AAGENT_FAKE_RUN_STATUS="95"
    run_cli "$provider-quiet" closed "" "-P" "$provider" "--quiet" "status test"
    assert_equals "$RUN_STATUS" "95" "$provider non-zero status was remapped"
    assert_equals "$(cat "$RUN_STDOUT")" "quiet-stdout-$provider" "$provider quiet stdout differs"
    assert_equals "$(cat "$RUN_STDERR")" "quiet-stderr-$provider" "$provider quiet suppressed stderr"
    assert_equals "$(tr -d '\r\n' < "$record_dir/run.count")" "4" "$provider launched more than once per request"

    dry_cli=("-P" "$provider" "--dry-run")
    if [[ -n "$model" ]]; then
        dry_cli+=("-m" "$model")
    fi
    dry_cli+=("dry-run-secret-prompt" "--" "--secret-native" "native-secret-value")
    run_cli "$provider-dry" closed "" "${dry_cli[@]}"
    assert_equals "$RUN_STATUS" "0" "$provider dry-run failed"
    dry_output="$(cat "$RUN_STDOUT")"
    assert_contains "$dry_output" "provider: $provider" "$provider dry-run ID is missing"
    assert_contains "$dry_output" "prompt" "$provider dry-run prompt placeholder is missing"
    [[ "$dry_output" != *"dry-run-secret-prompt"* ]] || fail "$provider dry-run leaked the prompt"
    [[ "$dry_output" != *"native-secret-value"* ]] || fail "$provider dry-run leaked a native argument"
    if [[ -n "$model" ]]; then
        [[ "$dry_output" != *"${model}"* ]] || fail "$provider dry-run leaked the model value"
    fi
    assert_equals "$(cat "$RUN_STDERR")" "" "$provider dry-run wrote a notice"
    assert_equals "$(tr -d '\r\n' < "$record_dir/run.count")" "4" "$provider dry-run launched a provider"

    if [[ "$provider" == "amp" ]]; then
        run_cli "$provider-model" closed "" "-P" "$provider" "-m" "unsupported-model" "model test"
        assert_equals "$RUN_STATUS" "64" "Amp accepted an unsupported model"
        assert_contains "$(cat "$RUN_STDERR")" "does not support --model" "Amp model error is missing"
        assert_equals "$(tr -d '\r\n' < "$record_dir/run.count")" "4" "Amp model error launched a provider"
    fi

    run_cli "$provider-empty" data "" "-P" "$provider"
    assert_equals "$RUN_STATUS" "64" "$provider empty input was accepted"
    assert_contains "$(cat "$RUN_STDERR")" "a non-empty prompt or piped stdin is required" "$provider empty input error differs"
    assert_equals "$(tr -d '\r\n' < "$record_dir/run.count")" "4" "$provider empty input launched a provider"

    adapter_index="$(aagent_get_adapter_index "$provider")"
    [[ -n "${AAGENT_ADAPTER_SAFETY[$adapter_index]}" ]] || fail "$provider safety note is missing"
done

printf 'Adapter Bash tests passed.\n'
