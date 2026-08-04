#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
aagent_script="$project_root/aagent.sh"
fake_provider="$project_root/tests/helpers/fake-provider.sh"

# shellcheck disable=SC1090
source "$aagent_script"

fail() {
    printf 'FAIL: launch: %s\n' "$1" >&2
    exit 1
}

assert_equals() {
    local actual="$1"
    local expected="$2"
    local message="$3"
    [[ "$actual" == "$expected" ]] || fail "$message (expected '$expected', got '$actual')"
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

run_plan() {
    local stdout_file="$1"
    local stderr_file="$2"
    local dry_run="$3"
    local quiet="$4"
    local status=0
    aagent_execute_launch_plan "$dry_run" "$quiet" >"$stdout_file" 2>"$stderr_file" || status=$?
    printf '%s\n' "$status"
}

test_dir="$(mktemp -d)"
original_pwd="$PWD"
original_set_value="${AAGENT_TEST_CHILD_SET-}"
original_unset_value="${AAGENT_TEST_CHILD_UNSET-}"

cleanup() {
    if [[ -n "$original_set_value" ]]; then
        export AAGENT_TEST_CHILD_SET="$original_set_value"
    else
        unset AAGENT_TEST_CHILD_SET
    fi
    if [[ -n "$original_unset_value" ]]; then
        export AAGENT_TEST_CHILD_UNSET="$original_unset_value"
    else
        unset AAGENT_TEST_CHILD_UNSET
    fi
    rm -rf "$test_dir"
}
trap cleanup EXIT

record_dir="$test_dir/records"
work_dir="$test_dir/working directory 🌍"
mkdir -p "$record_dir" "$work_dir"

export AAGENT_FAKE_RECORD_DIR="$record_dir"
export AAGENT_FAKE_PROVIDER="generic"
export AAGENT_FAKE_INVOCATION_KIND="run"
export AAGENT_FAKE_ENV_PRESENCE="AAGENT_TEST_CHILD_SET,AAGENT_TEST_CHILD_UNSET"
export AAGENT_FAKE_ENV_CAPTURE="AAGENT_TEST_CHILD_SET"
export AAGENT_TEST_CHILD_SET="parent-value"
export AAGENT_TEST_CHILD_UNSET="parent-only"

hostile_arguments=(
    "fixed"
    "space value"
    "single'quote"
    'double"quote'
    '$(touch launch-should-not-exist)'
    '*?[abc]'
    'semi;pipe|redirect>file'
    $'line one\nline two'
    "Unicode 🌍"
    "-leading"
    ""
)
stdin_payload=$'context line\nsecond line\n\n'

aagent_create_launch_plan \
    "$fake_provider" \
    "$work_dir" \
    "data" \
    "$stdin_payload" \
    "both" \
    "${hostile_arguments[@]}"
AAGENT_LAUNCH_PROVIDER="generic"
AAGENT_LAUNCH_REASON="contract test"
AAGENT_LAUNCH_NOTICE="using generic fake provider"
display_arguments=("fixed" "<prompt>" "<prompt>" "<prompt>" "<prompt>" "<prompt>" "<prompt>" "<prompt>" "<prompt>" "<native>" "<native>")
aagent_launch_plan_set_display_arguments "${display_arguments[@]}"
aagent_launch_plan_set_environment "AAGENT_TEST_CHILD_SET" "child-secret-value"
aagent_launch_plan_unset_environment "AAGENT_TEST_CHILD_UNSET"

export AAGENT_FAKE_RUN_STDOUT="provider-stdout"
export AAGENT_FAKE_RUN_STDERR="provider-stderr"
export AAGENT_FAKE_RUN_STATUS="73"
status="$(run_plan "$test_dir/run.stdout" "$test_dir/run.stderr" 0 0)"
assert_equals "$status" "73" "provider-defined status was remapped"
assert_equals "$(cat "$test_dir/run.stdout")" "provider-stdout" "provider stdout differs"
assert_equals "$(cat "$test_dir/run.stderr")" $'aagent: using generic fake provider\nprovider-stderr' "wrapper/provider stderr differs"
assert_equals "$PWD" "$original_pwd" "launcher changed the caller working directory"
assert_equals "$AAGENT_TEST_CHILD_SET" "parent-value" "child environment set leaked into the wrapper"
assert_equals "$AAGENT_TEST_CHILD_UNSET" "parent-only" "child environment unset leaked into the wrapper"

record="$record_dir/generic.run.1.record"
[[ -f "$record" ]] || fail "generic provider record is missing"
assert_file_line "$record" "cwd.hex=$(hex_string "$work_dir")" "child working directory differs"
assert_file_line "$record" "argc=${#hostile_arguments[@]}" "hostile argv count differs"
argument_index=0
for argument in "${hostile_arguments[@]}"; do
    assert_file_line "$record" "arg.$argument_index.hex=$(hex_string "$argument")" "argument $argument_index differs"
    argument_index=$((argument_index + 1))
done
assert_file_line "$record" "stdin.hex=$(hex_string "$stdin_payload")" "stdin bytes differ"
assert_file_line "$record" "env.AAGENT_TEST_CHILD_SET=present" "child set variable is absent"
assert_file_line "$record" "env.AAGENT_TEST_CHILD_UNSET=absent" "child unset variable is present"
assert_file_line "$record" "env.AAGENT_TEST_CHILD_SET.hex=$(hex_string "child-secret-value")" "child set value differs"
[[ ! -e "$work_dir/launch-should-not-exist" ]] || fail "hostile argv was evaluated"

export AAGENT_FAKE_RUN_STDOUT="quiet-stdout"
export AAGENT_FAKE_RUN_STDERR="quiet-stderr"
export AAGENT_FAKE_RUN_STATUS="0"
status="$(run_plan "$test_dir/quiet.stdout" "$test_dir/quiet.stderr" 0 1)"
assert_equals "$status" "0" "quiet launch failed"
assert_equals "$(cat "$test_dir/quiet.stdout")" "quiet-stdout" "quiet changed provider stdout"
assert_equals "$(cat "$test_dir/quiet.stderr")" "quiet-stderr" "quiet suppressed provider stderr"

inherit_payload=$'inherited stdin\n'
aagent_create_launch_plan "$fake_provider" "$work_dir" "inherit" "" "stdin"
AAGENT_LAUNCH_PROVIDER="generic"
export AAGENT_FAKE_RUN_STDOUT=""
export AAGENT_FAKE_RUN_STDERR=""
export AAGENT_FAKE_RUN_STATUS="0"
inherit_status=0
printf '%s' "$inherit_payload" | \
    aagent_execute_launch_plan 0 1 >"$test_dir/inherit.stdout" 2>"$test_dir/inherit.stderr" || inherit_status=$?
assert_equals "$inherit_status" "0" "inherited-stdin launch failed"
assert_file_line "$record_dir/generic.run.3.record" "argc=0" "empty argv gained an argument"
assert_file_line "$record_dir/generic.run.3.record" "stdin.hex=$(hex_string "$inherit_payload")" "inherited stdin differs"

aagent_create_launch_plan \
    "$fake_provider" \
    "$work_dir" \
    "data" \
    "$stdin_payload" \
    "both" \
    "${hostile_arguments[@]}"
AAGENT_LAUNCH_PROVIDER="generic"
AAGENT_LAUNCH_REASON="contract test"
AAGENT_LAUNCH_NOTICE="using generic fake provider"
aagent_launch_plan_set_display_arguments "${display_arguments[@]}"
aagent_launch_plan_set_environment "AAGENT_TEST_CHILD_SET" "child-secret-value"
aagent_launch_plan_unset_environment "AAGENT_TEST_CHILD_UNSET"

status="$(run_plan "$test_dir/dry-run.stdout" "$test_dir/dry-run.stderr" 1 0)"
assert_equals "$status" "0" "dry-run failed"
dry_run_output="$(cat "$test_dir/dry-run.stdout")"
[[ "$dry_run_output" == *"provider: generic"* ]] || fail "dry-run provider is missing"
[[ "$dry_run_output" == *"stdin: both"* ]] || fail "dry-run stdin mode is missing"
[[ "$dry_run_output" == *"AAGENT_TEST_CHILD_SET"* ]] || fail "dry-run set environment name is missing"
[[ "$dry_run_output" == *"AAGENT_TEST_CHILD_UNSET"* ]] || fail "dry-run unset environment name is missing"
[[ "$dry_run_output" != *"child-secret-value"* ]] || fail "dry-run leaked an environment value"
[[ "$dry_run_output" != *"context line"* ]] || fail "dry-run leaked stdin"
[[ "$dry_run_output" != *"launch-should-not-exist"* ]] || fail "dry-run leaked a redacted argument"
assert_equals "$(cat "$test_dir/dry-run.stderr")" "" "dry-run wrote a notice to stderr"
assert_equals "$(tr -d '\r\n' < "$record_dir/run.count")" "3" "dry-run launched a provider"

export AAGENT_FAKE_RUN_STDOUT=""
export AAGENT_FAKE_RUN_STDERR=""
for expected_status in 0 23 64 78 95 127 255; do
    export AAGENT_FAKE_RUN_STATUS="$expected_status"
    actual_status="$(run_plan "$test_dir/status-$expected_status.stdout" "$test_dir/status-$expected_status.stderr" 0 1)"
    assert_equals "$actual_status" "$expected_status" "status $expected_status was remapped"
done
assert_equals "$(tr -d '\r\n' < "$record_dir/run.count")" "10" "one launch did not produce exactly one provider run"

export AAGENT_FAKE_RUN_DELAY="30"
export AAGENT_FAKE_RUN_STATUS="0"
aagent_create_launch_plan "$fake_provider" "$work_dir" "closed" "" "none" "signal-test"
AAGENT_LAUNCH_PROVIDER="generic"
AAGENT_LAUNCH_NOTICE="using generic fake provider"
(
    aagent_execute_launch_plan 0 1 >"$test_dir/signal.stdout" 2>"$test_dir/signal.stderr"
) &
launcher_pid=$!

signal_record="$record_dir/generic.run.11.record"
for _ in {1..200}; do
    [[ -f "$signal_record" ]] && break
    sleep 0.01
done
[[ -f "$signal_record" ]] || fail "signal provider did not start"
provider_pid="$(sed -n 's/^pid=//p' "$signal_record")"
[[ -n "$provider_pid" ]] || fail "signal provider PID is missing"

kill -TERM "$launcher_pid"
set +e
wait "$launcher_pid"
signal_status=$?
set -e
assert_equals "$signal_status" "143" "termination status differs"
for _ in {1..100}; do
    if ! kill -0 "$provider_pid" 2>/dev/null; then
        break
    fi
    sleep 0.01
done
if kill -0 "$provider_pid" 2>/dev/null; then
    fail "terminated provider remained orphaned"
fi
assert_equals "$(tr -d '\r\n' < "$record_dir/run.count")" "11" "termination started a fallback provider"

printf 'Launch Bash tests passed.\n'
