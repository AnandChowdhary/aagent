$ErrorActionPreference = "Stop"

Set-Variable -Name AagentExitOk -Value 0 -Option Constant -Scope Script
Set-Variable -Name AagentExitUsage -Value 64 -Option Constant -Scope Script
Set-Variable -Name AagentExitUnavailable -Value 69 -Option Constant -Scope Script
Set-Variable -Name AagentExitSoftware -Value 70 -Option Constant -Scope Script
Set-Variable -Name AagentExitConfig -Value 78 -Option Constant -Scope Script
Set-Variable -Name AagentVersion -Value "0.1.0-dev" -Option Constant -Scope Script
Set-Variable -Name AagentPopularitySnapshot -Value "2026-08-04" -Option Constant -Scope Script
Set-Variable -Name AagentScriptPath -Value $PSCommandPath -Option Constant -Scope Script

function New-AagentAdapter {
    param(
        [string] $Id,
        [string] $Name,
        [string] $Executable,
        [string] $Override,
        [string] $Tier,
        [string] $Command,
        [string] $Stdin,
        [string] $Model,
        [string] $Structured,
        [string] $Sessions,
        [string] $Safety,
        [string] $Probe,
        [int] $Popularity,
        [int] $RegistryOrder
    )

    return [pscustomobject] @{
        Id = $Id
        Name = $Name
        Executable = $Executable
        Override = $Override
        Tier = $Tier
        Command = $Command
        Stdin = $Stdin
        Model = $Model
        Structured = $Structured
        Sessions = $Sessions
        Safety = $Safety
        Probe = $Probe
        Popularity = $Popularity
        RegistryOrder = $RegistryOrder
    }
}

function Get-AagentAdapterRegistry {
    return @(
        New-AagentAdapter "codex" "Codex CLI" "codex" "AAGENT_CODEX_BIN" "tier1" "codex exec PROMPT" "argument-and-stdin" "--model" "jsonl" "resume" "Read-only sandbox by default; broader sandboxes are explicit." "app-server account/read" 1 1
        New-AagentAdapter "claude" "Claude Code" "claude" "AAGENT_CLAUDE_BIN" "tier1" "claude --print PROMPT" "argument-and-stdin" "--model" "json,stream-json" "resume" "Permission modes are native; never add --bare or a bypass." "auth status --json" 2 2
        New-AagentAdapter "opencode" "OpenCode" "opencode" "AAGENT_OPENCODE_BIN" "tier1" "opencode run PROMPT" "argument" "--model" "json-events" "resume,fork" "Native permissions may allow tools; never add --auto." "auth list" 3 3
        New-AagentAdapter "copilot" "GitHub Copilot CLI" "copilot" "AAGENT_COPILOT_BIN" "planned" "copilot --prompt PROMPT" "argument" "--model" "none" "unknown" "Automatic tool approval is explicitly privileged." "unknown" 4 4
        New-AagentAdapter "gemini" "Gemini CLI" "gemini" "AAGENT_GEMINI_BIN" "tier1" "gemini --prompt PROMPT" "argument-and-stdin" "--model" "json,stream-json" "resume" "Approval and sandbox modes are native; never add yolo." "settings selectedType" 5 5
        New-AagentAdapter "cline" "Cline CLI" "cline" "AAGENT_CLINE_BIN" "planned" "cline PROMPT" "argument" "--model" "ndjson" "unknown" "Headless use documents automatic approval behavior." "unknown" 6 6
        New-AagentAdapter "goose" "Goose" "goose" "AAGENT_GOOSE_BIN" "planned" "goose run --text PROMPT" "argument" "provider-native" "json,stream-json" "unknown" "Headless automation may use GOOSE_MODE=auto only by user choice." "provider metadata" 7 7
        New-AagentAdapter "aider" "Aider" "aider" "AAGENT_AIDER_BIN" "planned" "aider --message PROMPT" "argument" "--model" "none" "unknown" "Automatically commits changes by default." "model metadata" 8 8
        New-AagentAdapter "qwen" "Qwen Code" "qwen" "AAGENT_QWEN_BIN" "planned" "qwen --prompt PROMPT" "argument-and-stdin" "--model" "json,stream-json" "resume" "Approval modes and budgets remain native." "auth selection" 9 9
        New-AagentAdapter "amp" "Amp" "amp" "AAGENT_AMP_BIN" "tier1" "amp --execute PROMPT" "argument-and-stdin" "none" "stream-json" "continue" "Uses tools without asking by default; no portable read-only promise." "unknown" 10 10
        New-AagentAdapter "kimi" "Kimi Code" "kimi" "AAGENT_KIMI_BIN" "planned" "kimi --prompt PROMPT" "argument" "--model" "stream-json" "unknown" "Print mode uses automatic permission handling." "managed-login metadata" 11 11
        New-AagentAdapter "droid" "Factory Droid" "droid" "AAGENT_DROID_BIN" "planned" "droid exec PROMPT" "argument" "--model" "json,stream-json,json-rpc" "unknown" "Read-only spec mode by default; autonomy flags are explicit." "account metadata" 12 12
        New-AagentAdapter "crush" "Crush" "crush" "AAGENT_CRUSH_BIN" "planned" "crush run PROMPT" "argument" "provider-native" "none" "unknown" "Native permission prompts remain unless user supplies yolo." "unknown" 13 13
        New-AagentAdapter "vibe" "Mistral Vibe" "vibe" "AAGENT_VIBE_BIN" "planned" "vibe --prompt PROMPT" "argument" "provider-native" "json,ndjson" "resume" "Auto-approval, tools, and budgets remain native." "profile metadata" 14 14
        New-AagentAdapter "kiro" "Kiro CLI" "kiro-cli" "AAGENT_KIRO_BIN" "planned" "kiro-cli chat --no-interactive PROMPT" "argument" "provider-native" "none" "unknown" "Trust flags control pre-approved tools and remain explicit." "unknown" 15 15
        New-AagentAdapter "cursor" "Cursor CLI" "agent" "AAGENT_CURSOR_BIN" "planned" "agent --print PROMPT" "argument" "--model" "json,stream-json" "resume" "Changes are proposed unless the user explicitly forces them." "status --format json" 16 16
    )
}

function Get-AagentAdapter([string] $Id) {
    return (Get-AagentAdapterRegistry | Where-Object Id -CEQ $Id | Select-Object -First 1)
}

function Get-AagentConfigurationPath {
    param([bool] $Windows = $IsWindows)

    if ($Windows) {
        $appData = [Environment]::GetEnvironmentVariable("APPDATA", "Process")
        if ([string]::IsNullOrEmpty($appData)) {
            return ""
        }
        return [IO.Path]::Combine($appData, "aagent", "config")
    }

    $xdgConfigHome = [Environment]::GetEnvironmentVariable("XDG_CONFIG_HOME", "Process")
    if (-not [string]::IsNullOrEmpty($xdgConfigHome)) {
        return [IO.Path]::Combine($xdgConfigHome, "aagent", "config")
    }
    $homeDirectory = [Environment]::GetEnvironmentVariable("HOME", "Process")
    if ([string]::IsNullOrEmpty($homeDirectory)) {
        return ""
    }
    return [IO.Path]::Combine($homeDirectory, ".config", "aagent", "config")
}

function Test-AagentPriorityValue([string] $Value) {
    if ([string]::IsNullOrEmpty($Value)) {
        return $false
    }

    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($rawId in $Value.Split(',', [StringSplitOptions]::None)) {
        $id = $rawId.Trim([char[]] @(' ', "`t"))
        if ([string]::IsNullOrEmpty($id) -or $null -eq (Get-AagentAdapter $id)) {
            return $false
        }
        if (-not $seen.Add($id)) {
            return $false
        }
    }
    return $true
}

function Test-AagentConfigurationValue([string] $Key, [string] $Value) {
    switch -CaseSensitive ($Key) {
        "provider" {
            return -not [string]::IsNullOrEmpty($Value) -and $null -ne (Get-AagentAdapter $Value)
        }
        "auth_policy" {
            return $Value -cin @("prefer-included", "native")
        }
        "priority" {
            return Test-AagentPriorityValue $Value
        }
        "allow_local" {
            return $Value -cin @("true", "false")
        }
        default {
            return $false
        }
    }
}

function New-AagentConfigurationResult([string] $Path) {
    return [pscustomobject] @{
        Path = $Path
        Values = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
        Lines = [Collections.Generic.Dictionary[string, int]]::new([StringComparer]::Ordinal)
        Warnings = [Collections.Generic.List[string]]::new()
        Error = ""
        Status = $AagentExitOk
    }
}

function Set-AagentConfigurationError {
    param(
        $Configuration,
        [int] $Line,
        [string] $Key,
        [string] $Message
    )

    $location = $Configuration.Path
    if ($Line -gt 0) {
        $location += " at line $Line"
    }
    if (-not [string]::IsNullOrEmpty($Key)) {
        $location += " ($Key)"
    }
    $Configuration.Error = "configuration error in ${location}: $Message"
    $Configuration.Status = $AagentExitConfig
    return $Configuration
}

