# Agent CLI specification

Status: Draft  
Research date: 2026-08-04  
Implementation scope: None in this change

## 1. Summary

`agent` is a small, cross-platform command-line wrapper that runs an installed
coding-agent CLI in non-interactive mode.

The primary experience is:

```console
$ agent "say hello"
Hello!
```

The user may have Claude Code, Codex CLI, OpenCode, Amp, Gemini CLI, or another
supported coding agent installed. `agent` discovers compatible executables,
chooses one deterministically, passes it the prompt, and preserves its output
and exit status.

The product is a compatibility layer, not a new agent runtime. Authentication,
models, tools, repository instructions, billing, and provider configuration
remain owned by the selected agent.

## 2. Goals

The first release must:

1. Make `agent "prompt"` work when at least one supported CLI is installed and
   already configured.
2. Support macOS and Linux in Bash, Windows in PowerShell, and Git Bash or WSL
   where the installed provider supports them.
3. Select providers predictably and make the selection visible.
4. Preserve the current working directory, stdin, stdout, stderr, signals, and
   the launched provider's exit status as faithfully as possible.
5. Avoid silently increasing the selected agent's permissions.
6. Remain dependency-free for the core text interface.
7. Make each provider integration an explicit, testable adapter.

## 3. Non-goals

The first release will not:

- install, upgrade, authenticate, or configure an agent;
- fall back to a second agent after a selected agent has started;
- emulate any provider's interactive terminal UI;
- make vendor model names portable;
- claim that permission modes have equivalent security across providers;
- normalize streaming events, token usage, costs, tool calls, or session IDs;
- manage branches, commits, pull requests, or deployments itself;
- wrap remote agent APIs, IDE-only agents, or server protocols such as ACP;
- source configuration as shell code; or
- require `jq`, Node.js, Python, or another runtime beyond the project runners.

## 4. Research conclusions

### 4.1 The portable core is small

Every Tier 1 CLI has a documented one-shot form:

| Provider | One-shot command | Prompt input | Structured output | Resume support |
| --- | --- | --- | --- | --- |
| Claude Code | `claude --print PROMPT` | argument and stdin | JSON or streaming JSON | yes |
| Codex CLI | `codex exec PROMPT` | argument and stdin | JSON Lines | yes |
| OpenCode | `opencode run PROMPT` | argument | raw JSON events | yes |
| Amp | `amp --execute PROMPT` | argument and stdin | streaming JSON | yes |
| Gemini CLI | `gemini --prompt PROMPT` | argument and stdin | JSON or streaming JSON | yes |

This gives `agent` a reliable minimum contract: choose a process, send one
prompt, wait for completion, and return its output and status.

### 4.2 The rest is not actually uniform

The researched tools differ materially in the following areas:

- **Permissions:** Codex and Factory Droid begin headless runs read-only. Amp
  does not ask for tool approval by default. Kimi's print mode uses automatic
  permissions. Cline documents automatic approval in headless use. Other tools
  offer combinations of allow lists, deny lists, sandboxes, approval modes, and
  `--yolo`-style bypasses.
- **Output:** Some CLIs print only a final answer in text mode; others include
  progress. Their JSON shapes and event names are unrelated.
- **Models:** Most accept a per-run model flag, but the model identifier is
  provider-specific. Amp does not expose a general per-run model flag in its
  documented execute interface.
- **Sessions:** Identifiers, continue/resume behavior, forking, and persistence
  all differ.
- **Authentication:** Status commands and exit behavior are inconsistent.
  Some tools use browser login, some environment API keys, and some support
  both.
- **Side effects:** Aider enables automatic Git commits by default. Cursor's
  headless mode proposes changes unless forced. Factory Droid defaults to
  read-only spec mode. A wrapper must not erase these distinctions.
- **Exit behavior:** Several providers publish exit-code contracts, while
  others only promise a non-zero failure. The wrapper can preserve an exit
  code but cannot reinterpret every code correctly.

Therefore the MVP standardizes invocation and selection, not the agent's
runtime semantics.

## 5. Command-line interface

