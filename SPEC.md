# aagent CLI specification

Status: Draft  
Research date: 2026-08-04  
Implementation scope: None in this change

## 1. Summary

`aagent` is a small, cross-platform command-line wrapper that runs an installed
coding-agent CLI in non-interactive mode.

The primary experience is:

```console
$ aagent "say hello"
Hello!
```

The user may have Claude Code, Codex CLI, OpenCode, Amp, Gemini CLI, or another
supported coding agent installed. `aagent` discovers compatible executables,
chooses one deterministically, passes it the prompt, and preserves its output
and exit status.

The product is a compatibility layer, not a new agent runtime. Authentication,
models, tools, repository instructions, billing, and provider configuration
remain owned by the selected agent.

## 2. Goals

The first release must:

1. Make `aagent "prompt"` work when at least one supported CLI is installed and
   already configured.
2. Support macOS and Linux in Bash, Windows in PowerShell, and Git Bash or WSL
   where the installed provider supports them.
3. Select providers predictably and make the selection visible.
4. Prefer an authenticated, included subscription or seat over a metered model
   API, so normal automatic selection minimizes marginal cost.
5. Preserve the current working directory, stdin, stdout, stderr, signals, and
   the launched provider's exit status as faithfully as possible.
6. Avoid silently increasing the selected agent's permissions.
7. Remain dependency-free for the core text interface.
8. Make each provider integration an explicit, testable adapter.

## 3. Non-goals

The first release will not:

- install, upgrade, authenticate, or configure an agent;
- fall back to a second agent after a selected agent has started;
- emulate any provider's interactive terminal UI;
- make vendor model names portable;
- claim that permission modes have equivalent security across providers;
- normalize streaming events, per-run token usage, exact costs, tool calls, or
  session IDs;
- decode, copy, print, hash, or transmit stored authentication tokens;
- send a model request merely to test authentication or quota;
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

This gives `aagent` a reliable minimum contract: choose a process, send one
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

### 4.3 Authentication and billing are different dimensions

Credential shape is not a safe proxy for cost. A direct `ANTHROPIC_API_KEY` or
`CODEX_API_KEY` selects metered model API usage, but GitHub tokens used by
Copilot and account keys used by Amp, Cursor, Factory, Kimi, or a Qwen Coding
Plan can represent subscriptions, seats, or prepaid account allowances.

`aagent` must classify the documented **funding path used by the selected
provider and model**, not merely whether a credential looks like OAuth or an
API key. An unknown funding path remains unknown; it is never guessed to be
free.

### 4.4 Passive probes are sufficient for static routing

The main cost-saving cases can be detected without reading tokens or making a
paid model request:

- Claude Code documents `claude auth status`; a `claude.ai` login represents
  Claude subscription access, while Console and direct model API credentials
  are metered or cost-unknown.
- Codex exposes `account/read` through its documented app-server protocol,
  including `type` and ChatGPT `planType`; `codex login status` is a less
  detailed fallback.
- Gemini stores a nonsecret selected authentication type; Google account login
  has included quota, while Gemini API-key and Vertex paths are separately
  identifiable.
- OpenCode documents `opencode auth list`, but its credential type must be
  combined with the selected model/provider. OAuth alone is not a universal
  subscription signal.
- Cursor exposes an authentication status command, although its plan tier is
  not reported.

Providers without a stable passive probe can still be used, but receive lower
authentication confidence during automatic selection.

## 5. Command-line interface

### 5.1 Synopsis

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

4. With neither a prompt nor piped stdin, `aagent` prints concise usage and exits
   with a usage error. It never opens an interactive provider UI accidentally.
5. An empty prompt is a usage error.

Prompts must always be passed as data in an argument array. Implementations must
not use `eval`, construct an executable command string, or interpolate a prompt
through `sh -c` or PowerShell expression evaluation.

### 5.3 Provider selection

#### 5.3.1 Explicit selection

Provider choice uses this precedence:

1. `--provider ID`
2. `AAGENT_PROVIDER`
3. `provider` in the user configuration file
4. automatic smart selection

An explicit provider is authoritative even when another candidate would be
cheaper or more popular. A missing explicit provider is an error and does not
fall through. The authentication policy still applies unless the user selects
`--auth-policy native`.

#### 5.3.2 Automatic smart selection

Automatic selection first discovers installed candidates, runs only passive
authentication probes, excludes candidates known to be unusable, and chooses
the greatest lexicographic tuple:

```text
(
  readiness,
  funding_class,
  authentication_confidence,
  configured_priority,
  popularity_prior,
  stable_registry_order
)
```

Earlier fields always dominate later fields. In particular, popularity can
never make a pay-as-you-go candidate outrank a confirmed included plan.

Readiness values are:

1. `ready` - a passive probe or documented configuration confirms usable auth;
2. `unknown` - the executable exists but readiness cannot be checked safely;
3. `unusable` - a probe confirms missing or invalid auth; excluded from
   automatic selection.

Funding classes, highest first, are:

| Class | Meaning |
| --- | --- |
| `included_confirmed` | The active provider/model path uses a documented fixed-price subscription, paid seat, or included plan. |
| `included_account` | The active account has included or free quota, but the exact paid tier is unavailable. |
| `prepaid_credits` | A documented passive probe confirms a positive prepaid provider balance. |
| `local` | No marginal model charge, but enabled only when `allow_local=true` because quality and machine cost vary. |
| `payg_byok` | The selected path uses a direct, metered model API or BYOK provider. |
| `unknown` | Authentication may work, but its funding path cannot be established safely. |

An API-shaped credential is not automatically `payg_byok`. For example, a
Qwen Coding Plan key, Kimi membership key, Copilot GitHub token,
`FACTORY_API_KEY`, `CURSOR_API_KEY`, or `AMP_API_KEY` can represent an account
entitlement rather than direct model API billing. The adapter must combine
credential source with the selected provider/model configuration.

Authentication confidence, highest first, is:

1. a documented machine-readable status or account interface;
2. a documented redacted text status or nonsecret configuration field;
3. a current official implementation detail with tolerant parsing;
4. environment-variable presence or credential-file existence only.

Low-confidence evidence cannot establish `included_confirmed`; it falls back to
`included_account` or `unknown`. Unknown quota is neutral, not zero.

Required outcomes include:

- Claude subscription plus OpenAI API-only Codex selects Claude.
- ChatGPT Plus/Pro/Business/Enterprise Codex plus Anthropic API-only Claude
  selects Codex.
- Two confirmed included plans proceed to configured priority and then the
  popularity prior; a future quota-aware mode may break this tie using fresh,
  comparable remaining-allowance evidence.
- If no included, prepaid, or allowed local candidate exists, a ready direct
  model API becomes the deliberate metered fallback.

`AAGENT_PRIORITY` or the configured `priority` list breaks ties within the same
funding and confidence class. It does not override the cost boundary. Users who
want an unconditional choice use `--provider`, `AAGENT_PROVIDER`, or the
`provider` config key.

#### 5.3.3 Popularity prior

The default popularity prior is a versioned build-time snapshot. It is not
downloaded during a run and does not create telemetry. Rolling public package
downloads are the primary signal because they are closer to CLI adoption;
official GitHub stars are a secondary interest signal. Both are imperfect:
downloads include automation and omit non-package installers, while stars favor
older open-source projects. Providers without comparable public metrics are
left in a documented registry position rather than assigned a fabricated
score.

The 2026-08-04 snapshot for the five largest comparable package channels is:

| Provider | Previous 30 days of npm downloads | GitHub stars |
| --- | ---: | ---: |
| Codex | 60,263,416 | 103,904 |
| Claude Code | 42,087,874 | 140,223 |
| OpenCode | 8,152,416 | 193,300 |
| GitHub Copilot CLI | 5,870,894 | 11,055 |
| Gemini CLI | 1,929,607 | 106,356 |

