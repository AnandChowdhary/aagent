# Provider selection and authentication

Status: Normative for the MVP
Default authentication policy: `prefer-included`

## Explicit selection

Provider choice uses this precedence:

1. `--provider ID`
2. `AAGENT_PROVIDER`
3. `provider` in the user configuration file
4. automatic smart selection

An explicit provider is authoritative even when another candidate would be
cheaper or more popular. A missing explicit provider is an error and does not
fall through. The authentication policy still applies unless the user selects
`--auth-policy native`.

## Automatic smart selection

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

Earlier fields always dominate later fields. Popularity can never make a
pay-as-you-go candidate outrank a confirmed included plan.

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
2. a machine-readable current official implementation detail with tolerant
   parsing;
3. a documented redacted text status;
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

`--priority`, `AAGENT_PRIORITY`, or the configured `priority` list breaks ties
within the same readiness, funding, and confidence class. It does not override
any of those boundaries. Users who want an unconditional choice use
`--provider`, `AAGENT_PROVIDER`, or the `provider` config key.

For deterministic comparison, `ready` and `unknown` normalize to descending
scores `2` and `1`; unusable candidates are excluded. Funding classes normalize
to descending scores `6` through `1` in the table order above. Authentication
uses the concrete `4` through `0` ranks in [probes.md](probes.md). Earlier
configured priority entries outrank later entries, and every listed provider
outranks every unlisted provider; unlisted providers tie on this field. Lower
numeric popularity and registry positions normalize to higher comparison
scores. No runtime network metric, wall-clock value, previous result, usage
history, or cached quota is part of the tuple.

The winner is compared with the runner-up to identify the first different
field. The stable reason codes are `only_candidate`, `readiness`,
`funding_class`, `authentication_confidence`, `configured_priority`,
`popularity_prior`, and `stable_registry_order`. Display strings contain only
fixed wording, safe enum values, and documented numeric positions.

## Popularity prior

The popularity prior is a versioned build-time snapshot. It is not downloaded
during a run and does not create telemetry. Rolling public package downloads
are the primary signal; official GitHub stars are secondary. Both are
imperfect, so providers without comparable public metrics retain a documented
registry position rather than a fabricated score.

The 2026-08-04 snapshot for the five largest comparable package channels is:

| Provider | Previous 30 days of npm downloads | GitHub stars |
| --- | ---: | ---: |
| Codex | 60,263,416 | 103,904 |
| Claude Code | 42,087,874 | 140,223 |
| OpenCode | 8,152,416 | 193,300 |
| GitHub Copilot CLI | 5,870,894 | 11,055 |
| Gemini CLI | 1,929,607 | 106,356 |

The initial popularity and registry order is:

```text
codex,claude,opencode,copilot,gemini,cline,goose,aider,qwen,amp,kimi,droid,crush,vibe,kiro,cursor
```

This order is only a late tie-breaker. It is reviewed in a normal release and
never changed from a network response at runtime.

## Selection notice and failure behavior

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

## Probe rules

The concrete result schema, supervisor bounds, confidence ranks, and Tier 1
classification table are defined in [probes.md](probes.md).

Normal selection may start installed CLIs only through documented, passive
status interfaces. Probes must:

- run without a TTY and with a short timeout;
- avoid model requests and login flows;
- avoid network calls by default, with documented passive status exceptions;
- parse an allowlist of nonsecret fields and discard the raw response;
- check environment variables by presence only;
- never invoke an `apiKeyHelper` or other credential-producing command;
- never open an OS credential-store entry or credential token file; and
- degrade to `unknown` on timeout, version drift, or parse failure.

Documented nonsecret configuration fields may be parsed as data with a real
JSON or TOML parser. Configuration is never sourced as shell code. Credential
file existence alone is low-confidence evidence and cannot establish a plan.

## Core provider probes

