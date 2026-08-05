# Research conclusions

Status: Normative research basis
Research snapshot: 2026-08-04

This document records the conclusions that shape the `aagent` contract. The
underlying first-party references and popularity inputs are in
[sources.md](sources.md).

## The portable core is small

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

## The rest is not uniform

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
- **Authentication:** Status commands and exit behavior are inconsistent. Some
  tools use browser login, some environment API keys, and some support both.
- **Side effects:** Aider enables automatic Git commits by default. Cursor's
  headless mode proposes changes unless forced. Factory Droid defaults to
  read-only autonomy; Spec Mode and higher autonomy are separate explicit
  controls. A wrapper must not erase these distinctions.
- **Exit behavior:** Several providers publish exit-code contracts, while
  others only promise a non-zero failure. The wrapper can preserve an exit code
  but cannot reinterpret every code correctly.

Therefore the MVP standardizes invocation and selection, not the agent's
runtime semantics.

## Authentication and billing are different dimensions

Credential shape is not a safe proxy for cost. A direct `ANTHROPIC_API_KEY` or
`CODEX_API_KEY` selects metered model API usage, but GitHub tokens used by
Copilot and account keys used by Amp, Cursor, Factory, Kimi, or a Qwen Coding
Plan can represent subscriptions, seats, or prepaid account allowances.

`aagent` must classify the documented **funding path used by the selected
provider and model**, not merely whether a credential looks like OAuth or an
API key. An unknown funding path remains unknown; it is never guessed to be
free.

## Passive probes are sufficient for static routing

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
- Copilot CLI documents GitHub token precedence and explicit BYOK provider
  overrides, but exposes no passive entitlement command. Token-variable
  presence is low-confidence account-path evidence; executable presence,
  `gh auth status`, and inaccessible stored OAuth remain funding-unknown.
- Cursor exposes an authentication status command, although its plan tier is
  not reported.
- Factory Droid exposes no passive account/plan command. Its account API key
  proves readiness but not funding; selected custom-model settings can identify
  only local versus remote BYOK routing.

Providers without a stable passive probe can still be used, but receive lower
authentication confidence during automatic selection.

## Product boundary

`aagent` is a compatibility layer, not a new agent runtime. Authentication,
models, tools, repository instructions, billing, and provider configuration
remain owned by the selected agent. The wrapper owns only discovery, passive
classification, deterministic selection, safe invocation, and diagnostics.