The initial popularity/registry order is:

```text
codex,claude,opencode,copilot,gemini,cline,goose,aider,qwen,amp,kimi,droid,crush,vibe,kiro,cursor
```

This order is only a late tie-breaker. It should be reviewed periodically in a
normal release, not silently changed from a network response at runtime.

#### 5.3.4 Selection notice and failure behavior

The selected provider, funding class, and decisive reason are reported to
stderr without account PII:

```text
aagent: using codex (included_confirmed, ChatGPT Pro; popularity #1)
```

`--quiet` suppresses only wrapper-owned notices. It does not suppress provider
diagnostics.

Automatic selection skips missing and known-unusable executables. After an
agent process starts, `aagent` never retries the prompt with another provider;
the failed process may already have changed files or consumed paid tokens.

### 5.4 Authentication and funding probes

#### 5.4.1 Probe rules

Normal selection may start installed CLIs only through documented, passive
status interfaces. Probes must:

- run without a TTY and with a short timeout;
- avoid model requests and login flows;
- avoid network calls by default;
- parse an allowlist of nonsecret fields and discard the raw response;
- check environment variables by presence only;
- never invoke an `apiKeyHelper` or other credential-producing command;
- never open an OS credential-store entry or credential token file; and
- degrade to `unknown` on timeout, version drift, or parse failure.

Documented nonsecret configuration fields may be parsed as data with a real
JSON or TOML parser. Configuration is never sourced as shell code. Credential
file existence alone is low-confidence evidence and cannot establish a plan.

#### 5.4.2 Core provider probes

| Provider | Passive evidence | Funding interpretation |
| --- | --- | --- |
| Claude Code | `claude auth status --json`; allowlist `loggedIn`, `authMethod`, `subscriptionType`, `apiProvider`, and `apiKeySource` | `claude.ai` is subscription-backed. Console, direct API, bearer-token, helper, gateway, Bedrock, Vertex, and Foundry paths are metered or cost-unknown. The JSON field schema is an implementation detail, so parsing must tolerate missing fields. |
| Codex | Start `codex app-server`, initialize it, then call `account/read` with `refreshToken:false`; fall back to `codex login status` | `account.type=chatgpt` is included and may include `planType`; `apiKey` is metered. A custom provider with `requiresOpenaiAuth=false` is funding-unknown. |
| OpenCode | `opencode auth list` plus the selected provider/model's documented nonsecret config | Credential types include OAuth, API, and well-known sources, but the selected provider determines funding. ChatGPT or Copilot OAuth can be included; OAuth alone is not sufficient. |
| Gemini CLI | `security.auth.selectedType` from documented settings | `oauth-personal` is account-included; `gemini-api-key`, Vertex, and ADC paths are metered or organization-funded. The local signal cannot distinguish Google free, AI Pro/Ultra, or Workspace tiers. |
| Amp | Installed/account state and `amp usage` when explicitly requested | `AMP_API_KEY` is an Amp account credential, not an Anthropic key. Credential shape cannot distinguish subscription, linked ChatGPT access, credits, or pay-as-you-go, so passive funding is often `unknown`. |

Additional adapters may classify only documented provider/model paths. Examples
include Copilot without BYOK as account-included, Qwen's Coding Plan endpoint as
included, Goose with Ollama as local, and Cline's `openai-codex` provider as
subscription-backed. Factory, Cursor, Kimi, Crush, and Vibe account keys must
not be treated as direct BYOK solely because they are called API keys.

#### 5.4.3 Credential persistence

The selector relies on provider processes instead of credential storage:

- Claude Code uses macOS Keychain or a protected credentials file on other
  platforms.
- Codex can use `$CODEX_HOME/auth.json` or the OS keyring according to
  `cli_auth_credentials_store`.
- Other providers use mixtures of keyrings, protected files, environment
  variables, and account configuration.

These stores contain secrets and their formats can change. `aagent` must not
read or decode them. The official provider process is the authority for cached
authentication state.