| Provider | Passive evidence | Funding interpretation |
| --- | --- | --- |
| Claude Code | `claude auth status --json`; allowlist `loggedIn`, `authMethod`, `subscriptionType`, `apiProvider`, and `apiKeySource` | `claude.ai` is subscription-backed. Console, direct API, bearer-token, helper, gateway, Bedrock, Vertex, and Foundry paths are metered or cost-unknown. The JSON field schema is an implementation detail, so parsing must tolerate missing fields. |
| Codex | Start `codex app-server`, initialize it, then call `account/read` with `refreshToken:false`; fall back to `codex login status` | `account.type=chatgpt` is included and may include `planType`; `apiKey` is metered. A custom provider with `requiresOpenaiAuth=false` is funding-unknown. |
| OpenCode | `opencode auth list` plus the selected provider/model's documented nonsecret config | Credential types include OAuth, API, and well-known sources, but the selected provider determines funding. ChatGPT or Copilot OAuth can be included; OAuth alone is not sufficient. |
| GitHub Copilot CLI | No CLI probe; documented BYOK and GitHub token variables are checked by presence, with only the BYOK endpoint authority classified | BYOK wins over GitHub auth. Loopback is local, a documented BYOK credential is metered, remote BYOK without one is unknown, and GitHub token presence is at most `included_account`. Stored OAuth does not prove entitlement. |
| Gemini CLI | `security.auth.selectedType` from documented settings | `oauth-personal` is account-included; `gemini-api-key`, Vertex, and ADC paths are metered or organization-funded. The local signal cannot distinguish Google free, AI Pro/Ultra, or Workspace tiers. |
| Amp | Installed/account state and `amp usage` when explicitly requested | `AMP_API_KEY` is an Amp account credential, not an Anthropic key. Credential shape cannot distinguish subscription, linked ChatGPT access, credits, or pay-as-you-go, so passive funding is often `unknown`. |
| Cursor CLI | `agent status --format json`, reduced to three authentication booleans and an optional endpoint class; `CURSOR_API_KEY` presence is a lower-confidence fallback | Authenticated vendor accounts are at most `included_account`; local endpoints require explicit opt-in, custom endpoints are funding-unknown, and plan or remaining allowance is never inferred. The status command may perform account enrichment. |
| Factory Droid | `FACTORY_API_KEY` presence plus bounded documented selected-model and custom-model endpoint settings; no CLI account probe | The key proves only a Factory account path and remains funding-unknown. A selected remote custom endpoint is `payg_byok`; loopback is opt-in `local`. Browser login, plan, credits, and allowance remain unknown. |
| Goose | bounded `active_provider`/`GOOSE_PROVIDER` plus allowlisted custom-provider route fields; no CLI command | Native CLI/ACP routes inherit the underlying adapter's passive funding and auth policy. Known account providers are included, loopback is opt-in local, direct API routes are BYOK, and unknown routes remain unknown. `goose info --check` is prohibited. |

Additional adapters may classify only documented provider/model paths.
Examples include Qwen's Coding Plan endpoint as included and Cline's
`openai-codex` provider as subscription-backed. Cursor,
Kimi, Crush, and Vibe account keys must
not be treated as direct BYOK solely because they are called API keys.

## Credential persistence boundary

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

## Preventing a metered credential from shadowing a plan

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

For Claude, the conservative environment allowlist includes the documented
Bedrock, Mantle, Vertex, Foundry, and Claude Platform on AWS selectors and base
URLs; `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_BASE_URL`,
`ANTHROPIC_CUSTOM_HEADERS`, Foundry resource/key variables, and the Bedrock
bearer-token variable. A present custom-route signal prevents every
subscription-shadow adjustment. An `apiKeySource` helper or status-reported
gateway/cloud path has the same effect even when it has no visible environment
variable.

Any child-environment adjustment is disclosed by variable name, never value:

```text
aagent: using claude subscription; omitting ANTHROPIC_API_KEY from the child process
```

`--auth-policy native` preserves the provider's environment and authentication
precedence exactly, disables both removal and mapping, and classifies the
candidate by the path the untouched provider would actually use.

An explicit Claude or Codex choice bypasses ranking but still runs that selected
provider's passive probe when needed to enforce `prefer-included`; it never
probes an unselected provider.
