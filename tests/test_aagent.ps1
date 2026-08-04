$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$aagentScript = Join-Path $projectRoot "aagent.ps1"
$installScript = Join-Path $projectRoot "install.ps1"
$fakeProvider = Join-Path $projectRoot "tests/helpers/fake-provider.ps1"
$parserTest = Join-Path $projectRoot "tests/test_parser.ps1"
$discoveryTest = Join-Path $projectRoot "tests/test_discovery.ps1"
$launchTest = Join-Path $projectRoot "tests/test_launch.ps1"
$utf8 = [Text.UTF8Encoding]::new($false)

function Assert-Equal($Actual, $Expected, [string] $Message) {
    if ($Actual -ne $Expected) {
        throw "$Message (expected '$Expected', got '$Actual')"
    }
}

function Assert-Contains([string] $Value, [string] $Expected, [string] $Message) {
    if (-not $Value.Contains($Expected)) {
        throw $Message
    }
}

function Assert-FileContains([string] $Path, [string] $Expected, [string] $Message) {
    $lines = [IO.File]::ReadAllLines($Path, $utf8)
    if ($Expected -notin $lines) {
        throw $Message
    }
}

function ConvertTo-Hex([string] $Value) {
    return [Convert]::ToHexString($utf8.GetBytes($Value)).ToLowerInvariant()
}

function Assert-PowerShellSyntax([string] $Path) {
    $tokens = $null
    $errors = $null
    [Management.Automation.Language.Parser]::ParseFile(
        (Resolve-Path -LiteralPath $Path),
        [ref] $tokens,
        [ref] $errors
    ) | Out-Null

    if ($errors.Count -gt 0) {
        throw "PowerShell syntax check failed for ${Path}: $($errors -join '; ')"
    }
}

