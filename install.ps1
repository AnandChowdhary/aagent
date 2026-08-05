$ErrorActionPreference = "Stop"

function Invoke-AagentInstallerDownload([string] $Uri, [string] $Destination) {
    Invoke-WebRequest -Uri $Uri -OutFile $Destination
}

function Get-AagentInstallerExpectedChecksum([string] $Path, [string] $AssetName) {
    $checksumMatches = [Collections.Generic.List[string]]::new()
    foreach ($line in [IO.File]::ReadAllLines($Path)) {
        if ($line -match '^([0-9A-Fa-f]{64})\s+\*?([^\s]+)$' -and $Matches[2] -ceq $AssetName) {
            $checksumMatches.Add($Matches[1].ToLowerInvariant())
        }
    }
    if ($checksumMatches.Count -ne 1) {
        throw "aagent installer expected exactly one checksum for $AssetName"
    }
    return $checksumMatches[0]
}

function Test-AagentInstalledRunner([string] $Path) {
    $pwsh = (Get-Command pwsh -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    & $pwsh -NoLogo -NoProfile -File $Path --help *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "aagent installer downloaded a runner whose help command failed"
    }
    $versionOutput = (& $pwsh -NoLogo -NoProfile -File $Path --version | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $versionOutput -cnotmatch '^aagent\s+\S+$') {
        throw "aagent installer downloaded a runner with an invalid version response"
    }
    if (
        -not [string]::IsNullOrEmpty($env:AAGENT_EXPECTED_VERSION) -and
        $versionOutput -cne "aagent $($env:AAGENT_EXPECTED_VERSION)"
    ) {
        throw "aagent installer expected version $($env:AAGENT_EXPECTED_VERSION) but downloaded $($versionOutput.Substring(7))"
    }
}

function Set-AagentInstallerFile([string] $StagedPath, [string] $TargetPath) {
    [IO.File]::Move($StagedPath, $TargetPath, $true)
}

function Invoke-AagentInstall {
    $installDir = if ($env:INSTALL_DIR) {
        $env:INSTALL_DIR
    } else {
        Join-Path $HOME ".local/bin"
    }
    $downloadBaseUrl = if ($env:AAGENT_DOWNLOAD_BASE_URL) {
        $env:AAGENT_DOWNLOAD_BASE_URL.TrimEnd('/')
    } else {
        "https://raw.githubusercontent.com/AnandChowdhary/aagent/main"
    }
    $aagentSource = if ($env:AAGENT_SOURCE) {
        $env:AAGENT_SOURCE
    } else {
        "$downloadBaseUrl/aagent.ps1"
    }
    $checksumSource = if ($env:AAGENT_CHECKSUM_SOURCE) {
        $env:AAGENT_CHECKSUM_SOURCE
    } else {
        "$downloadBaseUrl/SHA256SUMS"
    }
    $targetPath = Join-Path $installDir "aagent.ps1"
    $launcherPath = Join-Path $installDir "aagent.cmd"
    $stagedRunner = Join-Path $installDir (".aagent-" + [guid]::NewGuid().ToString("N") + ".tmp")
    $stagedChecksums = Join-Path $installDir (".aagent-checksums-" + [guid]::NewGuid().ToString("N") + ".tmp")
    $stagedLauncher = Join-Path $installDir (".aagent-launcher-" + [guid]::NewGuid().ToString("N") + ".tmp")

    Write-Host "Installing aagent..."
    [IO.Directory]::CreateDirectory($installDir) | Out-Null
    try {
        $sourceIsLocal = Test-Path -LiteralPath $aagentSource -PathType Leaf
        if ($sourceIsLocal) {
            [IO.File]::Copy((Resolve-Path -LiteralPath $aagentSource).ProviderPath, $stagedRunner, $true)
        } else {
            Invoke-AagentInstallerDownload $aagentSource $stagedRunner
            Invoke-AagentInstallerDownload $checksumSource $stagedChecksums
            $expectedChecksum = Get-AagentInstallerExpectedChecksum $stagedChecksums "aagent.ps1"
            $actualChecksum = (Get-FileHash -LiteralPath $stagedRunner -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($actualChecksum -cne $expectedChecksum) {
                throw "aagent installer checksum verification failed for aagent.ps1"
            }
        }

        Test-AagentInstalledRunner $stagedRunner
        $launcher = "@echo off`r`npwsh -NoLogo -NoProfile -File `"%~dp0aagent.ps1`" %*`r`nexit /b %ERRORLEVEL%`r`n"
        [IO.File]::WriteAllText($stagedLauncher, $launcher, [Text.UTF8Encoding]::new($false))

        Set-AagentInstallerFile $stagedRunner $targetPath
        $stagedRunner = ""
        Set-AagentInstallerFile $stagedLauncher $launcherPath
        $stagedLauncher = ""

        if ($IsWindows) {
            & cmd.exe /d /c $launcherPath --help *> $null
            if ($LASTEXITCODE -ne 0) { throw "installed aagent launcher smoke test failed" }
        }

        Write-Host "Installed aagent to $targetPath"
        $pathEntries = @($env:PATH -split [IO.Path]::PathSeparator)
        if ($pathEntries -notcontains $installDir) {
            Write-Warning "Add $installDir to your PATH to run aagent from anywhere."
        }
        Write-Host "Run 'aagent --help' to get started."
    } finally {
        foreach ($path in @($stagedRunner, $stagedChecksums, $stagedLauncher)) {
            if (-not [string]::IsNullOrEmpty($path) -and (Test-Path -LiteralPath $path)) {
                Remove-Item -LiteralPath $path -Force
            }
        }
    }
}

if ($MyInvocation.InvocationName -ne ".") {
    Invoke-AagentInstall
}
