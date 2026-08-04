$ErrorActionPreference = "Stop"

Set-Variable -Name AagentExitOk -Value 0 -Option Constant -Scope Script
Set-Variable -Name AagentExitUsage -Value 64 -Option Constant -Scope Script
Set-Variable -Name AagentExitUnavailable -Value 69 -Option Constant -Scope Script
Set-Variable -Name AagentExitSoftware -Value 70 -Option Constant -Scope Script
Set-Variable -Name AagentExitConfig -Value 78 -Option Constant -Scope Script

function Show-Help {
    @'
aagent
Run any CLI coding agent with a single command.

Usage:
  aagent [options]

Options:
  -h, --help  Show this help message
'@
}

$firstArgument = if ($args.Count -gt 0) { $args[0] } else { "" }

switch ($firstArgument) {
    "" {
        Show-Help
        break
    }
    "-h" {
        Show-Help
        break
    }
    "--help" {
        Show-Help
        break
    }
    default {
        [Console]::Error.WriteLine("aagent: unknown argument: $firstArgument")
        [Console]::Error.WriteLine("Try 'aagent --help' for more information.")
        exit $AagentExitUsage
    }
}