#### 5.4.4 Preventing a metered credential from shadowing a plan

The default `prefer-included` policy must evaluate the same environment the
child would receive. When a direct model API variable would override a
confirmed stored subscription, `aagent` may remove only that documented
override from the child process, never from the parent shell or persistent
configuration:

- Claude `-p` always uses `ANTHROPIC_API_KEY` when present. If a Claude.ai
  subscription is confirmed and this is the only shadowing signal, omit
  `ANTHROPIC_API_KEY` from the child. Do not add `--bare`, which disables
  subscription OAuth.
- `CODEX_API_KEY` overrides stored Codex auth for `codex exec`. If ChatGPT auth
  is selected, omit `CODEX_API_KEY` from the child. If Codex is selected only as
  a metered fallback and `CODEX_API_KEY` is absent, `aagent` may map a present
  `OPENAI_API_KEY` to `CODEX_API_KEY` in the child with a nonsecret notice. This
  is wrapper behavior, not native Codex behavior.

Do not strip custom base URLs, bearer tokens, cloud-provider selection,
enterprise gateways, or credential-helper configuration. Those signals may
represent intentional organization routing; classify them as their documented
path or `unknown` instead.

Any child-environment adjustment is disclosed by variable name, never value:

```text
aagent: using Claude subscription; ignoring ANTHROPIC_API_KEY for this child process
```

`--auth-policy native` preserves the provider's environment and authentication
precedence exactly, disables both removal and mapping, and classifies the
candidate by the path the untouched provider would actually use.

### 5.5 Discovery

The Bash runner resolves commands from `PATH` and accepts an explicit executable
override for each adapter. The PowerShell runner uses executable or external
script commands, not aliases or functions.

Overrides use the form:

```text
AAGENT_CLAUDE_BIN=/custom/path/claude
AAGENT_CODEX_BIN=/custom/path/codex
AAGENT_CURSOR_BIN=/custom/path/cursor-agent
```

Discovery itself only verifies that a resolved target exists and is executable.
Smart selection then runs passive probes for installed candidates only; it does
not probe missing commands, make model requests, or trigger authentication.

### 5.6 Configuration

Configuration locations:

- macOS/Linux: `${XDG_CONFIG_HOME:-$HOME/.config}/aagent/config`
- Windows: `%APPDATA%\aagent\config`

The file is a strict `key=value` format with only documented keys:

```ini
provider=codex
auth_policy=prefer-included
priority=codex,claude,opencode,copilot,gemini
allow_local=false
```

Whitespace around keys and values is ignored. Unknown keys are errors in
`aagent doctor` and warnings during normal invocation. The file is parsed as
data and is never sourced. Project-local configuration is deferred because
loading executable or behavioral configuration from an untrusted repository
would create a security boundary the MVP does not need.

Environment variables override the file. Command-line options override both.
The corresponding variables are `AAGENT_AUTH_POLICY`, `AAGENT_PRIORITY`, and
`AAGENT_ALLOW_LOCAL`.

### 5.7 Model selection

`--model ID` forwards an opaque, provider-native identifier. `aagent` does not
translate model families between vendors or check availability.

If an adapter has no documented per-run model option, `--model` fails before
launch with a clear unsupported-capability error. It is never silently ignored.

### 5.8 Native options

Provider-native options after `--` are an explicit escape hatch for features
that are unsafe or impossible to normalize, including approval modes,
sandboxes, budgets, tools, reasoning effort, and native output formats.

Examples:

```bash
aagent -P claude "update the changelog" -- --allowedTools Read,Edit
aagent -P codex "fix the issue" -- --sandbox workspace-write
aagent -P gemini "apply the refactor" -- --approval-mode auto_edit
aagent -P droid "fix formatting" -- --auto low
```

`aagent` must document that native options are provider-specific and may grant
substantial access. The wrapper must never add a native permission-bypass flag
on its own.

### 5.9 Output