### 5.1 Synopsis

```text
agent [OPTIONS] [PROMPT...]
agent providers
agent doctor [PROVIDER]
agent --help
agent --version
```

Core options:

```text
-P, --provider ID     Use a specific provider
-m, --model ID        Request a provider-native model ID
-C, --cwd DIRECTORY   Run from this working directory
    --dry-run         Print the resolved invocation without running it
    --quiet           Do not print the provider-selection notice
    --                Treat remaining arguments as provider-native options
```

Examples:

```bash
agent "say hello"
agent --provider codex "explain this repository"
agent --provider claude --model sonnet "review the current diff"
git diff | agent "summarize these changes"
agent --cwd ../service "run the tests and explain any failures"
agent --provider codex "fix the tests" -- --sandbox workspace-write
```

Unknown wrapper options before `--` are usage errors. Arguments after `--` are
deliberate provider-native options. Adapters place them in the position required
by the selected CLI; they are never evaluated as shell source.

### 5.2 Prompt rules

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

4. With neither a prompt nor piped stdin, `agent` prints concise usage and exits
   with a usage error. It never opens an interactive provider UI accidentally.
5. An empty prompt is a usage error.

Prompts must always be passed as data in an argument array. Implementations must
not use `eval`, construct an executable command string, or interpolate a prompt
through `sh -c` or PowerShell expression evaluation.

### 5.3 Provider selection

Selection uses this precedence:

1. `--provider ID`
2. `AGENT_PROVIDER`
3. `provider` in the user configuration file
4. the first installed provider in `AGENT_PRIORITY`
5. the first installed provider in the configured `priority` list
6. the first installed provider in the built-in priority list

The initial built-in list is:

```text
claude,codex,opencode,amp,gemini,droid,copilot,goose,qwen,kimi,cline,crush,vibe,kiro,aider
```

The order is a compatibility default, not a quality ranking. It begins with the
five Tier 1 adapters. A selected provider is reported to stderr:

```text
agent: using claude (/usr/local/bin/claude)
```

`--quiet` suppresses only this wrapper-owned notice. It does not suppress
provider diagnostics.

An explicit provider that is missing is an error; it does not fall through to
another provider. Automatic selection skips missing executables, but after an
agent process starts, `agent` never retries the prompt with a different agent.
The failed process may already have changed files or consumed paid tokens.

### 5.4 Discovery

The Bash runner resolves commands from `PATH` and accepts an explicit executable
override for each adapter. The PowerShell runner uses executable or external
script commands, not aliases or functions.

Overrides use the form:

```text
AGENT_CLAUDE_BIN=/custom/path/claude
AGENT_CODEX_BIN=/custom/path/codex
AGENT_CURSOR_BIN=/custom/path/cursor-agent
```

Discovery verifies that the resolved target exists and is executable. It does
not invoke every candidate, make network requests, or trigger authentication
during an ordinary run.

### 5.5 Configuration

Configuration locations:

- macOS/Linux: `${XDG_CONFIG_HOME:-$HOME/.config}/agent/config`
- Windows: `%APPDATA%\agent\config`

The file is a strict `key=value` format with only documented keys:

```ini
provider=codex
priority=codex,claude,gemini,opencode,amp
```

Whitespace around keys and values is ignored. Unknown keys are errors in
`agent doctor` and warnings during normal invocation. The file is parsed as
data and is never sourced. Project-local configuration is deferred because
loading executable or behavioral configuration from an untrusted repository
would create a security boundary the MVP does not need.

Environment variables override the file. Command-line options override both.

### 5.6 Model selection

`--model ID` forwards an opaque, provider-native identifier. `agent` does not
translate model families between vendors or check availability.

If an adapter has no documented per-run model option, `--model` fails before
launch with a clear unsupported-capability error. It is never silently ignored.

### 5.7 Native options

Provider-native options after `--` are an explicit escape hatch for features
that are unsafe or impossible to normalize, including approval modes,
sandboxes, budgets, tools, reasoning effort, and native output formats.

Examples:

