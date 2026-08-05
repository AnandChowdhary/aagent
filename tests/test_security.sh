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

hex_string() {
    printf '%s' "$1" | od -An -v -tx1 | tr -d ' \n'
}

# Production runners must never turn strings into shell programs.
if grep -En '^[[:space:]]*(eval|source|\.)[[:space:]]' "$aagent_script" >/dev/null; then
    fail "Bash runner contains a command-string evaluation primitive"
fi
if grep -En '(^|[;&|[:space:]])sh[[:space:]]+-c([;&|[:space:]]|$)' "$aagent_script" >/dev/null; then
    fail "Bash runner invokes sh -c"
fi
if grep -En 'Invoke-Expression|\[ScriptBlock\]::Create|ScriptBlock.*Create' \
    "$project_root/aagent.ps1" >/dev/null; then
    fail "PowerShell runner contains a command-string evaluation primitive"
fi

# shellcheck disable=SC1090
source "$aagent_script"
for flag in \
    --yolo --dangerously-skip-permissions --skip-permissions-unsafe \
    --allow-all-tools --allow-all-paths --allow-all-urls --allow-all \
    --auto --force --trust --approve-mcps --sandbox --sandbox=read-only \
    --permission-mode=bypassPermissions \
    --approval-mode=yolo --sandbox=danger-full-access; do
    aagent_is_unsafe_permission_flag "$flag" || fail "permission denylist omitted $flag"
done
# shellcheck disable=SC2034 # Read by the sourced safety-audit function.
AAGENT_ADAPTER_ARGUMENTS=(--yolo)
# shellcheck disable=SC2034 # Read by the sourced safety-audit function.
AAGENT_ADAPTER_DISPLAY_ARGUMENTS=(--yolo)
set +e
aagent_audit_generated_adapter_arguments >/dev/null 2>&1
audit_status=$?
set -e
assert_equals "$audit_status" 70 "generated permission injection should be a software error"
escaped_diagnostic="$(aagent_quote_for_display $'path\nforged: success')"
[[ "$escaped_diagnostic" != *$'\n'* ]] || fail "display quoting preserved a raw line break"
assert_contains "$escaped_diagnostic" '\n' "display quoting did not escape a line break"

test_dir="$(mktemp -d)"
original_path="$PATH"
trap 'export PATH="$original_path"; rm -rf "$test_dir"' EXIT
home_dir="$test_dir/home"
fake_bin="$test_dir/bin with spaces"
record_dir="$test_dir/records"
work_dir="$test_dir/work dir"
missing_dir="$test_dir/missing"
marker_dir="$test_dir/markers"
goose_root="$test_dir/goose-root"
goose_config_dir="$goose_root/config"
mkdir -p "$home_dir/.claude" "$home_dir/.codex" "$home_dir/.factory" \
    "$goose_config_dir/custom_providers" "$fake_bin" "$record_dir" "$work_dir" "$marker_dir"
cp "$fake_provider" "$fake_bin/codex"
cp "$fake_provider" "$fake_bin/copilot"
cp "$fake_provider" "$fake_bin/agent"
cp "$fake_provider" "$fake_bin/goose"
cp "$fake_provider" "$fake_bin/droid"
chmod +x "$fake_bin/codex" "$fake_bin/copilot" "$fake_bin/agent" "$fake_bin/goose" "$fake_bin/droid"

# Credential locations are traps. A direct read would block on the FIFO; helper
# lookups leave a marker. The provider status fixture is the only allowed source.
mkfifo "$home_dir/.claude/.credentials.json"
mkfifo "$home_dir/.codex/auth.json"
for helper in security sqlite3 keyring; do
    printf '#!/usr/bin/env bash\ntouch "%s/%s"\nexit 99\n' "$marker_dir" "$helper" >"$fake_bin/$helper"
    chmod +x "$fake_bin/$helper"
done

