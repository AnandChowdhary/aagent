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
mkdir -p "$HOME/.claude" "$HOME/.codex" "$HOME/.gemini" "$HOME/.factory" "$fake_bin" "$record_dir" "$trap_bin"
for provider in claude codex opencode agent goose; do
    cp "$fake_provider" "$fake_bin/$provider"
    chmod +x "$fake_bin/$provider"
done
export PATH="$trap_bin:$fake_bin:$PATH"
export AAGENT_FAKE_RECORD_DIR="$record_dir"
goose_root="$test_dir/goose-root"
goose_config_dir="$goose_root/config"
export GOOSE_PATH_ROOT="$goose_root"
mkdir -p "$goose_config_dir/custom_providers"

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
printf '%s\n' 'seeded-secret-token' >"$HOME/.factory/credentials.json"
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
        AAGENT_FAKE_CURSOR_STATUS_STDOUT AAGENT_FAKE_CURSOR_STATUS_STDERR \
        AAGENT_FAKE_CURSOR_STATUS_STATUS AAGENT_FAKE_CURSOR_STATUS_DELAY \
        AAGENT_FAKE_CURSOR_STATUS_BYTES CURSOR_API_KEY FACTORY_API_KEY \
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
        COPILOT_GITHUB_TOKEN GH_TOKEN GITHUB_TOKEN \
        GOOSE_PROVIDER GOOSE_PROVIDER__API_KEY OLLAMA_HOST TEST_GOOSE_API_KEY
    if [[ -n "${goose_config_dir-}" ]]; then
        rm -rf -- "$goose_config_dir"
        mkdir -p "$goose_config_dir/custom_providers"
    fi
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
cursor_probe_count_before="$(<"$record_dir/probe.count")"
export CURSOR_API_KEY='seeded-secret-token'
aagent_probe_provider cursor "$fake_bin/agent"
assert_probe cursor ready included_account 1 "Cursor account" cursor_api_key_environment environment environment_only
assert_equals "$AAGENT_PROBE_SHADOWING_VARIABLES" "CURSOR_API_KEY" "Cursor API key evidence differs"
assert_equals "$(<"$record_dir/probe.count")" "$cursor_probe_count_before" "Cursor API key launched a status probe"

clear_probe_case
export AAGENT_FAKE_CURSOR_STATUS_STDOUT='{"isAuthenticated":true,"hasAccessToken":true,"hasRefreshToken":true,"status":"authenticated","message":"Secret Organization","userInfo":{"email":"person@example.com","token":"seeded-secret-token"},"plan":"ultra"}'
aagent_probe_provider cursor "$fake_bin/agent"
assert_probe cursor ready included_account 3 "Cursor account" cursor_authenticated_status auth_status success
[[ -z "$AAGENT_PROBE_CAPTURE" ]] || fail "Cursor retained raw status JSON"

clear_probe_case
export AAGENT_FAKE_CURSOR_STATUS_STDOUT='{"isAuthenticated":false,"hasAccessToken":false,"hasRefreshToken":false}'
aagent_probe_provider cursor "$fake_bin/agent"
assert_probe cursor unusable unknown 3 "Not signed in" cursor_not_authenticated auth_status success

clear_probe_case
export AAGENT_FAKE_CURSOR_STATUS_STDOUT='{"isAuthenticated":true,"hasAccessToken":true}'
aagent_probe_provider cursor "$fake_bin/agent"
assert_probe cursor unknown unknown 0 "Unknown" cursor_schema_failure auth_status schema_failure

clear_probe_case
export AAGENT_FAKE_CURSOR_STATUS_STDOUT='{"isAuthenticated":true,"hasAccessToken":true,"hasRefreshToken":true,"endpoint":"https://api2.cursor.sh/v1"}'
aagent_probe_provider cursor "$fake_bin/agent"
assert_probe cursor ready included_account 3 "Cursor account" cursor_authenticated_status auth_status success

clear_probe_case
export AAGENT_FAKE_CURSOR_STATUS_STDOUT='{"isAuthenticated":true,"hasAccessToken":true,"hasRefreshToken":true,"endpoint":"http://127.0.0.42:11434/v1"}'
aagent_probe_provider cursor "$fake_bin/agent"
assert_probe cursor ready local 3 "Local provider" cursor_authenticated_local auth_status success

clear_probe_case
export AAGENT_FAKE_CURSOR_STATUS_STDOUT='{"isAuthenticated":true,"hasAccessToken":true,"hasRefreshToken":true,"endpoint":"http://[::1]:11434/v1"}'
aagent_probe_provider cursor "$fake_bin/agent"
assert_probe cursor ready local 3 "Local provider" cursor_authenticated_local auth_status success

clear_probe_case
export AAGENT_FAKE_CURSOR_STATUS_STDOUT='{"isAuthenticated":true,"hasAccessToken":true,"hasRefreshToken":true,"endpoint":"https://models.example.test/v1"}'
aagent_probe_provider cursor "$fake_bin/agent"
assert_probe cursor ready unknown 3 "Custom provider" cursor_authenticated_custom auth_status success