```bash
agent -P claude "update the changelog" -- --allowedTools Read,Edit
agent -P codex "fix the issue" -- --sandbox workspace-write
agent -P gemini "apply the refactor" -- --approval-mode auto_edit
agent -P droid "fix formatting" -- --auto low
```

`agent` must document that native options are provider-specific and may grant
substantial access. The wrapper must never add a native permission-bypass flag
on its own.

### 5.8 Output

For the MVP, stdout and stderr are passed through from the provider:

- wrapper notices and wrapper errors go to stderr;
- provider stdout remains provider stdout;
- provider stderr remains provider stderr; and
- no ANSI stripping, JSON parsing, or final-message extraction is attempted.

This preserves streaming and keeps the Bash and PowerShell implementations
dependency-free. Most headless text modes are suitable for command substitution,
but exact progress behavior remains provider-native and is listed by
`agent doctor`.

`--dry-run` is the exception: it prints a shell-appropriate, redacted display
of the resolved executable and arguments without launching the process. It must
not print environment secrets.

### 5.9 Exit status and signals

If a provider starts, `agent` exits with that provider's exact status. It does
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

## 6. Provider adapters

### 6.1 Adapter contract

Every adapter declares:

- stable provider ID and display name;
- executable name and optional override variable;
- one-shot command shape;
- whether prompt-only stdin and prompt-plus-stdin are documented;
- per-run model flag, if any;
- native structured output capability;
- session capability;
- known permission and side-effect behavior;
- optional non-mutating version and authentication probes; and
- any platform or name-collision constraints.

The implementation may use functions or case statements, but the data above
must remain inspectable and testable as an adapter registry. Adapter-specific
logic must not leak into global argument parsing.

### 6.2 Tier 1: required for the first functional release

#### Claude Code (`claude`)

- Invocation: `claude --print PROMPT`
- Model: `--model ID`
- Input: argument, stdin, or both; piped stdin has a documented 10 MB limit.
- Native output: `text`, `json`, and `stream-json`; JSON can include a session
  ID, usage, cost, and result.
- Sessions: `--continue`, `--resume`, and `--session-id`.
- Permissions: allow/deny tool flags and permission modes; the unsafe bypass is
  explicit. `--bare` is useful for isolated automation but changes hooks,
  skills, plugins, MCP, memory, project instructions, and authentication, so
  the wrapper must not add it by default.
- Authentication probe: `claude auth status`.

#### Codex CLI (`codex`)

- Invocation: `codex exec PROMPT`
- Model: `--model ID`
- Input: argument or `-` for stdin; argument plus stdin is documented as an
  instruction plus additional context.
- Native output: final text on stdout and progress on stderr; `--json` emits
  JSON Lines events. `--output-last-message` writes the final response to a
  file, and `--output-schema` requests schema-constrained output.
- Sessions: `codex exec resume`, including `--last` or an explicit ID.
- Permissions: read-only sandbox by default; `--sandbox workspace-write` and
  `danger-full-access` are explicit native choices.
- Authentication probe: `codex login status`.
- Repository behavior: may require a Git repository unless the user supplies
  the native `--skip-git-repo-check` option.

#### OpenCode (`opencode`)

- Invocation: `opencode run PROMPT`
- Model: `--model PROVIDER/MODEL`
- Native output: formatted output or raw JSON events with `--format json`.
- Sessions: `--continue`, `--session`, and `--fork`.
- Permissions: configured actions are `allow`, `ask`, or `deny`; most tools are
  allowed by default, while external-directory access and loop detection ask.
  `--auto` approves asks that are not explicitly denied. The wrapper must not
  add `--auto` implicitly.
- Additional interface: `opencode serve` exposes a headless HTTP server, but it
  is outside the one-shot MVP.

#### Amp (`amp`)

- Invocation: `amp --execute PROMPT`
- Model: no documented general per-run model flag; `--fast` is a mode override,
  not a portable model selector.
- Input: argument, stdin, or both; redirected stdout also enables execute mode.
- Native output: final text or `--stream-json`; optional thinking events extend
  the stream schema.
