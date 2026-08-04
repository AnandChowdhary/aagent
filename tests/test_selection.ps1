$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$aagentScript = Join-Path $projectRoot "aagent.ps1"
$fakeProvider = Join-Path $projectRoot "tests/helpers/fake-provider.ps1"
$utf8 = [Text.UTF8Encoding]::new($false)

. $aagentScript

function Assert-SelectionEqual($Actual, $Expected, [string] $Message) {
    if ($Actual -ne $Expected) {
        throw "$Message (expected '$Expected', got '$Actual')"
    }
}

function Assert-SelectionContains([string] $Actual, [string] $Expected, [string] $Message) {
    if (-not $Actual.Contains($Expected)) {
        throw "$Message (missing '$Expected')"
    }
}

function New-FixtureCandidate {
    param(
        [string] $Provider,
        [string] $Readiness,
        [string] $Funding,
        [int] $Confidence,
        [int] $Popularity,
        [int] $Registry,
        [string] $Priority = "",
        [bool] $AllowLocal = $false,
        [string] $Label = "Unknown"
    )
    $adapter = [pscustomobject] @{
        Id = $Provider
        Popularity = $Popularity
        RegistryOrder = $Registry
    }
    $probe = New-AagentProbeResult $Provider
    Set-AagentProbeResult $probe $Readiness $Funding $Confidence $Label fixture_probe fixture success | Out-Null
    return New-AagentSelectionCandidate $adapter "/fixture/$Provider" $probe $Priority $AllowLocal
}

function Assert-FixtureWinner {
    param(
        [object[]] $Candidates,
        [string] $Provider,
        [string] $Reason,
        [string] $Message
    )
    $selection = Select-AagentCandidates $Candidates
    if ($null -eq $selection.Winner) { throw "$Message (selection unexpectedly failed)" }
    Assert-SelectionEqual $selection.Winner.Provider $Provider $Message
    Assert-SelectionEqual $selection.ReasonCode $Reason "$Message reason differs"
    return $selection
}

$selection = Assert-FixtureWinner @(
    (New-FixtureCandidate codex unknown included_confirmed 4 1 1),
    (New-FixtureCandidate claude ready payg_byok 1 2 2)
) claude readiness "readiness did not dominate later tuple fields"

$fundingClasses = @("included_confirmed", "included_account", "prepaid_credits", "local", "payg_byok", "unknown")
for ($index = 0; $index -lt $fundingClasses.Count - 1; $index++) {
    $selection = Assert-FixtureWinner @(
        (New-FixtureCandidate higher ready $fundingClasses[$index] 4 16 16 "" $true),
        (New-FixtureCandidate lower ready $fundingClasses[$index + 1] 4 1 1 "" $true)
    ) higher funding_class "funding order differs for $($fundingClasses[$index])"
}

$localCandidate = New-FixtureCandidate local-provider ready local 4 1 1
$selection = Assert-FixtureWinner @(
    $localCandidate,
    (New-FixtureCandidate api-provider ready payg_byok 4 2 2)
) api-provider only_candidate "local candidate was not gated"
Assert-SelectionEqual $localCandidate.Exclusion local_not_allowed "local exclusion differs"

$selection = Assert-FixtureWinner @(
    (New-FixtureCandidate local-provider ready local 1 16 16 "" $true),
    (New-FixtureCandidate api-provider ready payg_byok 4 1 1 "" $true)
) local-provider funding_class "allowed local funding rank differs"

$selection = Assert-FixtureWinner @(
    (New-FixtureCandidate codex ready included_confirmed 4 16 16),
    (New-FixtureCandidate claude ready included_confirmed 3 1 1)
) codex authentication_confidence "confidence tie-break differs"

$selection = Assert-FixtureWinner @(
    (New-FixtureCandidate higher ready included_account 4 16 16 "lower,higher"),
    (New-FixtureCandidate lower ready payg_byok 4 1 1 "lower,higher")
) higher funding_class "priority crossed the funding boundary"

