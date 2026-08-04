# Command-line contract

Status: Normative for the MVP

## Synopsis

```text
aagent [OPTIONS] [PROMPT...]
aagent providers
aagent doctor [PROVIDER]
aagent --help
aagent --version
```

Core options:

```text
-P, --provider ID     Use a specific provider
-m, --model ID        Request a provider-native model ID
-C, --cwd DIRECTORY   Run from this working directory
    --auth-policy P   Authentication policy: prefer-included or native
    --priority IDS    Comma-separated provider tie-break order
    --allow-local B   Allow local models: true or false
    --dry-run         Print the resolved invocation without running it
    --quiet           Do not print the provider-selection notice
    --                Treat remaining arguments as provider-native options
```

Examples:

```bash
aagent "say hello"
aagent --provider codex "explain this repository"
aagent --provider claude --model sonnet "review the current diff"
aagent --auth-policy native "preserve every provider auth override"
git diff | aagent "summarize these changes"
aagent --cwd ../service "run the tests and explain any failures"
aagent --provider codex "fix the tests" -- --sandbox workspace-write
```

Unknown wrapper options before `--` are usage errors. Arguments after `--` are
deliberate provider-native options. Adapters place them in the position required
by the selected CLI; they are never evaluated as shell source.

Wrapper options are recognized anywhere before `--`, including between prompt
arguments. Prompt content that begins with a dash should be supplied through
stdin; after `--`, every argument is provider-native rather than prompt text.

## Prompt and stdin rules

1. Positional prompt arguments are joined with one ASCII space and sent as one
   argument. Shell quoting and embedded newlines are preserved by normal shell
   argument rules.
2. With no positional prompt and non-terminal stdin, stdin is the prompt.
3. With a positional prompt and non-terminal stdin, the positional text is the
   instruction and stdin is additional context. An adapter should use the
   provider's documented combined-input behavior. If that behavior is absent,
   the wrapper may combine them as:

   ```text
   <instruction>

   --- stdin context ---
   <stdin>
   ```

4. With neither a prompt nor piped stdin, `aagent` prints concise usage and
   exits with a usage error. It never opens an interactive provider UI
   accidentally.
5. An explicitly supplied empty prompt is a usage error, including when stdin
   is also present; stdin must not silently turn an empty instruction into an
   stdin-only run.

Prompts must always be passed as data in an argument array. Implementations must
not use `eval`, construct an executable command string, or interpolate a prompt
through `sh -c` or PowerShell expression evaluation.

## Discovery

The Bash runner resolves commands from `PATH` and accepts an explicit executable
override for each adapter. The PowerShell runner uses executable or external
script commands, not aliases or functions.

Overrides use the form:

```text
AAGENT_CLAUDE_BIN=/custom/path/claude
AAGENT_CODEX_BIN=/custom/path/codex
AAGENT_CURSOR_BIN=/custom/path/cursor-agent
```

Discovery only verifies that a resolved target exists and is executable. Smart
selection then runs passive probes for installed candidates only; it does not
probe missing commands, make model requests, or trigger authentication.

## Configuration

Configuration locations:

- macOS/Linux: `${XDG_CONFIG_HOME:-$HOME/.config}/aagent/config`
- Windows: `%APPDATA%\aagent\config`

If neither `XDG_CONFIG_HOME` nor `HOME` is available on Unix, or `APPDATA` is
absent on Windows, the user-config location is unavailable and no file is
loaded. Environment variables and defaults still apply deterministically.

The file is a strict `key=value` format with only documented keys:

```ini
provider=codex
auth_policy=prefer-included
priority=codex,claude,opencode,copilot,gemini
allow_local=false
```

Whitespace around keys and values is ignored. A line whose first non-whitespace
character is `#` is a comment; inline comments and quoted-value syntax do not
exist. Lines are limited to 4096 characters. Malformed lines, duplicate keys,
and invalid known values are configuration errors. Unknown keys are errors in
`aagent doctor` and warnings during normal invocation. Diagnostics identify the
file, line, and safe key name, but never reproduce a value.

The file is parsed as inert data and is never sourced. Project-local
configuration is deferred because loading behavioral configuration from an
untrusted repository would create a security boundary the MVP does not need.

Effective values use this stable precedence:

| Value | Command line | Environment | User config | Default |
| --- | --- | --- | --- | --- |
| provider | `--provider` | `AAGENT_PROVIDER` | `provider` | automatic selection |
| auth policy | `--auth-policy` | `AAGENT_AUTH_POLICY` | `auth_policy` | `prefer-included` |
| priority | `--priority` | `AAGENT_PRIORITY` | `priority` | empty |
| local models | `--allow-local true\|false` | `AAGENT_ALLOW_LOCAL` | `allow_local` | `false` |

Priority is only a tie-break order inside equivalent readiness, funding, and
confidence classes; it cannot cross any of those cost-safety boundaries.
Provider precedence is expanded in [selection.md](selection.md).

## Model selection

`--model ID` forwards an opaque, provider-native identifier. `aagent` does not
translate model families between vendors or check availability.

If an adapter has no documented per-run model option, `--model` fails before
launch with a clear unsupported-capability error. It is never silently ignored.

## Native options

Provider-native options after `--` are an explicit escape hatch for features
that are unsafe or impossible to normalize, including approval modes,
sandboxes, budgets, tools, reasoning effort, and native output formats.

```bash
aagent -P claude "update the changelog" -- --allowedTools Read,Edit
aagent -P codex "fix the issue" -- --sandbox workspace-write
aagent -P gemini "apply the refactor" -- --approval-mode auto_edit
aagent -P droid "fix formatting" -- --auto low
```

Native options are provider-specific and may grant substantial access. The
wrapper must never add a native permission-bypass flag on its own.

## Process and output contract

The selected provider runs in the requested working directory, or the caller's
current working directory when `--cwd` is absent. The wrapper preserves stdin,
stdout, stderr, signals, and status as faithfully as the platform permits.

For the MVP, stdout and stderr are passed through from the provider:

- wrapper notices and wrapper errors go to stderr;
- provider stdout remains provider stdout;
- provider stderr remains provider stderr; and
- no ANSI stripping, JSON parsing, or final-message extraction is attempted.

This preserves streaming and keeps both runners dependency-free. Most headless
text modes are suitable for command substitution, but exact progress behavior
remains provider-native and is listed by `aagent doctor`.

`--dry-run` is the exception: it prints a shell-appropriate, redacted display
of the resolved executable and arguments without launching the process. It must
not print environment secrets.

## Exit status and signals

If a provider starts, `aagent` exits with that provider's exact status. It does
not remap authentication, rate-limit, turn-limit, or tool-denial failures.

Wrapper-owned statuses follow `sysexits` values where they apply:

| Status | Meaning |
| --- | --- |
| `0` | wrapper operation succeeded, or launched provider returned `0` |
| `64` | invalid wrapper usage or unsupported requested capability |
| `69` | no compatible provider executable is available |
| `70` | internal wrapper failure before provider launch |
| `78` | invalid wrapper configuration |

The runner should replace itself with the provider process where the platform
allows it. Interrupt and termination signals must reach the provider. Bash
should naturally preserve conventional `128 + signal` statuses; PowerShell
should preserve the child process exit code.
