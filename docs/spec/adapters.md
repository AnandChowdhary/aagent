# Provider adapter registry

Status: Normative registry; Tier 1 is MVP scope

## Adapter contract

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

For OpenCode, whose documented `run` interface accepts a message argument but
does not document separate piped context, stdin-only input is passed as that
single message argument. Prompt-plus-stdin uses the separator fallback from
the CLI contract and is likewise passed as one message argument.

The registry is ordered by the versioned popularity/registry snapshot in
`selection.md`. Tier 1 entries are runnable once their later invocation phases
land. Planned entries are still discoverable for diagnostics but report
`unsupported` when installed; their presence never makes them an automatic MVP
candidate.

## Tier 1: required for the first functional release

### Claude Code (`claude`)

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

### Codex CLI (`codex`)

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

### OpenCode (`opencode`)

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

### Amp (`amp`)

- Invocation: `amp --execute PROMPT`
- Model: no documented general per-run model flag; `--fast` is a mode override,
  not a portable model selector.
- Input: argument, stdin, or both; redirected stdout also enables execute mode.
- Native output: final text or `--stream-json`; optional thinking events extend
  the stream schema.
- Sessions: threads can be continued in execute mode.
- Permissions: Amp documents that it does not ask permission before using tools
  by default. Settings or plugins may customize behavior. `aagent` must not
  imply that omitting an unsafe flag makes this equivalent to a read-only
  provider.
- Authentication: unattended execution can use `AMP_API_KEY`.

### Gemini CLI (`gemini`)

- Invocation: `gemini --prompt PROMPT`
- Model: `--model ID`
- Input: argument and stdin; piped content is appended to the prompt.
- Native output: `text`, one JSON result object, or streaming JSON events.
- Sessions: `--resume` supports the latest or a selected session.
- Permissions: native approval modes include `default`, `auto_edit`, `yolo`,
  and `plan`; sandboxing is a separate option. The deprecated `--yolo` alias
  must not be added by the wrapper.
- Published exit codes include success, general failure, invalid input, and
  turn limit. The wrapper preserves them without interpretation.

## Tier 2: planned adapters

| ID | Executable and one-shot form | Structured output | Important compatibility note |
| --- | --- | --- | --- |
| `droid` | `droid exec PROMPT` | JSON, stream JSON, and JSON-RPC | Read-only spec mode by default; `--auto low/medium/high` grants increasing autonomy. |
| `copilot` | `copilot --prompt PROMPT --silent --no-ask-user` | text or JSONL with `--output-format json` | Piped input is ignored when `--prompt` is present, so combined input must become one prompt argument. The wrapper adds no permission grant. See the [2026-08-05 revalidation](../research/copilot-cli-2026-08-05.md). |
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

## Planned authentication evidence

| Provider | Safe evidence | Selector limitation |
| --- | --- | --- |
| GitHub Copilot CLI | BYOK override-variable presence and GitHub token-variable presence, without values; there is no passive Copilot entitlement command | BYOK wins over GitHub auth and may be local, metered, or unknown by endpoint/credential class. GitHub token presence is low-confidence account-path evidence; executable presence, `gh auth status`, and inaccessible stored OAuth do not prove entitlement or a plan. |
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

## Explicit exclusions

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
