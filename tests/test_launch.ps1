param(
    [string] $DriverConfig = ""
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$aagentScript = Join-Path $projectRoot "aagent.ps1"
$fakeProvider = Join-Path $projectRoot "tests/helpers/fake-provider.ps1"
$utf8 = [Text.UTF8Encoding]::new($false)

. $aagentScript

if (-not [string]::IsNullOrEmpty($DriverConfig)) {
    $config = Get-Content -LiteralPath $DriverConfig -Raw | ConvertFrom-Json
    $plan = New-AagentLaunchPlan `
        -Executable $config.Executable `
        -Arguments ([string[]] $config.Arguments) `
        -WorkingDirectory $config.WorkingDirectory `
        -StdinMode $config.StdinMode `
        -Stdin $config.Stdin `
        -InputDescription $config.InputDescription
    $plan.Provider = $config.Provider
    $plan.Reason = $config.Reason
    $plan.Notice = $config.Notice
    Set-AagentLaunchDisplayArguments $plan ([string[]] $config.DisplayArguments)

    foreach ($entry in $config.EnvironmentSet.PSObject.Properties) {
        Set-AagentLaunchEnvironment $plan $entry.Name ([string] $entry.Value)
    }
    foreach ($name in [string[]] $config.EnvironmentUnset) {
        Remove-AagentLaunchEnvironment $plan $name
    }

    exit (Invoke-AagentLaunchPlan -Plan $plan -DryRun:$config.DryRun -Quiet:$config.Quiet)
}

function Assert-LaunchEqual($Actual, $Expected, [string] $Message) {
    if ($Actual -ne $Expected) {
        throw "$Message (expected '$Expected', got '$Actual')"
    }
}

function Assert-LaunchContains([string] $Value, [string] $Expected, [string] $Message) {
    if (-not $Value.Contains($Expected)) {
        throw $Message
    }
}

function Assert-LaunchFileLine([string] $Path, [string] $Expected, [string] $Message) {
    if ($Expected -notin [IO.File]::ReadAllLines($Path, $utf8)) {
        throw $Message
    }
}

function ConvertTo-LaunchHex([AllowEmptyString()][string] $Value) {
    return [Convert]::ToHexString($utf8.GetBytes($Value)).ToLowerInvariant()
}

function Invoke-LaunchDriver(
    $Config,
    [string] $ConfigPath,
    [AllowNull()]
    [string] $DriverStdin = $null
) {
    [IO.File]::WriteAllText($ConfigPath, ($Config | ConvertTo-Json -Depth 8), $utf8)
    $pwsh = (Get-Process -Id $PID).Path
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $pwsh
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    if ($null -ne $DriverStdin) {
        $startInfo.RedirectStandardInput = $true
        $startInfo.StandardInputEncoding = [Text.UTF8Encoding]::new($false)
    }
    $startInfo.ArgumentList.Add("-NoProfile")
    $startInfo.ArgumentList.Add("-File")
    $startInfo.ArgumentList.Add($PSCommandPath)
    $startInfo.ArgumentList.Add("-DriverConfig")
    $startInfo.ArgumentList.Add($ConfigPath)

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) {
        throw "Could not start the PowerShell launch driver."
    }
    if ($null -ne $DriverStdin) {
        $process.StandardInput.Write($DriverStdin)
        $process.StandardInput.Close()
    }
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    $status = $process.ExitCode
    $process.Dispose()

    return [pscustomobject] @{
        Stdout = $stdout
        Stderr = $stderr
        Status = $status
    }
}

function New-LaunchConfig(
    [string] $WorkingDirectory,
    [string[]] $Arguments,
    [string[]] $DisplayArguments,
    [string] $StdinMode = "data",
    [string] $Stdin = "",
    [string] $InputDescription = "both"
) {
    return [ordered] @{
        Executable = $fakeProvider
        Arguments = $Arguments
        WorkingDirectory = $WorkingDirectory
        StdinMode = $StdinMode
        Stdin = $Stdin
        InputDescription = $InputDescription
        EnvironmentSet = [ordered] @{ AAGENT_TEST_CHILD_SET = "child-secret-value" }
        EnvironmentUnset = @("AAGENT_TEST_CHILD_UNSET")
        DisplayArguments = $DisplayArguments
        Provider = "generic"
        Reason = "contract test"
        Notice = "using generic fake provider"
        DryRun = $false
        Quiet = $false
    }
}