function Read-AagentUserConfiguration {
    param([bool] $Doctor = $false)

    $path = Get-AagentConfigurationPath
    $configuration = New-AagentConfigurationResult $path
    if ([string]::IsNullOrEmpty($path) -or -not (Test-Path -LiteralPath $path)) {
        return $configuration
    }

    try {
        $item = Get-Item -LiteralPath $path -Force -ErrorAction Stop
        if ($item.PSIsContainer) {
            return Set-AagentConfigurationError $configuration 0 "" "configuration file is not a readable regular file"
        }
        $lines = [IO.File]::ReadAllLines($path)
    } catch {
        return Set-AagentConfigurationError $configuration 0 "" "configuration file is not a readable regular file"
    }

    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    for ($index = 0; $index -lt $lines.Count; $index++) {
        $lineNumber = $index + 1
        $line = $lines[$index]
        if ($line.Length -gt 4096) {
            return Set-AagentConfigurationError $configuration $lineNumber "" "line exceeds 4096 characters"
        }
        $trimmed = $line.Trim([char[]] @(' ', "`t"))
        if ([string]::IsNullOrEmpty($trimmed) -or $trimmed.StartsWith("#", [StringComparison]::Ordinal)) {
            continue
        }

        $separator = $trimmed.IndexOf('=')
        if ($separator -lt 0) {
            return Set-AagentConfigurationError $configuration $lineNumber "" "expected key=value"
        }
        $key = $trimmed.Substring(0, $separator).Trim([char[]] @(' ', "`t"))
        $value = $trimmed.Substring($separator + 1).Trim([char[]] @(' ', "`t"))
        if ($key -cnotmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
            return Set-AagentConfigurationError $configuration $lineNumber "" "invalid key name"
        }
        if (-not $seen.Add($key)) {
            return Set-AagentConfigurationError $configuration $lineNumber $key "duplicate key"
        }

        if ($key -cnotin @("provider", "auth_policy", "priority", "allow_local")) {
            if ($Doctor) {
                return Set-AagentConfigurationError $configuration $lineNumber $key "unknown key"
            }
            $configuration.Warnings.Add(
                "$path line ${lineNumber}: unknown configuration key '$key' ignored"
            )
            continue
        }
        if (-not (Test-AagentConfigurationValue $key $value)) {
            return Set-AagentConfigurationError $configuration $lineNumber $key "invalid value"
        }
        $configuration.Values.Add($key, $value)
        $configuration.Lines.Add($key, $lineNumber)
    }
    return $configuration
}

function Set-AagentConfigurationFailure($Result, [int] $Status, [string] $Message) {
    $Result.Status = $Status
    $Result.Error = $Message
    return $Result
}

function Resolve-AagentConfiguration {
    param(
        $Result,
        [bool] $Doctor = $false
    )

    $configuration = Read-AagentUserConfiguration -Doctor:$Doctor
    foreach ($warning in $configuration.Warnings) {
        [Console]::Error.WriteLine("aagent: warning: $warning")
    }
    if ($configuration.Status -ne $AagentExitOk) {
        [Console]::Error.WriteLine("aagent: $($configuration.Error)")
        return Set-AagentConfigurationFailure $Result $configuration.Status $configuration.Error
    }

    $environmentProvider = [Environment]::GetEnvironmentVariable("AAGENT_PROVIDER", "Process")
    if ($Result.ProviderSpecified) {
        $Result.ProviderSource = "cli"
        $Result.ProviderSourceLabel = "explicit --provider"
    } elseif ($null -ne $environmentProvider) {
        if (-not (Test-AagentConfigurationValue "provider" $environmentProvider)) {
            [Console]::Error.WriteLine("aagent: invalid AAGENT_PROVIDER configuration")
            return Set-AagentConfigurationFailure $Result $AagentExitConfig "invalid AAGENT_PROVIDER configuration"
        }
        $Result.Provider = $environmentProvider
        $Result.ProviderSource = "environment"
        $Result.ProviderSourceLabel = "AAGENT_PROVIDER"
    } elseif ($configuration.Values.ContainsKey("provider")) {
        $Result.Provider = $configuration.Values["provider"]
        $Result.ProviderSource = "config"
        $Result.ProviderSourceLabel = "user config"
    } else {
        $Result.Provider = ""
        $Result.ProviderSource = "default"
        $Result.ProviderSourceLabel = "automatic selection"
    }

    $environmentAuthPolicy = [Environment]::GetEnvironmentVariable("AAGENT_AUTH_POLICY", "Process")
    if ($Result.AuthPolicySpecified) {
        $Result.AuthPolicySource = "cli"
    } elseif ($null -ne $environmentAuthPolicy) {
        if (-not (Test-AagentConfigurationValue "auth_policy" $environmentAuthPolicy)) {
            [Console]::Error.WriteLine("aagent: invalid AAGENT_AUTH_POLICY configuration")
            return Set-AagentConfigurationFailure $Result $AagentExitConfig "invalid AAGENT_AUTH_POLICY configuration"
        }
        $Result.AuthPolicy = $environmentAuthPolicy
        $Result.AuthPolicySource = "environment"
    } elseif ($configuration.Values.ContainsKey("auth_policy")) {
        $Result.AuthPolicy = $configuration.Values["auth_policy"]
        $Result.AuthPolicySource = "config"
    } else {
        $Result.AuthPolicy = "prefer-included"
        $Result.AuthPolicySource = "default"
    }

    $environmentPriority = [Environment]::GetEnvironmentVariable("AAGENT_PRIORITY", "Process")
    if ($Result.PrioritySpecified) {
        if (-not (Test-AagentConfigurationValue "priority" $Result.Priority)) {
            return Set-AagentConfigurationFailure $Result $AagentExitUsage "invalid --priority value"
        }
        $Result.PrioritySource = "cli"
    } elseif ($null -ne $environmentPriority) {
        if (-not (Test-AagentConfigurationValue "priority" $environmentPriority)) {
            [Console]::Error.WriteLine("aagent: invalid AAGENT_PRIORITY configuration")
            return Set-AagentConfigurationFailure $Result $AagentExitConfig "invalid AAGENT_PRIORITY configuration"
        }
        $Result.Priority = $environmentPriority
        $Result.PrioritySource = "environment"
    } elseif ($configuration.Values.ContainsKey("priority")) {
        $Result.Priority = $configuration.Values["priority"]
        $Result.PrioritySource = "config"
    } else {
        $Result.Priority = ""
        $Result.PrioritySource = "default"
    }
    $Result.PriorityRole = "tie-break-only"

    $environmentAllowLocal = [Environment]::GetEnvironmentVariable("AAGENT_ALLOW_LOCAL", "Process")
    if ($Result.AllowLocalSpecified) {
        $Result.AllowLocalSource = "cli"
    } elseif ($null -ne $environmentAllowLocal) {
        if (-not (Test-AagentConfigurationValue "allow_local" $environmentAllowLocal)) {
            [Console]::Error.WriteLine("aagent: invalid AAGENT_ALLOW_LOCAL configuration")
            return Set-AagentConfigurationFailure $Result $AagentExitConfig "invalid AAGENT_ALLOW_LOCAL configuration"
        }
        $Result.AllowLocal = $environmentAllowLocal
        $Result.AllowLocalSource = "environment"
    } elseif ($configuration.Values.ContainsKey("allow_local")) {
        $Result.AllowLocal = $configuration.Values["allow_local"]
        $Result.AllowLocalSource = "config"
    } else {
        $Result.AllowLocal = "false"
        $Result.AllowLocalSource = "default"
    }
    return $Result
}

Set-Variable -Name AagentProbeTimeoutMilliseconds -Value 3000 -Option Constant -Scope Script
Set-Variable -Name AagentProbeMaxBytes -Value 65536 -Option Constant -Scope Script

function New-AagentProbeResult([string] $Provider) {
    return [pscustomobject] @{
        Provider = $Provider
        Readiness = "unknown"
        FundingClass = "unknown"
        ConfidenceRank = 0
        PlanLabel = "Unknown"
        ReasonCode = "probe_unavailable"
        ShadowingVariables = [string[]] @()
        Source = "none"
        ProbeStatus = "not_run"
    }
}

function Set-AagentProbeResult {
    param(
        $Result,
        [string] $Readiness,
        [string] $FundingClass,
        [int] $ConfidenceRank,
        [string] $PlanLabel,
        [string] $ReasonCode,
        [string] $Source,
        [string] $ProbeStatus,
        [string[]] $ShadowingVariables = @()
    )

    $Result.Readiness = $Readiness
    $Result.FundingClass = $FundingClass
    $Result.ConfidenceRank = $ConfidenceRank
    $Result.PlanLabel = $PlanLabel
    $Result.ReasonCode = $ReasonCode
    $Result.Source = $Source
    $Result.ProbeStatus = $ProbeStatus
    $Result.ShadowingVariables = [string[]] $ShadowingVariables
    return $Result
}

