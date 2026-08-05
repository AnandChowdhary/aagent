$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$aagentScript = Join-Path $projectRoot "aagent.ps1"
$fakeProvider = Join-Path $projectRoot "tests/helpers/fake-provider.ps1"
$utf8 = [Text.UTF8Encoding]::new($false)

function Assert-Equal($Actual, $Expected, [string] $Message) {
    if ($Actual -ne $Expected) { throw "$Message (expected '$Expected', got '$Actual')" }
}

function Assert-Contains([string] $Value, [string] $Expected, [string] $Message) {
    if (-not $Value.Contains($Expected)) { throw "$Message (missing '$Expected')" }
}

function Assert-NotContains([string] $Value, [string] $Expected, [string] $Message) {
    if ($Value.Contains($Expected)) { throw "$Message (unexpected '$Expected')" }
}

function Invoke-Wrapper([string[]] $Arguments) {
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
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
    if (-not $process.Start()) { throw "Could not start aagent" }
    $process.StandardInput.Close()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    return [pscustomobject] @{ Status = $process.ExitCode; Stdout = $stdout; Stderr = $stderr }
}

$testDir = Join-Path ([IO.Path]::GetTempPath()) ("aagent-introspection-" + [guid]::NewGuid().ToString("N"))
$environmentNames = @(
    "HOME", "XDG_CONFIG_HOME", "APPDATA", "PATH", "AAGENT_FAKE_RECORD_DIR",
    "AAGENT_PROVIDER", "AAGENT_AUTH_POLICY", "AAGENT_PRIORITY", "AAGENT_ALLOW_LOCAL",
    "ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_BASE_URL",
    "CODEX_API_KEY", "OPENAI_API_KEY", "AMP_API_KEY",
    "COPILOT_PROVIDER_BASE_URL", "COPILOT_PROVIDER_TYPE", "COPILOT_PROVIDER_API_KEY",
    "COPILOT_PROVIDER_BEARER_TOKEN", "COPILOT_PROVIDER_HEADERS", "COPILOT_MODEL",
    "COPILOT_PROVIDER_MODEL_ID", "COPILOT_PROVIDER_WIRE_MODEL",
    "COPILOT_GITHUB_TOKEN", "GH_TOKEN", "GITHUB_TOKEN",
    "AAGENT_FAKE_CODEX_APP_SERVER_STDOUT", "AAGENT_FAKE_CODEX_APP_SERVER_STATUS",
    "AAGENT_FAKE_VERSION_STDOUT", "AAGENT_FAKE_VERSION_STATUS",
    "AAGENT_FAKE_VERSION_DELAY", "AAGENT_FAKE_VERSION_BYTES"
)
$providerIds = @("codex", "claude", "opencode", "copilot", "gemini", "cline", "goose", "aider", "qwen", "amp", "kimi", "droid", "crush", "vibe", "kiro", "cursor")
$providerOverrides = @(
    "AAGENT_CODEX_BIN", "AAGENT_CLAUDE_BIN", "AAGENT_OPENCODE_BIN", "AAGENT_COPILOT_BIN",
    "AAGENT_GEMINI_BIN", "AAGENT_CLINE_BIN", "AAGENT_GOOSE_BIN", "AAGENT_AIDER_BIN",
    "AAGENT_QWEN_BIN", "AAGENT_AMP_BIN", "AAGENT_KIMI_BIN", "AAGENT_DROID_BIN",
    "AAGENT_CRUSH_BIN", "AAGENT_VIBE_BIN", "AAGENT_KIRO_BIN", "AAGENT_CURSOR_BIN"
)
$originalEnvironment = @{}
foreach ($name in ($environmentNames + $providerOverrides)) {
    $originalEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
}

