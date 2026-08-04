#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
aagent_script="$project_root/aagent.sh"
fake_provider="$project_root/tests/helpers/fake-provider.sh"

# shellcheck disable=SC1090
source "$aagent_script"

fail() {
    printf 'FAIL: config: %s\n' "$1" >&2
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

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

export HOME="$test_dir/home"
export XDG_CONFIG_HOME="$test_dir/config with spaces"
config_path="$XDG_CONFIG_HOME/aagent/config"
fake_bin="$test_dir/bin"
record_dir="$test_dir/records"
work_dir="$test_dir/work"
mkdir -p "$HOME" "$(dirname "$config_path")" "$fake_bin" "$record_dir" "$work_dir"
cp "$fake_provider" "$fake_bin/claude"
chmod +x "$fake_bin/claude"
export PATH="$fake_bin:$PATH"
export AAGENT_FAKE_RECORD_DIR="$record_dir"
export AAGENT_FAKE_RUN_STATUS=0
export AAGENT_FAKE_RUN_STDOUT=""
export AAGENT_FAKE_RUN_STDERR=""
unset AAGENT_PROVIDER AAGENT_AUTH_POLICY AAGENT_PRIORITY AAGENT_ALLOW_LOCAL

write_config() {
    printf '%s' "$1" >"$config_path"
}

resolve_config() {
    aagent_parse_arguments "$@"
    aagent_resolve_configuration normal
}

aagent_resolve_config_path
assert_equals "$AAGENT_CONFIG_PATH" "$config_path" "XDG config path differs"
unset XDG_CONFIG_HOME
aagent_resolve_config_path
assert_equals "$AAGENT_CONFIG_PATH" "$HOME/.config/aagent/config" "HOME fallback config path differs"
export XDG_CONFIG_HOME="$test_dir/config with spaces"

rm -f "$config_path"
resolve_config "say hello"
assert_equals "$AAGENT_EFFECTIVE_PROVIDER" "" "default provider differs"
assert_equals "$AAGENT_PROVIDER_SOURCE" "default" "default provider source differs"
assert_equals "$AAGENT_EFFECTIVE_AUTH_POLICY" "prefer-included" "default auth policy differs"
assert_equals "$AAGENT_EFFECTIVE_PRIORITY" "" "default priority differs"
assert_equals "$AAGENT_EFFECTIVE_ALLOW_LOCAL" "false" "default allow-local differs"
assert_equals "$AAGENT_PRIORITY_ROLE" "tie-break-only" "priority escaped its tie-break role"

write_config $'  # full-line comment\r\n provider = claude \r\n auth_policy = native\r\n priority = claude, codex\r\n allow_local = true\r\n'
resolve_config "say hello"
assert_equals "$AAGENT_EFFECTIVE_PROVIDER" "claude" "config provider differs"
assert_equals "$AAGENT_PROVIDER_SOURCE" "config" "config provider source differs"
assert_equals "$AAGENT_EFFECTIVE_AUTH_POLICY" "native" "config auth policy differs"
assert_equals "$AAGENT_AUTH_POLICY_SOURCE" "config" "config auth source differs"
assert_equals "$AAGENT_EFFECTIVE_PRIORITY" "claude, codex" "config priority differs"
assert_equals "$AAGENT_PRIORITY_SOURCE" "config" "config priority source differs"
assert_equals "$AAGENT_EFFECTIVE_ALLOW_LOCAL" "true" "config allow-local differs"
assert_equals "$AAGENT_ALLOW_LOCAL_SOURCE" "config" "config allow-local source differs"

export AAGENT_PROVIDER=claude
export AAGENT_AUTH_POLICY=prefer-included
export AAGENT_PRIORITY=codex,claude
export AAGENT_ALLOW_LOCAL=false
resolve_config "say hello"
assert_equals "$AAGENT_PROVIDER_SOURCE" "environment" "environment provider source differs"
assert_equals "$AAGENT_EFFECTIVE_AUTH_POLICY" "prefer-included" "environment auth precedence differs"
assert_equals "$AAGENT_EFFECTIVE_PRIORITY" "codex,claude" "environment priority precedence differs"
assert_equals "$AAGENT_EFFECTIVE_ALLOW_LOCAL" "false" "environment allow-local precedence differs"

resolve_config \
    --provider claude \
    --auth-policy native \
    --priority claude,codex \
    --allow-local true \
    "say hello"
assert_equals "$AAGENT_PROVIDER_SOURCE" "cli" "CLI provider source differs"
assert_equals "$AAGENT_EFFECTIVE_AUTH_POLICY" "native" "CLI auth precedence differs"
assert_equals "$AAGENT_EFFECTIVE_PRIORITY" "claude,codex" "CLI priority precedence differs"
assert_equals "$AAGENT_EFFECTIVE_ALLOW_LOCAL" "true" "CLI allow-local precedence differs"

export AAGENT_PROVIDER=invalid-lower-precedence
export AAGENT_AUTH_POLICY=invalid-lower-precedence
export AAGENT_PRIORITY=invalid-lower-precedence
export AAGENT_ALLOW_LOCAL=invalid-lower-precedence
resolve_config \
    --provider claude \
    --auth-policy native \
    --priority claude,codex \
    --allow-local false \
    "say hello"
assert_equals "$AAGENT_EFFECTIVE_PROVIDER" "claude" "CLI provider did not override the environment"
assert_equals "$AAGENT_EFFECTIVE_AUTH_POLICY" "native" "CLI auth did not override the environment"
assert_equals "$AAGENT_EFFECTIVE_PRIORITY" "claude,codex" "CLI priority did not override the environment"
assert_equals "$AAGENT_EFFECTIVE_ALLOW_LOCAL" "false" "CLI allow-local did not override the environment"

unset AAGENT_PROVIDER AAGENT_AUTH_POLICY AAGENT_PRIORITY AAGENT_ALLOW_LOCAL
warning_file="$test_dir/unknown-warning"
write_config $'future_option=opaque-secret-value\nprovider=claude\n'
aagent_parse_arguments --dry-run "say hello"
aagent_resolve_configuration normal 2>"$warning_file"
warning="$(cat "$warning_file")"
assert_contains "$warning" "line 1" "unknown-key warning lacks its line"
assert_contains "$warning" "future_option" "unknown-key warning lacks its safe key"
[[ "$warning" != *"opaque-secret-value"* ]] || fail "unknown-key warning exposed its value"

set +e
aagent_resolve_configuration doctor 2>"$test_dir/doctor-error"
doctor_status=$?
set -e
assert_equals "$doctor_status" "$AAGENT_EXIT_CONFIG" "doctor unknown-key status differs"
assert_contains "$(cat "$test_dir/doctor-error")" "future_option" "doctor error lacks its safe key"
[[ "$(cat "$test_dir/doctor-error")" != *"opaque-secret-value"* ]] || fail "doctor error exposed its value"

rm -f "$config_path"
mkdir "$config_path"
set +e
bash "$aagent_script" --provider claude "say hello" </dev/null \
    >"$test_dir/directory.stdout" 2>"$test_dir/directory.stderr"
directory_status=$?
set -e
assert_equals "$directory_status" "$AAGENT_EXIT_CONFIG" "config-directory status differs"
rmdir "$config_path"

# Literal command-substitution syntax is an inert parser fixture.
# shellcheck disable=SC2016
invalid_cases=(
    'missing separator'
    '=claude'
    'provider='
    'provider=unknown-secret-provider'
    'auth_policy=automatic-secret-policy'
    'priority=claude,claude'
    'priority=claude,unknown-secret-provider'
    'priority=claude,'
    'allow_local=True'
    'provider="claude"'
    'provider=claude; touch config-marker'
    'provider=$(touch config-marker)'
    $'provider=claude\nprovider=codex'
)

for invalid in "${invalid_cases[@]}"; do
    write_config "$invalid"
    set +e
    bash "$aagent_script" --provider claude "say hello" </dev/null \
        >"$test_dir/invalid.stdout" 2>"$test_dir/invalid.stderr"
    status=$?
    set -e
    assert_equals "$status" "$AAGENT_EXIT_CONFIG" "invalid config status differs"
    assert_contains "$(cat "$test_dir/invalid.stderr")" "configuration" "invalid config error is unclear"
    [[ "$(cat "$test_dir/invalid.stderr")" != *"unknown-secret-provider"* ]] || \
        fail "invalid config error exposed a provider value"
    [[ "$(cat "$test_dir/invalid.stderr")" != *"automatic-secret-policy"* ]] || \
        fail "invalid config error exposed an auth-policy value"
done

# shellcheck disable=SC2016
write_config 'future_option=$(touch config-marker)'
set +e
bash "$aagent_script" doctor </dev/null >"$test_dir/injection.stdout" 2>"$test_dir/injection.stderr"
injection_status=$?
set -e
assert_equals "$injection_status" "$AAGENT_EXIT_CONFIG" "injection config status differs"
[[ ! -e "$work_dir/config-marker" && ! -e "$project_root/config-marker" ]] || \
    fail "configuration content executed a command"

long_value="$(printf 'x%.0s' {1..4097})"
write_config "provider=$long_value"
set +e
bash "$aagent_script" --provider claude "say hello" </dev/null \
    >"$test_dir/long.stdout" 2>"$test_dir/long.stderr"
long_status=$?
set -e
assert_equals "$long_status" "$AAGENT_EXIT_CONFIG" "long config status differs"
assert_contains "$(cat "$test_dir/long.stderr")" "4096" "long config error lacks the safe limit"
[[ "$(cat "$test_dir/long.stderr")" != *"$long_value"* ]] || fail "long config error exposed its value"

rm -f "$config_path"
export AAGENT_PRIORITY=claude,claude
set +e
bash "$aagent_script" --provider claude "say hello" </dev/null \
    >"$test_dir/env.stdout" 2>"$test_dir/env.stderr"
env_status=$?
set -e
assert_equals "$env_status" "$AAGENT_EXIT_CONFIG" "invalid environment status differs"
assert_contains "$(cat "$test_dir/env.stderr")" "AAGENT_PRIORITY" "environment error lacks its variable name"
[[ "$(cat "$test_dir/env.stderr")" != *"claude,claude"* ]] || fail "environment error exposed its value"
unset AAGENT_PRIORITY

set +e
bash "$aagent_script" --priority claude,claude --provider claude "say hello" </dev/null \
    >"$test_dir/cli.stdout" 2>"$test_dir/cli.stderr"
cli_status=$?
set -e
assert_equals "$cli_status" "$AAGENT_EXIT_USAGE" "invalid CLI priority status differs"
assert_contains "$(cat "$test_dir/cli.stderr")" "invalid --priority value" "CLI priority error differs"

export AAGENT_CLAUDE_BIN="$test_dir/missing-claude"
set +e
AAGENT_PROVIDER=claude bash "$aagent_script" "say hello" </dev/null \
    >"$test_dir/missing.stdout" 2>"$test_dir/missing.stderr"
missing_status=$?
set -e
assert_equals "$missing_status" "$AAGENT_EXIT_UNAVAILABLE" "missing explicit provider status differs"
assert_contains "$(cat "$test_dir/missing.stderr")" "selected via AAGENT_PROVIDER" \
    "missing explicit provider did not explain its source"
unset AAGENT_CLAUDE_BIN

write_config $'provider=claude\n'
export AAGENT_CLAUDE_BIN="$test_dir/missing-claude"
set +e
bash "$aagent_script" "say hello" </dev/null \
    >"$test_dir/missing-config.stdout" 2>"$test_dir/missing-config.stderr"
missing_config_status=$?
set -e
assert_equals "$missing_config_status" "$AAGENT_EXIT_UNAVAILABLE" "missing config provider status differs"
assert_contains "$(cat "$test_dir/missing-config.stderr")" "selected via user config" \
    "missing config provider did not explain its source"
unset AAGENT_CLAUDE_BIN

[[ ! -e "$record_dir/run.count" ]] || fail "a provider launched during configuration failures"
[[ ! -e "$test_dir/config-marker" && ! -e "$project_root/config-marker" ]] || \
    fail "a configuration injection marker exists"

project_config="$work_dir/aagent/config"
mkdir -p "$(dirname "$project_config")"
# shellcheck disable=SC2016
printf '%s\n' 'provider=$(touch project-marker)' >"$project_config"
rm -f "$config_path"
(
    cd "$work_dir"
    aagent_parse_arguments "say hello"
    aagent_resolve_configuration normal
    assert_equals "$AAGENT_EFFECTIVE_PROVIDER" "" "project-local config was loaded"
)
[[ ! -e "$work_dir/project-marker" ]] || fail "project-local configuration executed"

printf 'Configuration Bash tests passed.\n'