- Sessions: threads can be continued in execute mode.
- Permissions: Amp documents that it does not ask permission before using tools
  by default. Settings or plugins may customize behavior. `agent` must not imply
  that omitting an unsafe flag makes this equivalent to a read-only provider.
- Authentication: unattended execution can use `AMP_API_KEY`.

#### Gemini CLI (`gemini`)

- Invocation: `gemini --prompt PROMPT`
- Model: `--model ID`
- Input: argument and stdin; piped content is appended to the prompt.
- Native output: `text`, one JSON result object, or streaming JSON events.
- Sessions: `--resume` supports the latest or a selected session.
- Permissions: native approval modes include `default`, `auto_edit`, `yolo`,
  and `plan`; sandboxing is a separate option. The deprecated `--yolo` alias
  must not be added by the wrapper.
- Published exit codes include success, general failure, invalid input, and turn
  limit. The wrapper preserves them without interpretation.

### 6.3 Tier 2: planned adapters

| ID | Executable and one-shot form | Structured output | Important compatibility note |
| --- | --- | --- | --- |
| `droid` | `droid exec PROMPT` | JSON, stream JSON, and JSON-RPC | Read-only spec mode by default; `--auto low/medium/high` grants increasing autonomy. |
| `copilot` | `copilot --prompt PROMPT` | no documented stable event format | Supports model and tool allow/deny flags; automatic tool approval is explicitly privileged. |
| `goose` | `goose run --text PROMPT` | JSON and stream JSON | Headless automation commonly uses `GOOSE_MODE=auto`; provider and model are separately selectable. |
| `qwen` | `qwen --prompt PROMPT` | JSON and stream JSON | Offers plan/default/auto-edit/auto/yolo approval modes and explicit run budgets. |
| `kimi` | `kimi --prompt PROMPT` | stream JSON | Print mode uses automatic permission handling and cannot be combined with its interactive `--auto`, `--plan`, or `--yolo` flags. |
| `cline` | `cline PROMPT` | NDJSON with `--json` | Headless operation documents automatic approval behavior; do not promise a read-only default. |
| `crush` | `crush run PROMPT` | no documented stable JSON mode | Native permission prompts remain unless `--yolo` is explicitly used. |
| `vibe` | `vibe --prompt PROMPT` | JSON and streaming NDJSON | Supports auto-approval, tool restrictions, budgets, sessions, and configurable agents. |
| `kiro` | `kiro-cli chat --no-interactive PROMPT` | no documented stable JSON mode | Headless use requires an API key; trust flags control pre-approved tools. |
| `aider` | `aider --message PROMPT` | no documented stable JSON mode | Automatically commits changes by default. An adapter must expose this fact and must not silently broaden Git side effects. |

Tier 2 means the official interface is suitable, but its adapter is not required
to call the initial implementation complete.

### 6.4 Special case: Cursor CLI

Cursor's CLI executable is also named `agent`, and its headless form is
`agent --print PROMPT`. Installing this project at the same `PATH` location can
mask or overwrite Cursor's executable, and naïve discovery can recursively
invoke the wrapper itself.

Until the installer and discovery behavior are explicitly designed for this
collision, Cursor is supported only through `AGENT_CURSOR_BIN` pointing to a
distinct executable or user-created shim. The adapter must canonicalize both
paths and reject its own executable. The installer must never overwrite an
existing non-project `agent` command without an explicit user decision.

Cursor's native headless output supports text, JSON, and streaming JSON.
Without its force/yolo option, changes are proposed rather than applied. The
wrapper must preserve that default.

### 6.5 Explicit exclusions

- **OpenHands:** the current project centers on Agent Server/Agent Canvas and
  ACP-compatible backends rather than a stable local one-shot CLI matching this
  adapter contract. A future server/ACP backend would be a different transport.
- **Amazon Q Developer CLI:** its public repository is in maintenance-only
  status and directs users to Kiro CLI, which is the planned adapter.
- **IDE-only assistants and raw model APIs:** they are not discoverable local
  coding-agent executables and require a different lifecycle.