For the MVP, stdout and stderr are passed through from the provider:

- wrapper notices and wrapper errors go to stderr;
- provider stdout remains provider stdout;
- provider stderr remains provider stderr; and
- no ANSI stripping, JSON parsing, or final-message extraction is attempted.

This preserves streaming and keeps the Bash and PowerShell implementations
dependency-free. Most headless text modes are suitable for command substitution,
but exact progress behavior remains provider-native and is listed by
`aagent doctor`.

`--dry-run` is the exception: it prints a shell-appropriate, redacted display
of the resolved executable and arguments without launching the process. It must
not print environment secrets.

### 5.10 Exit status and signals

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
  by default. Settings or plugins may customize behavior. `aagent` must not imply
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
| `cursor` | `agent --print PROMPT` | JSON and stream JSON | Changes are proposed unless the user explicitly supplies Cursor's force/yolo option. |
| `aider` | `aider --message PROMPT` | no documented stable JSON mode | Automatically commits changes by default. An adapter must expose this fact and must not silently broaden Git side effects. |

Tier 2 means the official interface is suitable, but its adapter is not required
to call the initial implementation complete.

### 6.4 Planned authentication evidence

| Provider | Safe evidence | Selector limitation |
| --- | --- | --- |
| GitHub Copilot CLI | GitHub login/token availability plus absence of active BYOK provider overrides | A GitHub PAT can authenticate an included Copilot seat; token shape does not imply BYOK. GitHub login alone does not prove Copilot entitlement. |
| Factory Droid | Account readiness plus selected Factory-managed or BYOK model configuration | Browser login and `FACTORY_API_KEY` both access Factory accounts; neither alone identifies funding. |
| Goose | Documented nonsecret provider ID | Native Claude/Codex/Cursor adapters inherit the underlying CLI's funding class. `goose info --check` sends a real prompt and is prohibited during selection. |
| Qwen Code | Coding Plan endpoint and documented auth-selection configuration | A Coding Plan uses an API key but is `included_confirmed`; generic API keys remain provider-specific. |
| Kimi Code | Managed-login or selected-provider metadata | Kimi membership API keys can share membership quota, so keys are not automatically BYOK. |
| Cline | Selected provider when exposed safely | `openai-codex` is subscription-backed; Cline account credits and other BYOK providers require different classes. No focused public status command currently exposes this safely. |
| Cursor CLI | `agent status --format json`, parsing only authentication booleans and endpoint class | Browser and `CURSOR_API_KEY` both authenticate Cursor accounts; plan tier and remaining personal usage are unavailable. |
| Aider | Nonsecret model/base-URL selection only | Local models and Copilot can avoid direct API billing; normal configs may contain raw keys and must not be emitted or parsed wholesale. |
| Crush | Selected provider and documented OAuth metadata, when safely exposed | Copilot can be included; Hyper and provider keys require provider-specific funding semantics. `crush login` is not a status probe. |
| Mistral Vibe | Browser/account state and selected provider profile, when safely exposed | Key location does not distinguish included Vibe budget from pay-as-you-go. |

If an adapter cannot obtain this evidence through a stable, nonsecret surface,
it reports `unknown` instead of inspecting private credential storage.

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

For permissions, the MVP uses the provider's installed configuration and native
headless default. The authentication policy may adjust a documented shadowing
API variable in the child process, but it does not change tool permissions. The
MVP does not define a universal `--read-only`, `--edit`, or `--full-access`
flag. Those names would imply equivalence that the underlying sandboxes and
tool policies do not provide.

The wrapper must:

- never append `--yolo`, `--dangerously-skip-permissions`,
  `--skip-permissions-unsafe`, `--allow-all-tools`, `--auto`, or equivalent;
- never answer an approval prompt on the user's behalf;
- display known provider safety notes in `aagent doctor`;
- treat native options after `--` as an explicit user choice;
- avoid silently changing provider configuration files; and
- never retry a failed run with another provider.

### 7.2 Future normalized policies

