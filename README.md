# aagent

Run any CLI coding agent with a single command.

`aagent` is being implemented in the phases tracked by `TODO.md`. The current
build implements the complete wrapper grammar, prompt/stdin resolution,
working-directory validation, `--help`, `--version`, the static provider
registry, and side-effect-free executable discovery. Provider process execution
now has a shared launch-plan contract and safe Bash/PowerShell execution core.
The five Tier 1 adapters (Claude, Codex, OpenCode, Amp, and Gemini) can be run
with an explicit provider selected by command line, environment, or strict user
configuration. Bounded passive authentication probes now classify safe local
evidence for every Tier 1 provider without opening credential stores or sending
model requests. With no explicit provider, deterministic automatic selection
prefers ready included accounts over metered API paths, then breaks exact ties
by authentication confidence, configured priority, the frozen popularity
prior, and stable registry order. Safe introspection is available through
`aagent providers`, `aagent doctor [PROVIDER]`, and `--dry-run`; these commands
use bounded passive probes and never start a model run.

The default `prefer-included` authentication policy also keeps metered API
variables from silently shadowing a confirmed Claude or ChatGPT account. Any
adjustment is limited to the selected child process, disclosed by environment
variable name, and redacted in dry-run output. `--auth-policy native` disables
all such set/omit behavior.

```bash
aagent "say hello"
aagent --provider claude "say hello"
aagent --provider codex --model gpt-5.4 "explain this repository"
git diff | aagent --provider gemini "summarize these changes"
aagent providers
aagent doctor codex
aagent --dry-run "say hello"
```

Optional user configuration lives at
`${XDG_CONFIG_HOME:-$HOME/.config}/aagent/config` on macOS/Linux and
`%APPDATA%\aagent\config` on Windows:

```ini
provider=codex
auth_policy=prefer-included
priority=codex,claude,opencode
allow_local=false
```

The file is strict inert `key=value` data; it is never sourced. Command-line
options override `AAGENT_*` environment variables, which override this file.
See the [command-line contract](docs/spec/cli-contract.md#configuration) for
the exact grammar and precedence table.

## Specification

- [SPEC.md](SPEC.md) is the product contract and index to the focused specification documents.
- [TODO.md](TODO.md) is the authoritative, phase-gated implementation ledger.

## Installation

On macOS and Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/AnandChowdhary/aagent/main/install.sh | bash
"$HOME/.local/bin/aagent" --help
```

The installer downloads the runner and `SHA256SUMS` independently, verifies the
runner before executing it, smoke-tests `--help` and `--version`, and then
replaces any existing install with a same-directory move. A failed download,
checksum, or smoke test leaves the current installation untouched.

On Windows with PowerShell 7:

```powershell
irm https://raw.githubusercontent.com/AnandChowdhary/aagent/main/install.ps1 | iex
& "$HOME/.local/bin/aagent.cmd" --help
```

The PowerShell installer writes both `aagent.ps1` and an `aagent.cmd` launcher
to `%USERPROFILE%\.local\bin`. Add that directory to `PATH` when prompted.

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

GitHub Actions runs the Bash suite on Linux, macOS, and Windows, and the
PowerShell suite on Windows. Both entrypoints include atomic installation,
strict configuration, passive probes, deterministic selection, child
authentication policy, process launch, introspection, security audits, and
Tier 1 adapter contract tests.

The test entrypoints create an isolated home, configuration directory, and
controlled `PATH`. Tier 1 provider behavior is simulated by credential-free
fake executables documented in
[tests/helpers/README.md](tests/helpers/README.md); normal tests never invoke a
locally installed coding agent. Launch tests verify argument boundaries, exact
stdin, child-only cwd and environment changes, stdout/stderr separation, native
statuses, interruption behavior where CI supports it, and redacted dry-runs.
Adapter snapshots additionally prove provider-specific command order, all three
input modes, model behavior, native options, safety defaults, and one-run-only
failure handling without credentials or network requests.

The security fixtures reject generated permission-escalation flags, ban
command-string evaluation, place traps at credential-file and credential-helper
boundaries, fuzz user-controlled arguments, and distinguish wrapper-owned
statuses from identical statuses returned by a launched provider.

## License

[MIT](LICENSE)
