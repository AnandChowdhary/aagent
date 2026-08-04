$ErrorActionPreference = "Stop"

$installDir = if ($env:INSTALL_DIR) { $env:INSTALL_DIR } else { Join-Path $HOME ".local/bin" }
$agentSource = if ($env:AGENT_SOURCE) { $env:AGENT_SOURCE } else { "https://raw.githubusercontent.com/AnandChowdhary/agent/main/agent.ps1" }
$targetPath = Join-Path $installDir "agent.ps1"

Write-Host "Installing Agent..."
New-Item -ItemType Directory -Force -Path $installDir | Out-Null

if (Test-Path -LiteralPath $agentSource -PathType Leaf) {
    Copy-Item -LiteralPath $agentSource -Destination $targetPath -Force
} else {
    Invoke-WebRequest -Uri $agentSource -OutFile $targetPath
}

Write-Host "Installed Agent to $targetPath"

$pathEntries = @($env:PATH -split [IO.Path]::PathSeparator)
if ($pathEntries -notcontains $installDir) {
    Write-Warning "Add $installDir to your PATH to run Agent from anywhere."
}

Write-Host "Run 'pwsh $targetPath --help' to get started."
