$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$aagentScript = Join-Path $projectRoot "aagent.ps1"
$installScript = Join-Path $projectRoot "install.ps1"

function Assert-Contains([string] $Value, [string] $Expected, [string] $Message) {
    if (-not $Value.Contains($Expected)) {
        throw $Message
    }
}

$helpOutput = (& $aagentScript --help | Out-String).Trim()
Assert-Contains $helpOutput "Run any CLI coding agent with a single command." "Help is missing the description."
Assert-Contains $helpOutput "Usage:" "Help is missing usage."
Assert-Contains $helpOutput "--help" "Help is missing the help option."

$shortHelpOutput = (& $aagentScript -h | Out-String).Trim()
if ($shortHelpOutput -ne $helpOutput) {
    throw "-h and --help output differ."
}

$defaultOutput = (& $aagentScript | Out-String).Trim()
if ($defaultOutput -ne $helpOutput) {
    throw "Running without arguments should show help."
}

$unknownOutput = (& pwsh -NoProfile -File $aagentScript --unknown 2>&1 | Out-String)
$unknownStatus = $LASTEXITCODE
if ($unknownStatus -eq 0) {
    throw "Unknown arguments should return a non-zero status."
}
Assert-Contains $unknownOutput "unknown argument: --unknown" "Unknown argument error is missing."

$testDir = Join-Path ([IO.Path]::GetTempPath()) ("aagent-tests-" + [guid]::NewGuid().ToString("N"))
$previousAagentSource = $env:AAGENT_SOURCE
$previousInstallDir = $env:INSTALL_DIR

try {
    $env:AAGENT_SOURCE = $aagentScript
    $env:INSTALL_DIR = Join-Path $testDir "bin"
    & $installScript | Out-Null

    $installedAagent = Join-Path $env:INSTALL_DIR "aagent.ps1"
    $installedHelpOutput = (& $installedAagent --help | Out-String).Trim()
    if ($installedHelpOutput -ne $helpOutput) {
        throw "Installed executable help differs."
    }
} finally {
    $env:AAGENT_SOURCE = $previousAagentSource
    $env:INSTALL_DIR = $previousInstallDir
    if (Test-Path -LiteralPath $testDir) {
        Remove-Item -LiteralPath $testDir -Recurse -Force
    }
}

Write-Host "All PowerShell tests passed."
exit 0