$selection = Assert-FixtureWinner @(
    (New-FixtureCandidate higher ready included_account 4 16 16 "lower,higher"),
    (New-FixtureCandidate lower ready included_account 3 1 1 "lower,higher")
) higher authentication_confidence "priority crossed the confidence boundary"

$selection = Assert-FixtureWinner @(
    (New-FixtureCandidate codex ready included_confirmed 4 1 1 "claude,codex"),
    (New-FixtureCandidate claude ready included_confirmed 4 16 16 "claude,codex")
) claude configured_priority "configured priority did not break an exact cost tie"
Assert-SelectionEqual $selection.ReasonDisplay "configured priority #1" "priority display differs"

$selection = Assert-FixtureWinner @(
    (New-FixtureCandidate codex ready included_confirmed 4 1 1 "claude"),
    (New-FixtureCandidate claude ready included_confirmed 4 16 16 "claude")
) claude configured_priority "listed provider did not outrank an unlisted tie"

$selection = Assert-FixtureWinner @(
    (New-FixtureCandidate codex ready included_account 4 1 16),
    (New-FixtureCandidate claude ready included_account 4 2 1)
) codex popularity_prior "frozen popularity prior differs"
Assert-SelectionEqual $selection.ReasonDisplay "popularity #1" "popularity display differs"

$selection = Assert-FixtureWinner @(
    (New-FixtureCandidate first ready unknown 0 5 1),
    (New-FixtureCandidate second ready unknown 0 5 2)
) first stable_registry_order "registry order did not break the final tie"

$unusableCandidate = New-FixtureCandidate unusable-provider unusable included_confirmed 4 1 1
$selection = Assert-FixtureWinner @(
    $unusableCandidate,
    (New-FixtureCandidate unknown-provider unknown unknown 0 16 16)
) unknown-provider only_candidate "unknown last-resort candidate was excluded"
Assert-SelectionEqual $unusableCandidate.Exclusion unusable_authentication "unusable exclusion differs"

$emptySelection = Select-AagentCandidates @(
    (New-FixtureCandidate unusable-provider unusable included_confirmed 4 1 1),
    (New-FixtureCandidate local-provider ready local 4 2 2)
)
if ($null -ne $emptySelection.Winner) {
    throw "empty eligible candidate set unexpectedly selected a provider"
}

function Invoke-SelectionProcess([string[]] $Arguments) {
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
    if (-not $process.Start()) { throw "could not start aagent selection fixture" }
    $process.StandardInput.Close()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    return [pscustomobject] @{ Status = $process.ExitCode; Stdout = $stdout; Stderr = $stderr }
}

$testDir = Join-Path ([IO.Path]::GetTempPath()) ("aagent-selection-" + [guid]::NewGuid().ToString("N"))
$selectionEnvironmentNames = @(
    "HOME", "XDG_CONFIG_HOME", "APPDATA", "AAGENT_PROVIDER", "AAGENT_AUTH_POLICY", "AAGENT_PRIORITY", "AAGENT_ALLOW_LOCAL",
    "AAGENT_CLAUDE_BIN", "AAGENT_CODEX_BIN", "AAGENT_OPENCODE_BIN", "AAGENT_GEMINI_BIN", "AAGENT_AMP_BIN",
    "AAGENT_FAKE_RECORD_DIR", "AAGENT_FAKE_INVOCATION_KIND", "AAGENT_FAKE_PROVIDER",
    "AAGENT_FAKE_ENV_PRESENCE", "AAGENT_FAKE_ENV_CAPTURE", "AAGENT_FAKE_PROBE_STDOUT", "AAGENT_FAKE_PROBE_STDERR",
    "AAGENT_FAKE_PROBE_STATUS", "AAGENT_FAKE_PROBE_DELAY", "AAGENT_FAKE_PROBE_BYTES",
    "AAGENT_FAKE_CLAUDE_STDOUT", "AAGENT_FAKE_CLAUDE_STDERR", "AAGENT_FAKE_CLAUDE_STATUS",
    "AAGENT_FAKE_CODEX_APP_SERVER_STDOUT", "AAGENT_FAKE_CODEX_APP_SERVER_STDERR",
    "AAGENT_FAKE_CODEX_APP_SERVER_STATUS", "AAGENT_FAKE_CODEX_LOGIN_STDERR",
    "AAGENT_FAKE_CODEX_LOGIN_STATUS", "AAGENT_FAKE_OPENCODE_STDOUT", "AAGENT_FAKE_OPENCODE_STATUS",
    "AAGENT_FAKE_RUN_STDOUT", "AAGENT_FAKE_RUN_STDERR", "AAGENT_FAKE_RUN_STATUS",
    "ANTHROPIC_API_KEY", "CODEX_API_KEY", "OPENAI_API_KEY", "AMP_API_KEY"
)
$originalEnvironment = @{}
foreach ($name in $selectionEnvironmentNames) {
    $originalEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
}

