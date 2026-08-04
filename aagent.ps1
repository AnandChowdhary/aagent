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
        Model = ""
        Cwd = ""
        AuthPolicy = "prefer-included"
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
        { $_ -in @("providers", "doctor") } {
            [Console]::Error.WriteLine("aagent: $($result.Command) is not available in this build yet")
            return $AagentExitUnavailable
        }
    }

    $stdinAvailable = [Console]::IsInputRedirected
    $stdinData = if ($stdinAvailable) { [Console]::In.ReadToEnd() } else { "" }
    $result = Resolve-AagentInput -Result $result -StdinAvailable $stdinAvailable -StdinData $stdinData
    if ($result.Status -ne $AagentExitOk) {
        Write-AagentUsageError $result.Error
        return $result.Status
    }

    [Console]::Error.WriteLine("aagent: provider discovery is not available in this build yet")
    return $AagentExitUnavailable
}

if ($MyInvocation.InvocationName -ne ".") {
    exit (Invoke-Aagent -Arguments $args)
}
