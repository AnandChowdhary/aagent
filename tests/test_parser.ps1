$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$aagentScript = Join-Path $projectRoot "aagent.ps1"
$fakeProvider = Join-Path $projectRoot "tests/helpers/fake-provider.ps1"

. $aagentScript

function Assert-ParserEqual($Actual, $Expected, [string] $Message) {
    if ($Actual -ne $Expected) {
        throw "$Message (expected '$Expected', got '$Actual')"
    }
}

function Assert-ParserError([string] $Expected, [string[]] $Arguments) {
    $result = Parse-AagentArguments -Arguments $Arguments
    Assert-ParserEqual $result.Status $AagentExitUsage "Parse error status differs for: $Arguments"
    Assert-ParserEqual $result.Error $Expected "Parse error message differs for: $Arguments"
}

function Invoke-AagentProcess {
    param(
        [string[]] $Arguments,
        [string] $Stdin,
        [string] $WorkingDirectory
    )

    $pwsh = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $pwsh
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.ArgumentList.Add("-NoProfile")
    $startInfo.ArgumentList.Add("-File")
    $startInfo.ArgumentList.Add($aagentScript)
    foreach ($argument in $Arguments) {
        $startInfo.ArgumentList.Add($argument)
    }

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) {
        throw "Could not start aagent parser process"
    }
    $process.StandardInput.Write($Stdin)
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

