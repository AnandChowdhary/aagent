#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
aagent_script="$project_root/aagent.sh"
install_script="$project_root/install.sh"
fake_provider="$project_root/tests/helpers/fake-provider.sh"
parser_test="$project_root/tests/test_parser.sh"
discovery_test="$project_root/tests/test_discovery.sh"
launch_test="$project_root/tests/test_launch.sh"
adapter_test="$project_root/tests/test_adapters.sh"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
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

assert_file_contains() {
    local file="$1"
    local expected="$2"
    local message="$3"
    grep -Fqx "$expected" "$file" || fail "$message"
}

hex_string() {
    printf '%s' "$1" | od -An -v -tx1 | tr -d ' \n'
}

bash -n \
    "$aagent_script" \
    "$install_script" \
    "$fake_provider" \
    "$parser_test" \
    "$discovery_test" \
    "$launch_test" \
    "$adapter_test" \
    "${BASH_SOURCE[0]}"

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
work_dir="$test_dir/work"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$fake_bin" "$record_dir" "$work_dir"
export PATH="$fake_bin:$original_path"

tier_one_providers=(claude codex opencode amp gemini)
for provider in "${tier_one_providers[@]}"; do
    cp "$fake_provider" "$fake_bin/$provider"
    chmod +x "$fake_bin/$provider"
done

help_output="$(bash "$aagent_script" --help)"
assert_contains "$help_output" "Run any CLI coding agent with a single command." "help is missing the description"
assert_contains "$help_output" "Usage:" "help is missing usage"
assert_contains "$help_output" "--help" "help is missing the help option"

short_help_output="$(bash "$aagent_script" -h)"
assert_equals "$short_help_output" "$help_output" "-h and --help output differ"

default_output="$test_dir/default.out"
set +e
bash "$aagent_script" >"$default_output" 2>&1
default_status=$?
set -e
assert_equals "$default_status" "64" "running without input should use the wrapper usage status"
grep -q "a non-empty prompt or piped stdin is required" "$default_output" || fail "missing input error is absent"

unknown_output="$test_dir/unknown.out"
set +e
bash "$aagent_script" --unknown >"$unknown_output" 2>&1
unknown_status=$?
set -e
assert_equals "$unknown_status" "64" "unknown arguments should use the wrapper usage status"
grep -q "unknown option: --unknown" "$unknown_output" || fail "unknown option error is missing"

AAGENT_SOURCE="$aagent_script" INSTALL_DIR="$test_dir/installed-bin" bash "$install_script" >/dev/null
installed_help_output="$("$test_dir/installed-bin/aagent" --help)"
assert_equals "$installed_help_output" "$help_output" "installed executable help differs"

export AAGENT_FAKE_RECORD_DIR="$record_dir"
export AAGENT_FAKE_RUN_STDOUT="run-output"
export AAGENT_FAKE_RUN_STDERR="run-error"
export AAGENT_FAKE_RUN_STATUS=0
export AAGENT_FAKE_ENV_PRESENCE="ANTHROPIC_API_KEY,CODEX_API_KEY"
export AAGENT_FAKE_ENV_CAPTURE="AAGENT_SAFE_SENTINEL"
export AAGENT_SAFE_SENTINEL="safe-value"
export ANTHROPIC_API_KEY="must-not-be-recorded"
unset CODEX_API_KEY
hostile_argument='$'
hostile_argument+='(touch should-not-exist)'