function Test-AagentEnvironmentPresent([string] $Name) {
    # The dictionary key is inspected, but its value is never indexed, copied,
    # transformed, compared, or emitted.
    return [Environment]::GetEnvironmentVariables("Process").Contains($Name)
}

function Get-AagentPresentEnvironmentNames([string[]] $Names) {
    $present = [Collections.Generic.List[string]]::new()
    foreach ($name in $Names) {
        if (Test-AagentEnvironmentPresent $name) {
            $present.Add($name)
        }
    }
    return [string[]] $present
}

function Get-AagentProbeCommand([string] $Executable, [string[]] $Arguments) {
    $extension = [IO.Path]::GetExtension($Executable)
    if ($extension -ieq ".ps1") {
        $pwsh = Get-Command pwsh -CommandType Application -ErrorAction Stop | Select-Object -First 1
        return [pscustomobject] @{
            Executable = $pwsh.Source
            Arguments = [string[]] (@("-NoProfile", "-File", $Executable) + $Arguments)
        }
    }
    if ($extension -iin @(".cmd", ".bat")) {
        throw "batch probes are unsupported"
    }
    return [pscustomobject] @{ Executable = $Executable; Arguments = [string[]] $Arguments }
}

function New-AagentProbeProcessResult([string] $Status, [string] $Capture = "") {
    return [pscustomobject] @{ Status = $Status; Capture = $Capture }
}

function Invoke-AagentProbeProcess {
    param(
        [string] $Executable,
        [string[]] $Arguments,
        [AllowEmptyString()]
        [string] $StdinData = "",
        [ValidateSet("stdout", "stderr")]
        [string] $CaptureStream = "stdout",
        [int] $StdinLingerMilliseconds = 0
    )

    try {
        $command = Get-AagentProbeCommand $Executable $Arguments
        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $command.Executable
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardInput = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        foreach ($argument in $command.Arguments) {
            $startInfo.ArgumentList.Add($argument)
        }

        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        if (-not $process.Start()) {
            return New-AagentProbeProcessResult "supervisor_failure"
        }
        $deadline = [DateTime]::UtcNow.AddMilliseconds($AagentProbeTimeoutMilliseconds)
        $process.StandardInput.Write($StdinData)
        if ($StdinLingerMilliseconds -gt 0) {
            Start-Sleep -Milliseconds $StdinLingerMilliseconds
        }
        $process.StandardInput.Close()

        $stdoutBuffer = [byte[]]::new(4096)
        $stderrBuffer = [byte[]]::new(4096)
        $stdoutCapture = [IO.MemoryStream]::new()
        $stderrCapture = [IO.MemoryStream]::new()
        $stdoutBytes = 0L
        $stderrBytes = 0L
        $stdoutDone = $false
        $stderrDone = $false
        $truncated = $false
        $timedOut = $false
        $stdoutTask = $process.StandardOutput.BaseStream.ReadAsync($stdoutBuffer, 0, $stdoutBuffer.Length)
        $stderrTask = $process.StandardError.BaseStream.ReadAsync($stderrBuffer, 0, $stderrBuffer.Length)
        while (-not $stdoutDone -or -not $stderrDone) {
            if (-not $stdoutDone -and $stdoutTask.IsCompleted) {
                $count = $stdoutTask.GetAwaiter().GetResult()
                if ($count -eq 0) {
                    $stdoutDone = $true
                } else {
                    $stdoutBytes += $count
                    if ($stdoutBytes -le $AagentProbeMaxBytes) {
                        $stdoutCapture.Write($stdoutBuffer, 0, $count)
                    } else {
                        $truncated = $true
                    }
                    $stdoutTask = $process.StandardOutput.BaseStream.ReadAsync(
                        $stdoutBuffer,
                        0,
                        $stdoutBuffer.Length
                    )
                }
            }
            if (-not $stderrDone -and $stderrTask.IsCompleted) {
                $count = $stderrTask.GetAwaiter().GetResult()
                if ($count -eq 0) {
                    $stderrDone = $true
                } else {
                    $stderrBytes += $count
                    if ($stderrBytes -le $AagentProbeMaxBytes) {
                        $stderrCapture.Write($stderrBuffer, 0, $count)
                    } else {
                        $truncated = $true
                    }
                    $stderrTask = $process.StandardError.BaseStream.ReadAsync(
                        $stderrBuffer,
                        0,
                        $stderrBuffer.Length
                    )
                }
            }
            if (-not $process.HasExited -and [DateTime]::UtcNow -ge $deadline) {
                $timedOut = $true
                try { $process.Kill($true) } catch { try { $process.Kill() } catch {} }
            }
            if (-not $stdoutDone -or -not $stderrDone) {
                Start-Sleep -Milliseconds 5
            }
        }
        $process.WaitForExit()
        if ($timedOut) {
            return New-AagentProbeProcessResult "timeout"
        }
        if ($truncated) {
            return New-AagentProbeProcessResult "truncated"
        }
        if ($process.ExitCode -ne 0) {
            return New-AagentProbeProcessResult "nonzero"
        }
        $utf8 = [Text.UTF8Encoding]::new($false, $true)
        $captureBytes = if ($CaptureStream -eq "stdout") {
            $stdoutCapture.ToArray()
        } else {
            $stderrCapture.ToArray()
        }
        $capture = $utf8.GetString($captureBytes)
        return New-AagentProbeProcessResult "success" $capture.TrimEnd([char[]] @("`r", "`n"))
    } catch {
        return New-AagentProbeProcessResult "supervisor_failure"
    }
}

function ConvertFrom-AagentProbeJson([string] $Json) {
    try {
        return $Json | ConvertFrom-Json -Depth 32 -NoEnumerate -ErrorAction Stop
    } catch {
        return $null
    }
}