try {
    $homeDir = Join-Path $testDir "home"
    $configDir = Join-Path $testDir "config"
    $appDataDir = Join-Path $testDir "appdata"
    $fakeBin = Join-Path $testDir "bin with spaces"
    $recordDir = Join-Path $testDir "records"
    $missingDir = Join-Path $testDir "missing"
    foreach ($directory in @($homeDir, $configDir, $appDataDir, $fakeBin, $recordDir)) {
        [IO.Directory]::CreateDirectory($directory) | Out-Null
    }
    $codexPath = Join-Path $fakeBin "codex.ps1"
    $copilotPath = Join-Path $fakeBin "copilot.ps1"
    Copy-Item -LiteralPath $fakeProvider -Destination $codexPath
    Copy-Item -LiteralPath $fakeProvider -Destination $copilotPath
    $env:HOME = $homeDir
    $env:XDG_CONFIG_HOME = $configDir
    $env:APPDATA = $appDataDir
    $env:AAGENT_FAKE_RECORD_DIR = $recordDir
    $env:AAGENT_FAKE_CODEX_APP_SERVER_STDOUT = '{"id":1,"result":{"account":{"type":"chatgpt","planType":"pro"},"requiresOpenaiAuth":true}}'
    $env:AAGENT_FAKE_CODEX_APP_SERVER_STATUS = "0"

    function Clear-Case {
        if (Test-Path -LiteralPath $recordDir) { Remove-Item -LiteralPath $recordDir -Recurse -Force }
        [IO.Directory]::CreateDirectory($recordDir) | Out-Null
        foreach ($name in $providerOverrides) {
            [Environment]::SetEnvironmentVariable($name, (Join-Path $missingDir $name), "Process")
        }
        foreach ($name in @(
            "AAGENT_PROVIDER", "AAGENT_AUTH_POLICY", "AAGENT_PRIORITY", "AAGENT_ALLOW_LOCAL",
            "ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_BASE_URL",
            "CODEX_API_KEY", "OPENAI_API_KEY", "AMP_API_KEY",
            "COPILOT_PROVIDER_BASE_URL", "COPILOT_PROVIDER_TYPE", "COPILOT_PROVIDER_API_KEY",
            "COPILOT_PROVIDER_BEARER_TOKEN", "COPILOT_PROVIDER_HEADERS", "COPILOT_MODEL",
            "COPILOT_PROVIDER_MODEL_ID", "COPILOT_PROVIDER_WIRE_MODEL",
            "COPILOT_GITHUB_TOKEN", "GH_TOKEN", "GITHUB_TOKEN",
            "AAGENT_FAKE_VERSION_DELAY", "AAGENT_FAKE_VERSION_BYTES"
        )) { Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue }
        $env:AAGENT_FAKE_VERSION_STDOUT = "codex-cli 1.2.3"
        $env:AAGENT_FAKE_VERSION_STATUS = "0"
    }

    Clear-Case
    $result = Invoke-Wrapper @("providers")
    Assert-Equal $result.Status 0 "providers should succeed when all providers are missing: $($result.Stderr.Trim())"
    $lines = @($result.Stdout.TrimEnd() -split "`r?`n")
    Assert-Equal $lines.Count 17 "providers row count differs"
    $actualIds = @($lines | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[0] })
    Assert-Equal ($actualIds -join " ") ($providerIds -join " ") "providers order differs from the registry"
    if (Test-Path -LiteralPath (Join-Path $recordDir "run.count")) { throw "providers launched a model" }

    Clear-Case
    $env:AAGENT_CODEX_BIN = $codexPath
    $result = Invoke-Wrapper @("providers")
    Assert-Equal $result.Status 0 "providers failed"
    Assert-Contains $result.Stdout "codex      ready       included_confirmed    yes" "providers did not show the winner"
    Assert-Equal ([IO.File]::ReadAllText((Join-Path $recordDir "probe.count"), $utf8).Trim()) "1" "providers probe count differs"
    if (Test-Path -LiteralPath (Join-Path $recordDir "run.count")) { throw "providers launched a model" }

    Clear-Case
    $env:AAGENT_CODEX_BIN = $codexPath
    $result = Invoke-Wrapper @("doctor", "codex")
    Assert-Equal $result.Status 0 "provider-scoped doctor failed"
    Assert-Contains $result.Stdout "wrapper: aagent 0.1.1" "doctor omitted wrapper information"
    Assert-Contains $result.Stdout "platform:" "doctor omitted platform information"
    Assert-Contains $result.Stdout "configuration: not found" "doctor omitted configuration status"
    Assert-Contains $result.Stdout "selected provider: none" "scoped doctor unexpectedly selected globally"
    Assert-Contains $result.Stdout "provider: codex" "scoped doctor omitted the provider"
    Assert-NotContains $result.Stdout "provider: claude" "scoped doctor included an unrelated provider"
    Assert-Contains $result.Stdout "version: codex-cli 1.2.3" "doctor omitted the safe version"
    Assert-Contains $result.Stdout "authentication: ready" "doctor omitted authentication readiness"
    Assert-Contains $result.Stdout "command: codex exec PROMPT" "doctor omitted capabilities"
    Assert-Contains $result.Stdout "safety:" "doctor omitted safety"
    Assert-Equal ([IO.File]::ReadAllText((Join-Path $recordDir "probe.count"), $utf8).Trim()) "2" "doctor probe count differs"
    if (Test-Path -LiteralPath (Join-Path $recordDir "run.count")) { throw "doctor launched a model" }

    Clear-Case
    $env:AAGENT_COPILOT_BIN = $copilotPath
    $env:COPILOT_GITHUB_TOKEN = "seeded-secret-token"
    $env:AAGENT_FAKE_VERSION_STDOUT = "GitHub Copilot CLI 1.0.78"
    $result = Invoke-Wrapper @("doctor", "copilot")
    Assert-Equal $result.Status 0 "Copilot doctor failed"
    Assert-Contains $result.Stdout "provider: copilot" "Copilot doctor omitted provider"
    Assert-Contains $result.Stdout "tier: tier2" "Copilot doctor omitted tier"
    Assert-Contains $result.Stdout "version: GitHub Copilot CLI 1.0.78" "Copilot doctor rejected the safe version"
    Assert-Contains $result.Stdout "authentication: ready" "Copilot doctor omitted authentication readiness"
    Assert-Contains $result.Stdout "funding: included_account" "Copilot doctor omitted funding"
    Assert-Contains $result.Stdout "command: copilot --prompt PROMPT --silent --no-ask-user" "Copilot doctor omitted command"
    Assert-Contains $result.Stdout "no allow-all or yolo" "Copilot doctor omitted safety caveat"
    Assert-Equal ([IO.File]::ReadAllText((Join-Path $recordDir "probe.count"), $utf8).Trim()) "1" `
        "Copilot doctor ran more than its version probe"
    if (Test-Path -LiteralPath (Join-Path $recordDir "run.count")) { throw "Copilot doctor launched a model" }

    Clear-Case
    $result = Invoke-Wrapper @("doctor", "claude")
    Assert-Equal $result.Status 0 "known missing provider should be a diagnostic result"
    Assert-Contains $result.Stdout "discovery: missing" "known missing diagnosis is absent"
    $result = Invoke-Wrapper @("doctor", "not-a-provider")
    Assert-Equal $result.Status 64 "unknown doctor provider should be a usage error"
    Assert-Contains $result.Stderr "aagent: unknown provider: not-a-provider" "unknown doctor error differs"

    Clear-Case
    $env:AAGENT_CODEX_BIN = $codexPath
    $env:AAGENT_FAKE_VERSION_STDOUT = "Secret Org 1.2.3"
    $result = Invoke-Wrapper @("doctor", "codex")
    Assert-Equal $result.Status 0 "doctor failed for unsafe version output"
    Assert-Contains $result.Stdout "version: unknown" "unsafe version output was not discarded"
    Assert-Contains $result.Stdout "version status: unsafe_output" "unsafe version reason differs"
    Assert-NotContains $result.Stdout "Secret Org" "doctor leaked organization data"

    . $aagentScript
    $env:AAGENT_FAKE_VERSION_STDOUT = ""
    $env:AAGENT_FAKE_VERSION_DELAY = "4"
    $version = Get-AagentVersionProbe "codex" $codexPath
    Assert-Equal $version.Version "unknown" "timed-out version should be unknown"
    Assert-Equal $version.Status "timeout" "version timeout reason differs"
    $env:AAGENT_FAKE_VERSION_DELAY = "0"
    $env:AAGENT_FAKE_VERSION_BYTES = "65537"
    $version = Get-AagentVersionProbe "codex" $codexPath
    Assert-Equal $version.Status "truncated" "oversized version reason differs"
    Remove-Item Env:AAGENT_FAKE_VERSION_BYTES -ErrorAction SilentlyContinue
    $env:AAGENT_FAKE_VERSION_STATUS = "23"
    $version = Get-AagentVersionProbe "codex" $codexPath
    Assert-Equal $version.Status "nonzero" "nonzero version reason differs"
    $invalidVersionPath = Join-Path $fakeBin "invalid-version.ps1"
    [IO.File]::WriteAllText(
        $invalidVersionPath,
        '[Console]::OpenStandardOutput().Write([byte[]] @(0xff), 0, 1)',
        $utf8
    )
    $version = Get-AagentVersionProbe "codex" $invalidVersionPath
    Assert-Equal $version.Version "unknown" "invalid UTF-8 version should be unknown"
    Assert-Equal $version.Status "supervisor_failure" "invalid UTF-8 version reason differs"

    Clear-Case
    $env:AAGENT_CODEX_BIN = $codexPath
    $result = Invoke-Wrapper @("--dry-run", "say hello")
    Assert-Equal $result.Status 0 "dry-run failed"
    Assert-Contains $result.Stdout "provider: codex" "dry-run did not resolve selection"
    Assert-Contains $result.Stdout "stdin: argv" "dry-run did not resolve input mode"
    if (Test-Path -LiteralPath (Join-Path $recordDir "run.count")) { throw "dry-run launched a model" }

    Clear-Case
    [void] (Invoke-Wrapper @("--help"))
    [void] (Invoke-Wrapper @("--version"))
    if (Test-Path -LiteralPath (Join-Path $recordDir "probe.count")) { throw "help or version ran a probe" }
    if (Test-Path -LiteralPath (Join-Path $recordDir "run.count")) { throw "help or version launched a model" }
} finally {
    foreach ($name in ($environmentNames + $providerOverrides)) {
        [Environment]::SetEnvironmentVariable($name, $originalEnvironment[$name], "Process")
    }
    if (Test-Path -LiteralPath $testDir) { Remove-Item -LiteralPath $testDir -Recurse -Force }
}

[Console]::Out.WriteLine("Introspection PowerShell tests passed.")
