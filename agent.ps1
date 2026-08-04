$ErrorActionPreference = "Stop"

function Show-Help {
    @'
Agent
Run any CLI coding agent with a single command.

Usage:
  agent [options]

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
        [Console]::Error.WriteLine("agent: unknown argument: $firstArgument")
        [Console]::Error.WriteLine("Try 'agent --help' for more information.")
        exit 1
    }
}
