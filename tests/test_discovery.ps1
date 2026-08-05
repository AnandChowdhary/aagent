$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$aagentScript = Join-Path $projectRoot "aagent.ps1"
$fakeProvider = Join-Path $projectRoot "tests/helpers/fake-provider.ps1"

. $aagentScript

function Assert-DiscoveryEqual($Actual, $Expected, [string] $Message) {
    if ($Actual -ne $Expected) {
        throw "$Message (expected '$Expected', got '$Actual')"
    }
}

function Get-DiscoveryResult([object[]] $Results, [string] $Id) {
    $result = $Results | Where-Object Id -CEQ $Id | Select-Object -First 1
    if ($null -eq $result) {
        throw "Adapter is absent from discovery results: $Id"
    }
    return $result
}

$testDir = Join-Path ([IO.Path]::GetTempPath()) ("aagent-discovery-" + [guid]::NewGuid().ToString("N"))
$originalPath = $env:PATH
$windowsExecutable = if ($IsWindows) {
    (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
} else {
    ""
}
$overrideNames = @(
    "AAGENT_CODEX_BIN", "AAGENT_CLAUDE_BIN", "AAGENT_OPENCODE_BIN", "AAGENT_COPILOT_BIN",
    "AAGENT_GEMINI_BIN", "AAGENT_CLINE_BIN", "AAGENT_GOOSE_BIN", "AAGENT_AIDER_BIN",
    "AAGENT_QWEN_BIN", "AAGENT_AMP_BIN", "AAGENT_KIMI_BIN", "AAGENT_DROID_BIN",
    "AAGENT_CRUSH_BIN", "AAGENT_VIBE_BIN", "AAGENT_KIRO_BIN", "AAGENT_CURSOR_BIN",
    "AAGENT_FAKE_RECORD_DIR", "AAGENT_FAKE_INVOCATION_KIND",
    "AAGENT_FAKE_PROBE_STDOUT", "AAGENT_FAKE_PROBE_STDERR", "AAGENT_FAKE_PROBE_STATUS",
    "AAGENT_FAKE_PROBE_DELAY", "AAGENT_FAKE_PROBE_BYTES",
    "AAGENT_FAKE_VERSION_STDOUT", "AAGENT_FAKE_VERSION_STATUS",
    "AAGENT_FAKE_VERSION_DELAY", "AAGENT_FAKE_VERSION_BYTES",
    "AAGENT_FAKE_HELP_STDOUT", "AAGENT_FAKE_HELP_STATUS",
    "AAGENT_FAKE_HELP_DELAY", "AAGENT_FAKE_HELP_BYTES"
)
$originalOverrides = @{}
foreach ($name in $overrideNames) {
    $originalOverrides[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
    [Environment]::SetEnvironmentVariable($name, $null, "Process")
}

try {
    $fakeBin = Join-Path $testDir "bin"
    $recordDir = Join-Path $testDir "records"
    $overrideDir = Join-Path $testDir "override paths 🌍"
    foreach ($directory in @($fakeBin, $recordDir, $overrideDir)) {
        [IO.Directory]::CreateDirectory($directory) | Out-Null
    }

    foreach ($provider in @("codex", "claude", "copilot", "agent", "goose", "droid")) {
        Copy-Item -LiteralPath $fakeProvider -Destination (Join-Path $fakeBin "$provider.ps1")
    }
    if ($IsWindows) {
        [IO.File]::WriteAllText((Join-Path $fakeBin "qwen.cmd"), "@exit /b 0`r`n")
    }

    $overrideExecutable = Join-Path $overrideDir "gemini executable 🌍.ps1"
    $leadingExecutable = Join-Path $overrideDir "-leading-agent.ps1"
    $invalidDirectory = Join-Path $overrideDir "not-an-executable-directory"
    Copy-Item -LiteralPath $fakeProvider -Destination $overrideExecutable
    Copy-Item -LiteralPath $fakeProvider -Destination $leadingExecutable
    [IO.Directory]::CreateDirectory($invalidDirectory) | Out-Null

    $brokenLink = Join-Path $overrideDir "broken-opencode.ps1"
    $brokenSupported = $false
    try {
        New-Item -ItemType SymbolicLink -Path $brokenLink -Target (Join-Path $overrideDir "missing.ps1") -ErrorAction Stop | Out-Null
        $brokenSupported = $true
    } catch {
        $brokenSupported = $false
    }

    $registry = Get-AagentAdapterRegistry
    Assert-DiscoveryEqual $registry.Count 16 "Registry size differs."
    $expectedOrder = "codex,claude,opencode,copilot,gemini,cline,goose,aider,qwen,amp,kimi,droid,crush,vibe,kiro,cursor"
    Assert-DiscoveryEqual (($registry.Id) -join ",") $expectedOrder "Registry order differs."
    Assert-DiscoveryEqual $AagentPopularitySnapshot "2026-08-04" "Popularity snapshot differs."
    Assert-DiscoveryEqual (Get-AagentAdapter "codex").Tier "tier1" "Codex tier differs."
    Assert-DiscoveryEqual (Get-AagentAdapter "codex").Command "codex exec PROMPT" "Codex command differs."
    Assert-DiscoveryEqual (Get-AagentAdapter "copilot").Tier "tier2" "Copilot tier differs."
    Assert-DiscoveryEqual (Get-AagentAdapter "copilot").Command "copilot --prompt PROMPT --silent --no-ask-user" "Copilot command differs."
    Assert-DiscoveryEqual (Get-AagentAdapter "copilot").Model "--model" "Copilot model capability differs."
    Assert-DiscoveryEqual (Get-AagentAdapter "copilot").Structured "jsonl" "Copilot structured-output capability differs."
    if (-not (Get-AagentAdapter "copilot").Safety.Contains("no allow-all or yolo")) { throw "Copilot safety metadata differs." }
    Assert-DiscoveryEqual (Get-AagentAdapter "copilot").Probe "environment precedence only" "Copilot probe metadata differs."
    Assert-DiscoveryEqual (Get-AagentAdapter "amp").Model "none" "Amp model capability differs."
    Assert-DiscoveryEqual (Get-AagentAdapter "cursor").Executable "agent" "Cursor executable differs."
    Assert-DiscoveryEqual (Get-AagentAdapter "cursor").Tier "tier2" "Cursor tier differs."
    Assert-DiscoveryEqual (Get-AagentAdapter "cursor").Command "agent --print --output-format text PROMPT" "Cursor command differs."
    Assert-DiscoveryEqual (Get-AagentAdapter "cursor").Probe "status --format json" "Cursor probe metadata differs."
    Assert-DiscoveryEqual (Get-AagentAdapter "goose").Tier "tier2" "Goose tier differs."
    Assert-DiscoveryEqual (Get-AagentAdapter "goose").Command "goose run --text PROMPT" "Goose command differs."
    Assert-DiscoveryEqual (Get-AagentAdapter "goose").Stdin "argument-and-stdin" "Goose input capability differs."
    Assert-DiscoveryEqual (Get-AagentAdapter "goose").Model "--model" "Goose model capability differs."
    Assert-DiscoveryEqual (Get-AagentAdapter "goose").Structured "json,stream-json" "Goose structured-output capability differs."
    Assert-DiscoveryEqual (Get-AagentAdapter "goose").Sessions "resume,name,no-session" "Goose session capability differs."
    if (-not (Get-AagentAdapter "goose").Safety.Contains("never enables auto approval")) { throw "Goose safety metadata differs." }
    Assert-DiscoveryEqual (Get-AagentAdapter "goose").Probe "selected provider config; never info --check" "Goose probe metadata differs."
    Assert-DiscoveryEqual (Get-AagentAdapter "droid").Tier "tier2" "Droid tier differs."
    Assert-DiscoveryEqual (Get-AagentAdapter "droid").Command "droid exec PROMPT" "Droid command differs."
    Assert-DiscoveryEqual (Get-AagentAdapter "droid").Stdin "argument-and-stdin" "Droid input capability differs."
    Assert-DiscoveryEqual (Get-AagentAdapter "droid").Structured "json,stream-json,stream-jsonrpc" "Droid structured-output capability differs."
    Assert-DiscoveryEqual (Get-AagentAdapter "droid").Sessions "resume,fork" "Droid session capability differs."
    if (-not (Get-AagentAdapter "droid").Safety.Contains("Read-only autonomy by default")) { throw "Droid safety metadata differs." }
    Assert-DiscoveryEqual (Get-AagentAdapter "droid").Probe "settings model + FACTORY_API_KEY presence" "Droid probe metadata differs."

    function global:gemini { "this function must not be discovered" }
    $env:AAGENT_FAKE_RECORD_DIR = $recordDir
    $env:AAGENT_FAKE_VERSION_STDOUT = "2026.07.23-e383d2b"
    $env:AAGENT_FAKE_VERSION_STATUS = "0"
    $env:AAGENT_FAKE_HELP_STDOUT = "Usage: agent Start the Cursor Agent --print status"
    $env:AAGENT_FAKE_HELP_STATUS = "0"
    $env:PATH = $fakeBin
    $results = Get-AagentDiscovery
    $env:PATH = $originalPath

    Assert-DiscoveryEqual (Get-DiscoveryResult $results "codex").Status "installed" "Codex PATH status differs."
    Assert-DiscoveryEqual (Get-DiscoveryResult $results "claude").Status "installed" "Claude PATH status differs."
    Assert-DiscoveryEqual (Get-DiscoveryResult $results "gemini").Status "missing" "A function was accepted as Gemini."
    Assert-DiscoveryEqual (Get-DiscoveryResult $results "amp").Status "missing" "Amp missing status differs."
    Assert-DiscoveryEqual (Get-DiscoveryResult $results "copilot").Status "installed" "Installed Copilot status differs."
    Assert-DiscoveryEqual (Get-DiscoveryResult $results "cursor").Status "installed" "Installed Cursor status differs."
    Assert-DiscoveryEqual (Get-DiscoveryResult $results "goose").Status "installed" "Installed Goose status differs."
    Assert-DiscoveryEqual (Get-DiscoveryResult $results "droid").Status "installed" "Installed Droid status differs."
    Assert-DiscoveryEqual (Get-DiscoveryResult $results "cursor").Path (Join-Path $fakeBin "agent.ps1") "Cursor path collides with aagent."
    Assert-DiscoveryEqual (Get-DiscoveryResult $results "cursor").Reason "Cursor CLI signature found" "Cursor signature reason differs."

    $fallbackBin = Join-Path $testDir "fallback-bin"
    [IO.Directory]::CreateDirectory($fallbackBin) | Out-Null
    try {
        New-Item -ItemType SymbolicLink -Path (Join-Path $fallbackBin "agent.ps1") -Target $aagentScript -ErrorAction Stop | Out-Null
    } catch {
        Copy-Item -LiteralPath $aagentScript -Destination (Join-Path $fallbackBin "agent.ps1")
    }
    Copy-Item -LiteralPath $fakeProvider -Destination (Join-Path $fallbackBin "cursor-agent.ps1")
    $env:PATH = $fallbackBin
    $fallbackResults = Get-AagentDiscovery
    $env:PATH = $originalPath
    Assert-DiscoveryEqual (Get-DiscoveryResult $fallbackResults "cursor").Status "installed" "Legacy Cursor alias fallback was rejected."
    Assert-DiscoveryEqual (Get-DiscoveryResult $fallbackResults "cursor").Path (Join-Path $fallbackBin "cursor-agent.ps1") "Legacy Cursor alias path differs."
    Assert-DiscoveryEqual (Get-DiscoveryResult $fallbackResults "cursor").Reason "Cursor CLI signature found via legacy cursor-agent" "Legacy Cursor reason differs."
    if ($IsWindows) {
        Assert-DiscoveryEqual (Get-DiscoveryResult $results "qwen").Status "unsupported" "Windows .cmd discovery differs."

        $env:AAGENT_AMP_BIN = $windowsExecutable
        $env:PATH = $fakeBin
        $windowsExecutableResults = Get-AagentDiscovery
        $env:PATH = $originalPath
        Assert-DiscoveryEqual (Get-DiscoveryResult $windowsExecutableResults "amp").Status "installed" "Windows .exe override discovery differs."
        Assert-DiscoveryEqual (Get-DiscoveryResult $windowsExecutableResults "amp").Path $windowsExecutable "Windows .exe override path differs."
        Remove-Item Env:AAGENT_AMP_BIN
    }

    $env:AAGENT_CODEX_BIN = $leadingExecutable
    $env:AAGENT_CLAUDE_BIN = $aagentScript
    $env:AAGENT_GEMINI_BIN = $overrideExecutable
    $env:AAGENT_GOOSE_BIN = $overrideExecutable
    $env:AAGENT_DROID_BIN = $overrideExecutable
    $env:AAGENT_AMP_BIN = $invalidDirectory
    if ($brokenSupported) {
        $env:AAGENT_OPENCODE_BIN = $brokenLink
    }

    $env:PATH = $fakeBin
    $results = Get-AagentDiscovery
    $env:PATH = $originalPath

    Assert-DiscoveryEqual (Get-DiscoveryResult $results "codex").Status "installed" "Leading-dash override was rejected."
    Assert-DiscoveryEqual (Get-DiscoveryResult $results "codex").Path $leadingExecutable "Leading-dash override path differs."
    Assert-DiscoveryEqual (Get-DiscoveryResult $results "claude").Status "missing" "Wrapper recursion was accepted."
    Assert-DiscoveryEqual (Get-DiscoveryResult $results "claude").Reason "resolved target is the aagent wrapper" "Wrapper recursion reason differs."
    Assert-DiscoveryEqual (Get-DiscoveryResult $results "gemini").Status "installed" "Unicode/spaced override was rejected."
    Assert-DiscoveryEqual (Get-DiscoveryResult $results "gemini").Path $overrideExecutable "Unicode/spaced override path differs."
    Assert-DiscoveryEqual (Get-DiscoveryResult $results "goose").Status "installed" "Goose override was rejected."
    Assert-DiscoveryEqual (Get-DiscoveryResult $results "goose").Path $overrideExecutable "Goose override path differs."
    Assert-DiscoveryEqual (Get-DiscoveryResult $results "droid").Status "installed" "Droid override was rejected."
    Assert-DiscoveryEqual (Get-DiscoveryResult $results "droid").Path $overrideExecutable "Droid override path differs."
    Assert-DiscoveryEqual (Get-DiscoveryResult $results "amp").Status "missing" "Directory override was accepted."
    Assert-DiscoveryEqual (Get-DiscoveryResult $results "amp").Reason "invalid executable override: AAGENT_AMP_BIN" "Invalid override reason differs."
    if ($brokenSupported) {
        Assert-DiscoveryEqual (Get-DiscoveryResult $results "opencode").Status "missing" "Broken override symlink was accepted."
    }

    $env:AAGENT_CURSOR_BIN = $aagentScript
    $env:PATH = $fakeBin
    $cursorOverrideResults = Get-AagentDiscovery
    $env:PATH = $originalPath
    Assert-DiscoveryEqual (Get-DiscoveryResult $cursorOverrideResults "cursor").Status "missing" "Cursor accepted an aagent override."
    Assert-DiscoveryEqual (Get-DiscoveryResult $cursorOverrideResults "cursor").Reason "invalid Cursor CLI executable override: AAGENT_CURSOR_BIN" "Cursor invalid override reason differs."
    Remove-Item Env:AAGENT_CURSOR_BIN

    if (Test-Path -LiteralPath (Join-Path $recordDir "run.count")) {
        throw "Discovery executed a provider run."
    }
    if (-not (Test-Path -LiteralPath (Join-Path $recordDir "probe.count"))) {
        throw "Cursor signature validation did not run."
    }
    foreach ($record in (Get-ChildItem -LiteralPath $recordDir -Filter "*.record")) {
        $contents = [IO.File]::ReadAllText($record.FullName)
        if ($contents.Contains("arg.0.hex=737461747573") -or $contents.Contains("arg.0.hex=61757468")) {
            throw "Discovery executed an authentication probe."
        }
    }
    $runnerSource = [IO.File]::ReadAllText($aagentScript)
    if ($runnerSource -match "curl|wget|Invoke-WebRequest") {
        throw "Runtime runner contains a network popularity lookup."
    }
} finally {
    Remove-Item Function:gemini -ErrorAction SilentlyContinue
    $env:PATH = $originalPath
    foreach ($name in $overrideNames) {
        [Environment]::SetEnvironmentVariable($name, $originalOverrides[$name], "Process")
    }
    if (Test-Path -LiteralPath $testDir) {
        Remove-Item -LiteralPath $testDir -Recurse -Force
    }
}

Write-Host "Discovery PowerShell tests passed."