function Get-AagentJsonProperty($Object, [string] $Name) {
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Set-AagentClaudeEnvironmentResult($Result, [string] $ProbeStatus) {
    $cloud = Get-AagentPresentEnvironmentNames @(
        "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX", "CLAUDE_CODE_USE_FOUNDRY"
    )
    if ($cloud.Count -gt 0) {
        Set-AagentProbeResult $Result ready unknown 1 "Organization route" `
            claude_cloud_environment environment $ProbeStatus $cloud | Out-Null
        return $true
    }
    if (Test-AagentEnvironmentPresent "ANTHROPIC_AUTH_TOKEN") {
        Set-AagentProbeResult $Result ready unknown 1 "Bearer or gateway" `
            claude_bearer_environment environment $ProbeStatus @("ANTHROPIC_AUTH_TOKEN") | Out-Null
        return $true
    }
    if (Test-AagentEnvironmentPresent "ANTHROPIC_API_KEY") {
        Set-AagentProbeResult $Result ready payg_byok 1 "Anthropic API" `
            claude_api_environment environment $ProbeStatus @("ANTHROPIC_API_KEY") | Out-Null
        return $true
    }
    if (Test-AagentEnvironmentPresent "CLAUDE_CODE_OAUTH_TOKEN") {
        Set-AagentProbeResult $Result ready included_account 1 "Claude subscription token" `
            claude_oauth_environment environment $ProbeStatus @("CLAUDE_CODE_OAUTH_TOKEN") | Out-Null
        return $true
    }
    return $false
}

function Invoke-AagentClaudeProbe([string] $Executable) {
    $result = New-AagentProbeResult "claude"
    $probe = Invoke-AagentProbeProcess $Executable @("auth", "status", "--json")
    if ($probe.Status -ne "success") {
        if (-not (Set-AagentClaudeEnvironmentResult $result $probe.Status)) {
            Set-AagentProbeResult $result unknown unknown 0 "Unknown" claude_probe_failed `
                auth_status $probe.Status | Out-Null
        }
        return $result
    }

    $json = ConvertFrom-AagentProbeJson $probe.Capture
    $probe.Capture = ""
    $loggedIn = Get-AagentJsonProperty $json "loggedIn"
    if ($loggedIn -isnot [bool]) {
        if (-not (Set-AagentClaudeEnvironmentResult $result "schema_failure")) {
            Set-AagentProbeResult $result unknown unknown 0 "Unknown" claude_schema_failure `
                auth_status schema_failure | Out-Null
        }
        return $result
    }

    $authMethod = Get-AagentJsonProperty $json "authMethod"
    $subscriptionType = Get-AagentJsonProperty $json "subscriptionType"
    $apiProvider = Get-AagentJsonProperty $json "apiProvider"
    $apiKeySource = Get-AagentJsonProperty $json "apiKeySource"
    foreach ($field in @("authMethod", "subscriptionType", "apiProvider", "apiKeySource")) {
        $value = Get-Variable -Name $field -ValueOnly
        if ($null -ne $value -and $value -isnot [string]) {
            Set-Variable -Name $field -Value ""
        }
    }
    if (-not $loggedIn) {
        if (-not (Set-AagentClaudeEnvironmentResult $result "success")) {
            Set-AagentProbeResult $result unusable unknown 3 "Not signed in" claude_not_logged_in `
                auth_status success | Out-Null
        }
        return $result
    }

    $authLower = ([string] $authMethod).ToLowerInvariant()
    $subscriptionLower = ([string] $subscriptionType).ToLowerInvariant()
    $providerLower = ([string] $apiProvider).ToLowerInvariant()
    $keySourceLower = ([string] $apiKeySource).ToLowerInvariant()
    $shadowing = Get-AagentPresentEnvironmentNames @(
        "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX", "CLAUDE_CODE_USE_FOUNDRY",
        "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_API_KEY"
    )

    if (
        $providerLower -match "bedrock|vertex|foundry" -or
        $authLower -match "bedrock|vertex|foundry"
    ) {
        Set-AagentProbeResult $result ready unknown 3 "Organization route" claude_cloud_status `
            auth_status success $shadowing | Out-Null
    } elseif ($authLower -match "bearer|gateway" -or $keySourceLower -match "helper") {
        Set-AagentProbeResult $result ready unknown 3 "Bearer or helper" claude_gateway_status `
            auth_status success $shadowing | Out-Null
    } elseif (
        $authLower -match "api|console" -or $providerLower -match "console" -or
        $keySourceLower -match "api"
    ) {
        Set-AagentProbeResult $result ready payg_byok 3 "Anthropic API" claude_api_status `
            auth_status success $shadowing | Out-Null
    } elseif (
        -not [string]::IsNullOrEmpty($subscriptionType) -or
        $providerLower.Contains("claude.ai") -or $authLower -match "claude.ai|oauth"
    ) {
        $funding = "included_account"
        $label = "Claude subscription"
        switch -Regex ($subscriptionLower) {
            '^pro' { $label = "Claude Pro"; $funding = "included_confirmed"; break }
            '^max' { $label = "Claude Max"; $funding = "included_confirmed"; break }
            '^team' { $label = "Claude Team"; $funding = "included_confirmed"; break }
            '^enterprise' { $label = "Claude Enterprise"; $funding = "included_confirmed"; break }
        }
        Set-AagentProbeResult $result ready $funding 3 $label claude_subscription_status `
            auth_status success $shadowing | Out-Null
    } else {
        Set-AagentProbeResult $result ready unknown 3 "Claude account" claude_unknown_status `
            auth_status success $shadowing | Out-Null
    }
    return $result
}

function Get-AagentCodexPlan([string] $PlanType) {
    switch ($PlanType.ToLowerInvariant()) {
        "plus" { return @("ChatGPT Plus", "included_confirmed") }
        "pro" { return @("ChatGPT Pro", "included_confirmed") }
        "team" { return @("ChatGPT Team", "included_confirmed") }
        "business" { return @("ChatGPT Business", "included_confirmed") }
        "enterprise" { return @("ChatGPT Enterprise", "included_confirmed") }
        "edu" { return @("ChatGPT Edu", "included_confirmed") }
        "free" { return @("ChatGPT Free", "included_account") }
        default { return @("ChatGPT account", "included_account") }
    }
}

function Set-AagentCodexEnvironmentResult($Result, [string] $ProbeStatus) {
    if (Test-AagentEnvironmentPresent "CODEX_API_KEY") {
        Set-AagentProbeResult $Result ready payg_byok 1 "OpenAI API" codex_api_environment `
            environment $ProbeStatus @("CODEX_API_KEY") | Out-Null
        return $true
    }
    if (Test-AagentEnvironmentPresent "OPENAI_API_KEY") {
        Set-AagentProbeResult $Result ready payg_byok 1 "OpenAI API" codex_openai_environment `
            environment $ProbeStatus @("OPENAI_API_KEY") | Out-Null
        return $true
    }
    return $false
}

function Get-AagentCodexAccountResponse([string] $Capture) {
    foreach ($line in ($Capture -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $message = ConvertFrom-AagentProbeJson $line
        if ($null -eq $message) { continue }
        $id = Get-AagentJsonProperty $message "id"
        if ($id -isnot [long] -and $id -isnot [int]) { continue }
        if ([long] $id -ne 1) { continue }
        return $message
    }
    return $null
}

function Invoke-AagentCodexFallback($Result, [string] $Executable) {
    $probe = Invoke-AagentProbeProcess $Executable @("login", "status") "" stderr
    if ($probe.Status -ne "success") {
        if (-not (Set-AagentCodexEnvironmentResult $Result $probe.Status)) {
            Set-AagentProbeResult $Result unknown unknown 0 "Unknown" codex_probe_failed `
                login_status $probe.Status | Out-Null
        }
        return $Result
    }
    $text = $probe.Capture
    $probe.Capture = ""
    if ($text.Contains("Logged in using ChatGPT")) {
        $shadowing = Get-AagentPresentEnvironmentNames @("CODEX_API_KEY")
        Set-AagentProbeResult $Result ready unknown 2 "ChatGPT account" codex_login_text_chatgpt `
            login_status fallback_success $shadowing | Out-Null
    } elseif ($text.Contains("Logged in using an API key")) {
        Set-AagentProbeResult $Result ready payg_byok 2 "OpenAI API" codex_login_text_api `
            login_status fallback_success @("CODEX_API_KEY") | Out-Null
    } elseif ($text.Contains("Not logged in")) {
        if (-not (Set-AagentCodexEnvironmentResult $Result "fallback_success")) {
            Set-AagentProbeResult $Result unusable unknown 2 "Not signed in" codex_not_logged_in `
                login_status fallback_success | Out-Null
        }
    } elseif (-not (Set-AagentCodexEnvironmentResult $Result "schema_failure")) {
        Set-AagentProbeResult $Result unknown unknown 0 "Unknown" codex_fallback_schema_failure `
            login_status schema_failure | Out-Null
    }
    return $Result
}

function Invoke-AagentCodexProbe([string] $Executable) {
    $result = New-AagentProbeResult "codex"
    $protocolInput = @(
        '{"method":"initialize","id":0,"params":{"clientInfo":{"name":"aagent","title":"aagent","version":"0.1.0"}}}'
        '{"method":"initialized","params":{}}'
        '{"method":"account/read","id":1,"params":{"refreshToken":false}}'
        ""
    ) -join "`n"
    $probe = Invoke-AagentProbeProcess $Executable @("app-server") $protocolInput stdout 500
    if ($probe.Status -ne "success") {
        return Invoke-AagentCodexFallback $result $Executable
    }
    $message = Get-AagentCodexAccountResponse $probe.Capture
    $probe.Capture = ""
    if ($null -eq $message) {
        return Invoke-AagentCodexFallback $result $Executable
    }
    $rpcResult = Get-AagentJsonProperty $message "result"
    if ($null -eq $rpcResult) {
        return Invoke-AagentCodexFallback $result $Executable
    }
    $requiresOpenaiAuth = Get-AagentJsonProperty $rpcResult "requiresOpenaiAuth"
    if ($requiresOpenaiAuth -isnot [bool]) {
        return Invoke-AagentCodexFallback $result $Executable
    }
    $account = Get-AagentJsonProperty $rpcResult "account"
    if ($null -eq $account) {
        if ($requiresOpenaiAuth) {
            if (-not (Set-AagentCodexEnvironmentResult $result "success")) {
                Set-AagentProbeResult $result unusable unknown 4 "Not signed in" codex_not_logged_in `
                    app_server success | Out-Null
            }
        } else {
            Set-AagentProbeResult $result ready unknown 4 "Custom provider" codex_custom_provider `
                app_server success | Out-Null
        }
        return $result
    }
    $accountType = Get-AagentJsonProperty $account "type"
    if ($accountType -isnot [string]) {
        return Invoke-AagentCodexFallback $result $Executable
    }
    switch ($accountType.ToLowerInvariant()) {
        "chatgpt" {
            $planType = Get-AagentJsonProperty $account "planType"
            if ($planType -isnot [string]) { $planType = "" }
            $plan = Get-AagentCodexPlan $planType
            $shadowing = Get-AagentPresentEnvironmentNames @("CODEX_API_KEY")
            Set-AagentProbeResult $result ready $plan[1] 4 $plan[0] codex_chatgpt_account `
                app_server success $shadowing | Out-Null
        }
        "apikey" {
            Set-AagentProbeResult $result ready payg_byok 4 "OpenAI API" codex_api_account `
                app_server success | Out-Null
        }
        "amazonbedrock" {
            Set-AagentProbeResult $result ready unknown 4 "Amazon Bedrock" codex_bedrock_account `
                app_server success | Out-Null
        }
        default {
            Set-AagentProbeResult $result ready unknown 4 "Codex account" codex_unknown_account `
                app_server success | Out-Null
        }
    }
    return $result
}

function Set-AagentOpenCodeEnvironmentResult($Result, [string] $ProbeStatus) {
    $present = Get-AagentPresentEnvironmentNames @(
        "OPENAI_API_KEY", "ANTHROPIC_API_KEY", "GEMINI_API_KEY", "GOOGLE_API_KEY"
    )
    if ($present.Count -eq 0) { return $false }
    Set-AagentProbeResult $Result ready unknown 1 "Provider credential" opencode_environment_auth `
        environment $ProbeStatus $present | Out-Null
    return $true
}

function Invoke-AagentOpenCodeProbe([string] $Executable) {
    $result = New-AagentProbeResult "opencode"
    $probe = Invoke-AagentProbeProcess $Executable @("auth", "list")
    if ($probe.Status -ne "success") {
        if (-not (Set-AagentOpenCodeEnvironmentResult $result $probe.Status)) {
            Set-AagentProbeResult $result unknown unknown 0 "Unknown" opencode_probe_failed `
                auth_list $probe.Status | Out-Null
        }
        return $result
    }
    $text = $probe.Capture
    $probe.Capture = ""
    if (-not [string]::IsNullOrWhiteSpace($text) -and -not $text.Contains("No credentials")) {
        Set-AagentProbeResult $result ready unknown 2 "OpenCode credential" opencode_auth_list `
            auth_list success | Out-Null
    } elseif (-not (Set-AagentOpenCodeEnvironmentResult $result "success")) {
        Set-AagentProbeResult $result unknown unknown 2 "No confirmed credential" opencode_no_auth `
            auth_list success | Out-Null
    }
    return $result
}

function Read-AagentProbeFile([string] $Path) {
    try {
        if (-not (Test-Path -LiteralPath $Path)) {
            return New-AagentProbeProcessResult "not_found"
        }
        $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
        if ($item.PSIsContainer -or $item.Length -gt $AagentProbeMaxBytes) {
            return New-AagentProbeProcessResult $(if ($item.PSIsContainer) { "read_error" } else { "truncated" })
        }
        return New-AagentProbeProcessResult "success" ([IO.File]::ReadAllText($Path))
    } catch {
        return New-AagentProbeProcessResult "read_error"
    }
}

function Set-AagentGeminiEnvironmentResult($Result, [string] $ProbeStatus) {
    $api = Get-AagentPresentEnvironmentNames @("GEMINI_API_KEY", "GOOGLE_API_KEY")
    if ($api.Count -gt 0) {
        Set-AagentProbeResult $Result ready payg_byok 1 "Gemini API" gemini_api_environment `
            environment $ProbeStatus $api | Out-Null
        return $true
    }
    $cloud = Get-AagentPresentEnvironmentNames @(
        "GOOGLE_APPLICATION_CREDENTIALS", "GOOGLE_GENAI_USE_VERTEXAI", "GOOGLE_GENAI_USE_GCA",
        "GOOGLE_GEMINI_BASE_URL", "CLOUD_SHELL", "GEMINI_CLI_USE_COMPUTE_ADC"
    )
    if ($cloud.Count -gt 0) {
        Set-AagentProbeResult $Result ready unknown 1 "Google organization route" gemini_cloud_environment `
            environment $ProbeStatus $cloud | Out-Null
        return $true
    }
    return $false
}

function Invoke-AagentGeminiProbe {
    $result = New-AagentProbeResult "gemini"
    $homeDirectory = [Environment]::GetEnvironmentVariable("HOME", "Process")
    if ([string]::IsNullOrEmpty($homeDirectory)) {
        if (-not (Set-AagentGeminiEnvironmentResult $result "not_found")) {
            Set-AagentProbeResult $result unknown unknown 0 "Unknown" gemini_settings_missing `
                user_settings not_found | Out-Null
        }
        return $result
    }
    $path = [IO.Path]::Combine($homeDirectory, ".gemini", "settings.json")
    $file = Read-AagentProbeFile $path
    if ($file.Status -ne "success") {
        if (-not (Set-AagentGeminiEnvironmentResult $result $file.Status)) {
            Set-AagentProbeResult $result unknown unknown 0 "Unknown" gemini_settings_unavailable `
                user_settings $file.Status | Out-Null
        }
        return $result
    }
    $json = ConvertFrom-AagentProbeJson $file.Capture
    $file.Capture = ""
    $security = Get-AagentJsonProperty $json "security"
    $auth = Get-AagentJsonProperty $security "auth"
    $selectedType = Get-AagentJsonProperty $auth "selectedType"
    if ($selectedType -isnot [string]) {
        if (-not (Set-AagentGeminiEnvironmentResult $result "schema_failure")) {
            Set-AagentProbeResult $result unknown unknown 0 "Unknown" gemini_settings_schema_failure `
                user_settings schema_failure | Out-Null
        }
        return $result
    }
    switch ($selectedType.ToLowerInvariant()) {
        "oauth-personal" {
            Set-AagentProbeResult $result ready included_account 4 "Google account" gemini_oauth_personal `
                user_settings success | Out-Null
        }
        "gemini-api-key" {
            $shadowing = Get-AagentPresentEnvironmentNames @("GEMINI_API_KEY", "GOOGLE_API_KEY")
            Set-AagentProbeResult $result ready payg_byok 4 "Gemini API" gemini_api_key `
                user_settings success $shadowing | Out-Null
        }
        { $_ -in @("vertex-ai", "cloud-shell", "compute-default-credentials", "gateway") } {
            $shadowing = Get-AagentPresentEnvironmentNames @(
                "GOOGLE_APPLICATION_CREDENTIALS", "GOOGLE_GENAI_USE_VERTEXAI", "GOOGLE_GEMINI_BASE_URL"
            )
            Set-AagentProbeResult $result ready unknown 4 "Google organization route" gemini_organization_auth `
                user_settings success $shadowing | Out-Null
        }
        default {
            if (-not (Set-AagentGeminiEnvironmentResult $result "schema_failure")) {
                Set-AagentProbeResult $result unknown unknown 0 "Unknown" gemini_unknown_auth_type `
                    user_settings schema_failure | Out-Null
            }
        }
    }
    return $result
}

function Invoke-AagentAmpProbe {
    $result = New-AagentProbeResult "amp"
    if (Test-AagentEnvironmentPresent "AMP_API_KEY") {
        Set-AagentProbeResult $result ready unknown 1 "Amp account credential" amp_environment_auth `
            environment environment_only @("AMP_API_KEY") | Out-Null
    } else {
        Set-AagentProbeResult $result unknown unknown 0 "Unknown" amp_no_passive_probe `
            none skipped_no_passive | Out-Null
    }
    return $result
}

function Invoke-AagentProviderProbe([string] $Provider, [string] $Executable = "") {
    switch ($Provider) {
        "claude" { return Invoke-AagentClaudeProbe $Executable }
        "codex" { return Invoke-AagentCodexProbe $Executable }
        "opencode" { return Invoke-AagentOpenCodeProbe $Executable }
        "gemini" { return Invoke-AagentGeminiProbe }
        "amp" { return Invoke-AagentAmpProbe }
        default {
            $result = New-AagentProbeResult $Provider
            Set-AagentProbeResult $result unknown unknown 0 "Unknown" unsupported_probe none unsupported | Out-Null
            return $result
        }
    }
}

function Resolve-AagentPhysicalPath([string] $Path) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    $isLink = -not [string]::IsNullOrEmpty($item.LinkType)
    try {
        $target = $item.ResolveLinkTarget($true)
        if ($null -ne $target) {
            if (-not $target.Exists) {
                throw "Symbolic link target does not exist: $Path"
            }
            return $target.FullName
        }
    } catch {
        if ($isLink) {
            throw
        }
        # ResolveLinkTarget is unavailable for some non-link filesystem items.
    }
    if ($isLink) {
        throw "Symbolic link target does not exist: $Path"
    }
    return $item.FullName
}

function Test-AagentSamePath([string] $Left, [string] $Right) {
    try {
        $leftPath = Resolve-AagentPhysicalPath $Left
        $rightPath = Resolve-AagentPhysicalPath $Right
    } catch {
        return $false
    }

    $comparison = if ($IsWindows) {
        [StringComparison]::OrdinalIgnoreCase
    } else {
        [StringComparison]::Ordinal
    }
    return [string]::Equals($leftPath, $rightPath, $comparison)
}

function Resolve-AagentDiscoveryTarget($Adapter) {
    $overrideValue = [Environment]::GetEnvironmentVariable($Adapter.Override, "Process")
    $source = if ([string]::IsNullOrEmpty($overrideValue)) { "path" } else { "override" }
    $requested = if ($source -eq "override") { $overrideValue } else { $Adapter.Executable }
    $command = $null

    try {
        $command = Get-Command -Name $requested -CommandType Application, ExternalScript -ErrorAction Stop |
            Select-Object -First 1
    } catch {
        $reason = if ($source -eq "override") {
            "invalid executable override: $($Adapter.Override)"
        } else {
            "executable missing"
        }
        return [pscustomobject] @{
            Path = ""
            Source = $source
            Reason = $reason
            Found = $false
        }
    }

    $path = $command.Source
    if ([string]::IsNullOrEmpty($path)) {
        $path = $command.Path
    }
    if ([string]::IsNullOrEmpty($path) -or -not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $reason = if ($source -eq "override") {
            "invalid executable override: $($Adapter.Override)"
        } else {
            "executable missing"
        }
        return [pscustomobject] @{ Path = ""; Source = $source; Reason = $reason; Found = $false }
    }

    try {
        Resolve-AagentPhysicalPath $path | Out-Null
    } catch {
        $reason = if ($source -eq "override") {
            "invalid executable override: $($Adapter.Override)"
        } else {
            "executable missing"
        }
        return [pscustomobject] @{ Path = ""; Source = $source; Reason = $reason; Found = $false }
    }

    if (Test-AagentSamePath $path $AagentScriptPath) {
        return [pscustomobject] @{
            Path = ""
            Source = $source
            Reason = "resolved target is the aagent wrapper"
            Found = $false
        }
    }

    return [pscustomobject] @{
        Path = $path
        Source = $source
        Reason = "executable found"
        Found = $true
    }
}

function Get-AagentDiscovery {
    $results = [Collections.Generic.List[object]]::new()
    foreach ($adapter in (Get-AagentAdapterRegistry)) {
        $target = Resolve-AagentDiscoveryTarget $adapter
        if (-not $target.Found) {
            $status = "missing"
        } elseif ($adapter.Tier -eq "tier1") {
            $status = "installed"
        } else {
            $status = "unsupported"
            $target.Reason = "adapter planned; executable found"
        }

        $results.Add([pscustomobject] @{
            Adapter = $adapter
            Id = $adapter.Id
            Tier = $adapter.Tier
            Status = $status
            Path = $target.Path
            Source = $target.Source
            Reason = $target.Reason
        })
    }
    return $results
}

function Test-AagentEnvironmentName([string] $Name) {
    return $Name -cmatch "^[A-Za-z_][A-Za-z0-9_]*$"
}

function New-AagentLaunchPlan {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Executable,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]] $Arguments,
        [Parameter(Mandatory = $true)]
        [string] $WorkingDirectory,
        [Parameter(Mandatory = $true)]
        [ValidateSet("inherit", "closed", "data")]
        [string] $StdinMode,
        [AllowEmptyString()]
        [string] $Stdin = "",
        [ValidateSet("argv", "stdin", "both", "none")]
        [string] $InputDescription = "none"
    )

    if (-not (Test-Path -LiteralPath $Executable -PathType Leaf)) {
        throw "launch executable is unavailable: $Executable"
    }
    if (-not (Test-Path -LiteralPath $WorkingDirectory -PathType Container)) {
        throw "launch working directory is unavailable: $WorkingDirectory"
    }

    $resolvedExecutable = (Resolve-Path -LiteralPath $Executable -ErrorAction Stop).ProviderPath
    $resolvedWorkingDirectory = (Resolve-Path -LiteralPath $WorkingDirectory -ErrorAction Stop).ProviderPath
    $displayArguments = [Collections.Generic.List[string]]::new()
    foreach ($argument in $Arguments) {
        $displayArguments.Add("<redacted>")
    }

    return [pscustomobject] @{
        Executable = $resolvedExecutable
        Arguments = [string[]] $Arguments
        WorkingDirectory = $resolvedWorkingDirectory
        StdinMode = $StdinMode
        Stdin = $Stdin
        InputDescription = $InputDescription
        EnvironmentSet = [ordered] @{}
        EnvironmentUnset = [Collections.Generic.List[string]]::new()
        DisplayArguments = $displayArguments
        Provider = ""
        Reason = ""
        Notice = ""
    }
}

function Set-AagentLaunchEnvironment($Plan, [string] $Name, [AllowEmptyString()][string] $Value) {
    if (-not (Test-AagentEnvironmentName $Name)) {
        throw "invalid child environment name: $Name"
    }
    $Plan.EnvironmentSet[$Name] = $Value
}

function Remove-AagentLaunchEnvironment($Plan, [string] $Name) {
    if (-not (Test-AagentEnvironmentName $Name)) {
        throw "invalid child environment name: $Name"
    }
    $Plan.EnvironmentUnset.Add($Name)
}

function Set-AagentLaunchDisplayArguments($Plan, [string[]] $Arguments) {
    if ($Arguments.Count -ne $Plan.Arguments.Count) {
        throw "launch display argument count differs from argv"
    }
    $Plan.DisplayArguments.Clear()
    foreach ($argument in $Arguments) {
        $Plan.DisplayArguments.Add($argument)
    }
}

function ConvertTo-AagentDisplayArgument([AllowEmptyString()][string] $Value) {
    return "'$($Value.Replace("'", "''"))'"
}

function Show-AagentEnvironmentNames([string] $Label, [string[]] $Names) {
    if ($Names.Count -eq 0) {
        [Console]::Out.WriteLine("${Label}: (none)")
    } else {
        [Console]::Out.WriteLine("${Label}: $($Names -join ' ')")
    }
}

function Show-AagentLaunchPlan($Plan) {
    $provider = if ([string]::IsNullOrEmpty($Plan.Provider)) { "unknown" } else { $Plan.Provider }
    $reason = if ([string]::IsNullOrEmpty($Plan.Reason)) { "not specified" } else { $Plan.Reason }
    $command = [Collections.Generic.List[string]]::new()
    $command.Add((ConvertTo-AagentDisplayArgument $Plan.Executable))
    foreach ($argument in $Plan.DisplayArguments) {
        $command.Add((ConvertTo-AagentDisplayArgument $argument))
    }

    [Console]::Out.WriteLine("provider: $provider")
    [Console]::Out.WriteLine("reason: $reason")
    [Console]::Out.WriteLine("command: $($command -join ' ')")
    [Console]::Out.WriteLine("working directory: $(ConvertTo-AagentDisplayArgument $Plan.WorkingDirectory)")
    [Console]::Out.WriteLine("stdin: $($Plan.InputDescription)")
    Show-AagentEnvironmentNames "set environment" ([string[]] $Plan.EnvironmentSet.Keys)
    Show-AagentEnvironmentNames "unset environment" ([string[]] $Plan.EnvironmentUnset)
}

function Write-AagentNotice([bool] $Quiet, [string] $Message) {
    if (-not $Quiet -and -not [string]::IsNullOrEmpty($Message)) {
        [Console]::Error.WriteLine("aagent: $Message")
    }
}

function Get-AagentLaunchCommand($Plan) {
    $arguments = [Collections.Generic.List[string]]::new()
    $extension = [IO.Path]::GetExtension($Plan.Executable)

    if ([string]::Equals($extension, ".ps1", [StringComparison]::OrdinalIgnoreCase)) {
        $hostExecutable = (Get-Process -Id $PID).Path
        $arguments.Add("-NoProfile")
        $arguments.Add("-File")
        $arguments.Add($Plan.Executable)
        foreach ($argument in $Plan.Arguments) {
            $arguments.Add($argument)
        }
        return [pscustomobject] @{
            Executable = $hostExecutable
            Arguments = $arguments
        }
    }

    if ($IsWindows -and $extension -in @(".cmd", ".bat")) {
        throw "batch launch is unsafe for untrusted arguments; install or select the PowerShell or executable shim"
    }

    foreach ($argument in $Plan.Arguments) {
        $arguments.Add($argument)
    }
    return [pscustomobject] @{
        Executable = $Plan.Executable
        Arguments = $arguments
    }
}

function Invoke-AagentLaunchPlan {
    param(
        [Parameter(Mandatory = $true)]
        $Plan,
        [switch] $DryRun,
        [switch] $Quiet
    )

    if ($DryRun) {
        Show-AagentLaunchPlan $Plan
        return $AagentExitOk
    }

    Write-AagentNotice -Quiet:$Quiet -Message $Plan.Notice

    $process = $null
    try {
        $command = Get-AagentLaunchCommand $Plan
        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $command.Executable
        $startInfo.UseShellExecute = $false
        $startInfo.WorkingDirectory = $Plan.WorkingDirectory
        foreach ($argument in $command.Arguments) {
            $startInfo.ArgumentList.Add($argument)
        }

        foreach ($name in $Plan.EnvironmentUnset) {
            $startInfo.Environment.Remove($name) | Out-Null
        }
        foreach ($entry in $Plan.EnvironmentSet.GetEnumerator()) {
            $startInfo.Environment[$entry.Key] = $entry.Value
        }

        if ($Plan.StdinMode -in @("closed", "data")) {
            $startInfo.RedirectStandardInput = $true
            $startInfo.StandardInputEncoding = [Text.UTF8Encoding]::new($false)
        }

        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        if (-not $process.Start()) {
            [Console]::Error.WriteLine("aagent: could not start provider process")
            return $AagentExitSoftware
        }

        if ($Plan.StdinMode -eq "data") {
            $process.StandardInput.Write($Plan.Stdin)
        }
        if ($Plan.StdinMode -in @("closed", "data")) {
            $process.StandardInput.Close()
        }

        $process.WaitForExit()
        return $process.ExitCode
    } catch {
        if ($null -ne $process -and -not $process.HasExited) {
            $process.Kill($true)
            $process.WaitForExit()
        }
        [Console]::Error.WriteLine("aagent: provider launch failed: $($_.Exception.Message)")
        return $AagentExitSoftware
    } finally {
        if ($null -ne $process) {
            $process.Dispose()
        }
    }
}

function New-AagentAdapterBuildResult([int] $Status, [string] $Error, $Plan) {
    return [pscustomobject] @{
        Status = $Status
        Error = $Error
        Plan = $Plan
    }
}

function New-AagentAdapterLaunchPlan($Result, $Adapter, [string] $Executable) {
    $arguments = [Collections.Generic.List[string]]::new()
    $displayArguments = [Collections.Generic.List[string]]::new()
    $stdinMode = "inherit"
    $stdinData = ""
    $inputDescription = "argv"

    switch ($Result.InputMode) {
        "prompt" {
            $stdinMode = "inherit"
            $inputDescription = "argv"
        }
        "stdin" {
            $stdinMode = "data"
            $stdinData = $Result.Stdin
            $inputDescription = "stdin"
        }
        "both" {
            $stdinMode = "data"
            $stdinData = $Result.Stdin
            $inputDescription = "both"
        }
        default {
            return New-AagentAdapterBuildResult `
                $AagentExitSoftware `
                "unsupported resolved input mode: $($Result.InputMode)" `
                $null
        }
    }

    switch ($Adapter.Id) {
        "claude" {
            $arguments.Add("--print")
            $displayArguments.Add("--print")
            if ($Result.InputMode -ne "stdin") {
                $arguments.Add($Result.Prompt)
                $displayArguments.Add("<prompt>")
            }
            if (-not [string]::IsNullOrEmpty($Result.Model)) {
                $arguments.Add("--model")
                $displayArguments.Add("--model")
                $arguments.Add($Result.Model)
                $displayArguments.Add("<model>")
            }
            foreach ($argument in $Result.NativeArguments) {
                $arguments.Add($argument)
                $displayArguments.Add("<native>")
            }
        }
        "codex" {
            $arguments.Add("exec")
            $displayArguments.Add("exec")
            if (-not [string]::IsNullOrEmpty($Result.Model)) {
                $arguments.Add("--model")
                $displayArguments.Add("--model")
                $arguments.Add($Result.Model)
                $displayArguments.Add("<model>")
            }
            foreach ($argument in $Result.NativeArguments) {
                $arguments.Add($argument)
                $displayArguments.Add("<native>")
            }
            if ($Result.InputMode -eq "stdin") {
                $arguments.Add("-")
                $displayArguments.Add("-")
            } else {
                $arguments.Add($Result.Prompt)
                $displayArguments.Add("<prompt>")
            }
        }
        "opencode" {
            $arguments.Add("run")
            $displayArguments.Add("run")
            if (-not [string]::IsNullOrEmpty($Result.Model)) {
                $arguments.Add("--model")
                $displayArguments.Add("--model")
                $arguments.Add($Result.Model)
                $displayArguments.Add("<model>")
            }
            foreach ($argument in $Result.NativeArguments) {
                $arguments.Add($argument)
                $displayArguments.Add("<native>")
            }

            $combinedPrompt = switch ($Result.InputMode) {
                "prompt" { $Result.Prompt }
                "stdin" { $Result.Stdin }
                "both" { "$($Result.Prompt)`n`n--- stdin context ---`n$($Result.Stdin)" }
            }
            $arguments.Add($combinedPrompt)
            $displayArguments.Add("<prompt>")
            $stdinMode = "closed"
            $stdinData = ""
            $inputDescription = "argv"
        }
        "amp" {
            if (-not [string]::IsNullOrEmpty($Result.Model)) {
                return New-AagentAdapterBuildResult `
                    $AagentExitUsage `
                    "provider amp does not support --model" `
                    $null
            }
            $arguments.Add("--execute")
            $displayArguments.Add("--execute")
            if ($Result.InputMode -ne "stdin") {
                $arguments.Add($Result.Prompt)
                $displayArguments.Add("<prompt>")
            }
            foreach ($argument in $Result.NativeArguments) {
                $arguments.Add($argument)
                $displayArguments.Add("<native>")
            }
        }
        "gemini" {
            if (-not [string]::IsNullOrEmpty($Result.Model)) {
                $arguments.Add("--model")
                $displayArguments.Add("--model")
                $arguments.Add($Result.Model)
                $displayArguments.Add("<model>")
            }
            foreach ($argument in $Result.NativeArguments) {
                $arguments.Add($argument)
                $displayArguments.Add("<native>")
            }
            if ($Result.InputMode -ne "stdin") {
                $arguments.Add("--prompt")
                $displayArguments.Add("--prompt")
                $arguments.Add($Result.Prompt)
                $displayArguments.Add("<prompt>")
            }
        }
        default {
            return New-AagentAdapterBuildResult `
                $AagentExitUsage `
                "provider adapter is not implemented: $($Adapter.Id)" `
                $null
        }
    }

    try {
        $plan = New-AagentLaunchPlan `
            -Executable $Executable `
            -Arguments ([string[]] $arguments) `
            -WorkingDirectory $Result.Cwd `
            -StdinMode $stdinMode `
            -Stdin $stdinData `
            -InputDescription $inputDescription
        if ($displayArguments.Count -gt 0) {
            Set-AagentLaunchDisplayArguments $plan ([string[]] $displayArguments)
        }
        $plan.Provider = $Adapter.Id
        $plan.Reason = $Result.ProviderSourceLabel
        $plan.Notice = "selected $($Adapter.Name) via $($Result.ProviderSourceLabel)"
        return New-AagentAdapterBuildResult $AagentExitOk "" $plan
    } catch {
        return New-AagentAdapterBuildResult $AagentExitSoftware $_.Exception.Message $null
    }
}

function Invoke-AagentExplicitProvider($Result) {
    $adapter = Get-AagentAdapter $Result.Provider
    if ($null -eq $adapter) {
        Write-AagentUsageError "unknown provider: $($Result.Provider)"
        return $AagentExitUsage
    }
    if ($adapter.Tier -ne "tier1") {
        Write-AagentUsageError "provider adapter is not implemented: $($Result.Provider)"
        return $AagentExitUsage
    }

    $target = Resolve-AagentDiscoveryTarget $adapter
    if (-not $target.Found) {
        [Console]::Error.WriteLine(
            "aagent: provider $($Result.Provider) selected via $($Result.ProviderSourceLabel) is unavailable: $($target.Reason)"
        )
        return $AagentExitUnavailable
    }

    $build = New-AagentAdapterLaunchPlan $Result $adapter $target.Path
    if ($build.Status -ne $AagentExitOk) {
        if ($build.Status -eq $AagentExitUsage) {
            Write-AagentUsageError $build.Error
        } elseif (-not [string]::IsNullOrEmpty($build.Error)) {
            [Console]::Error.WriteLine("aagent: $($build.Error)")
        }
        return $build.Status
    }

    return Invoke-AagentLaunchPlan -Plan $build.Plan -DryRun:$Result.DryRun -Quiet:$Result.Quiet
}

function Show-AagentHelp {
    @'
aagent
Run any CLI coding agent with a single command.

Usage:
  aagent [OPTIONS] [PROMPT...]
  aagent providers
  aagent doctor [PROVIDER]
  aagent --help
  aagent --version

Options:
  -P, --provider ID     Use a specific provider
  -m, --model ID        Request a provider-native model ID
  -C, --cwd DIRECTORY   Run from this working directory
      --auth-policy P   Authentication policy: prefer-included or native
      --priority IDS    Comma-separated provider tie-break order
      --allow-local B   Allow local models: true or false
      --dry-run         Print the resolved invocation without running it
      --quiet           Do not print the provider-selection notice
  -h, --help            Show this help message
      --version         Show the aagent version
      --                Treat remaining arguments as provider-native options

Input:
  Prompt arguments are joined with one space. With no prompt, piped stdin is
  used. With both, the prompt is the instruction and stdin is extra context.

Examples:
  aagent "say hello"
  aagent --provider codex "explain this repository"
  git diff | aagent "summarize these changes"
  aagent -P codex "fix the tests" -- --sandbox workspace-write
'@
}

function New-AagentParseResult {
    return [pscustomobject] @{
        Command = "run"
        Provider = ""
        ProviderSpecified = $false
        ProviderSource = ""
        ProviderSourceLabel = ""
        Model = ""
        Cwd = ""
        AuthPolicy = ""
        AuthPolicySpecified = $false
        AuthPolicySource = ""
        Priority = ""
        PrioritySpecified = $false
        PrioritySource = ""
        PriorityRole = ""
        AllowLocal = ""
        AllowLocalSpecified = $false
        AllowLocalSource = ""
        DryRun = $false
        Quiet = $false
        DoctorProvider = ""
        PromptArguments = [Collections.Generic.List[string]]::new()
        NativeArguments = [Collections.Generic.List[string]]::new()
        Prompt = ""
        Stdin = ""
        InputMode = ""
        Error = ""
        Status = $AagentExitOk
    }
}

function Set-AagentParseError($Result, [string] $Message) {
    $Result.Error = $Message
    $Result.Status = $AagentExitUsage
    return $Result
}

function Test-AagentOptionValue($Result, [string] $Option, [string[]] $Arguments, [int] $Index) {
    if ($Index + 1 -ge $Arguments.Count -or [string]::IsNullOrEmpty($Arguments[$Index + 1])) {
        Set-AagentParseError $Result "option $Option requires a value" | Out-Null
        return $false
    }
    return $true
}

function Resolve-AagentCwd($Result) {
    if ([string]::IsNullOrEmpty($Result.Cwd)) {
        $Result.Cwd = (Get-Location).ProviderPath
        return $Result
    }

    if (-not (Test-Path -LiteralPath $Result.Cwd -PathType Container)) {
        return Set-AagentParseError $Result "working directory does not exist: $($Result.Cwd)"
    }

    try {
        $resolved = Resolve-Path -LiteralPath $Result.Cwd -ErrorAction Stop
        if ($resolved.Provider.Name -ne "FileSystem") {
            return Set-AagentParseError $Result "working directory is not a filesystem path: $($Result.Cwd)"
        }
        $Result.Cwd = $resolved.ProviderPath
        return $Result
    } catch {
        return Set-AagentParseError $Result "cannot access working directory: $($Result.Cwd)"
    }
}

function Parse-AagentArguments {
    param([string[]] $Arguments)

    $result = New-AagentParseResult
    $index = 0

    while ($index -lt $Arguments.Count) {
        $token = $Arguments[$index]

        switch ($token) {
            { $_ -in @("-h", "--help") } {
                $result.Command = "help"
                return $result
            }
            "--version" {
                $result.Command = "version"
                return $result
            }
            { $_ -in @("-P", "--provider") } {
                if (-not (Test-AagentOptionValue $result $token $Arguments $index)) { return $result }
                $result.Provider = $Arguments[$index + 1]
                $result.ProviderSpecified = $true
                $index += 2
                continue
            }
            { $_ -in @("-m", "--model") } {
                if (-not (Test-AagentOptionValue $result $token $Arguments $index)) { return $result }
                $result.Model = $Arguments[$index + 1]
                $index += 2
                continue
            }
            { $_ -in @("-C", "--cwd") } {
                if (-not (Test-AagentOptionValue $result $token $Arguments $index)) { return $result }
                $result.Cwd = $Arguments[$index + 1]
                $index += 2
                continue
            }
            "--auth-policy" {
                if (-not (Test-AagentOptionValue $result $token $Arguments $index)) { return $result }
                $policy = $Arguments[$index + 1]
                if ($policy -notin @("prefer-included", "native")) {
                    return Set-AagentParseError $result "invalid authentication policy: $policy"
                }
                $result.AuthPolicy = $policy
                $result.AuthPolicySpecified = $true
                $index += 2
                continue
            }
            "--priority" {
                if (-not (Test-AagentOptionValue $result $token $Arguments $index)) { return $result }
                $result.Priority = $Arguments[$index + 1]
                $result.PrioritySpecified = $true
                $index += 2
                continue
            }
            "--allow-local" {
                if (-not (Test-AagentOptionValue $result $token $Arguments $index)) { return $result }
                $allowLocal = $Arguments[$index + 1]
                if ($allowLocal -cnotin @("true", "false")) {
                    return Set-AagentParseError $result "invalid --allow-local value"
                }
                $result.AllowLocal = $allowLocal
                $result.AllowLocalSpecified = $true
                $index += 2
                continue
            }
            "--dry-run" {
                $result.DryRun = $true
                $index++
                continue
            }
            "--quiet" {
                $result.Quiet = $true
                $index++
                continue
            }
            "--" {
                for ($nativeIndex = $index + 1; $nativeIndex -lt $Arguments.Count; $nativeIndex++) {
                    $result.NativeArguments.Add($Arguments[$nativeIndex])
                }
                $index = $Arguments.Count
                continue
            }
            "providers" {
                if ($result.PromptArguments.Count -gt 0) {
                    $result.PromptArguments.Add($token)
                    $index++
                    continue
                } else {
                    $result.Command = "providers"
                    if ($index + 1 -lt $Arguments.Count) {
                        return Set-AagentParseError $result "providers does not accept arguments"
                    }
                    $index = $Arguments.Count
                    continue
                }
            }
            "doctor" {
                if ($result.PromptArguments.Count -gt 0) {
                    $result.PromptArguments.Add($token)
                    $index++
                    continue
                } else {
                    $result.Command = "doctor"
                    $remaining = $Arguments.Count - $index - 1
                    if ($remaining -gt 1) {
                        return Set-AagentParseError $result "doctor accepts at most one provider"
                    }
                    if ($remaining -eq 1) {
                        $doctorProvider = $Arguments[$index + 1]
                        if ($doctorProvider.StartsWith("-")) {
                            return Set-AagentParseError $result "unknown option: $doctorProvider"
                        }
                        $result.DoctorProvider = $doctorProvider
                    }
                    $index = $Arguments.Count
                    continue
                }
            }
            { $_.StartsWith("-") } {
                return Set-AagentParseError $result "unknown option: $token"
            }
            default {
                $result.PromptArguments.Add($token)
                $index++
                continue
            }
        }
    }

    return Resolve-AagentCwd $result
}

function Resolve-AagentInput {
    param(
        $Result,
        [bool] $StdinAvailable,
        [AllowEmptyString()]
        [string] $StdinData
    )

    $Result.Prompt = [string]::Join(" ", [string[]] $Result.PromptArguments)
    $Result.Stdin = $StdinData

    if ($Result.PromptArguments.Count -gt 0 -and [string]::IsNullOrEmpty($Result.Prompt)) {
        return Set-AagentParseError $Result "prompt must not be empty"
    }

    if (
        -not [string]::IsNullOrEmpty($Result.Prompt) -and
        $StdinAvailable -and
        -not [string]::IsNullOrEmpty($Result.Stdin)
    ) {
        $Result.InputMode = "both"
    } elseif (-not [string]::IsNullOrEmpty($Result.Prompt)) {
        $Result.InputMode = "prompt"
        $Result.Stdin = ""
    } elseif ($StdinAvailable -and -not [string]::IsNullOrEmpty($Result.Stdin)) {
        $Result.InputMode = "stdin"
    } else {
        return Set-AagentParseError $Result "a non-empty prompt or piped stdin is required"
    }

    return $Result
}

function Write-AagentUsageError([string] $Message) {
    [Console]::Error.WriteLine("aagent: $Message")
    [Console]::Error.WriteLine("Try 'aagent --help' for more information.")
}

function Invoke-Aagent {
    param([string[]] $Arguments)

    $result = Parse-AagentArguments -Arguments $Arguments
    if ($result.Status -ne $AagentExitOk) {
        Write-AagentUsageError $result.Error
        return $result.Status
    }

    switch ($result.Command) {
        "help" {
            [Console]::Out.WriteLine((Show-AagentHelp))
            return $AagentExitOk
        }
        "version" {
            [Console]::Out.WriteLine("aagent $AagentVersion")
            return $AagentExitOk
        }
    }

    $result = Resolve-AagentConfiguration -Result $result -Doctor:($result.Command -eq "doctor")
    if ($result.Status -ne $AagentExitOk) {
        if ($result.Status -eq $AagentExitUsage) {
            Write-AagentUsageError $result.Error
        }
        return $result.Status
    }

    if ($result.Command -in @("providers", "doctor")) {
        [Console]::Error.WriteLine("aagent: $($result.Command) is not available in this build yet")
        return $AagentExitUnavailable
    }

    $stdinAvailable = [Console]::IsInputRedirected
    $stdinData = if ($stdinAvailable) { [Console]::In.ReadToEnd() } else { "" }
    $result = Resolve-AagentInput -Result $result -StdinAvailable $stdinAvailable -StdinData $stdinData
    if ($result.Status -ne $AagentExitOk) {
        Write-AagentUsageError $result.Error
        return $result.Status
    }

    if (-not [string]::IsNullOrEmpty($result.Provider)) {
        return Invoke-AagentExplicitProvider $result
    }

    [Console]::Error.WriteLine("aagent: automatic provider selection is not available in this build yet")
    return $AagentExitUnavailable
}

if ($MyInvocation.InvocationName -ne ".") {
    exit (Invoke-Aagent -Arguments $args)
}
