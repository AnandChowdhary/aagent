$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$aagentScript = Join-Path $projectRoot "aagent.ps1"
$fakeProvider = Join-Path $projectRoot "tests/helpers/fake-provider.ps1"
$utf8 = [Text.UTF8Encoding]::new($false)

. $aagentScript

function Assert-PolicyEqual($Actual, $Expected, [string] $Message) {
    if ($Actual -ne $Expected) {
        throw "$Message (expected '$Expected', got '$Actual')"
    }
}

function Assert-PolicyContains([string] $Value, [string] $Expected, [string] $Message) {
    if (-not $Value.Contains($Expected)) {
        throw "$Message (missing '$Expected')"
    }
}

function Assert-PolicyNotContains([string] $Value, [string] $Unexpected, [string] $Message) {
    if ($Value.Contains($Unexpected)) {
        throw "$Message (unexpected '$Unexpected')"
    }
}

function Assert-PolicyFileLine([string] $Path, [string] $Expected, [string] $Message) {
    if ($Expected -notin [IO.File]::ReadAllLines($Path, $utf8)) {
        throw "$Message (missing '$Expected')"
    }
}

function ConvertTo-PolicyHex([AllowEmptyString()][string] $Value) {
    return [Convert]::ToHexString($utf8.GetBytes($Value)).ToLowerInvariant()
}

function Invoke-PolicyProcess([string[]] $Arguments) {
    $pwsh = (Get-Process -Id $PID).Path
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $pwsh
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.ArgumentList.Add("-NoProfile")
    $startInfo.ArgumentList.Add("-File")
    $startInfo.ArgumentList.Add($aagentScript)
    foreach ($argument in $Arguments) { $startInfo.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) { throw "could not start aagent auth-policy fixture" }
    $process.StandardInput.Close()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    $status = $process.ExitCode
    $process.Dispose()
    return [pscustomobject] @{ Status = $status; Stdout = $stdout; Stderr = $stderr }
}

$testDir = Join-Path ([IO.Path]::GetTempPath()) ("aagent-auth-policy-" + [guid]::NewGuid().ToString("N"))
$homeDir = Join-Path $testDir "home"
$configDir = Join-Path $testDir "config"
$appDataDir = Join-Path $testDir "appdata"
$fakeBin = Join-Path $testDir "bin"
$recordDir = Join-Path $testDir "records"
$missingDir = Join-Path $testDir "missing"
foreach ($directory in @($homeDir, $configDir, $appDataDir, $fakeBin, $recordDir)) {
    [IO.Directory]::CreateDirectory($directory) | Out-Null
}
foreach ($provider in @("claude", "codex")) {
    Copy-Item -LiteralPath $fakeProvider -Destination (Join-Path $fakeBin "$provider.ps1")
}