This survey is representative, not a promise to include every CLI that calls
itself an agent. A new provider qualifies when it has an actively documented,
non-interactive, single-run interface with observable completion status.

## 7. Permissions and safety

### 7.1 MVP policy

The MVP uses the provider's installed configuration and native headless default.
It does not define a universal `--read-only`, `--edit`, or `--full-access` flag.
Those names would imply equivalence that the underlying sandboxes and tool
policies do not provide.

The wrapper must:

- never append `--yolo`, `--dangerously-skip-permissions`,
  `--skip-permissions-unsafe`, `--allow-all-tools`, `--auto`, or equivalent;
- never answer an approval prompt on the user's behalf;
- display known provider safety notes in `agent doctor`;
- treat native options after `--` as an explicit user choice;
- avoid silently changing provider configuration files; and
- never retry a failed run with another provider.

### 7.2 Future normalized policies

A later release may add capability-aware policy names such as `read-only`,
`workspace`, and `unrestricted`. Each adapter would need a documented mapping
and a fail-closed result when it cannot enforce the requested boundary. Merely
omitting a vendor's yolo flag is not evidence of read-only execution.

## 8. Introspection

### 8.1 `agent providers`

Lists every known adapter, resolution path, and availability without logging in
or contacting the network:

```text
ID        STATUS       COMMAND
claude    available    /usr/local/bin/claude
codex     available    /opt/homebrew/bin/codex
gemini    missing      gemini
cursor    override     /custom/bin/cursor-agent
```

### 8.2 `agent doctor [PROVIDER]`

Runs non-mutating diagnostics:

- wrapper version and platform;
- detected provider paths and versions;
- selected provider and why it won;
- configuration errors;
- authentication state only where an official status command exists;
- supported model, stdin, structured-output, and session capabilities; and
- provider-specific permission or side-effect warnings.

Authentication is reported as `ready`, `not ready`, or `unknown`. `unknown` is
valid when a provider lacks a stable, non-interactive status probe. Doctor must
not open a browser or begin login.

## 9. Future structured API

Structured output is valuable but not part of the dependency-free MVP. Native
schemas vary too much to concatenate safely or parse correctly in portable Bash
and PowerShell.

A later `--output json` may return one normalized result:

```json
{
  "schema_version": 1,
  "provider": "codex",
  "status": "success",
  "text": "The final assistant response",
  "session_id": null,
  "usage": null,
  "error": null
}
```

A later streaming mode may normalize only these conservative event types:

```text
run.started
assistant.delta
tool.started
tool.completed
run.completed
run.failed
```

Provider-specific fields should remain under a `native` object. Missing data is
`null`, not guessed. A normalized result must be versioned, and providers that
lack a structured mode must either be unsupported for that request or use an
explicitly documented text-only fallback.

## 10. Testing requirements

### 10.1 Adapter tests

Each provider gets a fake executable placed first on `PATH`. Tests record argv,
stdin, cwd, stdout, stderr, and exit status without requiring credentials or
making network requests.

Required cases:

- basic prompt command shape;
- model forwarding or a clear unsupported-capability error;
- prompt-only stdin and prompt-plus-stdin;
- native options after `--`;
- spaces, quotes, glob characters, command substitutions, newlines, Unicode,
  and leading dashes in prompts;
- provider stdout/stderr passthrough;
- non-zero exit preservation; and
- interrupt propagation where the CI platform permits it.

### 10.2 Selection tests

- no providers installed;
- exactly one provider installed;
- several installed providers and built-in priority;
- command-line, environment, and config precedence;
- explicit missing provider;
- executable overrides;
- a selected provider that fails authentication, proving no failover occurs;
- Cursor's binary collision and self-recursion prevention; and
- `--quiet` and `--dry-run` behavior.

### 10.3 Security tests

Prompts and configuration values containing shell syntax must remain inert.
Tests must prove that the wrapper never introduces a known approval-bypass flag
and never sources a configuration file.

### 10.4 Platform tests

GitHub Actions must run:

- Bash tests on Linux, macOS, and Windows Git Bash;
- PowerShell tests on Windows; and
- equivalent adapter and selection fixtures in both runners.

Live provider tests are opt-in, credentialed, and excluded from pull-request CI
to avoid cost and secret exposure. A scheduled compatibility workflow may
install current CLIs, inspect their documented help output, and flag adapter
drift without running a paid prompt.

## 11. MVP acceptance criteria

The implementation following this specification is complete when:

1. Tier 1 adapters work through `agent "say hello"` using fake-executable
   contract tests on every supported runner.
2. Explicit and automatic provider selection follow the documented precedence.
3. The chosen provider is visible on stderr unless `--quiet` is used.
4. Prompts, stdin, cwd, native arguments, stdout, stderr, signals, and exit
   statuses satisfy the contract above.
5. No provider receives a permission escalation unless it appears after the
   user's explicit `--` separator.
6. Missing providers, unsupported model flags, invalid configuration, and empty
   input produce stable wrapper errors.
7. `agent providers` and `agent doctor` are non-mutating and do not trigger
   login.
8. The Cursor collision cannot recurse into or overwrite the wrapper.
9. Existing `--help`, installation, and cross-platform test behavior remains
   intact.

## 12. Decisions deferred until after the MVP

- a normalized JSON result and streaming event protocol;
- portable sessions and resume behavior;
- capability-aware permission profiles;
- budget, reasoning-effort, system-prompt, and tool-selection flags;
- project-local configuration;
- automatic compatibility metadata updates; and
- server, SDK, or ACP transports.

## 13. Primary sources

Only first-party documentation and first-party repositories were used for the
interface survey.

- Claude Code: [headless mode](https://code.claude.com/docs/en/headless),
  [CLI reference](https://code.claude.com/docs/en/cli-reference)
- Codex CLI: [non-interactive mode](https://developers.openai.com/codex/noninteractive),
  [CLI reference](https://developers.openai.com/codex/cli/reference)
- OpenCode: [CLI](https://opencode.ai/docs/cli/),
  [permissions](https://opencode.ai/docs/permissions/)
- Amp: [CLI manual](https://ampcode.com/manual#cli),
  [streaming JSON](https://ampcode.com/manual#cli-streaming-json)
- Gemini CLI: [headless mode](https://geminicli.com/docs/cli/headless/),
  [CLI reference](https://geminicli.com/docs/cli/cli-reference/)
- Factory Droid: [headless exec](https://docs.factory.ai/droid-exec/overview),
  [CLI reference](https://docs.factory.ai/droid-cli/cli-reference)
- GitHub Copilot CLI: [official repository](https://github.com/github/copilot-cli),
  [product documentation](https://docs.github.com/en/copilot/concepts/agents/about-copilot-cli)
- Goose: [running tasks](https://goose-docs.ai/docs/guides/running-tasks/),
  [headless tutorial](https://goose-docs.ai/docs/tutorials/headless-goose/)
- Qwen Code: [headless mode](https://github.com/QwenLM/qwen-code/blob/main/docs/users/features/headless.md)
- Kimi Code: [command reference](https://moonshotai.github.io/kimi-code/en/reference/kimi-command)
- Cline: [CLI reference](https://docs.cline.bot/cli/cli-reference),
  [official repository](https://github.com/cline/cline)
- Crush: [official repository](https://github.com/charmbracelet/crush),
  [`run` command source](https://github.com/charmbracelet/crush/blob/main/internal/cmd/run.go)
- Mistral Vibe: [official repository](https://github.com/mistralai/mistral-vibe)
- Kiro CLI: [headless mode](https://kiro.dev/docs/cli/headless)
- Aider: [scripting guide](https://aider.chat/docs/scripting.html),
  [options reference](https://aider.chat/docs/config/options.html)
- Cursor CLI: [headless mode](https://cursor.com/docs/cli/headless),
  [parameter reference](https://cursor.com/docs/cli/reference/parameters)
- OpenHands: [official repository](https://github.com/OpenHands/OpenHands)
