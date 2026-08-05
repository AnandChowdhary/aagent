#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
aagent_script="$project_root/aagent.sh"
powershell_script="$project_root/aagent.ps1"
fake_provider="$project_root/tests/helpers/fake-provider.sh"

# shellcheck disable=SC1090
source "$aagent_script"

fail() {
    printf 'FAIL: probes: %s\n' "$1" >&2
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

hex_string() {
    printf '%s' "$1" | od -An -v -tx1 | tr -d ' \n'
}

assert_probe() {
    local provider="$1"
    local readiness="$2"
    local funding="$3"
    local confidence="$4"
    local label="$5"
    local reason="$6"
    local source="$7"
    local status="$8"
    local schema

    assert_equals "$AAGENT_PROBE_PROVIDER" "$provider" "$provider schema provider differs"
    assert_equals "$AAGENT_PROBE_READINESS" "$readiness" "$provider readiness differs"
    assert_equals "$AAGENT_PROBE_FUNDING_CLASS" "$funding" "$provider funding differs"
    assert_equals "$AAGENT_PROBE_CONFIDENCE_RANK" "$confidence" "$provider confidence differs"
    assert_equals "$AAGENT_PROBE_PLAN_LABEL" "$label" "$provider plan label differs"
    assert_equals "$AAGENT_PROBE_REASON_CODE" "$reason" "$provider reason differs"
    assert_equals "$AAGENT_PROBE_SOURCE" "$source" "$provider source differs"
    assert_equals "$AAGENT_PROBE_STATUS" "$status" "$provider probe status differs"
    assert_equals "$AAGENT_PROBE_CAPTURE" "" "$provider retained raw probe output"

    [[ "$readiness" =~ ^(ready|unknown|unusable)$ ]] || fail "$provider readiness escaped the schema"
    [[ "$funding" =~ ^(included_confirmed|included_account|prepaid_credits|local|payg_byok|unknown)$ ]] || \
        fail "$provider funding escaped the schema"
    [[ "$confidence" =~ ^[0-4]$ ]] || fail "$provider confidence escaped the schema"
    [[ "$AAGENT_PROBE_SHADOWING_VARIABLES" =~ ^$|^[A-Z][A-Z0-9_]*(,[A-Z][A-Z0-9_]*)*$ ]] || \
        fail "$provider shadowing variables escaped the schema"
    schema="$provider|$readiness|$funding|$confidence|$label|$reason|$source|$status|$AAGENT_PROBE_SHADOWING_VARIABLES"
    [[ "$schema" != *"seeded-secret-token"* ]] || fail "$provider schema leaked a token"
    [[ "$schema" != *"person@example.com"* ]] || fail "$provider schema leaked an email"
    [[ "$schema" != *"Secret Organization"* ]] || fail "$provider schema leaked an organization"
}

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
export HOME="$test_dir/home"
export XDG_CONFIG_HOME="$test_dir/config"
fake_bin="$test_dir/bin"
record_dir="$test_dir/records"
trap_bin="$test_dir/trap-bin"
marker="$test_dir/credential-store-accessed"
mkdir -p "$HOME/.claude" "$HOME/.codex" "$HOME/.gemini" "$fake_bin" "$record_dir" "$trap_bin"
for provider in claude codex opencode; do
    cp "$fake_provider" "$fake_bin/$provider"
    chmod +x "$fake_bin/$provider"
done
export PATH="$trap_bin:$fake_bin:$PATH"
export AAGENT_FAKE_RECORD_DIR="$record_dir"

for command_name in security secret-tool cmdkey api-key-helper; do
    printf '#!/usr/bin/env bash\nprintf "called" >%q\n' "$marker" >"$trap_bin/$command_name"
    chmod +x "$trap_bin/$command_name"
done
# These files contain executable-looking traps and secrets. Production must not
# name or open them; only Gemini's documented settings.json is allowed.
# shellcheck disable=SC2016
printf '%s\n' '$(api-key-helper)' 'seeded-secret-token' >"$HOME/.claude/.credentials.json"
printf '%s\n' 'seeded-secret-token' >"$HOME/.codex/auth.json"
printf '%s\n' 'seeded-secret-token' >"$HOME/.gemini/oauth_creds.json"
printf '%s\n' '{"apiKeyHelper":"api-key-helper"}' >"$HOME/.claude/settings.json"

clear_probe_case() {
    unset \
        AAGENT_FAKE_PROBE_STDOUT AAGENT_FAKE_PROBE_STDERR AAGENT_FAKE_PROBE_STATUS \
        AAGENT_FAKE_PROBE_DELAY AAGENT_FAKE_PROBE_BYTES \
        AAGENT_FAKE_CLAUDE_STDOUT AAGENT_FAKE_CLAUDE_STDERR AAGENT_FAKE_CLAUDE_STATUS \
        AAGENT_FAKE_CLAUDE_DELAY AAGENT_FAKE_CLAUDE_BYTES \
        AAGENT_FAKE_CODEX_APP_SERVER_STDOUT AAGENT_FAKE_CODEX_APP_SERVER_STDERR \
        AAGENT_FAKE_CODEX_APP_SERVER_STATUS AAGENT_FAKE_CODEX_APP_SERVER_DELAY \
        AAGENT_FAKE_CODEX_APP_SERVER_BYTES \
        AAGENT_FAKE_CODEX_LOGIN_STDOUT AAGENT_FAKE_CODEX_LOGIN_STDERR \
        AAGENT_FAKE_CODEX_LOGIN_STATUS AAGENT_FAKE_CODEX_LOGIN_DELAY \
        AAGENT_FAKE_CODEX_LOGIN_BYTES \
        AAGENT_FAKE_OPENCODE_STDOUT AAGENT_FAKE_OPENCODE_STDERR \
        AAGENT_FAKE_OPENCODE_STATUS AAGENT_FAKE_OPENCODE_DELAY AAGENT_FAKE_OPENCODE_BYTES \
        CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_MANTLE CLAUDE_CODE_USE_VERTEX \
        CLAUDE_CODE_USE_FOUNDRY CLAUDE_CODE_USE_ANTHROPIC_AWS \
        ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_BASE_URL \
        ANTHROPIC_BEDROCK_BASE_URL ANTHROPIC_BEDROCK_MANTLE_BASE_URL \
        ANTHROPIC_AWS_BASE_URL ANTHROPIC_VERTEX_BASE_URL ANTHROPIC_FOUNDRY_BASE_URL \
        ANTHROPIC_FOUNDRY_RESOURCE ANTHROPIC_FOUNDRY_API_KEY AWS_BEARER_TOKEN_BEDROCK \
        ANTHROPIC_CUSTOM_HEADERS CLAUDE_CODE_OAUTH_TOKEN \
        CODEX_API_KEY OPENAI_API_KEY GEMINI_API_KEY GOOGLE_API_KEY \
        GOOGLE_APPLICATION_CREDENTIALS GOOGLE_GENAI_USE_VERTEXAI GOOGLE_GENAI_USE_GCA \
        GOOGLE_GEMINI_BASE_URL CLOUD_SHELL GEMINI_CLI_USE_COMPUTE_ADC AMP_API_KEY \
        COPILOT_PROVIDER_BASE_URL COPILOT_PROVIDER_TYPE COPILOT_PROVIDER_API_KEY \
        COPILOT_PROVIDER_BEARER_TOKEN COPILOT_PROVIDER_HEADERS COPILOT_MODEL \
        COPILOT_PROVIDER_MODEL_ID COPILOT_PROVIDER_WIRE_MODEL \
        COPILOT_GITHUB_TOKEN GH_TOKEN GITHUB_TOKEN
}

clear_probe_case
export AAGENT_FAKE_CLAUDE_STDOUT='{"loggedIn":true,"authMethod":"claude.ai","subscriptionType":"max","apiProvider":"claude.ai","token":"seeded-secret-token","email":"person@example.com","organization":"Secret Organization","nested":{"huge":"ignored"}}'
aagent_probe_provider claude "$fake_bin/claude"
assert_probe claude ready included_confirmed 3 "Claude Max" claude_subscription_status auth_status success

clear_probe_case
export ANTHROPIC_API_KEY='seeded-secret-token'
export AAGENT_FAKE_CLAUDE_STDOUT='{"loggedIn":true,"authMethod":"claude.ai","subscriptionType":"pro","apiProvider":"claude.ai"}'
aagent_probe_provider claude "$fake_bin/claude"
assert_probe claude ready included_confirmed 3 "Claude Pro" claude_subscription_status auth_status success
assert_equals "$AAGENT_PROBE_SHADOWING_VARIABLES" "ANTHROPIC_API_KEY" "Claude API shadow differs"

clear_probe_case
export AAGENT_FAKE_CLAUDE_STDOUT='{"loggedIn":true,"authMethod":"api_key","apiProvider":"console","apiKeySource":"environment"}'
aagent_probe_provider claude "$fake_bin/claude"
assert_probe claude ready payg_byok 3 "Anthropic API" claude_api_status auth_status success

clear_probe_case
export AAGENT_FAKE_CLAUDE_STDOUT='{"loggedIn":true,"authMethod":"bedrock","apiProvider":"aws-bedrock"}'
aagent_probe_provider claude "$fake_bin/claude"
assert_probe claude ready unknown 3 "Organization route" claude_cloud_status auth_status success

clear_probe_case
export AAGENT_FAKE_CLAUDE_STDOUT='{"loggedIn":false}'
aagent_probe_provider claude "$fake_bin/claude"
assert_probe claude unusable unknown 3 "Not signed in" claude_not_logged_in auth_status success

clear_probe_case
export AAGENT_FAKE_CLAUDE_STDOUT='not-json seeded-secret-token person@example.com'
aagent_probe_provider claude "$fake_bin/claude"
assert_probe claude unknown unknown 0 "Unknown" claude_schema_failure auth_status schema_failure

clear_probe_case
export ANTHROPIC_API_KEY='seeded-secret-token'
export AAGENT_FAKE_CLAUDE_STATUS=23
export AAGENT_FAKE_CLAUDE_STDERR='seeded-secret-token person@example.com Secret Organization'
aagent_probe_provider claude "$fake_bin/claude"
assert_probe claude ready payg_byok 1 "Anthropic API" claude_api_environment environment nonzero

clear_probe_case
export AAGENT_FAKE_CLAUDE_DELAY=4
aagent_probe_provider claude "$fake_bin/claude"
assert_probe claude unknown unknown 0 "Unknown" claude_probe_failed auth_status timeout

clear_probe_case
export AAGENT_FAKE_CLAUDE_BYTES=70000
aagent_probe_provider claude "$fake_bin/claude"
assert_probe claude unknown unknown 0 "Unknown" claude_probe_failed auth_status truncated

clear_probe_case
export CODEX_API_KEY='seeded-secret-token'
export AAGENT_FAKE_CODEX_APP_SERVER_STDOUT=$'{"id":0,"result":{"serverInfo":"ignored"}}\n{"id":1,"result":{"account":{"type":"chatgpt","planType":"pro","email":"person@example.com","organization":"Secret Organization","token":"seeded-secret-token"},"requiresOpenaiAuth":true}}'
export AAGENT_FAKE_CODEX_LOGIN_STDERR='should-not-run'
aagent_probe_provider codex "$fake_bin/codex"
assert_probe codex ready included_confirmed 4 "ChatGPT Pro" codex_chatgpt_account app_server success
assert_equals "$AAGENT_PROBE_SHADOWING_VARIABLES" "CODEX_API_KEY" "Codex API shadow differs"

clear_probe_case
export AAGENT_FAKE_CODEX_APP_SERVER_STDOUT='{"id":1,"result":{"account":{"type":"apiKey"},"requiresOpenaiAuth":true}}'
aagent_probe_provider codex "$fake_bin/codex"
assert_probe codex ready payg_byok 4 "OpenAI API" codex_api_account app_server success

clear_probe_case
export AAGENT_FAKE_CODEX_APP_SERVER_STDOUT='{"id":1,"result":{"account":null,"requiresOpenaiAuth":true}}'
aagent_probe_provider codex "$fake_bin/codex"
assert_probe codex unusable unknown 4 "Not signed in" codex_not_logged_in app_server success

clear_probe_case
export AAGENT_FAKE_CODEX_APP_SERVER_STDOUT='{"id":1,"result":{"account":null,"requiresOpenaiAuth":false}}'
aagent_probe_provider codex "$fake_bin/codex"
assert_probe codex ready unknown 4 "Custom provider" codex_custom_provider app_server success

clear_probe_case
export AAGENT_FAKE_CODEX_APP_SERVER_STATUS=2
export AAGENT_FAKE_CODEX_LOGIN_STDERR='Logged in using ChatGPT'
aagent_probe_provider codex "$fake_bin/codex"
assert_probe codex ready unknown 2 "ChatGPT account" codex_login_text_chatgpt login_status fallback_success

clear_probe_case
export AAGENT_FAKE_CODEX_APP_SERVER_STDOUT='protocol mismatch seeded-secret-token'
export AAGENT_FAKE_CODEX_LOGIN_STDERR='Logged in using an API key - seeded-secret-token person@example.com'
aagent_probe_provider codex "$fake_bin/codex"
assert_probe codex ready payg_byok 2 "OpenAI API" codex_login_text_api login_status fallback_success

clear_probe_case
export AAGENT_FAKE_CODEX_APP_SERVER_STATUS=2
export AAGENT_FAKE_CODEX_LOGIN_STATUS=2
export AAGENT_FAKE_CODEX_LOGIN_STDERR='seeded-secret-token person@example.com'
export CODEX_API_KEY='seeded-secret-token'
aagent_probe_provider codex "$fake_bin/codex"
assert_probe codex ready payg_byok 1 "OpenAI API" codex_api_environment environment nonzero

clear_probe_case
export AAGENT_FAKE_CODEX_APP_SERVER_STATUS=2
export AAGENT_FAKE_CODEX_LOGIN_STDERR='Not logged in'
aagent_probe_provider codex "$fake_bin/codex"
assert_probe codex unusable unknown 2 "Not signed in" codex_not_logged_in login_status fallback_success

codex_input=$'{"method":"initialize","id":0,"params":{"clientInfo":{"name":"aagent","title":"aagent","version":"0.1.1"}}}\n{"method":"initialized","params":{}}\n{"method":"account/read","id":1,"params":{"refreshToken":false}}\n'
codex_input_hex="$(hex_string "$codex_input")"
grep -Fq "stdin.hex=$codex_input_hex" "$record_dir"/codex.probe.*.record || \
    fail "Codex app-server handshake or refreshToken:false request differs"

clear_probe_case
export AAGENT_FAKE_OPENCODE_STDOUT='anthropic oauth person@example.com seeded-secret-token Secret Organization'
aagent_probe_provider opencode "$fake_bin/opencode"
assert_probe opencode ready unknown 2 "OpenCode credential" opencode_auth_list auth_list success
[[ "$AAGENT_PROBE_FUNDING_CLASS" != included_* ]] || fail "OpenCode OAuth alone became included funding"

clear_probe_case
export AAGENT_FAKE_OPENCODE_STDOUT='No credentials found'
aagent_probe_provider opencode "$fake_bin/opencode"
assert_probe opencode unknown unknown 2 "No confirmed credential" opencode_no_auth auth_list success

clear_probe_case
export OPENAI_API_KEY='seeded-secret-token'
export AAGENT_FAKE_OPENCODE_STATUS=9
aagent_probe_provider opencode "$fake_bin/opencode"
assert_probe opencode ready unknown 1 "Provider credential" opencode_environment_auth environment nonzero

clear_probe_case
copilot_probe_count_before="$(<"$record_dir/probe.count")"
export COPILOT_PROVIDER_BASE_URL='https://models.example.test/v1'
export COPILOT_PROVIDER_API_KEY='seeded-secret-token'
export COPILOT_PROVIDER_HEADERS='Authorization=seeded-secret-token'
export COPILOT_GITHUB_TOKEN='seeded-secret-token'
aagent_probe_provider copilot ""
assert_probe copilot ready payg_byok 1 "Copilot BYOK" copilot_byok_credential_environment environment environment_only
assert_equals "$AAGENT_PROBE_SHADOWING_VARIABLES" \
    "COPILOT_PROVIDER_BASE_URL,COPILOT_PROVIDER_API_KEY,COPILOT_PROVIDER_HEADERS" \
    "Copilot BYOK variable evidence differs"

clear_probe_case
export COPILOT_PROVIDER_BASE_URL='http://127.0.0.42:11434/v1'
aagent_probe_provider copilot ""
assert_probe copilot ready local 1 "Local provider" copilot_local_byok_environment environment environment_only

clear_probe_case
export COPILOT_PROVIDER_BASE_URL='https://models.example.test/v1'
aagent_probe_provider copilot ""
assert_probe copilot unknown unknown 1 "Remote BYOK" copilot_remote_byok_unknown environment environment_only

clear_probe_case
export COPILOT_PROVIDER_BASE_URL='https://seeded-secret-token@example.test/v1'
export COPILOT_PROVIDER_HEADERS='Authorization=seeded-secret-token'
aagent_probe_provider copilot ""
assert_probe copilot unknown unknown 0 "Unknown" copilot_byok_endpoint_invalid environment invalid_configuration

clear_probe_case
export GH_TOKEN='seeded-secret-token'
aagent_probe_provider copilot ""
assert_probe copilot ready included_account 1 "GitHub account" copilot_github_token_environment environment environment_only
assert_equals "$AAGENT_PROBE_SHADOWING_VARIABLES" "GH_TOKEN" "Copilot GitHub token evidence differs"

clear_probe_case
aagent_probe_provider copilot ""
assert_probe copilot unknown unknown 0 "Unknown" copilot_no_passive_entitlement none skipped_no_passive
assert_equals "$(<"$record_dir/probe.count")" "$copilot_probe_count_before" "Copilot launched a provider probe"

clear_probe_case
probe_count_before="$(<"$record_dir/probe.count")"
printf '%s' '{"security":{"auth":{"selectedType":"oauth-personal"}},"token":"seeded-secret-token","email":"person@example.com","organization":"Secret Organization"}' >"$HOME/.gemini/settings.json"
aagent_probe_provider gemini ""
assert_probe gemini ready included_account 4 "Google account" gemini_oauth_personal user_settings success

printf '%s' '{"security":{"auth":{"selectedType":"gemini-api-key"}}}' >"$HOME/.gemini/settings.json"
aagent_probe_provider gemini ""
assert_probe gemini ready payg_byok 4 "Gemini API" gemini_api_key user_settings success

printf '%s' '{"security":{"auth":{"selectedType":"vertex-ai"}}}' >"$HOME/.gemini/settings.json"
aagent_probe_provider gemini ""
assert_probe gemini ready unknown 4 "Google organization route" gemini_organization_auth user_settings success

printf '%s' 'malformed seeded-secret-token person@example.com' >"$HOME/.gemini/settings.json"
export GEMINI_API_KEY='seeded-secret-token'
aagent_probe_provider gemini ""
assert_probe gemini ready payg_byok 1 "Gemini API" gemini_api_environment environment schema_failure
unset GEMINI_API_KEY

head -c 70000 /dev/zero | tr '\0' x >"$HOME/.gemini/settings.json"
aagent_probe_provider gemini ""
assert_probe gemini unknown unknown 0 "Unknown" gemini_settings_unavailable user_settings truncated
assert_equals "$(<"$record_dir/probe.count")" "$probe_count_before" "Gemini launched a provider probe"

clear_probe_case
aagent_probe_provider amp ""
assert_probe amp unknown unknown 0 "Unknown" amp_no_passive_probe none skipped_no_passive
export AMP_API_KEY='seeded-secret-token'
aagent_probe_provider amp ""
assert_probe amp ready unknown 1 "Amp account credential" amp_environment_auth environment environment_only
assert_equals "$(<"$record_dir/probe.count")" "$probe_count_before" "Amp launched a network-capable probe"

[[ ! -e "$record_dir/run.count" ]] || fail "authentication probes made a model request"
[[ ! -e "$marker" ]] || fail "authentication probes invoked a credential helper or store command"
if grep -Eq 'auth\.json|oauth_creds|\.credentials\.json|apiKeyHelper' "$aagent_script" "$powershell_script"; then
    fail "production source names a credential token file or helper"
fi
if grep -R -F -e seeded-secret-token -e person@example.com -e 'Secret Organization' "$record_dir" >/dev/null; then
    fail "fake-provider records retained seeded secret or PII values"
fi

printf 'Probe Bash tests passed.\n'