A later release may add capability-aware policy names such as `read-only`,
`workspace`, and `unrestricted`. Each adapter would need a documented mapping
and a fail-closed result when it cannot enforce the requested boundary. Merely
omitting a vendor's yolo flag is not evidence of read-only execution.

## 8. Introspection

### 8.1 `aagent providers`

Lists every known adapter, resolution path, passive authentication result,
funding class, and selection reason without logging in or contacting the
network:

```text
ID        STATUS   FUNDING               SELECTED  REASON
codex     ready    included_confirmed    yes       ChatGPT Pro
claude    ready    included_confirmed    no        popularity #2
gemini    missing  unknown               no        executable missing
cursor    ready    included_account      no        lower funding class
```

Paths and versions may be included in a verbose form. Account email,
organization, token fingerprints, credential values, and raw status output are
never displayed.

### 8.2 `aagent doctor [PROVIDER]`

Runs non-mutating diagnostics:

- wrapper version and platform;
- detected provider paths and versions;
- selected provider and why it won;
- configuration errors;
- readiness, funding class, confidence, safe plan label, and shadowing variable
  names where supported;
- supported model, stdin, structured-output, and session capabilities; and
- provider-specific permission or side-effect warnings.

Authentication is reported as `ready`, `unusable`, or `unknown`. Funding and
authentication confidence are reported separately. `unknown` is valid when a
provider lacks a stable, non-interactive status probe. Doctor must not open a
browser, begin login, display credentials, or send a model request.

## 9. Usage-aware routing backlog

Static funding-aware selection is part of the MVP. Live allowance balancing is
a separate, opt-in backlog feature because providers expose incompatible quota
windows and most lack a documented passive API.

Current capabilities:

- Codex documents `account/rateLimits/read` through app-server. It can return
  primary, secondary, and named buckets with `usedPercent`, window duration,
  reset time, plan type, and optional credits.
- Claude exposes five-hour and seven-day percentages in status-line data only
  after an API response, plus interactive `/usage`; it has no documented
  zero-request headless quota probe.
- Gemini `/stats model`, Factory `/limits`, Kimi `/usage`, and Amp `usage` expose
  provider-specific information, but not a common stable noninteractive schema.
- GitHub has an authenticated billing-usage API for some Copilot usage, but it
  requires additional scopes and does not alone establish the user's total
  organization-funded allowance.
- Direct Anthropic and OpenAI model API keys do not expose a simple personal
  remaining-balance probe suitable for automatic selection.

A future `quota-aware` mode may insert `remaining_allowance` after
`authentication_confidence` and before user priority in the selection tuple,
subject to all of these rules:

1. Use only documented zero-cost account endpoints or provider-emitted status
   data; never send a test prompt.
2. Cache only provider ID, normalized percentages, window/reset timestamps,
   source, and observation time. Never cache tokens or raw responses.
3. Apply a short timeout and TTL. Stale data becomes unknown.
4. For a provider with several active limits, use the most constrained window,
   not only its shortest or primary window.
5. Known exhaustion may demote a candidate. Unknown quota is neutral and must
   not be interpreted as empty or unlimited.
6. Compare headroom only between compatible included-plan candidates with
   sufficiently fresh evidence. Different window lengths, credits, and token
   accounting are not intrinsically equivalent.
7. Fall back to the static funding/popularity policy on any probe or schema
   failure.

Until comparable passive support exists for at least Claude and Codex, this
mode remains out of the default execution path. An opt-in collector could later
ingest Claude's emitted status-line fields after real user runs and combine
them with Codex's passive rate-limit endpoint.

## 10. Future structured API

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

## 11. Testing requirements

### 11.1 Adapter tests

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

### 11.2 Selection tests

- no providers installed;
- exactly one provider installed;
- several installed providers and the popularity prior;
- a less-popular included subscription beating a more-popular pay-as-you-go
  candidate;
- known-unusable auth being excluded while unknown auth remains a last resort;
- credential shapes that represent included plans, account credits, local
  models, and direct BYOK;
