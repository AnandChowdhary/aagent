$ErrorActionPreference = "Stop"

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
        exit 1
    }
}
