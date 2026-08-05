# aagent

Run whichever CLI coding agent you already have with one command.

```console
$ aagent "say hello"
aagent: using codex (included_confirmed, ChatGPT Pro; only eligible provider)
Hello!
```

`aagent` discovers installed coding-agent CLIs, checks only passive non-secret
authentication signals, chooses one deterministically, and runs it headlessly.
It prefers an included subscription or seat over a metered API path so that the
default choice minimizes marginal cost. You can always select a provider
explicitly.

The core is dependency-free: `aagent.sh` supports Bash and `aagent.ps1`
supports PowerShell 7. Authentication, billing, models, tools, repository
instructions, and permissions remain owned by the selected provider.

## Install

Install at least one [supported provider](#supported-providers) first. `aagent`
does not install or sign in to coding agents.

### macOS, Linux, Git Bash, or WSL

```bash
AAGENT_VERSION=0.1.1
AAGENT_BASE_URL="https://github.com/AnandChowdhary/aagent/releases/download/v${AAGENT_VERSION}"
curl -fsSL "$AAGENT_BASE_URL/install.sh" |
  AAGENT_DOWNLOAD_BASE_URL="$AAGENT_BASE_URL" \
  AAGENT_EXPECTED_VERSION="$AAGENT_VERSION" bash
export PATH="$HOME/.local/bin:$PATH"
aagent --version
```

The installer downloads `aagent.sh` and `SHA256SUMS` independently, verifies
the checksum, smoke-tests `--help` and `--version`, and atomically installs
`~/.local/bin/aagent`. A failed download or check leaves an existing install
untouched. Set `INSTALL_DIR` to choose a different destination.

### Windows PowerShell 7

```powershell
$AagentVersion = "0.1.1"
$AagentBaseUrl = "https://github.com/AnandChowdhary/aagent/releases/download/v$AagentVersion"
$env:AAGENT_DOWNLOAD_BASE_URL = $AagentBaseUrl
$env:AAGENT_EXPECTED_VERSION = $AagentVersion
irm "$AagentBaseUrl/install.ps1" | iex
Remove-Item Env:AAGENT_DOWNLOAD_BASE_URL, Env:AAGENT_EXPECTED_VERSION
$env:Path = "$HOME/.local/bin;$env:Path"
aagent --version
```

The PowerShell installer verifies and atomically installs `aagent.ps1` plus an
`aagent.cmd` launcher in `%USERPROFILE%\.local\bin`. Add that directory to the
user `PATH` to keep `aagent` available in new terminals.

These commands pin the installer, runner, and checksum manifest to the same
GitHub Release. You can inspect the published `SHA256SUMS` before installing.
The repository's `main` branch remains available for development snapshots,
but it is not the versioned release channel.

You can also clone the repository and run `./aagent.sh` or
`pwsh -File ./aagent.ps1` directly.

## Use

### Bash

```bash
# Let aagent choose.
aagent "explain this repository"

# Choose a provider or provider-native model.
aagent --provider claude --model sonnet "review the current diff"

# Use piped input as the prompt.
git diff | aagent --provider gemini

# Keep an instruction separate from piped context.
cat issue.md | aagent "fix the issue described in this document"

# Run the provider from another directory.
aagent -C ../service "run the tests and explain any failures"

# Deliberately pass native options after --.
aagent -P codex "fix the tests" -- --sandbox workspace-write
```

### PowerShell

```powershell
# Let aagent choose.
aagent "explain this repository"

# Choose a provider.
aagent --provider codex "review the current diff"

# Send a file as context with a separate instruction.
Get-Content -Raw .\issue.md | aagent --provider claude "fix this issue"

# Deliberately pass native options after --.
aagent -P gemini "apply the refactor" -- --approval-mode auto_edit
```

Prompt arguments are joined with one space. With no prompt, redirected stdin
becomes the prompt. With both, the positional prompt is the instruction and
stdin is additional context. `aagent` never opens an interactive agent merely
because input is missing.

Use `-P`/`--provider` for an unconditional provider choice and `-m`/`--model`
for an opaque provider-native model ID. Model names are not translated between
vendors. Amp has no documented general per-run model flag, so requesting one
with Amp fails before launch.

Use `-C`/`--cwd` to set the provider's working directory. `--dry-run` prints a
redacted launch plan, while `--quiet` hides only the wrapper's selection
notice. Run `aagent --help` for the complete option summary.

Everything after the first wrapper-level `--` is passed as provider-native
arguments. This is the escape hatch for native sandboxes, approval modes,
tools, budgets, and output formats. Those options can grant substantial access;
`aagent` preserves them because their presence is an explicit user choice.

## Smart selection and cost policy

Without an explicit provider, `aagent` considers installed Tier 1 candidates
using this fixed tuple, from most to least important:

```text
readiness
funding class
authentication confidence
configured priority
popularity prior
stable registry order
```

The funding classes are, in order:

1. confirmed included subscription or paid seat;
2. account with included or free quota but an unknown exact tier;
3. confirmed positive prepaid credits;
4. an explicitly enabled local model;
5. direct pay-as-you-go API or BYOK; and
6. unknown funding.

A confirmed Claude Max account therefore outranks Claude or Codex using only a
metered API key. A confirmed ChatGPT plan similarly outranks an Anthropic API
key. When two included plans are otherwise equivalent, configured priority is
used before the frozen popularity prior. `--priority` never crosses readiness,
funding, or confidence boundaries.

The selected provider, funding class, and decisive reason are written to
stderr. `--quiet` hides only this wrapper notice; it does not hide provider
diagnostics. Selection has no telemetry, network popularity lookup, previous-
run preference, or guessed quota. Unknown quota is neutral rather than treated
as empty or unlimited.

Explicit selection precedence is:

1. `--provider`;
2. `AAGENT_PROVIDER`;
3. `provider` in the user configuration file; and
4. automatic selection.

An explicit missing or unsupported provider is an error. Authentication and
runtime failures from an explicitly selected installed provider remain that
provider's responsibility. After any provider run starts, `aagent` never
retries the prompt with another agent: the first process may already have
changed files or spent tokens.

## Supported providers

Tier 1 adapters are included in the first release:

| Provider | One-shot command | Per-run model | Passive local evidence | Important native behavior |
| --- | --- | --- | --- | --- |
| [Codex CLI](https://github.com/openai/codex) (`codex`) | `codex exec` | `--model` | local app-server account read, then `login status` fallback | Read-only sandbox by default; broader sandboxes are explicit. It may require a Git repository unless the user passes its native skip option. |
| [Claude Code](https://code.claude.com/docs/en/getting-started) (`claude`) | `claude --print` | `--model` | `auth status --json` | Native permission modes and repository configuration remain active. `aagent` never adds `--bare` or a permission bypass. |
| [OpenCode](https://opencode.ai/docs/) (`opencode`) | `opencode run` | `--model` | `auth list` plus non-secret selected-provider configuration | Most tools are allowed by native defaults; `aagent` never adds `--auto`. |
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) (`gemini`) | `gemini --prompt` | `--model` | documented `security.auth.selectedType` setting | Approval and sandbox modes remain native; `aagent` never adds `yolo`. |
| [Amp](https://ampcode.com/manual) (`amp`) | `amp --execute` | not supported | account-token presence only | Amp documents that it uses tools without asking by default. Omitting an unsafe flag does not make it read-only. |

Installations are discovered from `PATH`. Advanced users can override an exact
executable with `AAGENT_CODEX_BIN`, `AAGENT_CLAUDE_BIN`,
`AAGENT_OPENCODE_BIN`, `AAGENT_GEMINI_BIN`, or `AAGENT_AMP_BIN`.

`aagent providers` also lists planned adapters, including Cursor's separate
`agent` executable, as unsupported rather than confusing it with `aagent`.

## Authentication policy

The default `prefer-included` policy prevents a metered environment variable
from silently shadowing a confirmed stored subscription when the provider
documents that behavior. The adjustment is limited to the selected child
process and reported by variable name only:

- for a confirmed Claude subscription, a shadowing `ANTHROPIC_API_KEY` can be
  omitted from the Claude child;
- for confirmed ChatGPT-backed Codex, a shadowing `CODEX_API_KEY` can be
  omitted from the Codex child; and
- when metered Codex is deliberately selected, a present `OPENAI_API_KEY` can
  be copied opaquely to child `CODEX_API_KEY` if needed.

The caller's environment is never modified. Use
`--auth-policy native` or `AAGENT_AUTH_POLICY=native` when the provider should
receive its environment exactly as-is.

Passive probes are bounded, non-interactive, and fail safely to `unknown`.
They do not read stored token files or keychains, invoke credential helpers,
start login, open a browser, contact a model, or ask the model about quota.

## Configuration

The optional user configuration file is:

- `${XDG_CONFIG_HOME:-$HOME/.config}/aagent/config` on macOS and Linux; or
- `%APPDATA%\aagent\config` on Windows.

```ini
# Strict inert key=value data; this file is never sourced.
provider=codex
auth_policy=prefer-included
priority=codex,claude,opencode,gemini,amp
allow_local=false
```

Supported settings use command line, then environment, then user config, then
the documented default:

| Setting | Command line | Environment | Default |
| --- | --- | --- | --- |
| provider | `--provider` | `AAGENT_PROVIDER` | automatic |
| authentication | `--auth-policy` | `AAGENT_AUTH_POLICY` | `prefer-included` |
| tie-break priority | `--priority` | `AAGENT_PRIORITY` | empty |
| local candidates | `--allow-local true\|false` | `AAGENT_ALLOW_LOCAL` | `false` |

Comments must begin with `#` after optional leading whitespace. Inline comments,
quoted values, duplicate keys, and malformed lines are not accepted. Unknown
keys are warnings during a normal run and errors in `doctor`.

## Inspect and troubleshoot

```bash
aagent providers
aagent doctor
aagent doctor codex
aagent --dry-run "explain this repository"
```

- `providers` shows every adapter's installed/auth status, funding class,
  selection state, and safe reason.
- `doctor [PROVIDER]` adds wrapper/platform data, resolved paths, bounded safe
  versions, capability metadata, and provider-specific safety notes.
- `--dry-run` resolves the real selection, child environment plan, cwd, stdin
  mode, and escaped command without starting the provider or printing the
  prompt/context.

These commands never log in or submit a prompt. They discard raw probe output
and do not print account email, organization, IDs, credential paths, token
fingerprints, or secret values.

Wrapper-owned exit statuses are stable:

| Status | Meaning |
| ---: | --- |
| `0` | wrapper operation or launched provider succeeded |
| `64` | invalid usage or unsupported requested capability |
| `69` | no compatible provider executable is available |
| `70` | internal wrapper failure before provider launch |
| `78` | invalid wrapper configuration |

Once a provider starts, its stdout, stderr, signals, and exact exit status pass
through without remapping.

## Platforms

| Platform | Runner | Install/launch notes |
| --- | --- | --- |
| macOS | Bash | `install.sh`; provider support still applies |
| Linux | Bash | `install.sh` |
| Windows | PowerShell 7 | `install.ps1` creates `aagent.ps1` and `aagent.cmd` |
| Windows Git Bash | Bash | `install.sh`; use providers that support native Windows/Git Bash |
| Windows WSL | Bash | Treated as Linux; install providers inside the WSL environment |

GitHub Actions runs the complete Bash suite on Linux, macOS, and Windows Git
Bash, plus the complete PowerShell suite on Windows. A separate weekly
credential-free workflow installs the current Tier 1 CLIs and verifies only
their documented help/version command surfaces.

## Safety boundary and limitations

`aagent` is a compatibility layer, not a sandbox. It never generates a
permission-escalation flag, evaluates prompts as code, sources configuration,
or changes provider configuration. Native options supplied after `--` and each
provider's installed defaults are the user's responsibility.

The first release deliberately does not:

- install, update, authenticate, or configure providers;
- normalize vendor model names, structured events, sessions, tool calls,
  token usage, or exact cost;
- measure live quota or compare incompatible usage windows;
- infer that an API-shaped account key is necessarily pay-as-you-go;
- support the planned Tier 2 adapters for real runs; or
- fall back to another provider after launch.

For the exact contracts and research boundary, start with [SPEC.md](SPEC.md).
Implementation order and verification evidence live in [TODO.md](TODO.md).

## Develop

```bash
bash ./tests/test_aagent.sh
pwsh -NoProfile -File ./tests/test_aagent.ps1
bash ./scripts/release-gate.sh
```

Tests use isolated homes, controlled `PATH` values, and credential-free fake
providers. They cover parsing, discovery, process fidelity, all Tier 1 command
shapes, passive probes, selection, child-only auth policy, introspection,
security, installation, and compatibility drift without invoking locally
installed coding agents or paid prompts.

The release gate requires a clean worktree, runs both aggregate suites when
PowerShell is installed, validates every shell script and local Markdown link,
and performs isolated Bash and PowerShell installations. Use `--allow-dirty`
only while developing the gate itself; release evidence always uses the clean
default.

## License

[MIT](LICENSE)
