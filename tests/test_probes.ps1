$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$aagentScript = Join-Path $projectRoot "aagent.ps1"
$bashScript = Join-Path $projectRoot "aagent.sh"
$fakeProvider = Join-Path $projectRoot "tests/helpers/fake-provider.ps1"
$utf8 = [Text.UTF8Encoding]::new($false)

. $aagentScript

function Assert-ProbeEqual($Actual, $Expected, [string] $Message) {
    if ($Actual -ne $Expected) {
        throw "$Message (expected '$Expected', got '$Actual')"
    }
}

function Convert-ProbeHex([string] $Value) {
    return [Convert]::ToHexString($utf8.GetBytes($Value)).ToLowerInvariant()
}

function Assert-ProbeResult {
    param(
        $Result,
        [string] $Provider,
        [string] $Readiness,
        [string] $Funding,
        [int] $Confidence,
        [string] $Label,
        [string] $Reason,
        [string] $Source,
        [string] $Status
    )

    Assert-ProbeEqual $Result.Provider $Provider "$Provider schema provider differs."
    Assert-ProbeEqual $Result.Readiness $Readiness "$Provider readiness differs."
    Assert-ProbeEqual $Result.FundingClass $Funding "$Provider funding differs."
    Assert-ProbeEqual $Result.ConfidenceRank $Confidence "$Provider confidence differs."
    Assert-ProbeEqual $Result.PlanLabel $Label "$Provider plan label differs."
    Assert-ProbeEqual $Result.ReasonCode $Reason "$Provider reason differs."
    Assert-ProbeEqual $Result.Source $Source "$Provider source differs."
    Assert-ProbeEqual $Result.ProbeStatus $Status "$Provider probe status differs."
    Assert-ProbeEqual (
        $Result.PSObject.Properties.Name -join ","
    ) "Provider,Readiness,FundingClass,ConfidenceRank,PlanLabel,ReasonCode,ShadowingVariables,Source,ProbeStatus" `
        "$Provider schema contains a raw-output field."

    if ($Result.Readiness -notin @("ready", "unknown", "unusable")) {
        throw "$Provider readiness escaped the schema."
    }
    if ($Result.FundingClass -notin @(
        "included_confirmed", "included_account", "prepaid_credits", "local", "payg_byok", "unknown"
    )) {
        throw "$Provider funding escaped the schema."
    }
    if ($Result.ConfidenceRank -lt 0 -or $Result.ConfidenceRank -gt 4) {
        throw "$Provider confidence escaped the schema."
    }
    foreach ($name in $Result.ShadowingVariables) {
        if ($name -cnotmatch '^[A-Z][A-Z0-9_]*$') {
            throw "$Provider shadowing variables escaped the schema."
        }
    }
    $schema = @(
        $Result.Provider, $Result.Readiness, $Result.FundingClass, $Result.ConfidenceRank,
        $Result.PlanLabel, $Result.ReasonCode, $Result.Source, $Result.ProbeStatus,
        ($Result.ShadowingVariables -join ",")
    ) -join "|"
    foreach ($secret in @("seeded-secret-token", "person@example.com", "Secret Organization")) {
        if ($schema.Contains($secret)) {
            throw "$Provider schema leaked seeded secret or PII data."
        }
    }
}

$testDir = Join-Path ([IO.Path]::GetTempPath()) ("aagent-probes-" + [guid]::NewGuid().ToString("N"))
$probeEnvironmentNames = @(
    "HOME", "XDG_CONFIG_HOME", "PATH", "AAGENT_FAKE_RECORD_DIR",
    "AAGENT_FAKE_PROBE_STDOUT", "AAGENT_FAKE_PROBE_STDERR", "AAGENT_FAKE_PROBE_STATUS",
    "AAGENT_FAKE_PROBE_DELAY", "AAGENT_FAKE_PROBE_BYTES",
    "AAGENT_FAKE_CLAUDE_STDOUT", "AAGENT_FAKE_CLAUDE_STDERR", "AAGENT_FAKE_CLAUDE_STATUS",
    "AAGENT_FAKE_CLAUDE_DELAY", "AAGENT_FAKE_CLAUDE_BYTES",
    "AAGENT_FAKE_CODEX_APP_SERVER_STDOUT", "AAGENT_FAKE_CODEX_APP_SERVER_STDERR",
    "AAGENT_FAKE_CODEX_APP_SERVER_STATUS", "AAGENT_FAKE_CODEX_APP_SERVER_DELAY",
    "AAGENT_FAKE_CODEX_APP_SERVER_BYTES", "AAGENT_FAKE_CODEX_LOGIN_STDOUT",
    "AAGENT_FAKE_CODEX_LOGIN_STDERR", "AAGENT_FAKE_CODEX_LOGIN_STATUS",
    "AAGENT_FAKE_CODEX_LOGIN_DELAY", "AAGENT_FAKE_CODEX_LOGIN_BYTES",
    "AAGENT_FAKE_OPENCODE_STDOUT", "AAGENT_FAKE_OPENCODE_STDERR",
    "AAGENT_FAKE_OPENCODE_STATUS", "AAGENT_FAKE_OPENCODE_DELAY", "AAGENT_FAKE_OPENCODE_BYTES",
    "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_MANTLE", "CLAUDE_CODE_USE_VERTEX",
    "CLAUDE_CODE_USE_FOUNDRY", "CLAUDE_CODE_USE_ANTHROPIC_AWS",
    "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_API_KEY", "ANTHROPIC_BASE_URL",
    "ANTHROPIC_BEDROCK_BASE_URL", "ANTHROPIC_BEDROCK_MANTLE_BASE_URL",
    "ANTHROPIC_AWS_BASE_URL", "ANTHROPIC_VERTEX_BASE_URL", "ANTHROPIC_FOUNDRY_BASE_URL",
    "ANTHROPIC_FOUNDRY_RESOURCE", "ANTHROPIC_FOUNDRY_API_KEY", "AWS_BEARER_TOKEN_BEDROCK",
    "ANTHROPIC_CUSTOM_HEADERS", "CLAUDE_CODE_OAUTH_TOKEN",
    "CODEX_API_KEY", "OPENAI_API_KEY", "GEMINI_API_KEY", "GOOGLE_API_KEY",
    "GOOGLE_APPLICATION_CREDENTIALS", "GOOGLE_GENAI_USE_VERTEXAI", "GOOGLE_GENAI_USE_GCA",
    "GOOGLE_GEMINI_BASE_URL", "CLOUD_SHELL", "GEMINI_CLI_USE_COMPUTE_ADC", "AMP_API_KEY",
    "COPILOT_PROVIDER_BASE_URL", "COPILOT_PROVIDER_TYPE", "COPILOT_PROVIDER_API_KEY",
    "COPILOT_PROVIDER_BEARER_TOKEN", "COPILOT_PROVIDER_HEADERS", "COPILOT_MODEL",
    "COPILOT_PROVIDER_MODEL_ID", "COPILOT_PROVIDER_WIRE_MODEL",
    "COPILOT_GITHUB_TOKEN", "GH_TOKEN", "GITHUB_TOKEN"
)
$originalEnvironment = @{}
foreach ($name in $probeEnvironmentNames) {
    $originalEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
}

function Clear-ProbeCase {
    foreach ($name in $probeEnvironmentNames) {
        if ($name -notin @("HOME", "XDG_CONFIG_HOME", "PATH", "AAGENT_FAKE_RECORD_DIR")) {
            Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
        }
    }
}

try {
    $homeDir = Join-Path $testDir "home"
    $fakeBin = Join-Path $testDir "bin"
    $recordDir = Join-Path $testDir "records"
    $trapBin = Join-Path $testDir "trap-bin"
    $marker = Join-Path $testDir "credential-store-accessed"
    foreach ($directory in @(
        $homeDir,
        (Join-Path $homeDir ".claude"),
        (Join-Path $homeDir ".codex"),
        (Join-Path $homeDir ".gemini"),
        $fakeBin,
        $recordDir,
        $trapBin
    )) {
        [IO.Directory]::CreateDirectory($directory) | Out-Null
    }
    foreach ($provider in @("claude", "codex", "opencode")) {
        Copy-Item -LiteralPath $fakeProvider -Destination (Join-Path $fakeBin "$provider.ps1")
    }
    foreach ($commandName in @("security", "secret-tool", "cmdkey", "api-key-helper")) {
        $trapPath = Join-Path $trapBin "$commandName.ps1"
        [IO.File]::WriteAllText($trapPath, "[IO.File]::WriteAllText('$marker', 'called')`n", $utf8)
    }
    [IO.File]::WriteAllText(
        (Join-Path $homeDir ".claude/.credentials.json"),
        '$(api-key-helper) seeded-secret-token',
        $utf8
    )
    [IO.File]::WriteAllText((Join-Path $homeDir ".codex/auth.json"), "seeded-secret-token", $utf8)
    [IO.File]::WriteAllText((Join-Path $homeDir ".gemini/oauth_creds.json"), "seeded-secret-token", $utf8)
    [IO.File]::WriteAllText(
        (Join-Path $homeDir ".claude/settings.json"),
        '{"apiKeyHelper":"api-key-helper"}',
        $utf8
    )

    $env:HOME = $homeDir
    $env:XDG_CONFIG_HOME = Join-Path $testDir "config"
    $env:PATH = "$trapBin$([IO.Path]::PathSeparator)$fakeBin$([IO.Path]::PathSeparator)$($originalEnvironment['PATH'])"
    $env:AAGENT_FAKE_RECORD_DIR = $recordDir

    Clear-ProbeCase
    $env:AAGENT_FAKE_CLAUDE_STDOUT = '{"loggedIn":true,"authMethod":"claude.ai","subscriptionType":"max","apiProvider":"claude.ai","token":"seeded-secret-token","email":"person@example.com","organization":"Secret Organization","nested":{"huge":"ignored"}}'
    $result = Invoke-AagentProviderProbe "claude" (Join-Path $fakeBin "claude.ps1")
    Assert-ProbeResult $result claude ready included_confirmed 3 "Claude Max" `
        claude_subscription_status auth_status success

    Clear-ProbeCase
    $env:ANTHROPIC_API_KEY = "seeded-secret-token"
    $env:AAGENT_FAKE_CLAUDE_STDOUT = '{"loggedIn":true,"authMethod":"claude.ai","subscriptionType":"pro","apiProvider":"claude.ai"}'
    $result = Invoke-AagentProviderProbe "claude" (Join-Path $fakeBin "claude.ps1")
    Assert-ProbeResult $result claude ready included_confirmed 3 "Claude Pro" `
        claude_subscription_status auth_status success
    Assert-ProbeEqual ($result.ShadowingVariables -join ",") "ANTHROPIC_API_KEY" "Claude API shadow differs."

    Clear-ProbeCase
    $env:AAGENT_FAKE_CLAUDE_STDOUT = '{"loggedIn":true,"authMethod":"api_key","apiProvider":"console","apiKeySource":"environment"}'
    $result = Invoke-AagentProviderProbe "claude" (Join-Path $fakeBin "claude.ps1")
    Assert-ProbeResult $result claude ready payg_byok 3 "Anthropic API" claude_api_status auth_status success

    Clear-ProbeCase
    $env:AAGENT_FAKE_CLAUDE_STDOUT = '{"loggedIn":true,"authMethod":"bedrock","apiProvider":"aws-bedrock"}'
    $result = Invoke-AagentProviderProbe "claude" (Join-Path $fakeBin "claude.ps1")
    Assert-ProbeResult $result claude ready unknown 3 "Organization route" claude_cloud_status auth_status success

    Clear-ProbeCase
    $env:AAGENT_FAKE_CLAUDE_STDOUT = '{"loggedIn":false}'
    $result = Invoke-AagentProviderProbe "claude" (Join-Path $fakeBin "claude.ps1")
    Assert-ProbeResult $result claude unusable unknown 3 "Not signed in" claude_not_logged_in auth_status success

    Clear-ProbeCase
    $env:AAGENT_FAKE_CLAUDE_STDOUT = 'not-json seeded-secret-token person@example.com'
    $result = Invoke-AagentProviderProbe "claude" (Join-Path $fakeBin "claude.ps1")
    Assert-ProbeResult $result claude unknown unknown 0 "Unknown" claude_schema_failure auth_status schema_failure

    Clear-ProbeCase
    $env:ANTHROPIC_API_KEY = "seeded-secret-token"
    $env:AAGENT_FAKE_CLAUDE_STATUS = "23"
    $env:AAGENT_FAKE_CLAUDE_STDERR = "seeded-secret-token person@example.com Secret Organization"
    $result = Invoke-AagentProviderProbe "claude" (Join-Path $fakeBin "claude.ps1")
    Assert-ProbeResult $result claude ready payg_byok 1 "Anthropic API" `
        claude_api_environment environment nonzero

    Clear-ProbeCase
    $env:AAGENT_FAKE_CLAUDE_DELAY = "4"
    $result = Invoke-AagentProviderProbe "claude" (Join-Path $fakeBin "claude.ps1")
    Assert-ProbeResult $result claude unknown unknown 0 "Unknown" claude_probe_failed auth_status timeout

    Clear-ProbeCase
    $env:AAGENT_FAKE_CLAUDE_BYTES = "70000"
    $result = Invoke-AagentProviderProbe "claude" (Join-Path $fakeBin "claude.ps1")
    Assert-ProbeResult $result claude unknown unknown 0 "Unknown" claude_probe_failed auth_status truncated

    Clear-ProbeCase
    $env:CODEX_API_KEY = "seeded-secret-token"
    $env:AAGENT_FAKE_CODEX_APP_SERVER_STDOUT = @(
        '{"id":0,"result":{"serverInfo":"ignored"}}'
        '{"id":1,"result":{"account":{"type":"chatgpt","planType":"pro","email":"person@example.com","organization":"Secret Organization","token":"seeded-secret-token"},"requiresOpenaiAuth":true}}'
    ) -join "`n"
    $env:AAGENT_FAKE_CODEX_LOGIN_STDERR = "should-not-run"
    $result = Invoke-AagentProviderProbe "codex" (Join-Path $fakeBin "codex.ps1")
    Assert-ProbeResult $result codex ready included_confirmed 4 "ChatGPT Pro" `
        codex_chatgpt_account app_server success
    Assert-ProbeEqual ($result.ShadowingVariables -join ",") "CODEX_API_KEY" "Codex API shadow differs."

    Clear-ProbeCase
    $env:AAGENT_FAKE_CODEX_APP_SERVER_STDOUT = '{"id":1,"result":{"account":{"type":"apiKey"},"requiresOpenaiAuth":true}}'
    $result = Invoke-AagentProviderProbe "codex" (Join-Path $fakeBin "codex.ps1")
    Assert-ProbeResult $result codex ready payg_byok 4 "OpenAI API" codex_api_account app_server success

    Clear-ProbeCase
    $env:AAGENT_FAKE_CODEX_APP_SERVER_STDOUT = '{"id":1,"result":{"account":null,"requiresOpenaiAuth":true}}'
    $result = Invoke-AagentProviderProbe "codex" (Join-Path $fakeBin "codex.ps1")
    Assert-ProbeResult $result codex unusable unknown 4 "Not signed in" codex_not_logged_in app_server success

    Clear-ProbeCase
    $env:AAGENT_FAKE_CODEX_APP_SERVER_STDOUT = '{"id":1,"result":{"account":null,"requiresOpenaiAuth":false}}'
    $result = Invoke-AagentProviderProbe "codex" (Join-Path $fakeBin "codex.ps1")
    Assert-ProbeResult $result codex ready unknown 4 "Custom provider" codex_custom_provider app_server success

    Clear-ProbeCase
    $env:AAGENT_FAKE_CODEX_APP_SERVER_STATUS = "2"
    $env:AAGENT_FAKE_CODEX_LOGIN_STDERR = "Logged in using ChatGPT"
    $result = Invoke-AagentProviderProbe "codex" (Join-Path $fakeBin "codex.ps1")
    Assert-ProbeResult $result codex ready unknown 2 "ChatGPT account" `
        codex_login_text_chatgpt login_status fallback_success

    Clear-ProbeCase
    $env:AAGENT_FAKE_CODEX_APP_SERVER_STDOUT = "protocol mismatch seeded-secret-token"
    $env:AAGENT_FAKE_CODEX_LOGIN_STDERR = "Logged in using an API key - seeded-secret-token person@example.com"
    $result = Invoke-AagentProviderProbe "codex" (Join-Path $fakeBin "codex.ps1")
    Assert-ProbeResult $result codex ready payg_byok 2 "OpenAI API" `
        codex_login_text_api login_status fallback_success

    Clear-ProbeCase
    $env:AAGENT_FAKE_CODEX_APP_SERVER_STATUS = "2"
    $env:AAGENT_FAKE_CODEX_LOGIN_STATUS = "2"
    $env:AAGENT_FAKE_CODEX_LOGIN_STDERR = "seeded-secret-token person@example.com"
    $env:CODEX_API_KEY = "seeded-secret-token"
    $result = Invoke-AagentProviderProbe "codex" (Join-Path $fakeBin "codex.ps1")
    Assert-ProbeResult $result codex ready payg_byok 1 "OpenAI API" codex_api_environment environment nonzero

    Clear-ProbeCase
    $env:AAGENT_FAKE_CODEX_APP_SERVER_STATUS = "2"
    $env:AAGENT_FAKE_CODEX_LOGIN_STDERR = "Not logged in"
    $result = Invoke-AagentProviderProbe "codex" (Join-Path $fakeBin "codex.ps1")
    Assert-ProbeResult $result codex unusable unknown 2 "Not signed in" `
        codex_not_logged_in login_status fallback_success

    $codexInput = @(
        '{"method":"initialize","id":0,"params":{"clientInfo":{"name":"aagent","title":"aagent","version":"0.1.1"}}}'
        '{"method":"initialized","params":{}}'
        '{"method":"account/read","id":1,"params":{"refreshToken":false}}'
        ""
    ) -join "`n"
    $codexInputHex = Convert-ProbeHex $codexInput
    $codexRecords = Get-ChildItem -LiteralPath $recordDir -Filter "codex.probe.*.record"
    if (-not ($codexRecords | Where-Object {
        [IO.File]::ReadAllText($_.FullName, $utf8).Contains("stdin.hex=$codexInputHex")
    })) {
        throw "Codex app-server handshake or refreshToken:false request differs."
    }

    Clear-ProbeCase
    $env:AAGENT_FAKE_OPENCODE_STDOUT = "anthropic oauth person@example.com seeded-secret-token Secret Organization"
    $result = Invoke-AagentProviderProbe "opencode" (Join-Path $fakeBin "opencode.ps1")
    Assert-ProbeResult $result opencode ready unknown 2 "OpenCode credential" opencode_auth_list auth_list success
    if ($result.FundingClass.StartsWith("included_")) {
        throw "OpenCode OAuth alone became included funding."
    }

    Clear-ProbeCase
    $env:AAGENT_FAKE_OPENCODE_STDOUT = "No credentials found"
    $result = Invoke-AagentProviderProbe "opencode" (Join-Path $fakeBin "opencode.ps1")
    Assert-ProbeResult $result opencode unknown unknown 2 "No confirmed credential" opencode_no_auth auth_list success

    Clear-ProbeCase
    $env:OPENAI_API_KEY = "seeded-secret-token"
    $env:AAGENT_FAKE_OPENCODE_STATUS = "9"
    $result = Invoke-AagentProviderProbe "opencode" (Join-Path $fakeBin "opencode.ps1")
    Assert-ProbeResult $result opencode ready unknown 1 "Provider credential" `
        opencode_environment_auth environment nonzero

    Clear-ProbeCase
    $copilotProbeCountBefore = [IO.File]::ReadAllText((Join-Path $recordDir "probe.count"), $utf8).Trim()
    $env:COPILOT_PROVIDER_BASE_URL = "https://models.example.test/v1"
    $env:COPILOT_PROVIDER_API_KEY = "seeded-secret-token"
    $env:COPILOT_PROVIDER_HEADERS = "Authorization=seeded-secret-token"
    $env:COPILOT_GITHUB_TOKEN = "seeded-secret-token"
    $result = Invoke-AagentProviderProbe "copilot"
    Assert-ProbeResult $result copilot ready payg_byok 1 "Copilot BYOK" `
        copilot_byok_credential_environment environment environment_only
    Assert-ProbeEqual ($result.ShadowingVariables -join ",") `
        "COPILOT_PROVIDER_BASE_URL,COPILOT_PROVIDER_API_KEY,COPILOT_PROVIDER_HEADERS" `
        "Copilot BYOK variable evidence differs."

    Clear-ProbeCase
    $env:COPILOT_PROVIDER_BASE_URL = "http://127.0.0.42:11434/v1"
    $result = Invoke-AagentProviderProbe "copilot"
    Assert-ProbeResult $result copilot ready local 1 "Local provider" `
        copilot_local_byok_environment environment environment_only

    Clear-ProbeCase
    $env:COPILOT_PROVIDER_BASE_URL = "https://models.example.test/v1"
    $result = Invoke-AagentProviderProbe "copilot"
    Assert-ProbeResult $result copilot unknown unknown 1 "Remote BYOK" `
        copilot_remote_byok_unknown environment environment_only

    Clear-ProbeCase
    $env:COPILOT_PROVIDER_BASE_URL = "https://seeded-secret-token@example.test/v1"
    $env:COPILOT_PROVIDER_HEADERS = "Authorization=seeded-secret-token"
    $result = Invoke-AagentProviderProbe "copilot"
    Assert-ProbeResult $result copilot unknown unknown 0 "Unknown" `
        copilot_byok_endpoint_invalid environment invalid_configuration

    Clear-ProbeCase
    $env:GH_TOKEN = "seeded-secret-token"
    $result = Invoke-AagentProviderProbe "copilot"
    Assert-ProbeResult $result copilot ready included_account 1 "GitHub account" `
        copilot_github_token_environment environment environment_only
    Assert-ProbeEqual ($result.ShadowingVariables -join ",") "GH_TOKEN" `
        "Copilot GitHub token evidence differs."

    Clear-ProbeCase
    $result = Invoke-AagentProviderProbe "copilot"
    Assert-ProbeResult $result copilot unknown unknown 0 "Unknown" `
        copilot_no_passive_entitlement none skipped_no_passive
    Assert-ProbeEqual (
        [IO.File]::ReadAllText((Join-Path $recordDir "probe.count"), $utf8).Trim()
    ) $copilotProbeCountBefore "Copilot launched a provider probe."

    Clear-ProbeCase
    $probeCountBefore = [IO.File]::ReadAllText((Join-Path $recordDir "probe.count"), $utf8).Trim()
    [IO.File]::WriteAllText(
        (Join-Path $homeDir ".gemini/settings.json"),
        '{"security":{"auth":{"selectedType":"oauth-personal"}},"token":"seeded-secret-token","email":"person@example.com","organization":"Secret Organization"}',
        $utf8
    )
    $result = Invoke-AagentProviderProbe "gemini"
    Assert-ProbeResult $result gemini ready included_account 4 "Google account" `
        gemini_oauth_personal user_settings success

    [IO.File]::WriteAllText(
        (Join-Path $homeDir ".gemini/settings.json"),
        '{"security":{"auth":{"selectedType":"gemini-api-key"}}}',
        $utf8
    )
    $result = Invoke-AagentProviderProbe "gemini"
    Assert-ProbeResult $result gemini ready payg_byok 4 "Gemini API" gemini_api_key user_settings success

    [IO.File]::WriteAllText(
        (Join-Path $homeDir ".gemini/settings.json"),
        '{"security":{"auth":{"selectedType":"vertex-ai"}}}',
        $utf8
    )
    $result = Invoke-AagentProviderProbe "gemini"
    Assert-ProbeResult $result gemini ready unknown 4 "Google organization route" `
        gemini_organization_auth user_settings success

    [IO.File]::WriteAllText(
        (Join-Path $homeDir ".gemini/settings.json"),
        "malformed seeded-secret-token person@example.com",
        $utf8
    )
    $env:GEMINI_API_KEY = "seeded-secret-token"
    $result = Invoke-AagentProviderProbe "gemini"
    Assert-ProbeResult $result gemini ready payg_byok 1 "Gemini API" `
        gemini_api_environment environment schema_failure
    Remove-Item Env:GEMINI_API_KEY

    [IO.File]::WriteAllText((Join-Path $homeDir ".gemini/settings.json"), ("x" * 70000), $utf8)
    $result = Invoke-AagentProviderProbe "gemini"
    Assert-ProbeResult $result gemini unknown unknown 0 "Unknown" `
        gemini_settings_unavailable user_settings truncated
    Assert-ProbeEqual (
        [IO.File]::ReadAllText((Join-Path $recordDir "probe.count"), $utf8).Trim()
    ) $probeCountBefore "Gemini launched a provider probe."

    Clear-ProbeCase
    $result = Invoke-AagentProviderProbe "amp"
    Assert-ProbeResult $result amp unknown unknown 0 "Unknown" amp_no_passive_probe none skipped_no_passive
    $env:AMP_API_KEY = "seeded-secret-token"
    $result = Invoke-AagentProviderProbe "amp"
    Assert-ProbeResult $result amp ready unknown 1 "Amp account credential" `
        amp_environment_auth environment environment_only
    Assert-ProbeEqual (
        [IO.File]::ReadAllText((Join-Path $recordDir "probe.count"), $utf8).Trim()
    ) $probeCountBefore "Amp launched a network-capable probe."

    if (Test-Path -LiteralPath (Join-Path $recordDir "run.count")) {
        throw "Authentication probes made a model request."
    }
    if (Test-Path -LiteralPath $marker) {
        throw "Authentication probes invoked a credential helper or store command."
    }
    foreach ($sourcePath in @($aagentScript, $bashScript)) {
        $source = [IO.File]::ReadAllText($sourcePath, $utf8)
        if ($source -match 'auth\.json|oauth_creds|\.credentials\.json|apiKeyHelper') {
            throw "Production source names a credential token file or helper."
        }
    }
    foreach ($record in (Get-ChildItem -LiteralPath $recordDir -Filter "*.record")) {
        $contents = [IO.File]::ReadAllText($record.FullName, $utf8)
        foreach ($secret in @("seeded-secret-token", "person@example.com", "Secret Organization")) {
            if ($contents.Contains($secret)) {
                throw "Fake-provider records retained seeded secret or PII values."
            }
        }
    }

    Write-Output "Probe PowerShell tests passed."
} finally {
    foreach ($name in $probeEnvironmentNames) {
        if ($null -eq $originalEnvironment[$name]) {
            Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
        } else {
            [Environment]::SetEnvironmentVariable($name, $originalEnvironment[$name], "Process")
        }
    }
    Remove-Item -LiteralPath $testDir -Recurse -Force -ErrorAction SilentlyContinue
}
