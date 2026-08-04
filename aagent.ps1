$ErrorActionPreference = "Stop"

Set-Variable -Name AagentExitOk -Value 0 -Option Constant -Scope Script
Set-Variable -Name AagentExitUsage -Value 64 -Option Constant -Scope Script
Set-Variable -Name AagentExitUnavailable -Value 69 -Option Constant -Scope Script
Set-Variable -Name AagentExitSoftware -Value 70 -Option Constant -Scope Script
Set-Variable -Name AagentExitConfig -Value 78 -Option Constant -Scope Script
Set-Variable -Name AagentVersion -Value "0.1.0-dev" -Option Constant -Scope Script

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
