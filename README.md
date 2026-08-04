# aagent

Run any CLI coding agent with a single command.

`aagent` is being implemented in the phases tracked by `TODO.md`. The current
build implements the complete wrapper grammar, prompt/stdin resolution,
working-directory validation, `--help`, and `--version`. Provider discovery and
execution are the next phases, so a valid prompt currently exits with status
`69` instead of starting a locally installed agent.

## Specification

- [SPEC.md](SPEC.md) is the product contract and index to the focused specification documents.
- [TODO.md](TODO.md) is the authoritative, phase-gated implementation ledger.

## Installation

On macOS and Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/AnandChowdhary/aagent/main/install.sh | bash
aagent --help
```

On Windows with PowerShell 7:

```powershell
irm https://raw.githubusercontent.com/AnandChowdhary/aagent/main/install.ps1 | iex
pwsh ~/.local/bin/aagent.ps1 --help
```

## Manual usage

Run the Bash script directly on macOS, Linux, or Windows with Git Bash or WSL:

```bash
./aagent.sh --help
./aagent.sh --version
```

Run the native PowerShell script on Windows:

```powershell
pwsh ./aagent.ps1 --help
pwsh ./aagent.ps1 --version
```

## Development

Run the Bash smoke tests:

```bash
bash ./tests/test_aagent.sh
```

Run the PowerShell smoke tests:

```powershell
pwsh ./tests/test_aagent.ps1
```

GitHub Actions runs the Bash suite on Linux, macOS, and Windows, and the PowerShell suite on Windows.

The test entrypoints create an isolated home, configuration directory, and
controlled `PATH`. Tier 1 provider behavior is simulated by credential-free
fake executables documented in
[tests/helpers/README.md](tests/helpers/README.md); normal tests never invoke a
locally installed coding agent.

## License

[MIT](LICENSE)
