$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$aagentScript = Join-Path $projectRoot "aagent.ps1"
$fakeProvider = Join-Path $projectRoot "tests/helpers/fake-provider.ps1"
$readmePath = Join-Path $projectRoot "README.md"
$contractPath = Join-Path $projectRoot "docs/spec/cli-contract.md"
$acceptancePath = Join-Path $projectRoot "docs/acceptance-evidence.md"
$specificationPath = Join-Path $projectRoot "SPEC.md"
$ledgerPath = Join-Path $projectRoot "TODO.md"
$copilotResearchPath = Join-Path $projectRoot "docs/research/copilot-cli-2026-08-05.md"
$cursorResearchPath = Join-Path $projectRoot "docs/research/cursor-cli-2026-08-05.md"
$droidResearchPath = Join-Path $projectRoot "docs/research/factory-droid-2026-08-05.md"
$adapterSpecPath = Join-Path $projectRoot "docs/spec/adapters.md"
$probeSpecPath = Join-Path $projectRoot "docs/spec/probes.md"
$securitySpecPath = Join-Path $projectRoot "docs/spec/security.md"
$utf8 = [Text.UTF8Encoding]::new($false)

function Assert-DocsContains([string] $Value, [string] $Expected, [string] $Message) {
    if (-not $Value.Contains($Expected)) { throw $Message }
}

$powershellHelp = (& pwsh -NoLogo -NoProfile -File $aagentScript --help | Out-String).Trim().Replace("`r", "")
$readme = [IO.File]::ReadAllText($readmePath, $utf8)
$contract = [IO.File]::ReadAllText($contractPath, $utf8)
$acceptance = [IO.File]::ReadAllText($acceptancePath, $utf8)
$specification = [IO.File]::ReadAllText($specificationPath, $utf8)
$ledger = [IO.File]::ReadAllText($ledgerPath, $utf8)
$copilotResearch = [IO.File]::ReadAllText($copilotResearchPath, $utf8)
$cursorResearch = [IO.File]::ReadAllText($cursorResearchPath, $utf8)
$droidResearch = [IO.File]::ReadAllText($droidResearchPath, $utf8)
$adapterSpec = [IO.File]::ReadAllText($adapterSpecPath, $utf8)
$probeSpec = [IO.File]::ReadAllText($probeSpecPath, $utf8)
$securitySpec = [IO.File]::ReadAllText($securitySpecPath, $utf8)

$releaseEvidenceContract = @(
    "Status: Complete for aagent 0.1.1",
    "50166f2a268b377e05f952687f59cac179858d28",
    "actions/runs/30981356014",
    "actions/runs/30981749311",
    "releases/tag/v0.1.1",
    "28e4fa20271c3e562f74cf88c7cafb93a11d2d618ccf5256591c91a1dba779bd",
    "ae75ac0a8d0a9c5a6691cdc276c26748a639600544b628ab6a88a23f2aca4f60"
)
foreach ($evidence in $releaseEvidenceContract) {
    Assert-DocsContains $acceptance $evidence "MVP acceptance evidence omitted $evidence"
}
foreach ($criterion in 1..12) {
    Assert-DocsContains $acceptance "| $criterion |" "MVP acceptance criterion $criterion is unrecorded"
}
Assert-DocsContains $specification "Status: MVP released" "SPEC does not mark the MVP released"
Assert-DocsContains $ledger "Current milestone: Phase 12 Tier 2 adapters" `
    "implementation ledger does not identify the active backlog phase"

$copilotResearchContract = @(
    "Status: Normative implementation input for P12A-02",
    "GitHub Copilot CLI 1.0.78",
    "87982a909d52fcf095ee4458d3b5a69bbfd8ae614177115191b977a93df3d807",
    "copilot --prompt PROMPT --silent --no-ask-user",
    "COPILOT_PROVIDER_BASE_URL",
    "no non-mutating",
    "No unresolved interface question blocks P12A-02"
)
foreach ($evidence in $copilotResearchContract) {
    Assert-DocsContains $copilotResearch $evidence "Copilot revalidation omitted $evidence"
}

$cursorResearchContract = @(
    "Status: Normative implementation input for P12A-04",
    "2026.07.23-e383d2b",
    "f2eb25851f2079dcdf0558a816e06c402d187abfca93255d35167020439ebbf2",
    "agent --print --output-format text PROMPT",
    "isAuthenticated",
    "CURSOR_API_KEY",
    "No unresolved interface question blocks P12A-04"
)
foreach ($evidence in $cursorResearchContract) {
    Assert-DocsContains $cursorResearch $evidence "Cursor revalidation omitted $evidence"
}
Assert-DocsContains $ledger '- [x] **P12A-03 Revalidate Cursor CLI.**' `
    "Implementation ledger does not mark Cursor revalidation complete"

$copilotImplementationContract = @(
    'GitHub Copilot CLI (`copilot`)',
    'copilot --prompt PROMPT --silent --no-ask-user',
    'COPILOT_PROVIDER_BASE_URL',
    'Copilot BYOK',
    'GitHub token presence'
)
foreach ($evidence in $copilotImplementationContract) {
    Assert-DocsContains ($readme + $adapterSpec + $probeSpec) $evidence `
        "Copilot implementation documentation omitted $evidence"
}
Assert-DocsContains $securitySpec '`--allow-all-paths`' `
    "Security documentation omitted Copilot permission escalation flags"
Assert-DocsContains $ledger '- [x] **P12A-02 Implement `copilot`.**' `
    "Implementation ledger does not mark Copilot complete"

$cursorImplementationContract = @(
    'Cursor CLI (`cursor`)',
    'agent --print --output-format text PROMPT',
    'AAGENT_CURSOR_BIN',
    'status --format json',
    'CURSOR_API_KEY',
    'included_account',
    'cursor-agent'
)
foreach ($evidence in $cursorImplementationContract) {
    Assert-DocsContains ($readme + $adapterSpec + $probeSpec) $evidence `
        "Cursor implementation documentation omitted $evidence"
}
Assert-DocsContains $securitySpec '`--approve-mcps`' `
    "Security documentation omitted Cursor permission escalation flags"
Assert-DocsContains $ledger '- [x] **P12A-04 Implement `cursor`.**' `
    "Implementation ledger does not mark Cursor complete"

$droidResearchContract = @(
    "Status: Normative implementation input for P12A-05",
    "0.188.0",
    "sha512-EKDcuuxZ4mQPQJP2ApZo6yd8915pORGbpZABRV4vXKqM2Z9wk+GHnoOPiejv9hYYzNXwQP95NSemK2DsXxf+fw==",
    "droid exec PROMPT",
    "FACTORY_API_KEY",
    "read-only autonomy",
    "No unresolved interface question blocks P12A-05"
)
foreach ($evidence in $droidResearchContract) {
    Assert-DocsContains $droidResearch $evidence "Droid revalidation omitted $evidence"
}

$droidImplementationContract = @(
    'Factory Droid (`droid`)',
    'droid exec PROMPT',
    'AAGENT_DROID_BIN',
    'FACTORY_API_KEY',
    'customModels[INDEX].baseUrl',
    'payg_byok'
)
foreach ($evidence in $droidImplementationContract) {
    Assert-DocsContains ($readme + $adapterSpec + $probeSpec) $evidence `
        "Droid implementation documentation omitted $evidence"
}
Assert-DocsContains $securitySpec '`--skip-permissions-unsafe`' `
    "Security documentation omitted Droid permission bypass"
Assert-DocsContains $ledger '- [x] **P12A-05 Revalidate and implement Factory Droid.**' `
    "Implementation ledger does not mark Droid complete"

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
