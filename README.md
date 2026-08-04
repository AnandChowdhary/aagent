# Agent

Run any CLI coding agent with a single command.

Agent is an intentionally small scaffold for now. The Bash and PowerShell runners only support `--help`.

## Installation

On macOS and Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/AnandChowdhary/agent/main/install.sh | bash
agent --help
```

On Windows with PowerShell 7:

```powershell
irm https://raw.githubusercontent.com/AnandChowdhary/agent/main/install.ps1 | iex
pwsh ~/.local/bin/agent.ps1 --help
```

## Manual usage

Run the Bash script directly on macOS, Linux, or Windows with Git Bash or WSL:

```bash
./agent.sh --help
```

Run the native PowerShell script on Windows:

```powershell
pwsh ./agent.ps1 --help
```

## Development

Run the Bash smoke tests:

```bash
bash ./tests/test_agent.sh
```

Run the PowerShell smoke tests:

```powershell
pwsh ./tests/test_agent.ps1
```

GitHub Actions runs the Bash suite on Linux, macOS, and Windows, and the PowerShell suite on Windows.

## License

[MIT](LICENSE)