function Invoke-FakeProvider {
    param(
        [string] $Path,
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
    $startInfo.ArgumentList.Add($Path)
    foreach ($argument in $Arguments) {
        $startInfo.ArgumentList.Add($argument)
    }

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) {
        throw "Could not start fake provider at $Path"
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

Assert-PowerShellSyntax $aagentScript
Assert-PowerShellSyntax $installScript
Assert-PowerShellSyntax $fakeProvider
Assert-PowerShellSyntax $parserTest
Assert-PowerShellSyntax $discoveryTest
Assert-PowerShellSyntax $launchTest
Assert-PowerShellSyntax $PSCommandPath

$testDir = Join-Path ([IO.Path]::GetTempPath()) ("aagent-tests-" + [guid]::NewGuid().ToString("N"))
$originalEnvironment = @{}
$environmentNames = @(
    "HOME",
    "XDG_CONFIG_HOME",
    "APPDATA",
    "PATH",
    "AAGENT_FAKE_RECORD_DIR",
    "AAGENT_FAKE_INVOCATION_KIND",
    "AAGENT_FAKE_RUN_STDOUT",
    "AAGENT_FAKE_RUN_STDERR",
    "AAGENT_FAKE_RUN_STATUS",
    "AAGENT_FAKE_PROBE_STDOUT",
    "AAGENT_FAKE_PROBE_STDERR",
    "AAGENT_FAKE_PROBE_STATUS",
    "AAGENT_FAKE_PROBE_DELAY",
    "AAGENT_FAKE_ENV_PRESENCE",
    "AAGENT_FAKE_ENV_CAPTURE",
    "AAGENT_SAFE_SENTINEL",
    "ANTHROPIC_API_KEY",
    "CODEX_API_KEY",
    "AAGENT_SOURCE",
    "INSTALL_DIR"
)

foreach ($name in $environmentNames) {
    $originalEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
}

try {
    $homeDir = Join-Path $testDir "home"
    $configDir = Join-Path $testDir "config"
    $appDataDir = Join-Path $testDir "appdata"
    $fakeBin = Join-Path $testDir "bin"
    $recordDir = Join-Path $testDir "records"
    $workDir = Join-Path $testDir "work"
    foreach ($directory in @($homeDir, $configDir, $appDataDir, $fakeBin, $recordDir, $workDir)) {
        [IO.Directory]::CreateDirectory($directory) | Out-Null
    }

    $expectedWorkDir = $workDir
    if (-not $IsWindows) {
        Push-Location $workDir
        try {
            $expectedWorkDir = (& /bin/pwd -P).Trim()
        } finally {
            Pop-Location
        }
    }

    $env:HOME = $homeDir
    $env:XDG_CONFIG_HOME = $configDir
    $env:APPDATA = $appDataDir
    $env:PATH = "$fakeBin$([IO.Path]::PathSeparator)$($originalEnvironment['PATH'])"

    $tierOneProviders = @("claude", "codex", "opencode", "amp", "gemini")
    foreach ($provider in $tierOneProviders) {
        Copy-Item -LiteralPath $fakeProvider -Destination (Join-Path $fakeBin "$provider.ps1")
    }

    $helpOutput = (& pwsh -NoProfile -File $aagentScript --help | Out-String).Trim()
    Assert-Contains $helpOutput "Run any CLI coding agent with a single command." "Help is missing the description."
    Assert-Contains $helpOutput "Usage:" "Help is missing usage."
    Assert-Contains $helpOutput "--help" "Help is missing the help option."

    $shortHelpOutput = (& pwsh -NoProfile -File $aagentScript -h | Out-String).Trim()
    Assert-Equal $shortHelpOutput $helpOutput "-h and --help output differ."

    $defaultOutput = (& pwsh -NoProfile -File $aagentScript 2>&1 | Out-String)
    $defaultStatus = $LASTEXITCODE
    Assert-Equal $defaultStatus 64 "Running without input should use the wrapper usage status."
    Assert-Contains $defaultOutput "a non-empty prompt or piped stdin is required" "Missing input error is absent."

    $unknownOutput = (& pwsh -NoProfile -File $aagentScript --unknown 2>&1 | Out-String)
    $unknownStatus = $LASTEXITCODE
    Assert-Equal $unknownStatus 64 "Unknown arguments should use the wrapper usage status."
    Assert-Contains $unknownOutput "unknown option: --unknown" "Unknown option error is missing."

    $env:AAGENT_SOURCE = $aagentScript
    $env:INSTALL_DIR = Join-Path $testDir "installed-bin"
    & $installScript | Out-Null

    $installedAagent = Join-Path $env:INSTALL_DIR "aagent.ps1"
    $installedHelpOutput = (& pwsh -NoProfile -File $installedAagent --help | Out-String).Trim()
    Assert-Equal $installedHelpOutput $helpOutput "Installed executable help differs."

    $env:AAGENT_FAKE_RECORD_DIR = $recordDir
    $env:AAGENT_FAKE_RUN_STDOUT = "run-output"
    $env:AAGENT_FAKE_RUN_STDERR = "run-error"
    $env:AAGENT_FAKE_RUN_STATUS = "0"
    $env:AAGENT_FAKE_ENV_PRESENCE = "ANTHROPIC_API_KEY,CODEX_API_KEY"
    $env:AAGENT_FAKE_ENV_CAPTURE = "AAGENT_SAFE_SENTINEL"
    $env:AAGENT_SAFE_SENTINEL = "safe-value"
    $env:ANTHROPIC_API_KEY = "must-not-be-recorded"
    Remove-Item Env:CODEX_API_KEY -ErrorAction SilentlyContinue

    $runIndex = 0
    foreach ($provider in $tierOneProviders) {
        $runIndex++
        $providerPath = Join-Path $fakeBin "$provider.ps1"
        $result = Invoke-FakeProvider -Path $providerPath -Arguments @(
            "say hello",
            '$(touch should-not-exist)'
        ) -Stdin "context`n" -WorkingDirectory $workDir

        Assert-Equal $result.Status 0 "$provider run status differs."
        Assert-Equal $result.Stdout "run-output" "$provider run stdout differs."
        Assert-Equal $result.Stderr "run-error" "$provider run stderr differs."

        $record = Join-Path $recordDir "$provider.run.$runIndex.record"
        if (-not (Test-Path -LiteralPath $record)) {
            throw "$provider did not create its run record."
        }
        Assert-FileContains $record "protocol=1" "$provider record protocol is missing."
        Assert-FileContains $record "kind=run" "$provider record kind differs."
        Assert-FileContains $record "argc=2" "$provider argc differs."
        Assert-FileContains $record "arg.0.hex=$(ConvertTo-Hex 'say hello')" "$provider first argument differs."
        Assert-FileContains $record "arg.1.hex=$(ConvertTo-Hex '$(touch should-not-exist)')" "$provider hostile argument differs."
        Assert-FileContains $record "stdin.hex=$(ConvertTo-Hex "context`n")" "$provider stdin differs."
        Assert-FileContains $record "cwd.hex=$(ConvertTo-Hex $expectedWorkDir)" "$provider cwd differs."
        Assert-FileContains $record "env.ANTHROPIC_API_KEY=present" "$provider did not record API-key presence."
        Assert-FileContains $record "env.CODEX_API_KEY=absent" "$provider did not record missing API-key state."
        Assert-FileContains $record "env.AAGENT_SAFE_SENTINEL.hex=$(ConvertTo-Hex 'safe-value')" "$provider safe sentinel differs."
    }

    Assert-Equal ([IO.File]::ReadAllText((Join-Path $recordDir "run.count"), $utf8).Trim()) "5" "Run launch count differs."
    $recordText = (Get-ChildItem -LiteralPath $recordDir -Filter "*.record" | ForEach-Object {
        [IO.File]::ReadAllText($_.FullName, $utf8)
    }) -join "`n"
    if ($recordText.Contains("must-not-be-recorded")) {
        throw "Fake-provider records contain an environment value requested by presence only."
    }
    if (Test-Path -LiteralPath (Join-Path $workDir "should-not-exist")) {
        throw "Hostile argument was evaluated."
    }

    $env:AAGENT_FAKE_PROBE_STDOUT = '{"loggedIn":true}'
    $env:AAGENT_FAKE_PROBE_STDERR = ""
    $env:AAGENT_FAKE_PROBE_STATUS = "0"
    $result = Invoke-FakeProvider -Path (Join-Path $fakeBin "claude.ps1") -Arguments @(
        "auth",
        "status",
        "--json"
    ) -Stdin "" -WorkingDirectory $workDir
    Assert-Equal $result.Stdout '{"loggedIn":true}' "Natural Claude probe response differs."
    Assert-FileContains (Join-Path $recordDir "claude.probe.1.record") "kind=probe" "Claude status was not classified as a probe."

    $env:AAGENT_FAKE_INVOCATION_KIND = "probe"
    $probeCases = @(
        '{}',
        'not-json',
        '{"token":"seeded-secret"}',
        '{"email":"person@example.com"}',
        '{"loggedIn":true,"subscriptionType":null}'
    )

    foreach ($response in $probeCases) {
        $env:AAGENT_FAKE_PROBE_STDOUT = $response
        $result = Invoke-FakeProvider -Path (Join-Path $fakeBin "gemini.ps1") -Arguments @(
            "settings"
        ) -Stdin "" -WorkingDirectory $workDir
        Assert-Equal $result.Stdout $response "Probe fixture did not preserve a response case."
    }

    $env:AAGENT_FAKE_PROBE_DELAY = "0.01"
    $env:AAGENT_FAKE_PROBE_STDOUT = "delayed"
    $result = Invoke-FakeProvider -Path (Join-Path $fakeBin "amp.ps1") -Arguments @(
        "status"
    ) -Stdin "" -WorkingDirectory $workDir
    Assert-Equal $result.Stdout "delayed" "Delayed probe response differs."
    $env:AAGENT_FAKE_PROBE_DELAY = "0"

    $env:AAGENT_FAKE_PROBE_STDOUT = ""
    $env:AAGENT_FAKE_PROBE_STDERR = "probe-failed"
    $env:AAGENT_FAKE_PROBE_STATUS = "23"
    $result = Invoke-FakeProvider -Path (Join-Path $fakeBin "opencode.ps1") -Arguments @(
        "auth",
        "list"
    ) -Stdin "" -WorkingDirectory $workDir
    Assert-Equal $result.Status 23 "Probe fixture did not preserve a non-zero status."
    Assert-Equal $result.Stderr "probe-failed" "Probe failure stderr differs."

    Assert-Equal ([IO.File]::ReadAllText((Join-Path $recordDir "probe.count"), $utf8).Trim()) "8" "Probe launch count differs."
    Assert-Equal ([IO.File]::ReadAllText((Join-Path $recordDir "run.count"), $utf8).Trim()) "5" "Probe fixtures changed the run launch count."

    & $parserTest
    & $discoveryTest
    & $launchTest
} finally {
    foreach ($name in $environmentNames) {
        $originalValue = $originalEnvironment[$name]
        if ($null -eq $originalValue) {
            [Environment]::SetEnvironmentVariable($name, $null, "Process")
        } else {
            [Environment]::SetEnvironmentVariable($name, $originalValue, "Process")
        }
    }

    if (Test-Path -LiteralPath $testDir) {
        Remove-Item -LiteralPath $testDir -Recurse -Force
    }
}

Write-Host "All PowerShell tests passed."
exit 0
