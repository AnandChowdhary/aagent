$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$installScript = Join-Path $projectRoot "install.ps1"
$aagentScript = Join-Path $projectRoot "aagent.ps1"
$utf8 = [Text.UTF8Encoding]::new($false)

function Assert-Equal($Actual, $Expected, [string] $Message) {
    if ($Actual -ne $Expected) { throw "$Message (expected '$Expected', got '$Actual')" }
}

function Assert-Contains([string] $Value, [string] $Expected, [string] $Message) {
    if (-not $Value.Contains($Expected)) { throw "$Message (missing '$Expected')" }
}

$testDir = Join-Path ([IO.Path]::GetTempPath()) ("aagent-install-" + [guid]::NewGuid().ToString("N"))
$installDir = Join-Path $testDir "install dir/bin"
$remoteDir = Join-Path $testDir "remote assets"
$environmentNames = @(
    "INSTALL_DIR", "AAGENT_SOURCE", "AAGENT_CHECKSUM_SOURCE",
    "AAGENT_DOWNLOAD_BASE_URL", "AAGENT_EXPECTED_VERSION"
)
$originalEnvironment = @{}
foreach ($name in $environmentNames) {
    $originalEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
}

try {
    [IO.Directory]::CreateDirectory($installDir) | Out-Null
    [IO.Directory]::CreateDirectory($remoteDir) | Out-Null
    $env:INSTALL_DIR = $installDir
    $env:AAGENT_SOURCE = $aagentScript
    $env:AAGENT_EXPECTED_VERSION = "0.1.0"

    . $installScript
    foreach ($releaseAsset in @("aagent.sh", "aagent.ps1", "install.sh", "install.ps1")) {
        $expectedReleaseChecksum = Get-AagentInstallerExpectedChecksum `
            (Join-Path $projectRoot "SHA256SUMS") `
            $releaseAsset
        $actualReleaseChecksum = (Get-FileHash -LiteralPath (Join-Path $projectRoot $releaseAsset) -Algorithm SHA256).Hash.ToLowerInvariant()
        Assert-Equal $actualReleaseChecksum $expectedReleaseChecksum "repository checksum differs for $releaseAsset"
    }

    & $installScript *> $null
    $targetPath = Join-Path $installDir "aagent.ps1"
    $launcherPath = Join-Path $installDir "aagent.cmd"
    if (-not (Test-Path -LiteralPath $targetPath -PathType Leaf)) { throw "PowerShell runner was not installed" }
    if (-not (Test-Path -LiteralPath $launcherPath -PathType Leaf)) { throw "Windows launcher was not installed" }
    $version = (& pwsh -NoLogo -NoProfile -File $targetPath --version | Out-String).Trim()
    Assert-Equal $version "aagent 0.1.0" "installed PowerShell version differs"
    $help = (& pwsh -NoLogo -NoProfile -File $targetPath --help | Out-String)
    Assert-Contains $help "aagent providers" "installed PowerShell help is incomplete"
    Assert-Contains ([IO.File]::ReadAllText($launcherPath, $utf8)) '"%~dp0aagent.ps1" %*' "launcher forwarding differs"

    $pipeInstallDir = Join-Path $testDir "pipe install/bin"
    $env:INSTALL_DIR = $pipeInstallDir
    Invoke-Expression ([IO.File]::ReadAllText($installScript, $utf8)) *> $null
    $pipeTarget = Join-Path $pipeInstallDir "aagent.ps1"
    $version = (& pwsh -NoLogo -NoProfile -File $pipeTarget --version | Out-String).Trim()
    Assert-Equal $version "aagent 0.1.0" "Invoke-Expression install did not execute"
    $env:INSTALL_DIR = $installDir

    [IO.File]::WriteAllText($targetPath, "old-install", $utf8)
    & $installScript *> $null
    $version = (& pwsh -NoLogo -NoProfile -File $targetPath --version | Out-String).Trim()
    Assert-Equal $version "aagent 0.1.0" "existing PowerShell install was not replaced"

    $knownGoodHash = (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash
    $invalidRunner = Join-Path $testDir "invalid runner.ps1"
    [IO.File]::WriteAllText($invalidRunner, "exit 23", $utf8)
    $env:AAGENT_SOURCE = $invalidRunner
    $failed = $false
    try { & $installScript *> $null } catch { $failed = $true }
    if (-not $failed) { throw "invalid local PowerShell runner unexpectedly installed" }
    Assert-Equal (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash $knownGoodHash `
        "failed local install changed the existing PowerShell runner"

    $remoteRunner = Join-Path $remoteDir "aagent.ps1"
    [IO.File]::Copy($aagentScript, $remoteRunner, $true)
    $remoteHash = (Get-FileHash -LiteralPath $remoteRunner -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText((Join-Path $remoteDir "SHA256SUMS"), "$remoteHash  aagent.ps1`n", $utf8)

    function Invoke-AagentInstallerDownload([string] $Uri, [string] $Destination) {
        $asset = [IO.Path]::GetFileName(([Uri] $Uri).AbsolutePath)
        [IO.File]::Copy((Join-Path $remoteDir $asset), $Destination, $true)
    }
    $env:AAGENT_SOURCE = "https://downloads.example.test/aagent.ps1"
    $env:AAGENT_CHECKSUM_SOURCE = "https://downloads.example.test/SHA256SUMS"
    Invoke-AagentInstall *> $null
    $version = (& pwsh -NoLogo -NoProfile -File $targetPath --version | Out-String).Trim()
    Assert-Equal $version "aagent 0.1.0" "checksummed remote PowerShell install failed"

    $knownGoodHash = (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash
    [IO.File]::WriteAllText(
        (Join-Path $remoteDir "SHA256SUMS"),
        "$(('0' * 64))  aagent.ps1`n",
        $utf8
    )
    $failed = $false
    try { Invoke-AagentInstall *> $null } catch {
        $failed = $true
        Assert-Contains $_.Exception.Message "checksum verification failed" "bad checksum error differs"
    }
    if (-not $failed) { throw "bad PowerShell checksum unexpectedly installed" }
    Assert-Equal (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash $knownGoodHash `
        "checksum failure changed the existing PowerShell runner"

    $env:AAGENT_SOURCE = $aagentScript
    Remove-Item Env:AAGENT_CHECKSUM_SOURCE -ErrorAction SilentlyContinue
    $env:AAGENT_EXPECTED_VERSION = "9.9.9"
    $failed = $false
    try { Invoke-AagentInstall *> $null } catch {
        $failed = $true
        Assert-Contains $_.Exception.Message "expected version 9.9.9" "version mismatch error differs"
    }
    if (-not $failed) { throw "PowerShell version mismatch unexpectedly installed" }

    $staged = @(Get-ChildItem -LiteralPath $installDir -File | Where-Object Name -Like ".aagent-*.tmp*")
    Assert-Equal $staged.Count 0 "PowerShell installer left staging files"
} finally {
    foreach ($name in $environmentNames) {
        if ($null -eq $originalEnvironment[$name]) {
            Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
        } else {
            [Environment]::SetEnvironmentVariable($name, $originalEnvironment[$name], "Process")
        }
    }
    if (Test-Path -LiteralPath $testDir) { Remove-Item -LiteralPath $testDir -Recurse -Force }
}

[Console]::Out.WriteLine("Install PowerShell tests passed.")