- Claude and Codex API variables shadowing stored subscriptions;
- `prefer-included` adjusting only the child environment and `native`
  preserving it;
- probe timeout, malformed output, missing fields, and version drift degrading
  to `unknown`;
- configured priority breaking ties without crossing funding classes;
- command-line, environment, and config precedence;
- explicit missing provider;
- executable overrides;
- a selected provider that fails authentication, proving no failover occurs;
- discovery of Cursor's separate `agent` executable; and
- `--quiet` and `--dry-run` behavior.

### 11.3 Security tests

Prompts and configuration values containing shell syntax must remain inert.
Tests must prove that the wrapper never introduces a known approval-bypass
flag, never sources a configuration file, never reads a credential token file,
never sends a model request for probing, never emits token or PII fields from a
status response, and never changes the parent environment.

### 11.4 Platform tests

GitHub Actions must run:

- Bash tests on Linux, macOS, and Windows Git Bash;
- PowerShell tests on Windows; and
- equivalent adapter and selection fixtures in both runners.

Live provider tests are opt-in, credentialed, and excluded from pull-request CI
to avoid cost and secret exposure. A scheduled compatibility workflow may
install current CLIs, inspect their documented help output, and flag adapter
drift without running a paid prompt.

## 12. MVP acceptance criteria

The implementation following this specification is complete when:

1. Tier 1 adapters work through `aagent "say hello"` using fake-executable
   contract tests on every supported runner.
2. Explicit and automatic provider selection follow the documented
   lexicographic formula.
3. A confirmed included plan always outranks a direct metered API during
   automatic selection, regardless of popularity.
4. Tier 1 passive auth probes fail safely to `unknown` without reading tokens
   or sending model requests.
5. The chosen provider, funding class, and decisive reason are visible on
   stderr unless `--quiet` is used.
6. Prompts, stdin, cwd, native arguments, stdout, stderr, signals, and exit
   statuses satisfy the contract above.
7. No provider receives a permission escalation unless it appears after the
   user's explicit `--` separator.
8. Missing providers, unsupported model flags, invalid configuration, and empty
   input produce stable wrapper errors.
9. `aagent providers` and `aagent doctor` are non-mutating, do not trigger
   login, and never reveal account PII or credential material.
10. Cursor's `agent` executable can be discovered without being confused with
   the `aagent` wrapper.
11. Existing `--help`, installation, and cross-platform test behavior remains
   intact.

## 13. Decisions deferred until after the MVP

- a normalized JSON result and streaming event protocol;
- portable sessions and resume behavior;
- capability-aware permission profiles;
- budget, reasoning-effort, system-prompt, and tool-selection flags;
- opt-in live quota-aware routing and post-run status-line collection;
- successful-provider history as a local tie-breaker;
- project-local configuration;
- automatic compatibility metadata updates; and
- server, SDK, or ACP transports.

## 14. Primary sources

Only first-party documentation, repositories, and package/download APIs were
used for the interface and selection survey.

