#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
aagent_script="$project_root/aagent.sh"
fake_provider="$project_root/tests/helpers/fake-provider.sh"

# shellcheck disable=SC1090
source "$aagent_script"

fail() {
    printf 'FAIL: parser: %s\n' "$1" >&2
    exit 1
}

assert_equals() {
    local actual="$1"
    local expected="$2"
    local message="$3"
    [[ "$actual" == "$expected" ]] || fail "$message (expected '$expected', got '$actual')"
}

assert_parse_error() {
    local expected="$1"
    shift
    local status

    set +e
    aagent_parse_arguments "$@"
    status=$?
    set -e

    assert_equals "$status" "$AAGENT_EXIT_USAGE" "parse error status differs for: $*"
    assert_equals "$AAGENT_PARSE_ERROR" "$expected" "parse error message differs for: $*"
}

test_dir="$(mktemp -d)"
original_home="${HOME-}"
original_xdg_config_home="${XDG_CONFIG_HOME-}"
original_path="$PATH"

cleanup() {
    export HOME="$original_home"
    if [[ -n "$original_xdg_config_home" ]]; then
        export XDG_CONFIG_HOME="$original_xdg_config_home"
    else
        unset XDG_CONFIG_HOME
    fi
    export PATH="$original_path"
    rm -rf "$test_dir"
}
trap cleanup EXIT

export HOME="$test_dir/home"
export XDG_CONFIG_HOME="$test_dir/config"
fake_bin="$test_dir/bin"
record_dir="$test_dir/records"
work_dir="$test_dir/work with spaces"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$fake_bin" "$record_dir" "$work_dir"
for provider in claude codex opencode amp gemini; do
    cp "$fake_provider" "$fake_bin/$provider"
    chmod +x "$fake_bin/$provider"
done
export PATH="$fake_bin:$original_path"
export AAGENT_FAKE_RECORD_DIR="$record_dir"

aagent_parse_arguments \
    -P claude \
    --model sonnet \
    -C "$work_dir" \
    --auth-policy native \
    --dry-run \
    --quiet \
    "say" "hello" \
    -- --sandbox workspace-write

assert_equals "$AAGENT_COMMAND" "run" "run command differs"
assert_equals "$AAGENT_PROVIDER" "claude" "provider differs"
assert_equals "$AAGENT_MODEL" "sonnet" "model differs"
assert_equals "$AAGENT_AUTH_POLICY" "native" "auth policy differs"
assert_equals "$AAGENT_DRY_RUN" "1" "dry-run flag differs"
assert_equals "$AAGENT_QUIET" "1" "quiet flag differs"
assert_equals "$AAGENT_CWD" "$(cd "$work_dir" && pwd -P)" "resolved cwd differs"
assert_equals "${#AAGENT_PROMPT_ARGS[@]}" "2" "prompt argument count differs"
assert_equals "${AAGENT_PROMPT_ARGS[0]}" "say" "first prompt argument differs"
assert_equals "${AAGENT_PROMPT_ARGS[1]}" "hello" "second prompt argument differs"
assert_equals "${#AAGENT_NATIVE_ARGS[@]}" "2" "native argument count differs"
assert_equals "${AAGENT_NATIVE_ARGS[0]}" "--sandbox" "first native argument differs"
assert_equals "${AAGENT_NATIVE_ARGS[1]}" "workspace-write" "second native argument differs"

aagent_resolve_input 0 ""
assert_equals "$AAGENT_PROMPT" "say hello" "joined prompt differs"
assert_equals "$AAGENT_INPUT_MODE" "prompt" "prompt-only input mode differs"

aagent_parse_arguments providers
assert_equals "$AAGENT_COMMAND" "providers" "providers subcommand differs"
aagent_parse_arguments doctor
assert_equals "$AAGENT_COMMAND" "doctor" "doctor subcommand differs"
assert_equals "$AAGENT_DOCTOR_PROVIDER" "" "empty doctor provider differs"
aagent_parse_arguments doctor claude
assert_equals "$AAGENT_DOCTOR_PROVIDER" "claude" "doctor provider differs"
aagent_parse_arguments --help ignored arguments
assert_equals "$AAGENT_COMMAND" "help" "help command differs"
aagent_parse_arguments --version
assert_equals "$AAGENT_COMMAND" "version" "version command differs"

aagent_parse_arguments explain providers doctor
aagent_resolve_input 0 ""
assert_equals "$AAGENT_COMMAND" "run" "subcommand word inside a prompt changed the command"
assert_equals "$AAGENT_PROMPT" "explain providers doctor" "subcommand words inside a prompt differ"

aagent_parse_arguments say --model sonnet hello
aagent_resolve_input 0 ""
assert_equals "$AAGENT_MODEL" "sonnet" "wrapper option after prompt text differs"
assert_equals "$AAGENT_PROMPT" "say hello" "prompt around a wrapper option differs"

assert_parse_error "unknown option: --unknown" --unknown
assert_parse_error "unknown option: --unknown" prompt --unknown
assert_parse_error "option --provider requires a value" --provider
assert_parse_error "option --model requires a value" --model ""
assert_parse_error "option --cwd requires a value" --cwd
assert_parse_error "option --auth-policy requires a value" --auth-policy
assert_parse_error "invalid authentication policy: cheapest" --auth-policy cheapest prompt
assert_parse_error "providers does not accept arguments" providers extra
assert_parse_error "doctor accepts at most one provider" doctor claude extra
assert_parse_error "unknown option: --bad" doctor --bad
assert_parse_error "working directory does not exist: $test_dir/missing" --cwd "$test_dir/missing" prompt