clear_probe_case
export AAGENT_FAKE_CURSOR_STATUS_STDOUT='{"isAuthenticated":true,"hasAccessToken":true,"hasRefreshToken":true,"endpoint":"https://seeded-secret-token@example.test/v1"}'
aagent_probe_provider cursor "$fake_bin/agent"
assert_probe cursor unknown unknown 0 "Unknown" cursor_endpoint_invalid auth_status invalid_configuration

clear_probe_case
export AAGENT_FAKE_CURSOR_STATUS_STDOUT='{"isAuthenticated":true,"hasAccessToken":true,"hasRefreshToken":true,"endpoint":null}'
aagent_probe_provider cursor "$fake_bin/agent"
assert_probe cursor unknown unknown 0 "Unknown" cursor_schema_failure auth_status schema_failure

clear_probe_case
export AAGENT_FAKE_CURSOR_STATUS_STDOUT='not-json seeded-secret-token person@example.com'
aagent_probe_provider cursor "$fake_bin/agent"
assert_probe cursor unknown unknown 0 "Unknown" cursor_schema_failure auth_status schema_failure

clear_probe_case
export AAGENT_FAKE_CURSOR_STATUS_DELAY=4
aagent_probe_provider cursor "$fake_bin/agent"
assert_probe cursor unknown unknown 0 "Unknown" cursor_probe_failed auth_status timeout

clear_probe_case
export AAGENT_FAKE_CURSOR_STATUS_BYTES=70000
aagent_probe_provider cursor "$fake_bin/agent"
assert_probe cursor unknown unknown 0 "Unknown" cursor_probe_failed auth_status truncated

cursor_status_hex="$(hex_string status)"
cursor_format_hex="$(hex_string --format)"
cursor_json_hex="$(hex_string json)"
grep -R -F "arg.0.hex=$cursor_status_hex" "$record_dir"/agent.probe.*.record >/dev/null || fail "Cursor status command was not recorded"
grep -R -F "arg.1.hex=$cursor_format_hex" "$record_dir"/agent.probe.*.record >/dev/null || fail "Cursor status format flag differs"
grep -R -F "arg.2.hex=$cursor_json_hex" "$record_dir"/agent.probe.*.record >/dev/null || fail "Cursor status JSON value differs"

clear_probe_case
goose_probe_count_before="$(<"$record_dir/probe.count")"
aagent_probe_provider goose "$fake_bin/goose"
assert_probe goose unknown unknown 0 "Unknown" goose_provider_not_selected none skipped_no_passive
assert_equals "$(<"$record_dir/probe.count")" "$goose_probe_count_before" "Goose ran an active provider probe without a selected provider"

clear_probe_case
export GOOSE_PROVIDER='anthropic'
export GOOSE_PROVIDER__API_KEY='seeded-secret-token'
aagent_probe_provider goose "$fake_bin/goose"
assert_probe goose ready payg_byok 2 "API provider via Goose" goose_api_provider_selected environment environment_only
assert_equals "$AAGENT_PROBE_SHADOWING_VARIABLES" "GOOSE_PROVIDER__API_KEY" "Goose API-key evidence differs"

clear_probe_case
printf '%s\n' 'active_provider: ollama' >"$goose_config_dir/config.yaml"
aagent_probe_provider goose "$fake_bin/goose"
assert_probe goose ready local 2 "Local provider via Goose" goose_local_provider_selected settings success

clear_probe_case
printf '%s\n' 'active_provider: ollama' >"$goose_config_dir/config.yaml"
export OLLAMA_HOST='https://ollama.example.test'
aagent_probe_provider goose "$fake_bin/goose"
assert_probe goose ready unknown 2 "Remote self-hosted Goose provider" goose_remote_local_provider_selected settings success

clear_probe_case
printf '%s\n' 'active_provider: chatgpt_codex' >"$goose_config_dir/config.yaml"
aagent_probe_provider goose "$fake_bin/goose"
assert_probe goose ready included_account 2 "ChatGPT account via Goose" goose_chatgpt_codex_selected settings success

clear_probe_case
printf '%s\n' 'active_provider: codex-acp' >"$goose_config_dir/config.yaml"
export AAGENT_CODEX_BIN="$fake_bin/codex"
export CODEX_API_KEY='seeded-secret-token'
export AAGENT_FAKE_CODEX_APP_SERVER_STDOUT='{"id":1,"result":{"account":{"type":"chatgpt","planType":"pro"},"requiresOpenaiAuth":true}}'
aagent_probe_provider goose "$fake_bin/goose"
assert_probe goose ready included_confirmed 4 "ChatGPT Pro" codex_chatgpt_account selected_provider/app_server success
assert_equals "$AAGENT_PROBE_UNDERLYING_PROVIDER" "codex" "Goose did not retain its funding inheritance source"
export AAGENT_EFFECTIVE_AUTH_POLICY='prefer-included'
aagent_project_probe_for_auth_policy goose
assert_equals "$AAGENT_AUTH_ENV_UNSET_NAME" "CODEX_API_KEY" "Goose did not inherit Codex API-key suppression"

