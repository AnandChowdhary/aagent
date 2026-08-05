param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $ProviderArguments
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrEmpty($env:AAGENT_FAKE_RECORD_DIR)) {
    [Console]::Error.WriteLine("AAGENT_FAKE_RECORD_DIR is required")
    exit 64
}

[IO.Directory]::CreateDirectory($env:AAGENT_FAKE_RECORD_DIR) | Out-Null
$utf8 = [Text.UTF8Encoding]::new($false)

function ConvertTo-Hex([string] $Value) {
    $bytes = $utf8.GetBytes($Value)
    return [Convert]::ToHexString($bytes).ToLowerInvariant()
}

$provider = $env:AAGENT_FAKE_PROVIDER
if ([string]::IsNullOrEmpty($provider)) {
    $provider = [IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Path)
}

$kind = $env:AAGENT_FAKE_INVOCATION_KIND
if ([string]::IsNullOrEmpty($kind)) {
    $first = if ($ProviderArguments.Count -gt 0) { $ProviderArguments[0] } else { "" }
    $second = if ($ProviderArguments.Count -gt 1) { $ProviderArguments[1] } else { "" }

    if (
        $first -eq "--version" -or
        ($provider -eq "claude" -and $first -eq "auth" -and $second -eq "status") -or
        ($provider -eq "codex" -and $first -eq "login" -and $second -eq "status") -or
        ($provider -eq "codex" -and $first -eq "app-server") -or
        ($provider -eq "opencode" -and $first -eq "auth" -and $second -eq "list")
    ) {
        $kind = "probe"
    } else {
        $kind = "run"
    }
}

if ($kind -notin @("run", "probe")) {
    [Console]::Error.WriteLine("fake-provider: invalid invocation kind: $kind")
    exit 64
}

$counterFile = Join-Path $env:AAGENT_FAKE_RECORD_DIR "$kind.count"
$count = 0
if (Test-Path -LiteralPath $counterFile) {
    $count = [int] ([IO.File]::ReadAllText($counterFile, $utf8).Trim())
}
$count++
[IO.File]::WriteAllText($counterFile, "$count`n", $utf8)

$stdin = if ([Console]::IsInputRedirected) {
    [Console]::In.ReadToEnd()
} else {
    ""
}

$record = [Collections.Generic.List[string]]::new()
$record.Add("protocol=1")
$record.Add("pid=$PID")
$record.Add("provider.hex=$(ConvertTo-Hex $provider)")
$record.Add("kind=$kind")
$record.Add("cwd.hex=$(ConvertTo-Hex (Get-Location).ProviderPath)")
$record.Add("argc=$($ProviderArguments.Count)")

for ($index = 0; $index -lt $ProviderArguments.Count; $index++) {
    $record.Add("arg.$index.hex=$(ConvertTo-Hex $ProviderArguments[$index])")
}

$record.Add("stdin.hex=$(ConvertTo-Hex $stdin)")

foreach ($name in ($env:AAGENT_FAKE_ENV_PRESENCE -split ",")) {
    if ($name -match "^[A-Za-z_][A-Za-z0-9_]*$") {
        $value = [Environment]::GetEnvironmentVariable($name, "Process")
        $state = if ($null -eq $value) { "absent" } else { "present" }
        $record.Add("env.$name=$state")
    }
}

foreach ($name in ($env:AAGENT_FAKE_ENV_CAPTURE -split ",")) {
    if ($name -match "^[A-Za-z_][A-Za-z0-9_]*$") {
        $value = [Environment]::GetEnvironmentVariable($name, "Process")
        $encoded = if ($null -eq $value) { "ABSENT" } else { ConvertTo-Hex $value }
        $record.Add("env.$name.hex=$encoded")
    }
}

$recordFile = Join-Path $env:AAGENT_FAKE_RECORD_DIR "$provider.$kind.$count.record"
[IO.File]::WriteAllText($recordFile, (($record -join "`n") + "`n"), $utf8)

if ($kind -eq "probe") {
    $delay = $env:AAGENT_FAKE_PROBE_DELAY
    $stdout = $env:AAGENT_FAKE_PROBE_STDOUT
    $stderr = $env:AAGENT_FAKE_PROBE_STDERR
    $statusText = $env:AAGENT_FAKE_PROBE_STATUS
    $probeProfile = if ($ProviderArguments.Count -gt 0 -and $ProviderArguments[0] -eq "--version") {
        "VERSION"
    } elseif ($provider -eq "claude" -and $ProviderArguments[0] -eq "auth") {
        "CLAUDE"
    } elseif ($provider -eq "codex" -and $ProviderArguments[0] -eq "app-server") {
        "CODEX_APP_SERVER"
    } elseif ($provider -eq "codex" -and $ProviderArguments[0] -eq "login") {
        "CODEX_LOGIN"
    } elseif ($provider -eq "opencode" -and $ProviderArguments[0] -eq "auth") {
        "OPENCODE"
    } else {
        ""
    }
    if (-not [string]::IsNullOrEmpty($probeProfile)) {
        $profileDelay = [Environment]::GetEnvironmentVariable("AAGENT_FAKE_${probeProfile}_DELAY", "Process")
        $profileStdout = [Environment]::GetEnvironmentVariable("AAGENT_FAKE_${probeProfile}_STDOUT", "Process")
        $profileStderr = [Environment]::GetEnvironmentVariable("AAGENT_FAKE_${probeProfile}_STDERR", "Process")
        $profileStatus = [Environment]::GetEnvironmentVariable("AAGENT_FAKE_${probeProfile}_STATUS", "Process")
        $profileBytes = [Environment]::GetEnvironmentVariable("AAGENT_FAKE_${probeProfile}_BYTES", "Process")
        if ($null -ne $profileDelay) { $delay = $profileDelay }
        if ($null -ne $profileStdout) { $stdout = $profileStdout }
        if ($null -ne $profileStderr) { $stderr = $profileStderr }
        if ($null -ne $profileStatus) { $statusText = $profileStatus }
        if ($null -ne $profileBytes) { $outputBytes = $profileBytes }
    }
    if ($null -eq $outputBytes) { $outputBytes = $env:AAGENT_FAKE_PROBE_BYTES }
} else {
    $delay = $env:AAGENT_FAKE_RUN_DELAY
    $stdout = $env:AAGENT_FAKE_RUN_STDOUT
    $stderr = $env:AAGENT_FAKE_RUN_STDERR
    $statusText = $env:AAGENT_FAKE_RUN_STATUS
}

if (-not [string]::IsNullOrEmpty($delay) -and [double] $delay -ne 0) {
    Start-Sleep -Milliseconds ([int] ([double] $delay * 1000))
}

if (-not [string]::IsNullOrEmpty($outputBytes) -and [int] $outputBytes -gt 0) {
    [Console]::Out.Write("x" * [int] $outputBytes)
}
if ($null -ne $stdout) {
    [Console]::Out.Write($stdout)
}
if ($null -ne $stderr) {
    [Console]::Error.Write($stderr)
}

$status = if ([string]::IsNullOrEmpty($statusText)) { 0 } else { [int] $statusText }
if ($status -lt 0 -or $status -gt 255) {
    [Console]::Error.WriteLine("fake-provider: invalid exit status: $statusText")
    exit 64
}

exit $status