export HOME="$home_dir"
export XDG_CONFIG_HOME="$home_dir/.config"
export PATH="$fake_bin:/usr/bin:/bin"
export AAGENT_FAKE_RECORD_DIR="$record_dir"
export AAGENT_CODEX_BIN="$fake_bin/codex"
export AAGENT_CLAUDE_BIN="$missing_dir/claude"
export AAGENT_OPENCODE_BIN="$missing_dir/opencode"
export AAGENT_COPILOT_BIN="$fake_bin/copilot"
export AAGENT_GEMINI_BIN="$missing_dir/gemini"
export AAGENT_AMP_BIN="$missing_dir/amp"
export AAGENT_CURSOR_BIN="$fake_bin/agent"
export AAGENT_GOOSE_BIN="$fake_bin/goose"
export AAGENT_DROID_BIN="$fake_bin/droid"
export AAGENT_FAKE_CODEX_APP_SERVER_STDOUT='{"id":1,"result":{"account":{"type":"chatgpt","planType":"pro","email":"person@example.com","organization":"Secret Org"},"requiresOpenaiAuth":true}}'
export AAGENT_FAKE_VERSION_STDOUT='2026.07.23-e383d2b'
export AAGENT_FAKE_HELP_STDOUT='Usage: agent Start the Cursor Agent --print status'
export AAGENT_FAKE_CURSOR_STATUS_STDOUT='{"isAuthenticated":true,"hasAccessToken":true,"hasRefreshToken":true,"status":"seeded-secret-token","message":"Cursor Secret Org","userInfo":{"email":"cursor@example.com","token":"cursor-secret-token"}}'
export FACTORY_API_KEY='seeded-secret-token'
printf '%s' '{"model":"custom:remote-0","customModels":[{"baseUrl":"https://models.example.test/v1","apiKey":"factory-secret-token","email":"factory@example.com","organization":"Factory Secret Org"}]}' >"$home_dir/.factory/settings.json"
export GOOSE_PATH_ROOT="$goose_root"
printf '%s\n' 'active_provider: custom_security' >"$goose_config_dir/config.yaml"
printf '%s' '{"name":"custom_security","base_url":"https://models.example.test/v1","api_key_env":"TEST_GOOSE_API_KEY","requires_auth":true,"api_key":"goose-secret-token","email":"goose@example.com","organization":"Goose Secret Org"}' >"$goose_config_dir/custom_providers/custom_security.json"
export TEST_GOOSE_API_KEY='seeded-secret-token'
export AAGENT_FAKE_CODEX_APP_SERVER_STATUS=0
export AAGENT_FAKE_RUN_STATUS=0
unset AAGENT_PROVIDER AAGENT_AUTH_POLICY AAGENT_PRIORITY AAGENT_ALLOW_LOCAL
unset CODEX_API_KEY OPENAI_API_KEY
export COPILOT_PROVIDER_BASE_URL='https://seeded-secret-token@example.test/v1'
export COPILOT_PROVIDER_HEADERS='Authorization=seeded-secret-token'
unset AAGENT_FAKE_INVOCATION_KIND AAGENT_FAKE_PROBE_STDOUT AAGENT_FAKE_PROBE_STDERR
unset AAGENT_FAKE_PROBE_STATUS AAGENT_FAKE_PROBE_DELAY AAGENT_FAKE_PROBE_BYTES

run_wrapper() {
    local prefix="$1"
    shift
    set +e
    bash "$aagent_script" "$@" </dev/null >"$prefix.stdout" 2>"$prefix.stderr"
    AAGENT_TEST_STATUS=$?
    set -e
}

run_wrapper "$test_dir/credential-audit" providers
assert_equals "$AAGENT_TEST_STATUS" 0 "credential audit providers command failed"
[[ -z "$(find "$marker_dir" -type f -print -quit)" ]] || fail "a credential helper was invoked"
assert_not_contains "$(<"$test_dir/credential-audit.stdout")" "person@example.com" "providers leaked an email"
assert_not_contains "$(<"$test_dir/credential-audit.stdout")" "Secret Org" "providers leaked an organization"
assert_not_contains "$(<"$test_dir/credential-audit.stdout")" "seeded-secret-token" "providers leaked Copilot configuration"
assert_not_contains "$(<"$test_dir/credential-audit.stdout")" "cursor@example.com" "providers leaked Cursor email"
assert_not_contains "$(<"$test_dir/credential-audit.stdout")" "Cursor Secret Org" "providers leaked Cursor team"
assert_not_contains "$(<"$test_dir/credential-audit.stdout")" "cursor-secret-token" "providers leaked Cursor status"
assert_not_contains "$(<"$test_dir/credential-audit.stdout")" "factory-secret-token" "providers leaked Droid API key"
assert_not_contains "$(<"$test_dir/credential-audit.stdout")" "factory@example.com" "providers leaked Droid email"
assert_not_contains "$(<"$test_dir/credential-audit.stdout")" "Factory Secret Org" "providers leaked Droid organization"
assert_not_contains "$(<"$test_dir/credential-audit.stdout")" "goose-secret-token" "providers leaked Goose API key"
assert_not_contains "$(<"$test_dir/credential-audit.stdout")" "goose@example.com" "providers leaked Goose email"
assert_not_contains "$(<"$test_dir/credential-audit.stdout")" "Goose Secret Org" "providers leaked Goose organization"
[[ ! -e "$record_dir/run.count" ]] || fail "credential audit launched a model"

rm -rf "$record_dir"
mkdir -p "$record_dir"
hostile_prompt=$'explain $(touch prompt-should-not-exist)\nnext'
# shellcheck disable=SC2016 # Literal metacharacters are the test input.
hostile_model='model;$(touch model-should-not-exist)'
hostile_native=$'--yolo\nnot-a-second-argument'
run_wrapper "$test_dir/native-permission" \
    --provider codex --cwd "$work_dir" --model "$hostile_model" "$hostile_prompt" -- "$hostile_native"
assert_equals "$AAGENT_TEST_STATUS" 0 "native permission forwarding failed"
record="$(find "$record_dir" -name 'codex.run.*.record' -print -quit)"
[[ -n "$record" ]] || fail "native permission test did not launch Codex"
grep -Fqx "arg.3.hex=$(hex_string "$hostile_native")" "$record" || fail "native permission argument changed"
assert_equals "$(grep -Fc "$(hex_string "$hostile_native")" "$record")" 1 \
    "user-supplied permission flag was duplicated"