$testDir = Join-Path ([IO.Path]::GetTempPath()) ("aagent-parser-" + [guid]::NewGuid().ToString("N"))
$originalHome = [Environment]::GetEnvironmentVariable("HOME", "Process")
$originalXdg = [Environment]::GetEnvironmentVariable("XDG_CONFIG_HOME", "Process")
$originalAppData = [Environment]::GetEnvironmentVariable("APPDATA", "Process")
$originalPath = $env:PATH
$originalRecordDir = [Environment]::GetEnvironmentVariable("AAGENT_FAKE_RECORD_DIR", "Process")
$overrideNames = @("AAGENT_CLAUDE_BIN", "AAGENT_CODEX_BIN", "AAGENT_OPENCODE_BIN", "AAGENT_COPILOT_BIN", "AAGENT_GEMINI_BIN", "AAGENT_AMP_BIN")
$originalOverrides = @{}
foreach ($name in $overrideNames) {
    $originalOverrides[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
}

try {
    $homeDir = Join-Path $testDir "home"
    $configDir = Join-Path $testDir "config"
    $appDataDir = Join-Path $testDir "appdata"
    $fakeBin = Join-Path $testDir "bin"
    $recordDir = Join-Path $testDir "records"
    $workDir = Join-Path $testDir "work with spaces"
    foreach ($directory in @($homeDir, $configDir, $appDataDir, $fakeBin, $recordDir, $workDir)) {
        [IO.Directory]::CreateDirectory($directory) | Out-Null
    }
    foreach ($provider in @("claude", "codex", "opencode", "amp", "gemini")) {
        Copy-Item -LiteralPath $fakeProvider -Destination (Join-Path $fakeBin "$provider.ps1")
    }

    $env:HOME = $homeDir
    $env:XDG_CONFIG_HOME = $configDir
    $env:APPDATA = $appDataDir
    $env:PATH = "$fakeBin$([IO.Path]::PathSeparator)$originalPath"
    $env:AAGENT_FAKE_RECORD_DIR = $recordDir

    $result = Parse-AagentArguments -Arguments @(
        "-P", "claude",
        "--model", "sonnet",
        "-C", $workDir,
        "--auth-policy", "native",
        "--priority", "claude,codex",
        "--allow-local", "true",
        "--dry-run",
        "--quiet",
        "say", "hello",
        "--", "--sandbox", "workspace-write"
    )

    Assert-ParserEqual $result.Status $AagentExitOk "Run parse status differs."
    Assert-ParserEqual $result.Command "run" "Run command differs."
    Assert-ParserEqual $result.Provider "claude" "Provider differs."
    Assert-ParserEqual $result.Model "sonnet" "Model differs."
    Assert-ParserEqual $result.AuthPolicy "native" "Auth policy differs."
    Assert-ParserEqual $result.Priority "claude,codex" "Priority differs."
    Assert-ParserEqual $result.AllowLocal "true" "Allow-local differs."
    Assert-ParserEqual $result.DryRun $true "Dry-run flag differs."
    Assert-ParserEqual $result.Quiet $true "Quiet flag differs."
    Assert-ParserEqual $result.Cwd (Resolve-Path -LiteralPath $workDir).ProviderPath "Resolved cwd differs."
    Assert-ParserEqual $result.PromptArguments.Count 2 "Prompt argument count differs."
    Assert-ParserEqual $result.PromptArguments[0] "say" "First prompt argument differs."
    Assert-ParserEqual $result.PromptArguments[1] "hello" "Second prompt argument differs."
    Assert-ParserEqual $result.NativeArguments.Count 2 "Native argument count differs."
    Assert-ParserEqual $result.NativeArguments[0] "--sandbox" "First native argument differs."
    Assert-ParserEqual $result.NativeArguments[1] "workspace-write" "Second native argument differs."

    $result = Resolve-AagentInput -Result $result -StdinAvailable $false -StdinData ""
    Assert-ParserEqual $result.Prompt "say hello" "Joined prompt differs."
    Assert-ParserEqual $result.InputMode "prompt" "Prompt-only input mode differs."

    $result = Parse-AagentArguments -Arguments @("providers")
    Assert-ParserEqual $result.Command "providers" "Providers subcommand differs."
    $result = Parse-AagentArguments -Arguments @("doctor")
    Assert-ParserEqual $result.Command "doctor" "Doctor subcommand differs."
    Assert-ParserEqual $result.DoctorProvider "" "Empty doctor provider differs."
    $result = Parse-AagentArguments -Arguments @("doctor", "claude")
    Assert-ParserEqual $result.DoctorProvider "claude" "Doctor provider differs."
    $result = Parse-AagentArguments -Arguments @("--help", "ignored", "arguments")
    Assert-ParserEqual $result.Command "help" "Help command differs."
    $result = Parse-AagentArguments -Arguments @("--version")
    Assert-ParserEqual $result.Command "version" "Version command differs."

    $result = Parse-AagentArguments -Arguments @("explain", "providers", "doctor")
    $result = Resolve-AagentInput -Result $result -StdinAvailable $false -StdinData ""
    Assert-ParserEqual $result.Command "run" "Subcommand word inside a prompt changed the command."
    Assert-ParserEqual $result.Prompt "explain providers doctor" "Subcommand words inside a prompt differ."

    $result = Parse-AagentArguments -Arguments @("say", "--model", "sonnet", "hello")
    $result = Resolve-AagentInput -Result $result -StdinAvailable $false -StdinData ""
    Assert-ParserEqual $result.Model "sonnet" "Wrapper option after prompt text differs."
    Assert-ParserEqual $result.Prompt "say hello" "Prompt around a wrapper option differs."

    Assert-ParserError "unknown option: --unknown" @("--unknown")
    Assert-ParserError "unknown option: --unknown" @("prompt", "--unknown")
    Assert-ParserError "option --provider requires a value" @("--provider")
    Assert-ParserError "option --model requires a value" @("--model", "")
    Assert-ParserError "option --cwd requires a value" @("--cwd")
    Assert-ParserError "option --auth-policy requires a value" @("--auth-policy")
    Assert-ParserError "invalid authentication policy: cheapest" @("--auth-policy", "cheapest", "prompt")
    Assert-ParserError "option --priority requires a value" @("--priority")
    Assert-ParserError "option --allow-local requires a value" @("--allow-local")
    Assert-ParserError "invalid --allow-local value" @("--allow-local", "yes", "prompt")
    Assert-ParserError "providers does not accept arguments" @("providers", "extra")
    Assert-ParserError "doctor accepts at most one provider" @("doctor", "claude", "extra")
    Assert-ParserError "unknown option: --bad" @("doctor", "--bad")
    Assert-ParserError "working directory does not exist: $(Join-Path $testDir 'missing')" @(
        "--cwd", (Join-Path $testDir "missing"), "prompt"
    )

    $result = Parse-AagentArguments -Arguments @("stdin prompt")
    $result = Resolve-AagentInput -Result $result -StdinAvailable $true -StdinData "context`n`n"
    Assert-ParserEqual $result.InputMode "both" "Prompt-plus-stdin mode differs."
    Assert-ParserEqual $result.Stdin "context`n`n" "Prompt-plus-stdin data differs."

    $result = Parse-AagentArguments -Arguments @()
    $result = Resolve-AagentInput -Result $result -StdinAvailable $true -StdinData "stdin only`n"
    Assert-ParserEqual $result.InputMode "stdin" "Stdin-only mode differs."
    Assert-ParserEqual $result.Stdin "stdin only`n" "Stdin-only data differs."

    $result = Parse-AagentArguments -Arguments @("prompt only")
    $result = Resolve-AagentInput -Result $result -StdinAvailable $true -StdinData ""
    Assert-ParserEqual $result.InputMode "prompt" "Empty redirected stdin changed prompt-only mode."

    $result = Parse-AagentArguments -Arguments @()
    $result = Resolve-AagentInput -Result $result -StdinAvailable $false -StdinData ""
    Assert-ParserEqual $result.Status $AagentExitUsage "Missing input status differs."
    Assert-ParserEqual $result.Error "a non-empty prompt or piped stdin is required" "Missing input message differs."

    $result = Parse-AagentArguments -Arguments @("")
    $result = Resolve-AagentInput -Result $result -StdinAvailable $true -StdinData "stdin must not rescue an empty instruction`n"
    Assert-ParserEqual $result.Status $AagentExitUsage "Empty prompt status differs."
    Assert-ParserEqual $result.Error "prompt must not be empty" "Empty prompt message differs."

    $result = Parse-AagentArguments -Arguments @()
    $result = Resolve-AagentInput -Result $result -StdinAvailable $true -StdinData "--leading-dash prompt`n"
    Assert-ParserEqual $result.InputMode "stdin" "Leading-dash stdin mode differs."
    Assert-ParserEqual $result.Stdin "--leading-dash prompt`n" "Leading-dash stdin differs."

    $result = Parse-AagentArguments -Arguments @(
        "literal",
        "semi; New-Item $testDir/evaluated",
        "pipe | New-Item $testDir/evaluated",
        "redirect > $testDir/evaluated",
        '$(New-Item marker)',
        '`New-Item marker`',
        "*.md",
        "line one`nline two",
        "tab`tvalue",
        "héllo 🌍",
        "quote ' `" value",
        "crlf`r`nvalue",
        "--",
        "--literal-native",
        "--"
    )
    $result = Resolve-AagentInput -Result $result -StdinAvailable $false -StdinData ""
    Assert-ParserEqual $result.PromptArguments.Count 12 "Hostile prompt argument count differs."
    Assert-ParserEqual $result.PromptArguments[4] '$(New-Item marker)' "Subexpression text differs."
    Assert-ParserEqual $result.PromptArguments[7] "line one`nline two" "Multiline prompt argument differs."
    Assert-ParserEqual $result.PromptArguments[9] "héllo 🌍" "Unicode prompt argument differs."
    Assert-ParserEqual $result.PromptArguments[10] "quote ' `" value" "Quoted prompt argument differs."
    Assert-ParserEqual $result.PromptArguments[11] "crlf`r`nvalue" "CRLF prompt argument differs."
    Assert-ParserEqual $result.NativeArguments[0] "--literal-native" "Literal separator native argument differs."
    Assert-ParserEqual $result.NativeArguments[1] "--" "Literal native double dash differs."
    if (Test-Path -LiteralPath (Join-Path $testDir "evaluated")) {
        throw "Hostile parser input was evaluated."
    }

    $processResult = Invoke-AagentProcess -Arguments @("--help") -Stdin "" -WorkingDirectory $workDir
    Assert-ParserEqual $processResult.Status 0 "Public help status differs."
    if (-not $processResult.Stdout.Contains("aagent doctor [PROVIDER]")) {
        throw "Public help omits doctor."
    }
    if (-not $processResult.Stdout.Contains("--auth-policy")) {
        throw "Public help omits auth policy."
    }
    if (-not $processResult.Stdout.Contains("--priority")) {
        throw "Public help omits priority."
    }
    if (-not $processResult.Stdout.Contains("--allow-local")) {
        throw "Public help omits allow-local."
    }

    $processResult = Invoke-AagentProcess -Arguments @("--version") -Stdin "" -WorkingDirectory $workDir
    Assert-ParserEqual $processResult.Stdout.Trim() "aagent $AagentVersion" "Public version differs."

    foreach ($name in $overrideNames) {
        [Environment]::SetEnvironmentVariable($name, (Join-Path $testDir "missing/$name"), "Process")
    }

    $processResult = Invoke-AagentProcess -Arguments @("--unknown") -Stdin "" -WorkingDirectory $workDir
    Assert-ParserEqual $processResult.Status $AagentExitUsage "Public unknown-option status differs."
    $processResult = Invoke-AagentProcess -Arguments @() -Stdin "" -WorkingDirectory $workDir
    Assert-ParserEqual $processResult.Status $AagentExitUsage "Public empty-stdin status differs."
    $processResult = Invoke-AagentProcess -Arguments @("valid prompt") -Stdin "" -WorkingDirectory $workDir
    Assert-ParserEqual $processResult.Status $AagentExitUnavailable "Valid parsed input should reach automatic no-provider handling."
    $processResult = Invoke-AagentProcess -Arguments @() -Stdin "stdin only`n" -WorkingDirectory $workDir
    Assert-ParserEqual $processResult.Status $AagentExitUnavailable "Stdin-only input should reach automatic no-provider handling."
    $processResult = Invoke-AagentProcess -Arguments @("instruction") -Stdin "context`n" -WorkingDirectory $workDir
    Assert-ParserEqual $processResult.Status $AagentExitUnavailable "Prompt-plus-stdin should reach automatic no-provider handling."

    if (Test-Path -LiteralPath (Join-Path $recordDir "run.count")) {
        throw "Parser paths launched a provider."
    }
    if (Test-Path -LiteralPath (Join-Path $recordDir "probe.count")) {
        throw "Parser paths launched an authentication probe."
    }
} finally {
    [Environment]::SetEnvironmentVariable("HOME", $originalHome, "Process")
    [Environment]::SetEnvironmentVariable("XDG_CONFIG_HOME", $originalXdg, "Process")
    [Environment]::SetEnvironmentVariable("APPDATA", $originalAppData, "Process")
    [Environment]::SetEnvironmentVariable("PATH", $originalPath, "Process")
    [Environment]::SetEnvironmentVariable("AAGENT_FAKE_RECORD_DIR", $originalRecordDir, "Process")
    foreach ($name in $overrideNames) {
        [Environment]::SetEnvironmentVariable($name, $originalOverrides[$name], "Process")
    }
    if (Test-Path -LiteralPath $testDir) {
        Remove-Item -LiteralPath $testDir -Recurse -Force
    }
}

Write-Host "Parser PowerShell tests passed."
