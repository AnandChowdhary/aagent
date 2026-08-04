$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$aagentScript = Join-Path $projectRoot "aagent.ps1"
$fakeProvider = Join-Path $projectRoot "tests/helpers/fake-provider.ps1"
$utf8 = [Text.UTF8Encoding]::new($false)

. $aagentScript

function Assert-ConfigEqual($Actual, $Expected, [string] $Message) {
    if ($Actual -ne $Expected) {
        throw "$Message (expected '$Expected', got '$Actual')"
    }
}

function Assert-ConfigContains([string] $Actual, [string] $Expected, [string] $Message) {
    if (-not $Actual.Contains($Expected)) {
        throw $Message
    }
}

function Invoke-AagentConfigProcess([string[]] $Arguments) {
    $pwsh = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $pwsh
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.ArgumentList.Add("-NoProfile")
    $startInfo.ArgumentList.Add("-File")
    $startInfo.ArgumentList.Add($aagentScript)
    foreach ($argument in $Arguments) {
        $startInfo.ArgumentList.Add($argument)
    }

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) {
        throw "Could not start aagent configuration process"
    }
    $process.StandardInput.Close()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    return [pscustomobject] @{
        Stdout = $stdout
        Stderr = $stderr
        Status = $process.ExitCode
    }
}

$testDir = Join-Path ([IO.Path]::GetTempPath()) ("aagent-config-" + [guid]::NewGuid().ToString("N"))
$environmentNames = @(
    "HOME", "XDG_CONFIG_HOME", "APPDATA", "PATH",
    "AAGENT_PROVIDER", "AAGENT_AUTH_POLICY", "AAGENT_PRIORITY", "AAGENT_ALLOW_LOCAL",
    "AAGENT_CLAUDE_BIN", "AAGENT_FAKE_RECORD_DIR", "AAGENT_FAKE_RUN_STATUS",
    "AAGENT_FAKE_RUN_STDOUT", "AAGENT_FAKE_RUN_STDERR"
)
$originalEnvironment = @{}
foreach ($name in $environmentNames) {
    $originalEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
}