$policyEnvironmentNames = @(
    "HOME", "XDG_CONFIG_HOME", "APPDATA", "AAGENT_AUTH_POLICY", "AAGENT_PROVIDER",
    "AAGENT_PRIORITY", "AAGENT_ALLOW_LOCAL",
    "AAGENT_CLAUDE_BIN", "AAGENT_CODEX_BIN", "AAGENT_OPENCODE_BIN",
    "AAGENT_GEMINI_BIN", "AAGENT_AMP_BIN", "AAGENT_FAKE_RECORD_DIR",
    "AAGENT_FAKE_PROVIDER", "AAGENT_FAKE_INVOCATION_KIND",
    "AAGENT_FAKE_ENV_PRESENCE", "AAGENT_FAKE_ENV_CAPTURE",
    "AAGENT_FAKE_PROBE_STDOUT", "AAGENT_FAKE_PROBE_STDERR", "AAGENT_FAKE_PROBE_STATUS",
    "AAGENT_FAKE_PROBE_DELAY", "AAGENT_FAKE_PROBE_BYTES",
    "AAGENT_FAKE_CLAUDE_STDOUT", "AAGENT_FAKE_CLAUDE_STDERR", "AAGENT_FAKE_CLAUDE_STATUS",
    "AAGENT_FAKE_CLAUDE_DELAY", "AAGENT_FAKE_CLAUDE_BYTES",
    "AAGENT_FAKE_CODEX_APP_SERVER_STDOUT", "AAGENT_FAKE_CODEX_APP_SERVER_STATUS",
    "AAGENT_FAKE_CODEX_APP_SERVER_STDERR", "AAGENT_FAKE_CODEX_APP_SERVER_DELAY",
    "AAGENT_FAKE_CODEX_APP_SERVER_BYTES",
    "AAGENT_FAKE_CODEX_LOGIN_STDERR", "AAGENT_FAKE_CODEX_LOGIN_STATUS",
    "AAGENT_FAKE_CODEX_LOGIN_STDOUT", "AAGENT_FAKE_CODEX_LOGIN_DELAY", "AAGENT_FAKE_CODEX_LOGIN_BYTES",
    "AAGENT_FAKE_RUN_STDOUT", "AAGENT_FAKE_RUN_STDERR", "AAGENT_FAKE_RUN_STATUS",
    "ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_BASE_URL",
    "ANTHROPIC_BEDROCK_BASE_URL", "ANTHROPIC_BEDROCK_MANTLE_BASE_URL",
    "ANTHROPIC_AWS_BASE_URL", "ANTHROPIC_VERTEX_BASE_URL", "ANTHROPIC_FOUNDRY_BASE_URL",
    "ANTHROPIC_FOUNDRY_RESOURCE", "ANTHROPIC_FOUNDRY_API_KEY", "AWS_BEARER_TOKEN_BEDROCK",
    "ANTHROPIC_CUSTOM_HEADERS", "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_MANTLE",
    "CLAUDE_CODE_USE_VERTEX", "CLAUDE_CODE_USE_FOUNDRY", "CLAUDE_CODE_USE_ANTHROPIC_AWS",
    "CODEX_API_KEY", "OPENAI_API_KEY"
)
$originalEnvironment = @{}
foreach ($name in $policyEnvironmentNames) {
    $originalEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
}

$claudeSubscription = '{"loggedIn":true,"authMethod":"claude.ai","subscriptionType":"max","apiProvider":"claude.ai"}'
$codexSubscription = '{"id":1,"result":{"account":{"type":"chatgpt","planType":"pro"},"requiresOpenaiAuth":true}}'
$codexApi = '{"id":1,"result":{"account":{"type":"apiKey"},"requiresOpenaiAuth":true}}'
$secretAnthropic = "anthropic-phase9-secret"
$secretCodex = "codex-phase9-secret"
$secretOpenai = "openai-phase9-secret"