$testDir = Join-Path ([IO.Path]::GetTempPath()) ("aagent-launch-" + [guid]::NewGuid().ToString("N"))
$environmentNames = @(
    "AAGENT_FAKE_RECORD_DIR",
    "AAGENT_FAKE_PROVIDER",
    "AAGENT_FAKE_INVOCATION_KIND",
    "AAGENT_FAKE_ENV_PRESENCE",
    "AAGENT_FAKE_ENV_CAPTURE",
    "AAGENT_FAKE_RUN_STDOUT",
    "AAGENT_FAKE_RUN_STDERR",
    "AAGENT_FAKE_RUN_STATUS",
    "AAGENT_FAKE_RUN_DELAY",
    "AAGENT_TEST_CHILD_SET",
    "AAGENT_TEST_CHILD_UNSET"
)
$originalEnvironment = @{}
foreach ($name in $environmentNames) {
    $originalEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
}
$originalLocation = (Get-Location).ProviderPath

try {
    $recordDir = Join-Path $testDir "records"
    $workDir = Join-Path $testDir "working directory 🌍"
    [IO.Directory]::CreateDirectory($recordDir) | Out-Null
    [IO.Directory]::CreateDirectory($workDir) | Out-Null
    $expectedWorkDir = $workDir
    if (-not $IsWindows) {
        Push-Location $workDir
        try {
            $expectedWorkDir = (& /bin/pwd -P).Trim()
        } finally {
            Pop-Location
        }
    }

    $env:AAGENT_FAKE_RECORD_DIR = $recordDir
    $env:AAGENT_FAKE_PROVIDER = "generic"
    $env:AAGENT_FAKE_INVOCATION_KIND = "run"
    $env:AAGENT_FAKE_ENV_PRESENCE = "AAGENT_TEST_CHILD_SET,AAGENT_TEST_CHILD_UNSET"
    $env:AAGENT_FAKE_ENV_CAPTURE = "AAGENT_TEST_CHILD_SET"
    $env:AAGENT_TEST_CHILD_SET = "parent-value"
    $env:AAGENT_TEST_CHILD_UNSET = "parent-only"

    $hostileArguments = @(
        "fixed",
        "space value",
        "single'quote",
        'double"quote',
        '$(New-Item launch-should-not-exist)',
        "*?[abc]",
        "semi;pipe|redirect>file",
        "line one`nline two",
        "Unicode 🌍",
        "-leading",
        ""
    )
    $displayArguments = @(
        "fixed", "<prompt>", "<prompt>", "<prompt>", "<prompt>", "<prompt>",
        "<prompt>", "<prompt>", "<prompt>", "<native>", "<native>"
    )
    $stdinPayload = "context line`nsecond line`n`n"
    $config = New-LaunchConfig $workDir $hostileArguments $displayArguments -Stdin $stdinPayload

    $env:AAGENT_FAKE_RUN_STDOUT = "provider-stdout"
    $env:AAGENT_FAKE_RUN_STDERR = "provider-stderr"
    $env:AAGENT_FAKE_RUN_STATUS = "73"
    $result = Invoke-LaunchDriver $config (Join-Path $testDir "run.json")
    Assert-LaunchEqual $result.Status 73 "Provider-defined status was remapped. Driver stderr: $($result.Stderr)"
    Assert-LaunchEqual $result.Stdout "provider-stdout" "Provider stdout differs."
    Assert-LaunchEqual $result.Stderr "aagent: using generic fake provider$([Environment]::NewLine)provider-stderr" "Wrapper/provider stderr differs."
    Assert-LaunchEqual (Get-Location).ProviderPath $originalLocation "Launcher changed the caller working directory."
    Assert-LaunchEqual $env:AAGENT_TEST_CHILD_SET "parent-value" "Child environment set leaked into the wrapper."
    Assert-LaunchEqual $env:AAGENT_TEST_CHILD_UNSET "parent-only" "Child environment unset leaked into the wrapper."

    $record = Join-Path $recordDir "generic.run.1.record"
    if (-not (Test-Path -LiteralPath $record)) {
        throw "Generic provider record is missing."
    }
    Assert-LaunchFileLine $record "cwd.hex=$(ConvertTo-LaunchHex $expectedWorkDir)" "Child working directory differs."
    Assert-LaunchFileLine $record "argc=$($hostileArguments.Count)" "Hostile argv count differs."
    for ($index = 0; $index -lt $hostileArguments.Count; $index++) {
        Assert-LaunchFileLine $record "arg.$index.hex=$(ConvertTo-LaunchHex $hostileArguments[$index])" "Argument $index differs."
    }
    Assert-LaunchFileLine $record "stdin.hex=$(ConvertTo-LaunchHex $stdinPayload)" "Stdin bytes differ."
    Assert-LaunchFileLine $record "env.AAGENT_TEST_CHILD_SET=present" "Child set variable is absent."
    Assert-LaunchFileLine $record "env.AAGENT_TEST_CHILD_UNSET=absent" "Child unset variable is present."
    Assert-LaunchFileLine $record "env.AAGENT_TEST_CHILD_SET.hex=$(ConvertTo-LaunchHex 'child-secret-value')" "Child set value differs."
    if (Test-Path -LiteralPath (Join-Path $workDir "launch-should-not-exist")) {
        throw "Hostile argv was evaluated."
    }

    $env:AAGENT_FAKE_RUN_STDOUT = "quiet-stdout"
    $env:AAGENT_FAKE_RUN_STDERR = "quiet-stderr"
    $env:AAGENT_FAKE_RUN_STATUS = "0"
    $config.Quiet = $true
    $result = Invoke-LaunchDriver $config (Join-Path $testDir "quiet.json")
    Assert-LaunchEqual $result.Status 0 "Quiet launch failed."
    Assert-LaunchEqual $result.Stdout "quiet-stdout" "Quiet changed provider stdout."
    Assert-LaunchEqual $result.Stderr "quiet-stderr" "Quiet suppressed provider stderr."

    $inheritPayload = "inherited stdin`n"
    $inheritConfig = New-LaunchConfig $workDir @("placeholder") @("placeholder")
    $inheritConfig.Arguments = @()
    $inheritConfig.DisplayArguments = @()
    $inheritConfig.StdinMode = "inherit"
    $inheritConfig.Stdin = ""
    $inheritConfig.InputDescription = "stdin"
    $inheritConfig.EnvironmentSet = [ordered] @{}
    $inheritConfig.EnvironmentUnset = @()
    $inheritConfig.Notice = ""
    $inheritConfig.Quiet = $true
    $env:AAGENT_FAKE_RUN_STDOUT = ""
    $env:AAGENT_FAKE_RUN_STDERR = ""
    $result = Invoke-LaunchDriver $inheritConfig (Join-Path $testDir "inherit.json") $inheritPayload
    Assert-LaunchEqual $result.Status 0 "Inherited-stdin launch failed."
    Assert-LaunchFileLine (Join-Path $recordDir "generic.run.3.record") "argc=0" "Empty argv gained an argument."
    Assert-LaunchFileLine (Join-Path $recordDir "generic.run.3.record") "stdin.hex=$(ConvertTo-LaunchHex $inheritPayload)" "Inherited stdin differs."

    $config.DryRun = $true
    $config.Quiet = $false
    $result = Invoke-LaunchDriver $config (Join-Path $testDir "dry-run.json")
    Assert-LaunchEqual $result.Status 0 "Dry-run failed."
    Assert-LaunchContains $result.Stdout "provider: generic" "Dry-run provider is missing."
    Assert-LaunchContains $result.Stdout "stdin: both" "Dry-run stdin mode is missing."
    Assert-LaunchContains $result.Stdout "AAGENT_TEST_CHILD_SET" "Dry-run set environment name is missing."
    Assert-LaunchContains $result.Stdout "AAGENT_TEST_CHILD_UNSET" "Dry-run unset environment name is missing."
    if ($result.Stdout.Contains("child-secret-value")) { throw "Dry-run leaked an environment value." }
    if ($result.Stdout.Contains("context line")) { throw "Dry-run leaked stdin." }
    if ($result.Stdout.Contains("launch-should-not-exist")) { throw "Dry-run leaked a redacted argument." }
    Assert-LaunchEqual $result.Stderr "" "Dry-run wrote a notice to stderr."
    Assert-LaunchEqual ([IO.File]::ReadAllText((Join-Path $recordDir "run.count"), $utf8).Trim()) "3" "Dry-run launched a provider."

    $config.DryRun = $false
    $config.Quiet = $true
    $env:AAGENT_FAKE_RUN_STDOUT = ""
    $env:AAGENT_FAKE_RUN_STDERR = ""
    foreach ($expectedStatus in @(0, 23, 64, 78, 95, 127, 130, 143, 255)) {
        $env:AAGENT_FAKE_RUN_STATUS = [string] $expectedStatus
        $result = Invoke-LaunchDriver $config (Join-Path $testDir "status-$expectedStatus.json")
        Assert-LaunchEqual $result.Status $expectedStatus "Status $expectedStatus was remapped."
    }
    Assert-LaunchEqual ([IO.File]::ReadAllText((Join-Path $recordDir "run.count"), $utf8).Trim()) "12" "One launch did not produce exactly one provider run."
} finally {
    foreach ($name in $environmentNames) {
        [Environment]::SetEnvironmentVariable($name, $originalEnvironment[$name], "Process")
    }
    if (Test-Path -LiteralPath $testDir) {
        Remove-Item -LiteralPath $testDir -Recurse -Force
    }
}

Write-Host "Launch PowerShell tests passed."