- Claude Code: [headless mode](https://code.claude.com/docs/en/headless),
  [CLI reference](https://code.claude.com/docs/en/cli-reference),
  [authentication and precedence](https://code.claude.com/docs/en/iam),
  [status-line rate limits](https://code.claude.com/docs/en/statusline#rate-limit-usage)
- Codex CLI: [non-interactive mode](https://developers.openai.com/codex/noninteractive),
  [CLI reference](https://developers.openai.com/codex/cli/reference),
  [authentication](https://learn.chatgpt.com/docs/auth),
  [app-server account and rate-limit API](https://learn.chatgpt.com/docs/app-server#auth-endpoints),
  [pricing and usage limits](https://learn.chatgpt.com/docs/pricing)
- OpenCode: [CLI](https://opencode.ai/docs/cli/),
  [permissions](https://opencode.ai/docs/permissions/),
  [providers](https://opencode.ai/docs/providers/)
- Amp: [CLI manual](https://ampcode.com/manual#cli),
  [streaming JSON](https://ampcode.com/manual#cli-streaming-json)
- Gemini CLI: [headless mode](https://geminicli.com/docs/cli/headless/),
  [CLI reference](https://geminicli.com/docs/cli/cli-reference/),
  [authentication](https://geminicli.com/docs/get-started/authentication/),
  [quota and pricing](https://geminicli.com/docs/resources/quota-and-pricing/)
- Factory Droid: [headless exec](https://docs.factory.ai/droid-exec/overview),
  [CLI reference](https://docs.factory.ai/droid-cli/cli-reference),
  [BYOK](https://docs.factory.ai/model-independence/byok),
  [pricing](https://docs.factory.ai/pricing/individuals)
- GitHub Copilot CLI: [official repository](https://github.com/github/copilot-cli),
  [authentication](https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/authenticate-copilot-cli),
  [billing usage API](https://docs.github.com/en/rest/billing/usage)
- Goose: [running tasks](https://goose-docs.ai/docs/guides/running-tasks/),
  [headless tutorial](https://goose-docs.ai/docs/tutorials/headless-goose/),
  [providers](https://goose-docs.ai/docs/getting-started/providers/)
- Qwen Code: [headless mode](https://github.com/QwenLM/qwen-code/blob/main/docs/users/features/headless.md),
  [authentication](https://qwenlm.github.io/qwen-code-docs/en/users/configuration/auth/)
- Kimi Code: [command reference](https://moonshotai.github.io/kimi-code/en/reference/kimi-command),
  [membership](https://www.kimi.com/code/docs/en/kimi-code/membership.html)
- Cline: [CLI reference](https://docs.cline.bot/cli/cli-reference),
  [authorization](https://docs.cline.bot/getting-started/authorizing-with-cline),
  [official repository](https://github.com/cline/cline)
- Crush: [official repository](https://github.com/charmbracelet/crush),
  [`run` command source](https://github.com/charmbracelet/crush/blob/main/internal/cmd/run.go),
  [`login` command source](https://github.com/charmbracelet/crush/blob/main/internal/cmd/login.go)
- Mistral Vibe: [official repository](https://github.com/mistralai/mistral-vibe),
  [API keys and profiles](https://docs.mistral.ai/vibe/code/cli/api-keys-profiles)
- Kiro CLI: [headless mode](https://kiro.dev/docs/cli/headless)
- Aider: [scripting guide](https://aider.chat/docs/scripting.html),
  [options reference](https://aider.chat/docs/config/options.html),
  [Copilot subscription provider](https://aider.chat/docs/llms/github.html)
- Cursor CLI: [headless mode](https://cursor.com/docs/cli/headless),
  [authentication](https://docs.cursor.com/en/cli/reference/authentication),
  [parameter reference](https://cursor.com/docs/cli/reference/parameters)
- OpenHands: [official repository](https://github.com/OpenHands/OpenHands)

Popularity snapshot inputs:

- npm downloads: [`@openai/codex`](https://api.npmjs.org/downloads/point/last-month/%40openai%2Fcodex),
  [`@anthropic-ai/claude-code`](https://api.npmjs.org/downloads/point/last-month/%40anthropic-ai%2Fclaude-code),
  [`opencode-ai`](https://api.npmjs.org/downloads/point/last-month/opencode-ai),
  [`@github/copilot`](https://api.npmjs.org/downloads/point/last-month/%40github%2Fcopilot),
  [`@google/gemini-cli`](https://api.npmjs.org/downloads/point/last-month/%40google%2Fgemini-cli)
- GitHub repositories: [Codex](https://github.com/openai/codex),
  [Claude Code](https://github.com/anthropics/claude-code),
  [OpenCode](https://github.com/anomalyco/opencode),
  [Copilot CLI](https://github.com/github/copilot-cli),
  [Gemini CLI](https://github.com/google-gemini/gemini-cli)
