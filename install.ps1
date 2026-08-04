$ErrorActionPreference = "Stop"

$installDir = if ($env:INSTALL_DIR) { $env:INSTALL_DIR } else { Join-Path $HOME ".local/bin" }
$aagentSource = if ($env:AAGENT_SOURCE) { $env:AAGENT_SOURCE } else { "https://raw.githubusercontent.com/AnandChowdhary/aagent/main/aagent.ps1" }
$targetPath = Join-Path $installDir "aagent.ps1"

Write-Host "Installing aagent..."
New-Item -ItemType Directory -Force -Path $installDir | Out-Null

if (Test-Path -LiteralPath $aagentSource -PathType Leaf) {
    Copy-Item -LiteralPath $aagentSource -Destination $targetPath -Force
} else {
    Invoke-WebRequest -Uri $aagentSource -OutFile $targetPath
}

Write-Host "Installed aagent to $targetPath"

$pathEntries = @($env:PATH -split [IO.Path]::PathSeparator)
if ($pathEntries -notcontains $installDir) {
    Write-Warning "Add $installDir to your PATH to run aagent from anywhere."
}

Write-Host "Run 'pwsh $targetPath --help' to get started."