try {
    $homeDir = Join-Path $testDir "home"
    $xdgDir = Join-Path $testDir "config with spaces"
    $appDataDir = Join-Path $testDir "appdata with spaces"
    $fakeBin = Join-Path $testDir "bin"
    $recordDir = Join-Path $testDir "records"
    $workDir = Join-Path $testDir "work"
    foreach ($directory in @($homeDir, $xdgDir, $appDataDir, $fakeBin, $recordDir, $workDir)) {
        [IO.Directory]::CreateDirectory($directory) | Out-Null
    }
    Copy-Item -LiteralPath $fakeProvider -Destination (Join-Path $fakeBin "claude.ps1")

    $env:HOME = $homeDir
    $env:XDG_CONFIG_HOME = $xdgDir
    $env:APPDATA = $appDataDir
    $env:PATH = "$fakeBin$([IO.Path]::PathSeparator)$($originalEnvironment['PATH'])"
    $env:AAGENT_FAKE_RECORD_DIR = $recordDir
    $env:AAGENT_FAKE_RUN_STATUS = "0"
    $env:AAGENT_FAKE_RUN_STDOUT = ""
    $env:AAGENT_FAKE_RUN_STDERR = ""
    Remove-Item Env:AAGENT_PROVIDER, Env:AAGENT_AUTH_POLICY, Env:AAGENT_PRIORITY, Env:AAGENT_ALLOW_LOCAL `
        -ErrorAction SilentlyContinue

    $unixPath = [IO.Path]::Combine($xdgDir, "aagent", "config")
    $windowsPath = [IO.Path]::Combine($appDataDir, "aagent", "config")
    Assert-ConfigEqual (Get-AagentConfigurationPath -Windows:$false) $unixPath "XDG config path differs."
    Assert-ConfigEqual (Get-AagentConfigurationPath -Windows:$true) $windowsPath "APPDATA config path differs."
    Remove-Item Env:APPDATA -ErrorAction SilentlyContinue
    Assert-ConfigEqual (Get-AagentConfigurationPath -Windows:$true) "" "Missing APPDATA behavior differs."
    $env:APPDATA = $appDataDir
    Remove-Item Env:XDG_CONFIG_HOME -ErrorAction SilentlyContinue
    Assert-ConfigEqual (Get-AagentConfigurationPath -Windows:$false) `
        ([IO.Path]::Combine($homeDir, ".config", "aagent", "config")) `
        "HOME fallback config path differs."
    $env:XDG_CONFIG_HOME = $xdgDir

    $configPath = Get-AagentConfigurationPath
    [IO.Directory]::CreateDirectory((Split-Path -Parent $configPath)) | Out-Null

    $result = Parse-AagentArguments -Arguments @("say hello")
    $result = Resolve-AagentConfiguration -Result $result
    Assert-ConfigEqual $result.Provider "" "Default provider differs."
    Assert-ConfigEqual $result.ProviderSource "default" "Default provider source differs."
    Assert-ConfigEqual $result.AuthPolicy "prefer-included" "Default auth policy differs."
    Assert-ConfigEqual $result.Priority "" "Default priority differs."
    Assert-ConfigEqual $result.AllowLocal "false" "Default allow-local differs."
    Assert-ConfigEqual $result.PriorityRole "tie-break-only" "Priority escaped its tie-break role."

    [IO.File]::WriteAllText(
        $configPath,
        "  # full-line comment`r`n provider = claude `r`n auth_policy = native`r`n" +
            " priority = claude, codex`r`n allow_local = true`r`n",
        $utf8
    )
    $result = Resolve-AagentConfiguration -Result (Parse-AagentArguments @("say hello"))
    Assert-ConfigEqual $result.Provider "claude" "Config provider differs."
    Assert-ConfigEqual $result.ProviderSource "config" "Config provider source differs."
    Assert-ConfigEqual $result.AuthPolicy "native" "Config auth policy differs."
    Assert-ConfigEqual $result.AuthPolicySource "config" "Config auth source differs."
    Assert-ConfigEqual $result.Priority "claude, codex" "Config priority differs."
    Assert-ConfigEqual $result.PrioritySource "config" "Config priority source differs."
    Assert-ConfigEqual $result.AllowLocal "true" "Config allow-local differs."
    Assert-ConfigEqual $result.AllowLocalSource "config" "Config allow-local source differs."

    $env:AAGENT_PROVIDER = "claude"
    $env:AAGENT_AUTH_POLICY = "prefer-included"
    $env:AAGENT_PRIORITY = "codex,claude"
    $env:AAGENT_ALLOW_LOCAL = "false"
    $result = Resolve-AagentConfiguration -Result (Parse-AagentArguments @("say hello"))
    Assert-ConfigEqual $result.ProviderSource "environment" "Environment provider source differs."
    Assert-ConfigEqual $result.AuthPolicy "prefer-included" "Environment auth precedence differs."
    Assert-ConfigEqual $result.Priority "codex,claude" "Environment priority precedence differs."
    Assert-ConfigEqual $result.AllowLocal "false" "Environment allow-local precedence differs."

    $result = Parse-AagentArguments @(
        "--provider", "claude",
        "--auth-policy", "native",
        "--priority", "claude,codex",
        "--allow-local", "true",
        "say hello"
    )
    $result = Resolve-AagentConfiguration -Result $result
    Assert-ConfigEqual $result.ProviderSource "cli" "CLI provider source differs."
    Assert-ConfigEqual $result.AuthPolicy "native" "CLI auth precedence differs."
    Assert-ConfigEqual $result.Priority "claude,codex" "CLI priority precedence differs."
    Assert-ConfigEqual $result.AllowLocal "true" "CLI allow-local precedence differs."

    $env:AAGENT_PROVIDER = "invalid-lower-precedence"
    $env:AAGENT_AUTH_POLICY = "invalid-lower-precedence"
    $env:AAGENT_PRIORITY = "invalid-lower-precedence"
    $env:AAGENT_ALLOW_LOCAL = "invalid-lower-precedence"
    $result = Parse-AagentArguments @(
        "--provider", "claude",
        "--auth-policy", "native",
        "--priority", "claude,codex",
        "--allow-local", "false",
        "say hello"
    )
    $result = Resolve-AagentConfiguration -Result $result
    Assert-ConfigEqual $result.Provider "claude" "CLI provider did not override the environment."
    Assert-ConfigEqual $result.AuthPolicy "native" "CLI auth did not override the environment."
    Assert-ConfigEqual $result.Priority "claude,codex" "CLI priority did not override the environment."
    Assert-ConfigEqual $result.AllowLocal "false" "CLI allow-local did not override the environment."

    Remove-Item Env:AAGENT_PROVIDER, Env:AAGENT_AUTH_POLICY, Env:AAGENT_PRIORITY, Env:AAGENT_ALLOW_LOCAL `
        -ErrorAction SilentlyContinue
    [IO.File]::WriteAllText($configPath, "future_option=opaque-secret-value`nprovider=claude`n", $utf8)
    $configuration = Read-AagentUserConfiguration
    Assert-ConfigEqual $configuration.Status $AagentExitOk "Normal unknown-key status differs."
    Assert-ConfigEqual $configuration.Warnings.Count 1 "Unknown-key warning count differs."
    Assert-ConfigContains $configuration.Warnings[0] "line 1" "Unknown-key warning lacks its line."
    Assert-ConfigContains $configuration.Warnings[0] "future_option" "Unknown-key warning lacks its safe key."
    if ($configuration.Warnings[0].Contains("opaque-secret-value")) {
        throw "Unknown-key warning exposed its value."
    }
    $configuration = Read-AagentUserConfiguration -Doctor:$true
    Assert-ConfigEqual $configuration.Status $AagentExitConfig "Doctor unknown-key status differs."
    Assert-ConfigContains $configuration.Error "future_option" "Doctor error lacks its safe key."
    if ($configuration.Error.Contains("opaque-secret-value")) {
        throw "Doctor error exposed its value."
    }

    Remove-Item -LiteralPath $configPath
    [IO.Directory]::CreateDirectory($configPath) | Out-Null
    $processResult = Invoke-AagentConfigProcess @("--provider", "claude", "say hello")
    Assert-ConfigEqual $processResult.Status $AagentExitConfig "Config-directory status differs."
    Remove-Item -LiteralPath $configPath

    $invalidCases = @(
        "missing separator",
        "=claude",
        "provider=",
        "provider=unknown-secret-provider",
        "auth_policy=automatic-secret-policy",
        "priority=claude,claude",
        "priority=claude,unknown-secret-provider",
        "priority=claude,",
        "allow_local=True",
        'provider="claude"',
        "provider=claude; New-Item config-marker",
        'provider=$(New-Item config-marker)',
        "provider=claude`nprovider=codex"
    )
    foreach ($invalid in $invalidCases) {
        [IO.File]::WriteAllText($configPath, $invalid, $utf8)
        $processResult = Invoke-AagentConfigProcess @("--provider", "claude", "say hello")
        Assert-ConfigEqual $processResult.Status $AagentExitConfig "Invalid config status differs."
        Assert-ConfigContains $processResult.Stderr "configuration" "Invalid config error is unclear."
        if (
            $processResult.Stderr.Contains("unknown-secret-provider") -or
            $processResult.Stderr.Contains("automatic-secret-policy")
        ) {
            throw "Invalid config error exposed a value."
        }
    }

    [IO.File]::WriteAllText($configPath, 'future_option=$(New-Item config-marker)', $utf8)
    $processResult = Invoke-AagentConfigProcess @("doctor")
    Assert-ConfigEqual $processResult.Status $AagentExitConfig "Injection config status differs."
    if (Test-Path -LiteralPath (Join-Path $projectRoot "config-marker")) {
        throw "Configuration content executed a command."
    }

    $longValue = "x" * 4097
    [IO.File]::WriteAllText($configPath, "provider=$longValue", $utf8)
    $processResult = Invoke-AagentConfigProcess @("--provider", "claude", "say hello")
    Assert-ConfigEqual $processResult.Status $AagentExitConfig "Long config status differs."
    Assert-ConfigContains $processResult.Stderr "4096" "Long config error lacks the safe limit."
    if ($processResult.Stderr.Contains($longValue)) {
        throw "Long config error exposed its value."
    }

    Remove-Item -LiteralPath $configPath
    $env:AAGENT_PRIORITY = "claude,claude"
    $processResult = Invoke-AagentConfigProcess @("--provider", "claude", "say hello")
    Assert-ConfigEqual $processResult.Status $AagentExitConfig "Invalid environment status differs."
    Assert-ConfigContains $processResult.Stderr "AAGENT_PRIORITY" "Environment error lacks its variable name."
    if ($processResult.Stderr.Contains("claude,claude")) {
        throw "Environment error exposed its value."
    }
    Remove-Item Env:AAGENT_PRIORITY

    $processResult = Invoke-AagentConfigProcess @(
        "--priority", "claude,claude", "--provider", "claude", "say hello"
    )
    Assert-ConfigEqual $processResult.Status $AagentExitUsage "Invalid CLI priority status differs."
    Assert-ConfigContains $processResult.Stderr "invalid --priority value" "CLI priority error differs."

    $env:AAGENT_CLAUDE_BIN = Join-Path $testDir "missing-claude"
    $env:AAGENT_PROVIDER = "claude"
    $processResult = Invoke-AagentConfigProcess @("say hello")
    Assert-ConfigEqual $processResult.Status $AagentExitUnavailable "Missing explicit provider status differs."
    Assert-ConfigContains $processResult.Stderr "selected via AAGENT_PROVIDER" `
        "Missing explicit provider did not explain its source."
    Remove-Item Env:AAGENT_CLAUDE_BIN, Env:AAGENT_PROVIDER

    [IO.File]::WriteAllText($configPath, "provider=claude`n", $utf8)
    $env:AAGENT_CLAUDE_BIN = Join-Path $testDir "missing-claude"
    $processResult = Invoke-AagentConfigProcess @("say hello")
    Assert-ConfigEqual $processResult.Status $AagentExitUnavailable "Missing config provider status differs."
    Assert-ConfigContains $processResult.Stderr "selected via user config" `
        "Missing config provider did not explain its source."
    Remove-Item Env:AAGENT_CLAUDE_BIN

    if (Test-Path -LiteralPath (Join-Path $recordDir "run.count")) {
        throw "A provider launched during configuration failures."
    }
    if (Test-Path -LiteralPath (Join-Path $projectRoot "config-marker")) {
        throw "A configuration injection marker exists."
    }

    Remove-Item -LiteralPath $configPath
    $projectConfig = Join-Path $workDir "aagent/config"
    [IO.Directory]::CreateDirectory((Split-Path -Parent $projectConfig)) | Out-Null
    [IO.File]::WriteAllText($projectConfig, 'provider=$(New-Item project-marker)', $utf8)
    Push-Location $workDir
    try {
        $result = Resolve-AagentConfiguration -Result (Parse-AagentArguments @("say hello"))
        Assert-ConfigEqual $result.Provider "" "Project-local config was loaded."
    } finally {
        Pop-Location
    }
    if (Test-Path -LiteralPath (Join-Path $workDir "project-marker")) {
        throw "Project-local configuration executed."
    }

    Write-Output "Configuration PowerShell tests passed."
} finally {
    foreach ($name in $environmentNames) {
        $value = $originalEnvironment[$name]
        if ($null -eq $value) {
            [Environment]::SetEnvironmentVariable($name, $null, "Process")
        } else {
            [Environment]::SetEnvironmentVariable($name, $value, "Process")
        }
    }
    Remove-Item -LiteralPath $testDir -Recurse -Force -ErrorAction SilentlyContinue
}