[[ ! -e "$work_dir/prompt-should-not-exist" ]] || fail "prompt was evaluated"
[[ ! -e "$work_dir/model-should-not-exist" ]] || fail "model was evaluated"
assert_equals "$(<"$record_dir/run.count")" 1 "native permission test launched more than one provider"

rm -rf "$record_dir"
mkdir -p "$record_dir"
run_wrapper "$test_dir/safe-dry-run" --provider codex --dry-run 'say hello'
assert_equals "$AAGENT_TEST_STATUS" 0 "safe dry-run failed"
safe_plan="$(<"$test_dir/safe-dry-run.stdout")"
for flag in --yolo --dangerously-skip-permissions --allow-all-tools \
    --allow-all-paths --allow-all-urls --allow-all --auto --force --trust \
    --approve-mcps --sandbox; do
    assert_not_contains "$safe_plan" "$flag" "wrapper injected $flag"
done
[[ ! -e "$record_dir/run.count" ]] || fail "safe dry-run launched a model"

run_wrapper "$test_dir/droid-safe-dry-run" --provider droid --dry-run 'say hello'
assert_equals "$AAGENT_TEST_STATUS" 0 "Droid safe dry-run failed"
droid_safe_plan="$(<"$test_dir/droid-safe-dry-run.stdout")"
for flag in --auto --skip-permissions-unsafe --use-spec; do
    assert_not_contains "$droid_safe_plan" "$flag" "Droid wrapper injected $flag"
done
assert_contains "$droid_safe_plan" "exec" "Droid dry-run omitted exec"
[[ ! -e "$record_dir/run.count" ]] || fail "Droid safe dry-run launched a model"

run_wrapper "$test_dir/goose-safe-dry-run" --provider goose --dry-run 'say hello'
assert_equals "$AAGENT_TEST_STATUS" 0 "Goose safe dry-run failed"
goose_safe_plan="$(<"$test_dir/goose-safe-dry-run.stdout")"
for flag in --auto --yolo --with-builtin --no-profile; do
    assert_not_contains "$goose_safe_plan" "$flag" "Goose wrapper injected $flag"
done
assert_contains "$goose_safe_plan" "run" "Goose dry-run omitted run"
assert_contains "$goose_safe_plan" "--text" "Goose dry-run omitted text mode"
[[ ! -e "$record_dir/run.count" ]] || fail "Goose safe dry-run launched a model"

hostile_provider=$'not-a-provider\nforged: success'
run_wrapper "$test_dir/hostile-provider" doctor "$hostile_provider"
assert_equals "$AAGENT_TEST_STATUS" 64 "hostile provider ID should be a usage error"
assert_contains "$(<"$test_dir/hostile-provider.stderr")" 'not-a-provider\nforged: success' \
    "usage diagnostics did not escape a line break"
assert_equals "$(wc -l < "$test_dir/hostile-provider.stderr" | tr -d ' ')" 2 \
    "hostile provider ID injected a diagnostic line"

# Wrapper-owned errors use sysexits-style statuses and an aagent prefix.
run_wrapper "$test_dir/usage" --unknown
assert_equals "$AAGENT_TEST_STATUS" 64 "usage status differs"
assert_contains "$(<"$test_dir/usage.stderr")" "aagent:" "usage error prefix differs"
run_wrapper "$test_dir/unavailable" --provider claude 'say hello'
assert_equals "$AAGENT_TEST_STATUS" 69 "unavailable status differs"
assert_contains "$(<"$test_dir/unavailable.stderr")" "aagent:" "unavailable error prefix differs"
export AAGENT_AUTH_POLICY=invalid
run_wrapper "$test_dir/config" providers
assert_equals "$AAGENT_TEST_STATUS" 78 "configuration status differs"
assert_contains "$(<"$test_dir/config.stderr")" "aagent:" "configuration error prefix differs"
unset AAGENT_AUTH_POLICY

# A provider disappearing after its status probe is a wrapper-owned launch-plan
# failure, not a provider status.
vanishing="$fake_bin/vanishing-codex"
# shellcheck disable=SC2016 # These variables belong to the generated fixture.
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'if [[ "${1-}" == "app-server" ]]; then' \
    '    rm -f -- "$0"' \
    '    printf '\''%s'\'' '\''{"id":1,"result":{"account":{"type":"chatgpt","planType":"pro"},"requiresOpenaiAuth":true}}'\''' \
    'fi' >"$vanishing"
chmod +x "$vanishing"
export AAGENT_CODEX_BIN="$vanishing"
run_wrapper "$test_dir/software" --provider codex 'say hello'
assert_equals "$AAGENT_TEST_STATUS" 70 "software status differs"
assert_contains "$(<"$test_dir/software.stderr")" "aagent:" "software error prefix differs"

printf 'Security Bash tests passed.\n'
