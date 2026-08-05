$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$aagentScript = Join-Path $projectRoot "aagent.ps1"
$fakeProvider = Join-Path $projectRoot "tests/helpers/fake-provider.ps1"
$readmePath = Join-Path $projectRoot "README.md"
$contractPath = Join-Path $projectRoot "docs/spec/cli-contract.md"
$utf8 = [Text.UTF8Encoding]::new($false)

function Assert-DocsContains([string] $Value, [string] $Expected, [string] $Message) {
    if (-not $Value.Contains($Expected)) { throw $Message }
}

$powershellHelp = (& pwsh -NoLogo -NoProfile -File $aagentScript --help | Out-String).Trim().Replace("`r", "")
$readme = [IO.File]::ReadAllText($readmePath, $utf8)
$contract = [IO.File]::ReadAllText($contractPath, $utf8)

$helpContract = @(
    "aagent [OPTIONS] [PROMPT...]",
    "aagent providers",
    "aagent doctor [PROVIDER]",
    "-P, --provider ID",
    "-m, --model ID",
    "-C, --cwd DIRECTORY",
    "--auth-policy P",
    "--priority IDS",
    "--allow-local B",
    "--dry-run",
    "--quiet",
    "-h, --help",
    "--version",
    "Treat remaining arguments as provider-native options"
)
foreach ($surface in $helpContract) {
    Assert-DocsContains $powershellHelp $surface "PowerShell help omitted $surface"
}

$publicContract = @(
    "aagent providers", "aagent doctor", "--provider", "--model", "--cwd",
    "--auth-policy", "--priority", "--allow-local", "--dry-run", "--quiet",
    "--help", "--version", "provider-native"
)
foreach ($surface in $publicContract) {
    Assert-DocsContains $readme $surface "README omitted $surface"
    Assert-DocsContains $contract $surface "CLI specification omitted $surface"
}

$documentedExamples = @(
    'aagent --provider claude --model sonnet "review the current diff"',
    'git diff | aagent --provider gemini',
    'aagent -P codex "fix the tests" -- --sandbox workspace-write',
    'Get-Content -Raw .\issue.md | aagent --provider claude "fix this issue"'
)
foreach ($example in $documentedExamples) {
    Assert-DocsContains $readme $example "README example drifted: $example"
}

$gitBash = if ($IsWindows) { Join-Path $env:ProgramFiles "Git/bin/bash.exe" } else { "" }
$bashPath = if (-not [string]::IsNullOrEmpty($gitBash) -and (Test-Path -LiteralPath $gitBash)) {
    $gitBash
} else {
    (Get-Command bash -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source
}
if (-not [string]::IsNullOrEmpty($bashPath)) {
    Push-Location $projectRoot
    try {
        $bashHelp = (& $bashPath ./aagent.sh --help | Out-String).Trim().Replace("`r", "")
    } finally {
        Pop-Location
    }
    if ($bashHelp -cne $powershellHelp) { throw "Bash and PowerShell help output differ" }
}

$testDir = Join-Path ([IO.Path]::GetTempPath()) ("aagent-docs-" + [guid]::NewGuid().ToString("N"))
$environmentNames = @(
    "HOME", "XDG_CONFIG_HOME", "APPDATA", "AAGENT_GEMINI_BIN", "AAGENT_FAKE_RECORD_DIR",
    "AAGENT_PROVIDER", "AAGENT_AUTH_POLICY", "AAGENT_PRIORITY", "AAGENT_ALLOW_LOCAL"
)
$originalEnvironment = @{}
foreach ($name in $environmentNames) {
    $originalEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
}

try {
    $homeDir = Join-Path $testDir "home"
    $configDir = Join-Path $testDir "config"
    $appDataDir = Join-Path $testDir "appdata"
    $recordDir = Join-Path $testDir "records"
    foreach ($directory in @($homeDir, $configDir, $appDataDir, $recordDir)) {
        [IO.Directory]::CreateDirectory($directory) | Out-Null
    }
    $env:HOME = $homeDir
    $env:XDG_CONFIG_HOME = $configDir
    $env:APPDATA = $appDataDir
    $env:AAGENT_GEMINI_BIN = $fakeProvider
    $env:AAGENT_FAKE_RECORD_DIR = $recordDir
    Remove-Item Env:AAGENT_PROVIDER, Env:AAGENT_AUTH_POLICY, Env:AAGENT_PRIORITY, Env:AAGENT_ALLOW_LOCAL `
        -ErrorAction SilentlyContinue

    $nativeOutput = (& pwsh -NoLogo -NoProfile -File $aagentScript --dry-run -P gemini `
        "apply the refactor" -- --approval-mode auto_edit 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) { throw "PowerShell native-argument example failed: $($nativeOutput.Trim())" }
    Assert-DocsContains $nativeOutput "provider: gemini" "PowerShell native-argument example selected the wrong provider"
    Assert-DocsContains $nativeOutput "'<native>' '<native>'" "PowerShell native-argument example lost redacted argument boundaries"

    $stdinOutput = ("issue context" | & pwsh -NoLogo -NoProfile -File $aagentScript `
        --dry-run -P gemini "fix this issue" 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) { throw "PowerShell stdin example failed: $($stdinOutput.Trim())" }
    Assert-DocsContains $stdinOutput "provider: gemini" "PowerShell stdin example selected the wrong provider"
    Assert-DocsContains $stdinOutput "stdin: both" "PowerShell stdin example lost its input mode"
    if (Test-Path -LiteralPath (Join-Path $recordDir "run.count")) {
        throw "documentation examples launched a provider"
    }
} finally {
    foreach ($name in $environmentNames) {
        [Environment]::SetEnvironmentVariable($name, $originalEnvironment[$name], "Process")
    }
    if (Test-Path -LiteralPath $testDir) {
        Remove-Item -LiteralPath $testDir -Recurse -Force
    }
}

$linkPattern = [regex]'\[[^\]]+\]\(([^)]+)\)'
foreach ($file in Get-ChildItem -LiteralPath $projectRoot -Filter *.md -File -Recurse) {
    $contents = [IO.File]::ReadAllText($file.FullName, $utf8)
    foreach ($link in $linkPattern.Matches($contents)) {
        $target = $link.Groups[1].Value.Trim('<', '>')
        if ($target -match '^(https?://|mailto:|#)') { continue }
        $relativePath = ($target -split '#', 2)[0]
        if ([string]::IsNullOrEmpty($relativePath)) { continue }
        $resolved = Join-Path $file.DirectoryName $relativePath
        if (-not (Test-Path -LiteralPath $resolved)) {
            throw "broken local Markdown link: $($file.FullName) -> $target"
        }
    }
}

[Console]::Out.WriteLine("Documentation PowerShell tests passed.")