run_index=0
for provider in "${tier_one_providers[@]}"; do
    run_index=$((run_index + 1))
    run_stdout="$test_dir/$provider.stdout"
    run_stderr="$test_dir/$provider.stderr"
    (
        cd "$work_dir"
        printf 'context\n' | "$fake_bin/$provider" "say hello" "$hostile_argument" >"$run_stdout" 2>"$run_stderr"
    )

    assert_equals "$(cat "$run_stdout")" "run-output" "$provider run stdout differs"
    assert_equals "$(cat "$run_stderr")" "run-error" "$provider run stderr differs"

    record="$record_dir/$provider.run.$run_index.record"
    [[ -f "$record" ]] || fail "$provider did not create its run record"
    assert_file_contains "$record" "protocol=1" "$provider record protocol is missing"
    assert_file_contains "$record" "kind=run" "$provider record kind differs"
    assert_file_contains "$record" "argc=2" "$provider argc differs"
    assert_file_contains "$record" "arg.0.hex=$(hex_string 'say hello')" "$provider first argument differs"
    assert_file_contains "$record" "arg.1.hex=$(hex_string "$hostile_argument")" "$provider hostile argument differs"
    assert_file_contains "$record" "stdin.hex=$(hex_string $'context\n')" "$provider stdin differs"
    assert_file_contains "$record" "cwd.hex=$(hex_string "$work_dir")" "$provider cwd differs"
    assert_file_contains "$record" "env.ANTHROPIC_API_KEY=present" "$provider did not record API-key presence"
    assert_file_contains "$record" "env.CODEX_API_KEY=absent" "$provider did not record missing API-key state"
    assert_file_contains "$record" "env.AAGENT_SAFE_SENTINEL.hex=$(hex_string 'safe-value')" "$provider safe sentinel differs"
done

assert_equals "$(tr -d '\r\n' < "$record_dir/run.count")" "5" "run launch count differs"
if grep -R -Fq "must-not-be-recorded" "$record_dir"; then
    fail "fake-provider records contain an environment value requested by presence only"
fi
[[ ! -e "$work_dir/should-not-exist" ]] || fail "hostile argument was evaluated"

export AAGENT_FAKE_PROBE_STDOUT='{"loggedIn":true}'
export AAGENT_FAKE_PROBE_STDERR=""
export AAGENT_FAKE_PROBE_STATUS=0
probe_output="$("$fake_bin/claude" auth status --json </dev/null)"
assert_equals "$probe_output" '{"loggedIn":true}' "natural Claude probe response differs"
assert_file_contains "$record_dir/claude.probe.1.record" "kind=probe" "Claude status was not classified as a probe"

export AAGENT_FAKE_INVOCATION_KIND=probe
probe_cases=(
    '{}'
    'not-json'
    '{"token":"seeded-secret"}'
    '{"email":"person@example.com"}'
    '{"loggedIn":true,"subscriptionType":null}'
)

for response in "${probe_cases[@]}"; do
    export AAGENT_FAKE_PROBE_STDOUT="$response"
    probe_output="$("$fake_bin/gemini" settings </dev/null)"
    assert_equals "$probe_output" "$response" "probe fixture did not preserve a response case"
done

export AAGENT_FAKE_PROBE_DELAY=0.01
export AAGENT_FAKE_PROBE_STDOUT="delayed"
probe_output="$("$fake_bin/amp" status </dev/null)"
assert_equals "$probe_output" "delayed" "delayed probe response differs"
export AAGENT_FAKE_PROBE_DELAY=0

export AAGENT_FAKE_PROBE_STDOUT=""
export AAGENT_FAKE_PROBE_STDERR="probe-failed"
export AAGENT_FAKE_PROBE_STATUS=23
set +e
"$fake_bin/opencode" auth list >"$test_dir/probe-failure.stdout" 2>"$test_dir/probe-failure.stderr"
probe_status=$?
set -e
assert_equals "$probe_status" "23" "probe fixture did not preserve a non-zero status"
assert_equals "$(cat "$test_dir/probe-failure.stderr")" "probe-failed" "probe failure stderr differs"

assert_equals "$(tr -d '\r\n' < "$record_dir/probe.count")" "8" "probe launch count differs"
assert_equals "$(tr -d '\r\n' < "$record_dir/run.count")" "5" "probe fixtures changed the run launch count"

bash "$parser_test"
bash "$discovery_test"
bash "$launch_test"
bash "$adapter_test"

printf 'All Bash tests passed.\n'