try {
    $env:HOME = $homeDir
    $env:XDG_CONFIG_HOME = $configDir
    $env:APPDATA = $appDataDir
    $env:AAGENT_FAKE_RECORD_DIR = $recordDir

    function Clear-PolicyCase {
        Remove-Item -LiteralPath $recordDir -Recurse -Force -ErrorAction SilentlyContinue
        [IO.Directory]::CreateDirectory($recordDir) | Out-Null
        Remove-Item -LiteralPath (Join-Path $configDir "aagent/config") -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $appDataDir "aagent/config") -Force -ErrorAction SilentlyContinue
        foreach ($name in $policyEnvironmentNames) {
            if ($name -notin @("HOME", "XDG_CONFIG_HOME", "APPDATA", "AAGENT_FAKE_RECORD_DIR")) {
                Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
            }
        }
        $env:AAGENT_CLAUDE_BIN = Join-Path $missingDir "claude.ps1"
        $env:AAGENT_CODEX_BIN = Join-Path $missingDir "codex.ps1"
        $env:AAGENT_OPENCODE_BIN = Join-Path $missingDir "opencode.ps1"
        $env:AAGENT_GEMINI_BIN = Join-Path $missingDir "gemini.ps1"
        $env:AAGENT_AMP_BIN = Join-Path $missingDir "amp.ps1"
        $env:AAGENT_FAKE_ENV_PRESENCE = @(
            "ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_BASE_URL",
            "ANTHROPIC_CUSTOM_HEADERS", "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX",
            "CLAUDE_CODE_USE_FOUNDRY", "CODEX_API_KEY", "OPENAI_API_KEY"
        ) -join ","
        $env:AAGENT_FAKE_ENV_CAPTURE = "CODEX_API_KEY,OPENAI_API_KEY"
        $env:AAGENT_FAKE_RUN_STATUS = "0"
    }

    Clear-PolicyCase
    # Projection itself must not mutate the wrapper process environment.
    $env:ANTHROPIC_API_KEY = $secretAnthropic
    $probe = New-AagentProbeResult "claude"
    Set-AagentProbeResult $probe ready included_confirmed 3 "Claude Max" `
        claude_subscription_status auth_status success @("ANTHROPIC_API_KEY") | Out-Null
    $projection = Resolve-AagentProbeAuthPolicy $probe "prefer-included"
    Assert-PolicyEqual $env:ANTHROPIC_API_KEY $secretAnthropic "Probe projection mutated its process environment."
    Assert-PolicyEqual $projection.EnvironmentPlan.Unset[0] "ANTHROPIC_API_KEY" "Claude projection omitted the wrong name."

    Clear-PolicyCase
    $env:AAGENT_CLAUDE_BIN = Join-Path $fakeBin "claude.ps1"
    $env:AAGENT_FAKE_CLAUDE_STDOUT = $claudeSubscription
    $env:ANTHROPIC_API_KEY = $secretAnthropic
    $result = Invoke-PolicyProcess @("--provider", "claude", "say hello")
    Assert-PolicyEqual $result.Status 0 "Claude subscription launch failed."
    Assert-PolicyFileLine (Join-Path $recordDir "claude.run.1.record") `
        "env.ANTHROPIC_API_KEY=absent" "Claude child retained the shadowing API key."
    Assert-PolicyEqual $env:ANTHROPIC_API_KEY $secretAnthropic "Claude success mutated the parent key."
    Assert-PolicyContains $result.Stderr `
        "using claude subscription; omitting ANTHROPIC_API_KEY from the child process" `
        "Claude adjustment notice differs."
    Assert-PolicyNotContains ($result.Stdout + $result.Stderr) $secretAnthropic "Claude output leaked the API key."

    Clear-PolicyCase
    $env:AAGENT_CLAUDE_BIN = Join-Path $fakeBin "claude.ps1"
    $env:AAGENT_CODEX_BIN = Join-Path $fakeBin "codex.ps1"
    $env:AAGENT_FAKE_CLAUDE_STDOUT = $claudeSubscription
    $env:AAGENT_FAKE_CODEX_APP_SERVER_STDOUT = $codexApi
    $env:ANTHROPIC_API_KEY = $secretAnthropic
    $result = Invoke-PolicyProcess @("say hello")
    Assert-PolicyContains $result.Stderr "using claude (included_confirmed, Claude Max;" `
        "Claude subscription shadow was ranked as metered."
    Assert-PolicyFileLine (Join-Path $recordDir "claude.run.1.record") `
        "env.ANTHROPIC_API_KEY=absent" "Selected Claude subscription retained its API-key shadow."

    Clear-PolicyCase
    $env:AAGENT_CLAUDE_BIN = Join-Path $fakeBin "claude.ps1"
    $env:AAGENT_FAKE_CLAUDE_STDOUT = $claudeSubscription
    $env:ANTHROPIC_API_KEY = $secretAnthropic
    $result = Invoke-PolicyProcess @("--auth-policy", "native", "--provider", "claude", "say hello")
    Assert-PolicyFileLine (Join-Path $recordDir "claude.run.1.record") `
        "env.ANTHROPIC_API_KEY=present" "Native Claude changed the child environment."
    Assert-PolicyNotContains $result.Stderr "omitting ANTHROPIC_API_KEY" "Native Claude emitted an adjustment."

    foreach ($routeName in @(
        "ANTHROPIC_BASE_URL", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_CUSTOM_HEADERS",
        "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX", "CLAUDE_CODE_USE_FOUNDRY"
    )) {
        Clear-PolicyCase
        $env:AAGENT_CLAUDE_BIN = Join-Path $fakeBin "claude.ps1"
        $env:AAGENT_FAKE_CLAUDE_STDOUT = $claudeSubscription
        $env:ANTHROPIC_API_KEY = $secretAnthropic
        Set-Item -LiteralPath "Env:$routeName" -Value "organization-route"
        $result = Invoke-PolicyProcess @("say hello")
        Assert-PolicyEqual $result.Status 0 "$routeName route launch failed."
        Assert-PolicyFileLine (Join-Path $recordDir "claude.run.1.record") `
            "env.ANTHROPIC_API_KEY=present" "$routeName route lost the API key."
        Assert-PolicyFileLine (Join-Path $recordDir "claude.run.1.record") `
            "env.$routeName=present" "$routeName route was not preserved."
        Assert-PolicyContains $result.Stderr `
            "using claude (unknown, Organization route; only eligible provider)" `
            "$routeName route was not classified unknown."
        Assert-PolicyNotContains $result.Stderr "omitting ANTHROPIC_API_KEY" `
            "$routeName route triggered an unsafe adjustment."
    }

    Clear-PolicyCase
    $env:AAGENT_CLAUDE_BIN = Join-Path $fakeBin "claude.ps1"
    $env:AAGENT_FAKE_CLAUDE_STDOUT = '{"loggedIn":true,"authMethod":"oauth","subscriptionType":"max","apiProvider":"claude.ai","apiKeySource":"helper"}'
    $env:ANTHROPIC_API_KEY = $secretAnthropic
    $result = Invoke-PolicyProcess @("say hello")
    Assert-PolicyFileLine (Join-Path $recordDir "claude.run.1.record") `
        "env.ANTHROPIC_API_KEY=present" "Claude helper configuration lost the native API key."
    Assert-PolicyContains $result.Stderr "using claude (unknown, Bearer or helper; only eligible provider)" `
        "Claude helper configuration was not classified unknown."

    Clear-PolicyCase
    $env:AAGENT_CLAUDE_BIN = Join-Path $fakeBin "claude.ps1"
    $env:AAGENT_FAKE_CLAUDE_STATUS = "23"
    $env:ANTHROPIC_API_KEY = $secretAnthropic
    $result = Invoke-PolicyProcess @("--provider", "claude", "say hello")
    Assert-PolicyEqual $result.Status 0 "Claude probe-failure fallback failed."
    Assert-PolicyFileLine (Join-Path $recordDir "claude.run.1.record") `
        "env.ANTHROPIC_API_KEY=present" "Probe failure stripped a credential."
    Assert-PolicyEqual $env:ANTHROPIC_API_KEY $secretAnthropic "Probe failure mutated the parent key."

    Clear-PolicyCase
    $env:AAGENT_CODEX_BIN = Join-Path $fakeBin "codex.ps1"
    $env:AAGENT_FAKE_CODEX_APP_SERVER_STDOUT = $codexSubscription
    $env:CODEX_API_KEY = $secretCodex
    $result = Invoke-PolicyProcess @("--provider", "codex", "say hello")
    Assert-PolicyEqual $result.Status 0 "Codex subscription launch failed."
    Assert-PolicyFileLine (Join-Path $recordDir "codex.run.1.record") `
        "env.CODEX_API_KEY=absent" "Codex child retained the shadowing API key."
    Assert-PolicyEqual $env:CODEX_API_KEY $secretCodex "Codex success mutated the parent key."
    Assert-PolicyContains $result.Stderr `
        "using codex ChatGPT account; omitting CODEX_API_KEY from the child process" `
        "Codex adjustment notice differs."
    Assert-PolicyNotContains ($result.Stdout + $result.Stderr) $secretCodex "Codex output leaked the API key."

    Clear-PolicyCase
    $env:AAGENT_CLAUDE_BIN = Join-Path $fakeBin "claude.ps1"
    $env:AAGENT_CODEX_BIN = Join-Path $fakeBin "codex.ps1"
    $env:AAGENT_FAKE_CLAUDE_STDOUT = '{"loggedIn":true,"authMethod":"api_key","apiProvider":"console"}'
    $env:AAGENT_FAKE_CODEX_APP_SERVER_STDOUT = $codexSubscription
    $env:CODEX_API_KEY = $secretCodex
    $result = Invoke-PolicyProcess @("say hello")
    Assert-PolicyContains $result.Stderr "using codex (included_confirmed, ChatGPT Pro;" `
        "Codex account shadow was ranked as metered."
    Assert-PolicyFileLine (Join-Path $recordDir "codex.run.1.record") `
        "env.CODEX_API_KEY=absent" "Selected Codex account retained its API-key shadow."

    Clear-PolicyCase
    $env:AAGENT_CODEX_BIN = Join-Path $fakeBin "codex.ps1"
    $env:AAGENT_FAKE_CODEX_APP_SERVER_STDOUT = $codexSubscription
    $env:CODEX_API_KEY = $secretCodex
    $result = Invoke-PolicyProcess @("--auth-policy", "native", "--provider", "codex", "say hello")
    Assert-PolicyFileLine (Join-Path $recordDir "codex.run.1.record") `
        "env.CODEX_API_KEY=present" "Native Codex changed the child environment."
    Assert-PolicyNotContains $result.Stderr "omitting CODEX_API_KEY" "Native Codex emitted an adjustment."

    Clear-PolicyCase
    $env:AAGENT_CODEX_BIN = Join-Path $fakeBin "codex.ps1"
    $env:AAGENT_FAKE_CODEX_APP_SERVER_STDOUT = $codexApi
    $env:OPENAI_API_KEY = $secretOpenai
    $result = Invoke-PolicyProcess @("--provider", "codex", "say hello")
    Assert-PolicyEqual $result.Status 0 "Codex metered mapping failed."
    Assert-PolicyFileLine (Join-Path $recordDir "codex.run.1.record") `
        "env.CODEX_API_KEY=present" "Codex metered child lacks CODEX_API_KEY."
    Assert-PolicyFileLine (Join-Path $recordDir "codex.run.1.record") `
        "env.CODEX_API_KEY.hex=$(ConvertTo-PolicyHex $secretOpenai)" `
        "Codex metered mapping changed the value."
    Assert-PolicyEqual $env:OPENAI_API_KEY $secretOpenai "Codex mapping mutated the parent key."
    Assert-PolicyContains $result.Stderr `
        "mapping OPENAI_API_KEY to CODEX_API_KEY for the child process" `
        "Codex mapping notice differs."
    Assert-PolicyNotContains ($result.Stdout + $result.Stderr) $secretOpenai "Codex mapping output leaked the key."

    Clear-PolicyCase
    $env:AAGENT_CODEX_BIN = Join-Path $fakeBin "codex.ps1"
    $env:AAGENT_FAKE_CODEX_APP_SERVER_STDOUT = $codexApi
    $env:OPENAI_API_KEY = $secretOpenai
    $result = Invoke-PolicyProcess @("--dry-run", "--provider", "codex", "say hello")
    Assert-PolicyEqual $result.Status 0 "Codex mapping dry-run failed."
    Assert-PolicyContains $result.Stdout "set environment: CODEX_API_KEY" `
        "Codex dry-run omitted the set variable name."
    Assert-PolicyNotContains ($result.Stdout + $result.Stderr) $secretOpenai "Codex dry-run leaked the mapped value."
    if (Test-Path -LiteralPath (Join-Path $recordDir "run.count")) {
        throw "Codex dry-run launched a provider."
    }
    Assert-PolicyEqual $env:OPENAI_API_KEY $secretOpenai "Dry-run mutated the parent key."

    Clear-PolicyCase
    $env:AAGENT_CODEX_BIN = Join-Path $fakeBin "codex.ps1"
    $env:AAGENT_FAKE_CODEX_APP_SERVER_STATUS = "23"
    $env:AAGENT_FAKE_CODEX_LOGIN_STATUS = "23"
    $env:OPENAI_API_KEY = $secretOpenai
    $result = Invoke-PolicyProcess @("--auth-policy", "native", "say hello")
    Assert-PolicyEqual $result.Status 0 "Native Codex unknown fallback failed."
    Assert-PolicyFileLine (Join-Path $recordDir "codex.run.1.record") `
        "env.CODEX_API_KEY=absent" "Native Codex mapped OPENAI_API_KEY."
    Assert-PolicyContains $result.Stderr "using codex (unknown; only eligible provider)" `
        "Native Codex did not classify the untouched path unknown."

    Clear-PolicyCase
    $env:AAGENT_CODEX_BIN = Join-Path $fakeBin "codex.ps1"
    $env:AAGENT_FAKE_CODEX_APP_SERVER_STDOUT = '{"id":1,"result":{"account":null,"requiresOpenaiAuth":false}}'
    $env:OPENAI_API_KEY = $secretOpenai
    $result = Invoke-PolicyProcess @("say hello")
    Assert-PolicyFileLine (Join-Path $recordDir "codex.run.1.record") `
        "env.CODEX_API_KEY=absent" "Custom Codex provider received an unsafe API-key mapping."
    Assert-PolicyContains $result.Stderr "using codex (unknown, Custom provider; only eligible provider)" `
        "Custom Codex provider was not classified unknown."

    Clear-PolicyCase
    $env:AAGENT_CLAUDE_BIN = Join-Path $fakeBin "claude.ps1"
    $env:AAGENT_FAKE_CLAUDE_STDOUT = $claudeSubscription
    $env:AAGENT_FAKE_RUN_STATUS = "23"
    $env:ANTHROPIC_API_KEY = $secretAnthropic
    $result = Invoke-PolicyProcess @("--provider", "claude", "say hello")
    Assert-PolicyEqual $result.Status 23 "Provider failure status was remapped."
    Assert-PolicyEqual $env:ANTHROPIC_API_KEY $secretAnthropic "Provider failure mutated the parent key."

    Clear-PolicyCase
    $env:AAGENT_CLAUDE_BIN = Join-Path $fakeBin "claude.ps1"
    $env:AAGENT_FAKE_CLAUDE_STDOUT = $claudeSubscription
    $env:AAGENT_FAKE_RUN_STDERR = "provider diagnostic"
    $env:ANTHROPIC_API_KEY = $secretAnthropic
    $result = Invoke-PolicyProcess @("--quiet", "--provider", "claude", "say hello")
    Assert-PolicyEqual $result.Stderr "provider diagnostic" "Quiet did not suppress auth notices."

    Write-Output "Authentication policy PowerShell tests passed."
} finally {
    foreach ($name in $policyEnvironmentNames) {
        if ($null -eq $originalEnvironment[$name]) {
            Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
        } else {
            [Environment]::SetEnvironmentVariable($name, $originalEnvironment[$name], "Process")
        }
    }
    Remove-Item -LiteralPath $testDir -Recurse -Force -ErrorAction SilentlyContinue
}
