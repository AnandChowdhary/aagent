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

function ConvertTo-Hex([string] $Value) {
    return [Convert]::ToHexString($utf8.GetBytes($Value)).ToLowerInvariant()
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

$bashSource = [IO.File]::ReadAllText((Join-Path $projectRoot "aagent.sh"), $utf8)
$powerShellSource = [IO.File]::ReadAllText($aagentScript, $utf8)
if ($bashSource -match '(?m)^\s*(eval|source|\.)\s' -or $bashSource -match '(^|[;&|\s])sh\s+-c([;&|\s]|$)') {
    throw "Bash runner contains a command-string evaluation primitive"
}
if ($powerShellSource -match 'Invoke-Expression|\[ScriptBlock\]::Create|ScriptBlock.*Create') {
    throw "PowerShell runner contains a command-string evaluation primitive"
}

. $aagentScript
foreach ($flag in @(
    "--yolo", "--dangerously-skip-permissions", "--skip-permissions-unsafe",
    "--allow-all-tools", "--allow-all-paths", "--allow-all-urls", "--allow-all",
    "--auto", "--force", "--trust", "--approve-mcps", "--sandbox", "--sandbox=read-only",
    "--permission-mode=bypassPermissions",
    "--approval-mode=yolo", "--sandbox=danger-full-access"
)) {
    if (-not (Test-AagentUnsafePermissionFlag $flag)) { throw "permission denylist omitted $flag" }
}
if (Test-AagentGeneratedAdapterArguments @("--yolo") @("--yolo")) {
    throw "generated permission injection passed the audit"
}
$escapedDiagnostic = ConvertTo-AagentDisplayArgument "path`nforged: success"
if ($escapedDiagnostic.Contains("`n")) { throw "display quoting preserved a raw line break" }
Assert-Contains $escapedDiagnostic '`n' "display quoting did not escape a line break"

$testDir = Join-Path ([IO.Path]::GetTempPath()) ("aagent-security-" + [guid]::NewGuid().ToString("N"))
$environmentNames = @(
    "HOME", "XDG_CONFIG_HOME", "APPDATA", "PATH", "AAGENT_FAKE_RECORD_DIR",
    "AAGENT_PROVIDER", "AAGENT_AUTH_POLICY", "AAGENT_PRIORITY", "AAGENT_ALLOW_LOCAL",
    "AAGENT_CODEX_BIN", "AAGENT_CLAUDE_BIN", "AAGENT_OPENCODE_BIN", "AAGENT_COPILOT_BIN",
    "AAGENT_GEMINI_BIN", "AAGENT_AMP_BIN", "AAGENT_CURSOR_BIN",
    "AAGENT_FAKE_CODEX_APP_SERVER_STDOUT", "AAGENT_FAKE_CODEX_APP_SERVER_STATUS",
    "AAGENT_FAKE_RUN_STATUS", "AAGENT_FAKE_INVOCATION_KIND",
    "AAGENT_FAKE_PROBE_STDOUT", "AAGENT_FAKE_PROBE_STDERR", "AAGENT_FAKE_PROBE_STATUS",
    "AAGENT_FAKE_PROBE_DELAY", "AAGENT_FAKE_PROBE_BYTES", "CODEX_API_KEY", "OPENAI_API_KEY",
    "COPILOT_PROVIDER_BASE_URL", "COPILOT_PROVIDER_HEADERS",
    "AAGENT_FAKE_VERSION_STDOUT", "AAGENT_FAKE_HELP_STDOUT",
    "AAGENT_FAKE_CURSOR_STATUS_STDOUT", "CURSOR_API_KEY"
)
$originalEnvironment = @{}
foreach ($name in $environmentNames) {
    $originalEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
}
$locks = [Collections.Generic.List[IO.FileStream]]::new()

try {
    $homeDir = Join-Path $testDir "home"
    $configDir = Join-Path $testDir "config"
    $appDataDir = Join-Path $testDir "appdata"
    $fakeBin = Join-Path $testDir "bin with spaces"
    $recordDir = Join-Path $testDir "records"
    $workDir = Join-Path $testDir "work dir"
    $missingDir = Join-Path $testDir "missing"
    $markerDir = Join-Path $testDir "markers"
    foreach ($directory in @(
        $homeDir, $configDir, $appDataDir, $fakeBin, $recordDir, $workDir, $markerDir,
        (Join-Path $homeDir ".claude"), (Join-Path $homeDir ".codex")
    )) { [IO.Directory]::CreateDirectory($directory) | Out-Null }
    $codexPath = Join-Path $fakeBin "codex.ps1"
    $copilotPath = Join-Path $fakeBin "copilot.ps1"
    $cursorPath = Join-Path $fakeBin "agent.ps1"
    Copy-Item -LiteralPath $fakeProvider -Destination $codexPath
    Copy-Item -LiteralPath $fakeProvider -Destination $copilotPath
    Copy-Item -LiteralPath $fakeProvider -Destination $cursorPath
    foreach ($credentialPath in @(
        (Join-Path $homeDir ".claude/.credentials.json"),
        (Join-Path $homeDir ".codex/auth.json")
    )) {
        [IO.File]::WriteAllText($credentialPath, "credential-trap", $utf8)
        $locks.Add([IO.File]::Open($credentialPath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None))
    }
    foreach ($helper in @("security", "sqlite3", "keyring")) {
        $helperPath = Join-Path $fakeBin "$helper.ps1"
        [IO.File]::WriteAllText($helperPath, "[IO.File]::WriteAllText('$markerDir/$helper', 'called'); exit 99", $utf8)
    }

    $env:HOME = $homeDir
    $env:XDG_CONFIG_HOME = $configDir
    $env:APPDATA = $appDataDir
    $env:AAGENT_FAKE_RECORD_DIR = $recordDir
    $env:AAGENT_CODEX_BIN = $codexPath
    $env:AAGENT_CLAUDE_BIN = Join-Path $missingDir "claude"
    $env:AAGENT_OPENCODE_BIN = Join-Path $missingDir "opencode"
    $env:AAGENT_COPILOT_BIN = $copilotPath
    $env:AAGENT_GEMINI_BIN = Join-Path $missingDir "gemini"
    $env:AAGENT_AMP_BIN = Join-Path $missingDir "amp"
    $env:AAGENT_CURSOR_BIN = $cursorPath
    $env:AAGENT_FAKE_CODEX_APP_SERVER_STDOUT = '{"id":1,"result":{"account":{"type":"chatgpt","planType":"pro","email":"person@example.com","organization":"Secret Org"},"requiresOpenaiAuth":true}}'
    $env:AAGENT_FAKE_CODEX_APP_SERVER_STATUS = "0"
    $env:AAGENT_FAKE_VERSION_STDOUT = "2026.07.23-e383d2b"
    $env:AAGENT_FAKE_HELP_STDOUT = "Usage: agent Start the Cursor Agent --print status"
    $env:AAGENT_FAKE_CURSOR_STATUS_STDOUT = '{"isAuthenticated":true,"hasAccessToken":true,"hasRefreshToken":true,"status":"seeded-secret-token","message":"Cursor Secret Org","userInfo":{"email":"cursor@example.com","token":"cursor-secret-token"}}'
    $env:AAGENT_FAKE_RUN_STATUS = "0"
    foreach ($name in @(
        "AAGENT_PROVIDER", "AAGENT_AUTH_POLICY", "AAGENT_PRIORITY", "AAGENT_ALLOW_LOCAL",
        "AAGENT_FAKE_INVOCATION_KIND", "AAGENT_FAKE_PROBE_STDOUT", "AAGENT_FAKE_PROBE_STDERR",
        "AAGENT_FAKE_PROBE_STATUS", "AAGENT_FAKE_PROBE_DELAY", "AAGENT_FAKE_PROBE_BYTES",
        "CODEX_API_KEY", "OPENAI_API_KEY", "COPILOT_PROVIDER_BASE_URL", "COPILOT_PROVIDER_HEADERS"
    )) {
        Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
    }
    $env:COPILOT_PROVIDER_BASE_URL = "https://seeded-secret-token@example.test/v1"
    $env:COPILOT_PROVIDER_HEADERS = "Authorization=seeded-secret-token"

    $result = Invoke-Wrapper @("providers")
    Assert-Equal $result.Status 0 "credential audit providers command failed"
    if (@(Get-ChildItem -LiteralPath $markerDir -File).Count -gt 0) { throw "a credential helper was invoked" }
    Assert-NotContains $result.Stdout "person@example.com" "providers leaked an email"
    Assert-NotContains $result.Stdout "Secret Org" "providers leaked an organization"
    Assert-NotContains $result.Stdout "seeded-secret-token" "providers leaked Copilot configuration"
    Assert-NotContains $result.Stdout "cursor@example.com" "providers leaked Cursor email"
    Assert-NotContains $result.Stdout "Cursor Secret Org" "providers leaked Cursor team"
    Assert-NotContains $result.Stdout "cursor-secret-token" "providers leaked Cursor status"
    if (Test-Path -LiteralPath (Join-Path $recordDir "run.count")) { throw "credential audit launched a model" }

    Remove-Item -LiteralPath $recordDir -Recurse -Force
    [IO.Directory]::CreateDirectory($recordDir) | Out-Null
    $hostilePrompt = "explain `$(touch prompt-should-not-exist)`nnext"
    $hostileModel = 'model;$(touch model-should-not-exist)'
    $hostileNative = "--yolo`nnot-a-second-argument"
    $result = Invoke-Wrapper @(
        "--provider", "codex", "--cwd", $workDir, "--model", $hostileModel,
        $hostilePrompt, "--", $hostileNative
    )
    Assert-Equal $result.Status 0 "native permission forwarding failed"
    $record = Get-ChildItem -LiteralPath $recordDir -Filter "codex.run.*.record" | Select-Object -First 1
    if ($null -eq $record) { throw "native permission test did not launch Codex" }
    $recordText = [IO.File]::ReadAllText($record.FullName, $utf8)
    Assert-Contains $recordText "arg.3.hex=$(ConvertTo-Hex $hostileNative)" "native permission argument changed"
    Assert-Equal ([regex]::Matches($recordText, [regex]::Escape((ConvertTo-Hex $hostileNative))).Count) 1 "native permission flag was duplicated"
    if (Test-Path -LiteralPath (Join-Path $workDir "prompt-should-not-exist")) { throw "prompt was evaluated" }
    if (Test-Path -LiteralPath (Join-Path $workDir "model-should-not-exist")) { throw "model was evaluated" }
    Assert-Equal ([IO.File]::ReadAllText((Join-Path $recordDir "run.count"), $utf8).Trim()) "1" "native permission launched more than one provider"

    Remove-Item -LiteralPath $recordDir -Recurse -Force
    [IO.Directory]::CreateDirectory($recordDir) | Out-Null
    $result = Invoke-Wrapper @("--provider", "codex", "--dry-run", "say hello")
    Assert-Equal $result.Status 0 "safe dry-run failed"
    foreach ($flag in @(
        "--yolo", "--dangerously-skip-permissions", "--allow-all-tools",
        "--allow-all-paths", "--allow-all-urls", "--allow-all", "--auto", "--force",
        "--trust", "--approve-mcps", "--sandbox"
    )) {
        Assert-NotContains $result.Stdout $flag "wrapper injected $flag"
    }
    if (Test-Path -LiteralPath (Join-Path $recordDir "run.count")) { throw "safe dry-run launched a model" }

    $hostileProvider = "not-a-provider`nforged: success"
    $result = Invoke-Wrapper @("doctor", $hostileProvider)
    Assert-Equal $result.Status 64 "hostile provider ID should be a usage error"
    Assert-Contains $result.Stderr 'not-a-provider`nforged: success' "usage diagnostic did not escape a line break"
    Assert-Equal @(($result.Stderr.TrimEnd() -split "`r?`n")).Count 2 "hostile provider injected a diagnostic line"

    $result = Invoke-Wrapper @("--unknown")
    Assert-Equal $result.Status 64 "usage status differs"
    Assert-Contains $result.Stderr "aagent:" "usage error prefix differs"
    $result = Invoke-Wrapper @("--provider", "claude", "say hello")
    Assert-Equal $result.Status 69 "unavailable status differs"
    Assert-Contains $result.Stderr "aagent:" "unavailable error prefix differs"
    $env:AAGENT_AUTH_POLICY = "invalid"
    $result = Invoke-Wrapper @("providers")
    Assert-Equal $result.Status 78 "configuration status differs"
    Assert-Contains $result.Stderr "aagent:" "configuration error prefix differs"
    Remove-Item Env:AAGENT_AUTH_POLICY -ErrorAction SilentlyContinue

    $vanishingPath = Join-Path $fakeBin "vanishing-codex.ps1"
    [IO.File]::WriteAllText(
        $vanishingPath,
        @'
param([Parameter(ValueFromRemainingArguments = $true)][string[]] $ProviderArguments)
if ($ProviderArguments[0] -eq "app-server") {
    Remove-Item -LiteralPath $PSCommandPath -Force
    [Console]::Out.Write('{"id":1,"result":{"account":{"type":"chatgpt","planType":"pro"},"requiresOpenaiAuth":true}}')
}
'@,
        $utf8
    )
    $env:AAGENT_CODEX_BIN = $vanishingPath
    $result = Invoke-Wrapper @("--provider", "codex", "say hello")
    Assert-Equal $result.Status 70 "software status differs"
    Assert-Contains $result.Stderr "aagent:" "software error prefix differs"
} finally {
    foreach ($lock in $locks) { $lock.Dispose() }
    foreach ($name in $environmentNames) {
        [Environment]::SetEnvironmentVariable($name, $originalEnvironment[$name], "Process")
    }
    if (Test-Path -LiteralPath $testDir) { Remove-Item -LiteralPath $testDir -Recurse -Force }
}

[Console]::Out.WriteLine("Security PowerShell tests passed.")