clear_probe_case
printf '%s\n' 'active_provider: custom_loopback' >"$goose_config_dir/config.yaml"
printf '%s' '{"name":"custom_loopback","base_url":"http://127.0.0.1:8080/v1","api_key_env":"","requires_auth":false,"secret":"seeded-secret-token"}' >"$goose_config_dir/custom_providers/custom_loopback.json"
aagent_probe_provider goose "$fake_bin/goose"
assert_probe goose ready local 2 "Local custom Goose provider" goose_custom_provider_local selected_provider success

clear_probe_case
printf '%s\n' 'active_provider: custom_remote' >"$goose_config_dir/config.yaml"
printf '%s' '{"name":"custom_remote","base_url":"https://models.example.test/v1","api_key_env":"TEST_GOOSE_API_KEY","requires_auth":true,"secret":"seeded-secret-token"}' >"$goose_config_dir/custom_providers/custom_remote.json"
export TEST_GOOSE_API_KEY='seeded-secret-token'
aagent_probe_provider goose "$fake_bin/goose"
assert_probe goose ready payg_byok 2 "Goose BYOK provider" goose_custom_provider_byok selected_provider success
assert_equals "$AAGENT_PROBE_SHADOWING_VARIABLES" "TEST_GOOSE_API_KEY" "Goose custom-provider key evidence differs"

clear_probe_case
printf '%s\n' 'active_provider: [malformed seeded-secret-token]' >"$goose_config_dir/config.yaml"
aagent_probe_provider goose "$fake_bin/goose"
assert_probe goose unknown unknown 0 "Unknown" goose_provider_config_unavailable selected_provider schema_failure

goose_records_before="$(find "$record_dir" -name 'goose.probe.*.record' | wc -l | tr -d ' ')"
assert_equals "$goose_records_before" "0" "Goose probe invoked goose info --check or another active command"

clear_probe_case
rm -f "$HOME/.factory/settings.json" "$HOME/.factory/settings.local.json"
aagent_probe_provider droid ""
assert_probe droid unknown unknown 0 "Unknown" droid_no_passive_account_probe none skipped_no_passive

clear_probe_case
export FACTORY_API_KEY='seeded-secret-token'
aagent_probe_provider droid ""
assert_probe droid ready unknown 1 "Factory account" droid_factory_api_key environment environment_only
assert_equals "$AAGENT_PROBE_SHADOWING_VARIABLES" "FACTORY_API_KEY" "Droid API key evidence differs"

clear_probe_case
export FACTORY_API_KEY='seeded-secret-token'
printf '%s' '{"model":"custom:remote-0","customModels":[{"model":"remote","baseUrl":"https://models.example.test/v1","apiKey":"seeded-secret-token","email":"person@example.com","organization":"Secret Organization"}]}' >"$HOME/.factory/settings.json"
aagent_probe_provider droid ""
assert_probe droid ready payg_byok 1 "Factory BYOK model" droid_custom_model_byok settings success
assert_equals "$AAGENT_PROBE_SHADOWING_VARIABLES" "FACTORY_API_KEY" "Droid BYOK shadow evidence differs"

clear_probe_case
printf '%s' '{"model":"custom:local-0","customModels":[{"model":"local","baseUrl":"http://127.0.0.1:11434/v1","apiKey":"seeded-secret-token"}]}' >"$HOME/.factory/settings.json"
aagent_probe_provider droid ""
assert_probe droid unknown local 0 "Local custom model" droid_custom_model_local settings success

clear_probe_case
export FACTORY_API_KEY='seeded-secret-token'
printf '%s' '{"model":"claude-sonnet-managed"}' >"$HOME/.factory/settings.json"
aagent_probe_provider droid ""
assert_probe droid ready unknown 1 "Factory account" droid_factory_api_key environment environment_only

clear_probe_case
export FACTORY_API_KEY='seeded-secret-token'
printf '%s' 'malformed seeded-secret-token person@example.com' >"$HOME/.factory/settings.json"
aagent_probe_provider droid ""
assert_probe droid ready unknown 1 "Factory account" droid_settings_unavailable settings schema_failure

clear_probe_case
head -c 70000 /dev/zero | tr '\0' x >"$HOME/.factory/settings.json"
aagent_probe_provider droid ""
assert_probe droid unknown unknown 0 "Factory account" droid_settings_unavailable settings truncated

clear_probe_case
project_dir="$test_dir/project"
mkdir -p "$project_dir/.git" "$project_dir/.factory"
printf '%s' '{"model":"custom:user-0","customModels":[{"baseUrl":"https://user.example.test/v1"}]}' >"$HOME/.factory/settings.json"
printf '%s' '{"model":"custom:project-0","customModels":[{"baseUrl":"http://localhost:11434/v1"}]}' >"$project_dir/.factory/settings.local.json"
AAGENT_CWD="$project_dir" aagent_probe_provider droid ""
assert_probe droid unknown local 0 "Local custom model" droid_custom_model_local settings success
unset AAGENT_CWD
rm -f "$HOME/.factory/settings.json"

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