try {
    $homeDir = Join-Path $testDir "home"
    $configDir = Join-Path $testDir "config"
    $appDataDir = Join-Path $testDir "appdata"
    $fakeBin = Join-Path $testDir "bin"
    $recordDir = Join-Path $testDir "records"
    $missingDir = Join-Path $testDir "missing"
    foreach ($directory in @(
        $homeDir, $configDir, $appDataDir, $fakeBin, $recordDir,
        (Join-Path $homeDir ".gemini")
    )) {
        [IO.Directory]::CreateDirectory($directory) | Out-Null
    }
    foreach ($provider in @("claude", "codex", "opencode", "amp", "gemini")) {
        Copy-Item -LiteralPath $fakeProvider -Destination (Join-Path $fakeBin "$provider.ps1")
    }
    $env:HOME = $homeDir
    $env:XDG_CONFIG_HOME = $configDir
    $env:APPDATA = $appDataDir
    $env:AAGENT_FAKE_RECORD_DIR = $recordDir

    function Clear-SelectionCase {
        Remove-Item -LiteralPath $recordDir -Recurse -Force -ErrorAction SilentlyContinue
        [IO.Directory]::CreateDirectory($recordDir) | Out-Null
        Remove-Item -LiteralPath (Join-Path $homeDir ".gemini/settings.json") -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $configDir "aagent/config") -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $appDataDir "aagent/config") -Force -ErrorAction SilentlyContinue
        foreach ($name in $selectionEnvironmentNames) {
            if ($name -notin @("HOME", "XDG_CONFIG_HOME", "APPDATA", "AAGENT_FAKE_RECORD_DIR")) {
                Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
            }
        }
        $env:AAGENT_CLAUDE_BIN = Join-Path $missingDir "claude"
        $env:AAGENT_CODEX_BIN = Join-Path $missingDir "codex"
        $env:AAGENT_OPENCODE_BIN = Join-Path $missingDir "opencode"
        $env:AAGENT_GEMINI_BIN = Join-Path $missingDir "gemini"
        $env:AAGENT_AMP_BIN = Join-Path $missingDir "amp"
        $env:AAGENT_FAKE_RUN_STDOUT = "provider-output"
        $env:AAGENT_FAKE_RUN_STATUS = "0"
    }

    Clear-SelectionCase
    $env:AAGENT_CLAUDE_BIN = Join-Path $fakeBin "claude.ps1"
    $env:AAGENT_CODEX_BIN = Join-Path $fakeBin "codex.ps1"
    $env:AAGENT_FAKE_CLAUDE_STDOUT = '{"loggedIn":true,"authMethod":"claude.ai","subscriptionType":"max","apiProvider":"claude.ai"}'
    $env:AAGENT_FAKE_CODEX_APP_SERVER_STDOUT = '{"id":1,"result":{"account":{"type":"apiKey"},"requiresOpenaiAuth":true}}'
    $processResult = Invoke-SelectionProcess @("say hello")
    Assert-SelectionEqual $processResult.Status 0 "Claude included scenario failed"
    if (-not (Get-ChildItem -LiteralPath $recordDir -Filter "claude.run.*.record")) {
        throw "Claude subscription did not beat API-only Codex"
    }
    Assert-SelectionContains $processResult.Stderr `
        "using claude (included_confirmed, Claude Max; higher funding class (included_confirmed))" `
        "Claude selection notice differs"

    Clear-SelectionCase
    $env:AAGENT_CLAUDE_BIN = Join-Path $fakeBin "claude.ps1"
    $env:AAGENT_CODEX_BIN = Join-Path $fakeBin "codex.ps1"
    $env:AAGENT_FAKE_CLAUDE_STDOUT = '{"loggedIn":true,"authMethod":"api_key","apiProvider":"console","apiKeySource":"environment"}'
    $env:AAGENT_FAKE_CODEX_APP_SERVER_STDOUT = '{"id":1,"result":{"account":{"type":"chatgpt","planType":"pro"},"requiresOpenaiAuth":true}}'
    $processResult = Invoke-SelectionProcess @("say hello")
    Assert-SelectionEqual $processResult.Status 0 "Codex included scenario failed"
    if (-not (Get-ChildItem -LiteralPath $recordDir -Filter "codex.run.*.record")) {
        throw "ChatGPT Codex did not beat API-only Claude"
    }
    Assert-SelectionContains $processResult.Stderr `
        "using codex (included_confirmed, ChatGPT Pro; higher funding class (included_confirmed))" `
        "Codex selection notice differs"

    Clear-SelectionCase
    $env:AAGENT_CLAUDE_BIN = Join-Path $fakeBin "claude.ps1"
    $env:AAGENT_CODEX_BIN = Join-Path $fakeBin "codex.ps1"
    $env:AAGENT_FAKE_CLAUDE_STDOUT = '{"loggedIn":true,"authMethod":"api_key","apiProvider":"console"}'
    $env:AAGENT_FAKE_CODEX_APP_SERVER_STDOUT = '{"id":1,"result":{"account":{"type":"apiKey"},"requiresOpenaiAuth":true}}'
    $processResult = Invoke-SelectionProcess @("say hello")
    Assert-SelectionEqual $processResult.Status 0 "metered fallback scenario failed"
    if (-not (Get-ChildItem -LiteralPath $recordDir -Filter "codex.run.*.record")) {
        throw "best metered candidate was not selected"
    }
    Assert-SelectionContains $processResult.Stderr `
        "using codex (payg_byok, OpenAI API; authentication confidence 4)" `
        "metered fallback notice differs"

    Clear-SelectionCase
    $env:AAGENT_CLAUDE_BIN = Join-Path $fakeBin "claude.ps1"
    $env:AAGENT_OPENCODE_BIN = Join-Path $fakeBin "opencode.ps1"
    $env:AAGENT_FAKE_CLAUDE_STDOUT = '{"loggedIn":false}'
    $env:AAGENT_FAKE_OPENCODE_STDOUT = "No credentials found"
    $processResult = Invoke-SelectionProcess @("say hello")
    Assert-SelectionEqual $processResult.Status 0 "unknown fallback scenario failed"
    if (-not (Get-ChildItem -LiteralPath $recordDir -Filter "opencode.run.*.record")) {
        throw "unknown candidate was not retained as a last resort"
    }

    Clear-SelectionCase
    $env:AAGENT_CLAUDE_BIN = Join-Path $fakeBin "claude.ps1"
    $env:AAGENT_FAKE_CLAUDE_STDOUT = '{"loggedIn":false}'
    $processResult = Invoke-SelectionProcess @("say hello")
    Assert-SelectionEqual $processResult.Status $AagentExitUnavailable "all-unusable status differs"
    Assert-SelectionContains $processResult.Stderr `
        "no installed provider is eligible for automatic selection" `
        "all-unusable guidance differs"
    if (Test-Path -LiteralPath (Join-Path $recordDir "run.count")) {
        throw "known-unusable provider received the prompt"
    }

    Clear-SelectionCase
    $processResult = Invoke-SelectionProcess @("say hello")
    Assert-SelectionEqual $processResult.Status $AagentExitUnavailable "empty automatic selection status differs"
    Assert-SelectionContains $processResult.Stderr "no supported coding agent is installed" `
        "empty automatic selection guidance differs"
    if (Test-Path -LiteralPath (Join-Path $recordDir "run.count")) {
        throw "empty automatic selection launched a provider"
    }

    Clear-SelectionCase
    $env:AAGENT_CLAUDE_BIN = Join-Path $fakeBin "claude.ps1"
    $env:AAGENT_CODEX_BIN = Join-Path $fakeBin "codex.ps1"
    $env:AAGENT_FAKE_CLAUDE_STDOUT = "probe-must-not-run"
    $env:AAGENT_FAKE_CODEX_APP_SERVER_STDOUT = "probe-must-not-run"
    $processResult = Invoke-SelectionProcess @("--provider", "claude", "say hello")
    Assert-SelectionEqual $processResult.Status 0 "explicit provider failed"
    if (Test-Path -LiteralPath (Join-Path $recordDir "probe.count")) {
        throw "explicit provider entered automatic probing"
    }

    Clear-SelectionCase
    $processResult = Invoke-SelectionProcess @("--provider", "copilot", "say hello")
    Assert-SelectionEqual $processResult.Status $AagentExitUnavailable "known missing provider status differs"
    $processResult = Invoke-SelectionProcess @("--provider", "not-a-provider", "say hello")
    Assert-SelectionEqual $processResult.Status $AagentExitUsage "unknown provider status differs"

    Clear-SelectionCase
    $env:AAGENT_CLAUDE_BIN = Join-Path $fakeBin "claude.ps1"
    $env:AAGENT_FAKE_CLAUDE_STDOUT = '{"loggedIn":true,"authMethod":"claude.ai","subscriptionType":"pro","apiProvider":"claude.ai"}'
    $env:AAGENT_FAKE_RUN_STDERR = "provider diagnostic"
    $processResult = Invoke-SelectionProcess @("--quiet", "say hello")
    Assert-SelectionEqual $processResult.Status 0 "quiet selection failed"
    Assert-SelectionEqual $processResult.Stderr "provider diagnostic" "quiet suppressed or added the wrong stderr"

    Clear-SelectionCase
    $env:AAGENT_CLAUDE_BIN = Join-Path $fakeBin "claude.ps1"
    $env:AAGENT_CODEX_BIN = Join-Path $fakeBin "codex.ps1"
    $env:AAGENT_FAKE_CLAUDE_STDOUT = '{"loggedIn":true,"authMethod":"claude.ai","subscriptionType":"max","apiProvider":"claude.ai"}'
    $env:AAGENT_FAKE_CODEX_APP_SERVER_STDOUT = '{"id":1,"result":{"account":{"type":"apiKey"},"requiresOpenaiAuth":true}}'
    $usagePath = Join-Path $configDir "aagent/usage.json"
    [IO.Directory]::CreateDirectory((Split-Path -Parent $usagePath)) | Out-Null
    [IO.File]::WriteAllText($usagePath, '{"last":"codex","quota":"exhausted"}', $utf8)
    $firstResult = Invoke-SelectionProcess @("say hello")
    Remove-Item -LiteralPath $recordDir -Recurse -Force
    [IO.Directory]::CreateDirectory($recordDir) | Out-Null
    [IO.File]::WriteAllText($usagePath, '{"last":"claude","quota":"full"}', $utf8)
    $secondResult = Invoke-SelectionProcess @("say hello")
    Assert-SelectionEqual $secondResult.Status 0 "repeated deterministic selection failed"
    Assert-SelectionContains $firstResult.Stderr "using claude" "history changed first selection"
    Assert-SelectionContains $secondResult.Stderr "using claude" "history or quota changed repeated selection"

    Write-Output "Selection PowerShell tests passed."
} finally {
    foreach ($name in $selectionEnvironmentNames) {
        if ($null -eq $originalEnvironment[$name]) {
            Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
        } else {
            [Environment]::SetEnvironmentVariable($name, $originalEnvironment[$name], "Process")
        }
    }
    Remove-Item -LiteralPath $testDir -Recurse -Force -ErrorAction SilentlyContinue
}