aagent_parse_arguments "stdin prompt"
aagent_resolve_input 1 $'context\n\n'
assert_equals "$AAGENT_INPUT_MODE" "both" "prompt-plus-stdin mode differs"
assert_equals "$AAGENT_STDIN" $'context\n\n' "prompt-plus-stdin data differs"

aagent_parse_arguments
aagent_resolve_input 1 $'stdin only\n'
assert_equals "$AAGENT_INPUT_MODE" "stdin" "stdin-only mode differs"
assert_equals "$AAGENT_STDIN" $'stdin only\n' "stdin-only data differs"

aagent_parse_arguments "prompt only"
aagent_resolve_input 1 ""
assert_equals "$AAGENT_INPUT_MODE" "prompt" "empty redirected stdin changed prompt-only mode"

aagent_parse_arguments
set +e
aagent_resolve_input 0 ""
missing_status=$?
set -e
assert_equals "$missing_status" "$AAGENT_EXIT_USAGE" "missing input status differs"
assert_equals "$AAGENT_PARSE_ERROR" "a non-empty prompt or piped stdin is required" "missing input message differs"

aagent_parse_arguments ""
set +e
aagent_resolve_input 1 $'stdin must not rescue an empty instruction\n'
empty_status=$?
set -e
assert_equals "$empty_status" "$AAGENT_EXIT_USAGE" "empty prompt status differs"
assert_equals "$AAGENT_PARSE_ERROR" "prompt must not be empty" "empty prompt message differs"

aagent_parse_arguments
aagent_resolve_input 1 $'--leading-dash prompt\n'
assert_equals "$AAGENT_INPUT_MODE" "stdin" "leading-dash stdin mode differs"
assert_equals "$AAGENT_STDIN" $'--leading-dash prompt\n' "leading-dash stdin differs"

marker="$test_dir/evaluated"
hostile_dollar='$'
hostile_dollar+='(touch '
hostile_dollar+="$marker"
hostile_dollar+=')'
hostile_backtick='`touch '
hostile_backtick+="$marker"
hostile_backtick+='`'
hostile_powershell='$'
hostile_powershell+='(New-Item '
hostile_powershell+="$marker"
hostile_powershell+=')'

aagent_parse_arguments \
    "literal" \
    "semi; touch $marker" \
    "pipe | touch $marker" \
    "redirect > $marker" \
    "$hostile_dollar" \
    "$hostile_backtick" \
    "$hostile_powershell" \
    "*.md" \
    $'line one\nline two' \
    $'tab\tvalue' \
    "héllo 🌍" \
    "quote ' \" value" \
    $'crlf\r\nvalue' \
    -- --literal-native --
aagent_resolve_input 0 ""

assert_equals "${#AAGENT_PROMPT_ARGS[@]}" "13" "hostile prompt argument count differs"
assert_equals "${AAGENT_PROMPT_ARGS[4]}" "$hostile_dollar" "command-substitution text differs"
assert_equals "${AAGENT_PROMPT_ARGS[8]}" $'line one\nline two' "multiline prompt argument differs"
assert_equals "${AAGENT_PROMPT_ARGS[10]}" "héllo 🌍" "Unicode prompt argument differs"
assert_equals "${AAGENT_PROMPT_ARGS[11]}" "quote ' \" value" "quoted prompt argument differs"
assert_equals "${AAGENT_PROMPT_ARGS[12]}" $'crlf\r\nvalue' "CRLF prompt argument differs"
assert_equals "${AAGENT_NATIVE_ARGS[0]}" "--literal-native" "literal separator native argument differs"
assert_equals "${AAGENT_NATIVE_ARGS[1]}" "--" "literal native double dash differs"
[[ ! -e "$marker" ]] || fail "hostile parser input was evaluated"

help_output="$(bash "$aagent_script" --help)"
[[ "$help_output" == *"aagent doctor [PROVIDER]"* ]] || fail "public help omits doctor"
[[ "$help_output" == *"--auth-policy"* ]] || fail "public help omits auth policy"
assert_equals "$(bash "$aagent_script" --version)" "aagent $AAGENT_VERSION" "public version differs"

set +e
bash "$aagent_script" --unknown >"$test_dir/cli-error.out" 2>&1
cli_error_status=$?
printf '' | bash "$aagent_script" >"$test_dir/empty-stdin.out" 2>&1
empty_stdin_status=$?
bash "$aagent_script" "valid prompt" </dev/null >"$test_dir/valid.out" 2>&1
valid_status=$?
printf 'stdin only\n' | bash "$aagent_script" >"$test_dir/stdin-only.out" 2>&1
stdin_only_status=$?
printf 'context\n' | bash "$aagent_script" "instruction" >"$test_dir/both.out" 2>&1
both_status=$?
set -e

assert_equals "$cli_error_status" "$AAGENT_EXIT_USAGE" "public unknown-option status differs"
assert_equals "$empty_stdin_status" "$AAGENT_EXIT_USAGE" "public empty-stdin status differs"
assert_equals "$valid_status" "$AAGENT_EXIT_UNAVAILABLE" "valid parsed input should reach the next unavailable phase"
assert_equals "$stdin_only_status" "$AAGENT_EXIT_UNAVAILABLE" "stdin-only input should reach the next unavailable phase"
assert_equals "$both_status" "$AAGENT_EXIT_UNAVAILABLE" "prompt-plus-stdin should reach the next unavailable phase"
[[ ! -e "$record_dir/run.count" ]] || fail "parser paths launched a provider"
[[ ! -e "$record_dir/probe.count" ]] || fail "parser paths launched an authentication probe"

printf 'Parser Bash tests passed.\n'
