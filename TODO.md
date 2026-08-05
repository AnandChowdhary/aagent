# aagent implementation ledger

Status: Authoritative source of truth for implementation
Specification snapshot: 2026-08-04
Current milestone: Phase 11 release readiness

This ledger turns [SPEC.md](SPEC.md) into ordered, independently verifiable
work. Phases 0 through 11 define the MVP. Phases 12 onward are backlog and must
not delay the MVP.

## How to use this ledger

- `[ ]` means not started, `[x]` means verified complete, and `[!]` means
  blocked with the reason recorded directly below the task.
- Check a task only after its production change, tests, documentation, and
  platform-relevant verification all pass.
- Task IDs are stable. If scope changes, retain the old ID with a note and add a
  new ID instead of silently reusing it.
- Dependencies are hard gates. Do not start a task until every listed task or
  phase is complete unless the work is an isolated test fixture or research
  spike that cannot affect production behavior.
- Production remains dependency-free and self-contained in `aagent.sh` and
  `aagent.ps1`. Tests and documentation may be split into supporting files.
- No live provider credential, login, or paid prompt belongs in normal tests.
- If this ledger conflicts with a normative specification, the specification
  wins. Update the specification and this ledger before continuing.
- Each implementation pull request should name the task IDs it completes.

## Definition of done for every implementation task

A task is done only when all applicable conditions are true:

1. Bash and PowerShell have equivalent observable behavior.
2. New behavior has deterministic fake-provider or unit coverage.
3. Error paths assert both exit status and user-facing stderr.
4. User-controlled strings remain inert data and are tested with hostile input.
5. No secret, account PII, or raw authentication response is logged.
6. `bash tests/test_aagent.sh` passes locally.
7. `pwsh -NoProfile -File tests/test_aagent.ps1` passes where PowerShell is
   available.
8. `git diff --check` passes and the relevant specification/help text agrees
   with the implementation.
9. Required GitHub Actions jobs pass on Linux, macOS, Windows Git Bash, and
   Windows PowerShell before merge.

## Phase 0 - Specification baseline

Dependencies: none
Deliverable: one reviewable contract and one ordered implementation ledger

- [x] **P0-01 Split the monolithic specification by responsibility.**
  Deliver `docs/spec/` documents for research, CLI behavior, selection and
  authentication, adapters, security, introspection, testing, backlog, and
  sources.

- [x] **P0-02 Define normative document precedence.**
  Record how conflicts, provider drift, and requirement changes must update the
  specification before implementation continues.

- [x] **P0-03 Preserve the research evidence.**
  Retain the 2026-08-04 first-party source list, popularity metrics, provider
  commands, funding distinctions, and quota limitations.

- [x] **P0-04 Define stable implementation task IDs and dependencies.**
  Cover all MVP layers, cross-platform gates, Tier 2 adapters, and post-MVP
  work in this ledger.

- [x] **P0-05 Define MVP acceptance traceability.**
  Map every acceptance criterion from `docs/spec/testing.md` to concrete phases
  in the traceability table at the end of this file.

### Phase 0 exit gate

- [x] All local Markdown links resolve, no requirement remains only in the old
  monolith, and the repository diff contains documentation changes only.

## Phase 1 - Test harness and shared behavioral vocabulary

Dependencies: Phase 0
Deliverable: deterministic, credential-free fixtures that both runners can use

- [x] **P1-01 Introduce wrapper status constants.**
  Define named internal constants for `0`, `64`, `69`, `70`, and `78` in both
  runners; update current unknown-option behavior to use `64`.

- [x] **P1-02 Turn existing test files into stable entrypoints.**
  Keep `tests/test_aagent.sh` and `tests/test_aagent.ps1` as the commands CI
  invokes, even if they dispatch to focused test files later.

- [x] **P1-03 Add isolated temporary-environment helpers.**
  Every test must get a unique temporary directory, synthetic `HOME`,
  `XDG_CONFIG_HOME` or `APPDATA`, controlled `PATH`, cleanup trap/finally block,
  and no access to the developer's provider configuration.

- [x] **P1-04 Define the fake-provider recording protocol.**
  Fake executables must record one argument per line with an unambiguous length
  or encoding, stdin bytes, cwd, selected allowlisted environment variables,
  requested stdout/stderr, and requested exit status.

- [x] **P1-05 Add fake executables for all Tier 1 command names.**
  Provide test doubles for `claude`, `codex`, `opencode`, `amp`, and `gemini` on
  Bash and PowerShell platforms without invoking real installations.

- [x] **P1-06 Add fake passive-probe responses.**
  Fixtures must support valid, missing-field, malformed, delayed, non-zero,
  secret-bearing, and PII-bearing status responses separately from run
  responses.

- [x] **P1-07 Add reusable assertions.**
  Assert exact argv order, stdin, cwd, stdout, stderr, status, environment
  presence/absence, lack of unexpected launches, and secret absence in output.

- [x] **P1-08 Add a provider-launch counter.**
  Tests must prove whether zero, one, or more provider run processes started;
  authentication probe invocations are counted separately.

- [x] **P1-09 Add shell and PowerShell syntax checks.**
  Run `bash -n aagent.sh install.sh tests/test_aagent.sh` and PowerShell parser
  validation before behavioral tests.

### Phase 1 exit gate

- [x] A deliberately fake prompt run can capture identical logical argv,
  stdin, cwd, environment, output, and status evidence from both runners; all
  existing help and installer tests still pass.

  Evidence: [PR #1](https://github.com/AnandChowdhary/aagent/pull/1) and
  [cross-platform CI run 30946990236](https://github.com/AnandChowdhary/aagent/actions/runs/30946990236).

## Phase 2 - Wrapper argument parsing and input resolution

Dependencies: Phase 1
Deliverable: the complete wrapper grammar without provider selection or launch

- [x] **P2-01 Implement long and short option parsing.**
  Support `-P/--provider`, `-m/--model`, `-C/--cwd`, `--auth-policy`,
  `--dry-run`, `--quiet`, `-h/--help`, and `--version` in both runners.

- [x] **P2-02 Implement subcommand recognition.**
  Recognize `providers` and `doctor [PROVIDER]` only in command position while
  allowing those words inside ordinary prompts.

- [x] **P2-03 Implement the native-option separator.**
  Preserve every argument after the first wrapper-level `--` exactly and stop
  wrapper option parsing at that point.

- [x] **P2-04 Reject unknown or incomplete wrapper options.**
  Missing option values, unknown options before `--`, extra `doctor` arguments,
  and invalid auth policies exit `64` without launching or probing a provider.

- [x] **P2-05 Join positional prompt arguments.**
  Join prompt words with exactly one ASCII space while preserving the contents
  of each shell-parsed argument, including embedded newlines.

- [x] **P2-06 Resolve stdin-only prompts.**
  When there are no prompt arguments and stdin is non-terminal, capture or
  forward stdin as the prompt without opening an interactive provider UI.

- [x] **P2-07 Represent prompt-plus-stdin separately.**
  Preserve positional instruction and piped context as distinct internal
  values so each adapter can apply its documented behavior.

- [x] **P2-08 Reject missing and empty input.**
  No prompt plus terminal stdin, an explicit empty prompt, or empty piped input
  exits `64` with concise usage on stderr.

- [x] **P2-09 Validate `--cwd` before any probe.**
  Require an existing directory, resolve it without executing user input, and
  return `64` for invalid paths.

- [x] **P2-10 Make help the public contract.**
  Update both help outputs to match `docs/spec/cli-contract.md`, including
  subcommands, options, stdin behavior, `--`, and representative examples.

- [x] **P2-11 Add parser injection cases.**
  Cover spaces, single and double quotes, glob characters, leading dashes,
  semicolons, pipes, redirections, backticks, `$()` text, PowerShell
  subexpressions, CRLF, newlines, tabs, Unicode, and a literal `--`.

- [x] **P2-12 Verify parsing has no side effects.**
  All parser error and help/version cases must prove zero discovery probes and
  zero provider run launches.

### Phase 2 exit gate

- [x] A parser fixture produces the same logical parse record in Bash and
  PowerShell for every valid and invalid CLI example in the specification.

  Evidence: [PR #2](https://github.com/AnandChowdhary/aagent/pull/2) and
  [cross-platform CI run 30948205134](https://github.com/AnandChowdhary/aagent/actions/runs/30948205134).

## Phase 3 - Adapter registry and executable discovery

Dependencies: Phase 2
Deliverable: inspectable metadata and deterministic installed-provider results

- [x] **P3-01 Define the internal adapter record.**
  Represent provider ID, display name, executable, override variable, command
  shape, stdin modes, model support, structured/session capability, safety
  note, probe capability, popularity rank, and stable registry rank.

- [x] **P3-02 Register the five Tier 1 adapters.**
  Add `claude`, `codex`, `opencode`, `amp`, and `gemini` in the documented
  registry order with no adapter-specific condition in global parsing.

- [x] **P3-03 Reserve Tier 2 identities.**
  Record metadata sufficient for `providers` to call them unsupported/planned,
  but do not make Tier 2 candidates runnable during the MVP.

- [x] **P3-04 Implement Bash `PATH` discovery.**
  Resolve executable files only, reject directories and non-executable targets,
  preserve paths containing spaces, and do not execute a version command during
  normal discovery.

- [x] **P3-05 Implement PowerShell command discovery.**
  Accept application and external-script commands; reject aliases, functions,
  cmdlets, and wrapper self-resolution.

- [x] **P3-06 Implement explicit executable overrides.**
  Honor `AAGENT_<PROVIDER>_BIN`, validate the exact target, and treat an invalid
  override as that adapter being unavailable with a diagnostic reason.

- [x] **P3-07 Prevent wrapper recursion and name collisions.**
  Detect the current `aagent` runner path and ensure Cursor's native `agent`
  executable is a separate future adapter rather than an alias for the wrapper.

- [x] **P3-08 Separate missing, installed, and unsupported.**
  Discovery must return stable statuses and nonsecret reasons suitable for both
  automatic selection and introspection.

- [x] **P3-09 Freeze the popularity and registry snapshot.**
  Encode the documented 2026-08-04 order as constants with a snapshot label;
  prove there is no runtime HTTP, package-manager, or telemetry call.

- [x] **P3-10 Test hostile executable paths.**
  Cover spaces, Unicode, leading dashes, symlinks, broken links, non-executable
  files, same-name wrapper targets, and Windows `.exe/.cmd/.ps1` resolution.

### Phase 3 exit gate

- [x] Given a controlled `PATH`, both runners emit the same ordered registry
  with correct resolution status and never start a provider run.

  Evidence: [PR #3](https://github.com/AnandChowdhary/aagent/pull/3) and
  [cross-platform CI run 30949018135](https://github.com/AnandChowdhary/aagent/actions/runs/30949018135).

## Phase 4 - Process execution core

Dependencies: Phase 3
Deliverable: one safe, platform-specific process launcher used by every adapter

- [x] **P4-01 Define a launch plan value.**
  Hold executable, argv array, cwd, stdin mode, child-only environment changes,
  and redacted display metadata without constructing a command string.

- [x] **P4-02 Implement Bash array-based launch.**
  Invoke the resolved executable directly from an argv array; use `exec` when
  no wrapper cleanup or mediation remains necessary.

- [x] **P4-03 Implement PowerShell argument-safe launch.**
  Preserve logical arguments without expression evaluation and return the
  actual native process exit code across Windows PowerShell quoting cases.

- [x] **P4-04 Apply the requested working directory.**
  Change only the child launch context and leave the caller's shell directory
  unchanged after wrapper completion.

- [x] **P4-05 Preserve provider stdout and stderr.**
  Do not merge, parse, buffer to completion, strip ANSI, or move provider
  diagnostics between streams during a normal run.

- [x] **P4-06 Preserve provider status exactly.**
  Test `0`, common non-zero values, provider-defined values above `64`, and
  signal-derived statuses without wrapper remapping.

- [x] **P4-07 Propagate interruption and termination.**
  Verify Ctrl-C/interrupt reaches the child, no orphan remains, and Bash uses
  conventional signal status where CI supports the assertion.

- [x] **P4-08 Guarantee at-most-one run launch.**
  Once a launch begins, any authentication, rate-limit, tool, or generic
  failure returns directly; no other provider receives the prompt.

- [x] **P4-09 Keep wrapper notices on stderr.**
  Selection and environment notices must never contaminate provider stdout;
  `--quiet` suppresses wrapper notices only.

- [x] **P4-10 Add a redacted dry-run renderer.**
  Render executable and argv in a platform-appropriate escaped form without
  starting the provider or displaying environment values or piped context.

### Phase 4 exit gate

- [x] A generic fake provider proves cwd, stdin, stream separation, hostile
  argv safety, exact status, signal behavior, dry-run non-launch, and no
  failover in both runners.

  Evidence: [PR #4](https://github.com/AnandChowdhary/aagent/pull/4) and
  [cross-platform CI run 30950678475](https://github.com/AnandChowdhary/aagent/actions/runs/30950678475).

## Phase 5 - Tier 1 invocation adapters

Dependencies: Phase 4
Deliverable: correct one-shot execution for all five MVP providers

- [x] **P5-01 Implement Claude command construction.**
  Build `claude --print PROMPT`, place `--model ID` and native arguments where
  Claude accepts them, support stdin modes, and never add `--bare` or a
  permission bypass.

- [x] **P5-02 Implement Codex command construction.**
  Build `codex exec PROMPT`, use `-` for stdin-only mode, preserve separate
  instruction plus stdin context, forward `--model ID`, and never add a sandbox
  escalation or `--skip-git-repo-check`.

- [x] **P5-03 Implement OpenCode command construction.**
  Build `opencode run PROMPT`, forward `--model PROVIDER/MODEL`, use the
  documented or specified fallback for prompt-plus-stdin, and never add
  `--auto`.

- [x] **P5-04 Implement Amp command construction.**
  Build `amp --execute PROMPT`, support its documented stdin combinations, and
  reject wrapper `--model` with status `64` before launch rather than mapping it
  to `--fast` or ignoring it.

- [x] **P5-05 Implement Gemini command construction.**
  Build `gemini --prompt PROMPT`, append piped context through documented stdin
  behavior, forward `--model ID`, and never add `--yolo` or change approval
  mode.

- [x] **P5-06 Place native options per adapter.**
  Test at least two native arguments and a leading-dash value for each provider
  so `--` content is neither re-parsed nor reordered incorrectly.

- [x] **P5-07 Cover every adapter input matrix.**
  For each provider test positional prompt, stdin-only, prompt-plus-stdin,
  multiline input, empty input rejection, model support, and native options.

- [x] **P5-08 Cover every adapter process matrix.**
  For each provider test stdout, stderr, success, non-zero status, cwd, quiet
  notice behavior, dry-run, and one-run-only guarantees.

- [x] **P5-09 Surface provider safety notes.**
  Store the documented permission/side-effect distinction for later doctor
  output without attempting to normalize it.

### Phase 5 exit gate

- [x] Fake-executable snapshots for all five Tier 1 providers pass on Bash and
  PowerShell and satisfy acceptance criterion 1 without real credentials.

  Evidence: [PR #5](https://github.com/AnandChowdhary/aagent/pull/5) and
  [cross-platform CI run 30952123338](https://github.com/AnandChowdhary/aagent/actions/runs/30952123338).

## Phase 6 - User configuration and precedence

Dependencies: Phases 2 and 3
Deliverable: strict, non-executable user configuration with stable precedence

- [x] **P6-01 Resolve the Unix configuration path.**
  Use `${XDG_CONFIG_HOME:-$HOME/.config}/aagent/config` without reading a
  project-local file.

- [x] **P6-02 Resolve the Windows configuration path.**
  Use `%APPDATA%\aagent\config` and define deterministic behavior when
  `APPDATA` is absent.

- [x] **P6-03 Implement a strict `key=value` parser.**
  Trim surrounding whitespace, ignore blank lines and documented comment
  syntax only, reject malformed lines, and never source or evaluate content.

- [x] **P6-04 Validate the key allowlist.**
  Accept only `provider`, `auth_policy`, `priority`, and `allow_local`; normal
  invocation warns on unknown keys while doctor treats them as configuration
  errors.

- [x] **P6-05 Validate configuration values.**
  Check provider IDs, auth policy enum, comma-separated priority IDs without
  duplicates, and strict boolean values; invalid known values exit `78`.

- [x] **P6-06 Apply value precedence.**
  Enforce command line over environment over user config over defaults for
  provider, auth policy, priority, and allow-local.

- [x] **P6-07 Distinguish explicit provider sources.**
  Preserve whether the choice came from CLI, `AAGENT_PROVIDER`, or config so
  diagnostics explain it and a missing explicit provider never falls through.

- [x] **P6-08 Make priority cost-safe.**
  Parse `AAGENT_PRIORITY` and config priority as a tie-break order only; prove
  neither can cross readiness, funding, or confidence boundaries.

- [x] **P6-09 Add configuration injection tests.**
  Include command substitutions, PowerShell expressions, quotes, separators,
  newlines, duplicate keys, very long values, CRLF, and paths with spaces; no
  marker command may execute.

- [x] **P6-10 Keep configuration diagnostics nonsecret.**
  Report file and line plus key name where safe, but do not echo arbitrary
  values that may contain secrets.

### Phase 6 exit gate

- [x] Precedence and invalid-config tables pass identically in both runners,
  with zero provider launches for all configuration failures.

  Evidence: [PR #6](https://github.com/AnandChowdhary/aagent/pull/6) and
  [cross-platform CI run 30953801910](https://github.com/AnandChowdhary/aagent/actions/runs/30953801910).

## Phase 7 - Passive authentication probes and funding classification

Dependencies: Phases 3 and 6
Deliverable: safe `readiness`, `funding_class`, confidence, and reason records

- [x] **P7-01 Define the probe result schema.**
  Include provider ID, readiness, funding class, confidence rank, safe plan
  label, decisive reason code, shadowing variable names, source, and probe
  status; exclude tokens, email, organization, and raw output.

- [x] **P7-02 Implement the probe supervisor.**
  Run without TTY, impose a short documented timeout, capture bounded output,
  discard raw responses after allowlist parsing, and degrade all operational or
  schema failures to `unknown`.

- [x] **P7-03 Enforce the no-network default.**
  Use only documented local/passive interfaces during automatic selection;
  any adapter status command known to require a network call must be explicit
  doctor-only or remain `unknown`.

- [x] **P7-04 Implement Claude status parsing.**
  Call `claude auth status --json`; allowlist only `loggedIn`, `authMethod`,
  `subscriptionType`, `apiProvider`, and `apiKeySource`; tolerate absent or
  changed fields.

- [x] **P7-05 Classify Claude funding paths.**
  Treat confirmed `claude.ai` subscription access as `included_confirmed`;
  direct API, Console, helper, bearer, gateway, Bedrock, Vertex, and Foundry
  paths are metered or `unknown` according to evidence.

- [x] **P7-06 Implement Codex app-server account probing.**
  Start `codex app-server`, complete its required initialization, call
  `account/read` with `refreshToken:false`, bound the protocol exchange, and
  terminate the probe process cleanly.

- [x] **P7-07 Implement the Codex fallback probe.**
  On unavailable or incompatible app-server protocol, use `codex login status`
  only for readiness; lower confidence and avoid inventing a plan type.

- [x] **P7-08 Classify Codex funding paths.**
  Treat `account.type=chatgpt` as included with an allowlisted safe `planType`;
  `apiKey` as `payg_byok`; custom providers with
  `requiresOpenaiAuth=false` as `unknown` unless separately documented.

- [x] **P7-09 Implement OpenCode auth evidence.**
  Parse `opencode auth list` plus only documented nonsecret selected
  provider/model configuration; OAuth alone must not establish included
  funding.

- [x] **P7-10 Implement Gemini auth evidence.**
  Read only documented `security.auth.selectedType`; classify `oauth-personal`
  as `included_account`, API key as metered, and Vertex/ADC as organization
  funded or `unknown` without guessing the Google plan tier.

- [x] **P7-11 Implement Amp conservative evidence.**
  Detect installed/account readiness through stable passive surfaces if
  available; treat `AMP_API_KEY` as an account credential and leave funding
  `unknown` unless a documented passive balance or plan signal exists.

- [x] **P7-12 Implement environment presence evidence.**
  Check only whether documented variable names exist; never read, transform,
  fingerprint, compare, or log their values.

- [x] **P7-13 Enforce confidence ceilings.**
  Machine-readable status may confirm a plan; redacted text/config and
  implementation-detail evidence have lower ranks; variable or file existence
  alone cannot yield `included_confirmed`.

- [x] **P7-14 Enforce the credential-store boundary.**
  Add tests with trap files and fake keychain helpers proving the wrapper never
  opens token files, credential stores, `auth.json`, or `apiKeyHelper`.

- [x] **P7-15 Redact probe output.**
  Seed fake responses with tokens, emails, organization names, unknown nested
  fields, and huge strings; none may appear in stdout, stderr, cache, or test
  snapshots.

- [x] **P7-16 Test every degradation path.**
  Timeout, executable crash, malformed JSON/text, missing fields, unexpected
  types, protocol mismatch, truncated output, and unsupported versions all
  produce usable `unknown` records without aborting selection.

### Phase 7 exit gate

- [x] The full Tier 1 probe matrix classifies safe fixtures correctly, makes no
  model request, accesses no credential material, leaks no seeded PII, and
  never turns probe failure into wrapper failure.

  Evidence: [PR #7](https://github.com/AnandChowdhary/aagent/pull/7) and
  [cross-platform CI run 30956519072](https://github.com/AnandChowdhary/aagent/actions/runs/30956519072).

## Phase 8 - Deterministic cost-aware selector

Dependencies: Phases 6 and 7
Deliverable: the exact lexicographic selection formula and explainable result

- [x] **P8-01 Encode ordered readiness ranks.**
  `ready` outranks `unknown`; `unusable` is excluded from automatic selection
  but retained for diagnostics.

- [x] **P8-02 Encode ordered funding ranks.**
  Implement `included_confirmed`, `included_account`, `prepaid_credits`, opt-in
  `local`, `payg_byok`, and `unknown` in the documented order.

- [x] **P8-03 Gate local providers.**
  Exclude the `local` class unless effective `allow_local=true`; do not equate
  local execution with zero machine cost or acceptable quality.

- [x] **P8-04 Encode authentication confidence ranks.**
  Make confidence a tie-breaker only after readiness and funding, preserving
  the ceiling rules from Phase 7.

- [x] **P8-05 Apply configured priority.**
  Rank listed providers in user order within equal earlier fields; assign a
  deterministic position to unlisted providers.

- [x] **P8-06 Apply the frozen popularity prior.**
  Use the build-time order only after cost, readiness, confidence, and user
  priority; never query current metrics during a run.

- [x] **P8-07 Apply stable registry order.**
  Guarantee a deterministic final tie-break even when all prior fields are
  equal or unavailable.

- [x] **P8-08 Implement explicit-provider authority.**
  CLI, environment, and config explicit choices bypass automatic ranking; a
  known but missing choice exits `69`, an unknown ID exits `64`, and neither
  falls through.

- [x] **P8-09 Explain the decisive field.**
  Produce a nonsecret reason code and display string identifying the first
  tuple field that distinguished the winner.

- [x] **P8-10 Emit the selection notice.**
  Write provider, funding class, safe plan label if available, and decisive
  reason to stderr; `--quiet` suppresses only this wrapper-owned notice.

- [x] **P8-11 Handle an empty candidate set.**
  When no installed usable/unknown adapter exists, exit `69` with install or
  explicit-provider guidance and no model launch.

- [x] **P8-12 Test the two primary cost-saving scenarios.**
  Claude subscription plus API-only Codex selects Claude; ChatGPT included
  Codex plus API-only Claude selects Codex, independent of popularity.

- [x] **P8-13 Test included-plan ties.**
  Two included plans resolve by confidence, configured priority, popularity,
  then registry order; unknown remaining quota is neutral.

- [x] **P8-14 Test deliberate metered fallback.**
  With no included, prepaid, or allowed local path, choose the best ready direct
  API candidate and clearly label it `payg_byok`.

- [x] **P8-15 Test unusable and unknown candidates.**
  Known-unusable candidates are skipped; an unknown candidate remains eligible
  as a last resort; probe failure cannot silently become `ready`.

- [x] **P8-16 Prove no history or quota tie-break exists in MVP.**
  Repeated runs with identical inputs must select identically regardless of
  previous success, wall-clock time, or any cached provider usage file.

### Phase 8 exit gate

- [x] A table-driven cross-runner suite covers every tuple field and all
  required outcomes; acceptance criteria 2, 3, and 5 pass exactly.

  Evidence: [PR #8](https://github.com/AnandChowdhary/aagent/pull/8) and
  [cross-platform CI run 30958377635](https://github.com/AnandChowdhary/aagent/actions/runs/30958377635).

## Phase 9 - Child authentication environment policy

Dependencies: Phases 7 and 8
Deliverable: narrowly scoped cost-saving overrides without parent mutation

- [x] **P9-01 Build a child-environment plan.**
  Represent set/omit actions by allowlisted variable name; never mutate the
  wrapper process environment during classification or the caller environment
  after exit.

- [x] **P9-02 Implement Claude subscription shadow handling.**
  Under `prefer-included`, omit `ANTHROPIC_API_KEY` from the Claude child only
  when Claude.ai subscription access is confirmed and no other custom routing
  signal makes the active path ambiguous.

- [x] **P9-03 Protect Claude custom routes.**
  Do not strip base URLs, bearer tokens, credential helpers, Bedrock, Vertex,
  Foundry, gateway, or organization-routing configuration; classify the path
  as documented or `unknown`.

- [x] **P9-04 Implement Codex subscription shadow handling.**
  Under `prefer-included`, omit `CODEX_API_KEY` from the Codex child only when
  ChatGPT account auth is confirmed.

- [x] **P9-05 Implement Codex metered fallback mapping.**
  When Codex is deliberately selected as `payg_byok`, `CODEX_API_KEY` is absent,
  and `OPENAI_API_KEY` is present, map it to child `CODEX_API_KEY` and identify
  that wrapper behavior by variable names only.

- [x] **P9-06 Implement native auth policy.**
  `--auth-policy native` and its environment/config equivalents disable every
  child set/omit adjustment and classify the path the untouched provider would
  use.

- [x] **P9-07 Emit safe adjustment notices.**
  Report only the selected provider, action, and variable name on stderr;
  respect `--quiet` and never display a before/after value.

- [x] **P9-08 Keep dry-run values redacted.**
  Show that a variable would be set or omitted without rendering its value,
  length, prefix, hash, source-file content, or token fingerprint.

- [x] **P9-09 Prove parent immutability.**
  Tests must inspect the wrapper's parent test process after success, provider
  failure, probe failure, dry-run, and interruption.

- [x] **P9-10 Cover ambiguous shadowing.**
  Multiple auth signals, custom provider configuration, helper configuration,
  or incomplete probe evidence must preserve the native environment and produce
  `unknown` rather than an unsafe guess.

### Phase 9 exit gate

- [x] Child fixtures observe exactly the allowed set/omit behavior for Claude
  and Codex, all native-policy cases are untouched, parent values survive, and
  no output contains a seeded credential value.

  Evidence: [PR #9](https://github.com/AnandChowdhary/aagent/pull/9) and
  [cross-platform CI run 30961449062](https://github.com/AnandChowdhary/aagent/actions/runs/30961449062).

## Phase 10 - Introspection and security hardening

Dependencies: Phases 3 through 9
Deliverable: safe visibility into discovery, classification, and launch plans

- [x] **P10-01 Implement `aagent providers`.**
  List every known adapter in stable order with status, funding, selected flag,
  and nonsecret reason; return `0` even when all providers are missing.

- [x] **P10-02 Implement `aagent doctor`.**
  Report wrapper/platform data, paths, versions where safely available,
  configuration findings, selection explanation, auth confidence, capabilities,
  safety notes, and shadowing variable names without launching a model.

- [x] **P10-03 Implement provider-scoped doctor.**
  A known provider argument limits diagnostics; a known missing provider is a
  diagnostic result, while an unknown ID is a `64` usage error.

- [x] **P10-04 Complete dry-run parity.**
  Resolve the same config, probes, selection, child environment, cwd, stdin
  mode, and adapter argv as a real run while proving the provider run command
  never starts.

- [x] **P10-05 Bound all diagnostic subprocesses.**
  Version and passive status checks need timeouts, output limits, noninteractive
  input, cleanup, and `unknown` fallback.

- [x] **P10-06 Redact paths and account data appropriately.**
  Default output may show resolved executable paths but not home-relative
  credential paths, email, organization, raw endpoint credentials, tokens, or
  probe payloads.

- [x] **P10-07 Audit permission escalation.**
  Search every generated argv for a maintained denylist of known unsafe flags;
  tests prove such flags appear only when the user supplied them after `--`.

- [x] **P10-08 Audit evaluation primitives.**
  Add a source-level test or lint assertion preventing `eval`, configuration
  sourcing, `sh -c` with user data, PowerShell `Invoke-Expression`, and
  equivalent command-string evaluation.

- [x] **P10-09 Audit credential access.**
  Tests use unreadable/trap credential locations and fake helper commands to
  prove the wrapper relies exclusively on provider status processes and
  allowlisted nonsecret config fields.

- [x] **P10-10 Audit no-model-probe behavior.**
  Fake providers distinguish status and run subcommands; providers, doctor,
  automatic selection, help, version, and dry-run must record zero prompt/run
  calls.

- [x] **P10-11 Fuzz user-controlled boundaries.**
  Feed prompt, model, cwd, provider ID, override path, config, native argv, and
  probe fields with shell metacharacters, Unicode, invalid encodings where
  representable, long values, and line breaks.

- [x] **P10-12 Verify error taxonomy.**
  Table-test every wrapper-owned `64`, `69`, `70`, and `78` path, confirming
  stable stderr prefixes and no collision with a launched provider's identical
  numeric status.

### Phase 10 exit gate

- [x] Providers, doctor, and dry-run meet the introspection contract; security
  tests prove no evaluation, permission injection, credential access, paid
  probe, PII leak, parent mutation, or automatic failover.

  Evidence: [PR #10](https://github.com/AnandChowdhary/aagent/pull/10) and
  [cross-platform CI run 30963936536](https://github.com/AnandChowdhary/aagent/actions/runs/30963936536).

## Phase 11 - Installation, platform parity, and MVP release

Dependencies: Phases 1 through 10
Deliverable: installable, documented MVP with passing cross-platform CI

- [x] **P11-01 Preserve direct executability.**
  `aagent.sh` has the correct shebang and executable bit; `aagent.ps1` runs with
  `pwsh -File`; both work from paths containing spaces.

- [x] **P11-02 Update the Bash installer.**
  Install the current runner atomically to the documented destination, preserve
  executable permissions, handle an existing install, and verify installed
  help/version without invoking a provider.

- [x] **P11-03 Update the PowerShell installer.**
  Install the current script and launcher behavior to the documented Windows
  destination, handle an existing install, and verify installed help/version.

- [x] **P11-04 Test local and remote install paths.**
  Cover repository-local source overrides in CI and a checksum/release-asset
  strategy before advertising a pipe-to-shell remote installer.

- [x] **P11-05 Complete the CI platform matrix.**
  Run Bash tests on `ubuntu-latest`, `macos-latest`, and Windows Git Bash; run
  PowerShell tests on Windows; keep fail-fast disabled so parity failures are
  visible together.

- [x] **P11-06 Add platform-specific signal tests.**
  Run where supported and explicitly document any Windows limitation rather
  than weakening the general status/cleanup contract.

  Evidence for P11-01 through P11-06: [PR #11](https://github.com/AnandChowdhary/aagent/pull/11)
  and [cross-platform CI run 30965728505](https://github.com/AnandChowdhary/aagent/actions/runs/30965728505).

- [x] **P11-07 Add scheduled compatibility checks.**
  In a non-secret workflow, install or inspect current Tier 1 CLI help/version
  output and flag command drift without authenticating or running a prompt.

  Evidence: `scripts/check-provider-compatibility.sh`,
  `tests/test_compatibility.sh`, and `.github/workflows/compatibility.yml`.

- [ ] **P11-08 Rewrite README for the functional MVP.**
  Document installation, examples, supported providers, selection/cost policy,
  explicit provider choice, native args, auth policy, config, diagnostics,
  safety boundary, platform support, and known provider-specific side effects.

- [ ] **P11-09 Synchronize help, README, and specification.**
  Add a test for stable option/subcommand coverage and ensure examples are valid
  in both Bash-oriented and PowerShell-oriented contexts.

- [ ] **P11-10 Run the full local release gate.**
  Execute syntax checks, Bash tests, PowerShell tests when available, Markdown
  link checks, `git diff --check`, and a clean-room install smoke test.

- [ ] **P11-11 Run the full GitHub Actions gate.**
  Require every matrix job at the exact release commit; rerun only to diagnose
  infrastructure flakiness, never to mask deterministic failures.

- [ ] **P11-12 Audit all MVP acceptance criteria.**
  Record evidence for each item in `docs/spec/testing.md`, including exact test
  name or workflow job, and leave no criterion inferred from another.

- [ ] **P11-13 Cut the first functional release.**
  Tag a reviewed commit, publish checksummed artifacts/install instructions,
  verify the remote artifact on macOS, Linux, and Windows, and publish known
  limitations without claiming live-provider testing that did not occur.

### Phase 11 exit gate - MVP complete

- [ ] Every task in Phases 1 through 11 is checked, every acceptance criterion
  has direct evidence, all required CI jobs pass at the release commit, and a
  clean machine can install and run `aagent --help`, `aagent providers`, and a
  fake or explicitly authorized real Tier 1 provider invocation.

## Phase 12 - Tier 2 adapters

Dependencies: MVP complete; current first-party interface revalidation for each
provider
Deliverable: separately releasable adapter batches using the same contract

### Phase 12A - Account-backed and name-collision adapters

- [ ] **P12A-01 Revalidate GitHub Copilot CLI.**
  Confirm current one-shot syntax, model behavior, auth/status evidence, BYOK
  overrides, permission flags, and exit behavior; update sources before code.

- [ ] **P12A-02 Implement `copilot`.**
  Add invocation, input, model, discovery, conservative funding classification,
  safety note, complete fake-adapter matrix, and cross-runner parity.

- [ ] **P12A-03 Revalidate Cursor CLI.**
  Confirm the `agent` executable, `--print`, model/native options,
  `status --format json`, plan visibility, and proposed-change default.

- [ ] **P12A-04 Implement `cursor`.**
  Prevent `agent`/`aagent` recursion, allowlist authentication booleans and
  endpoint class only, classify plan as no stronger than evidence permits, and
  add complete tests.

- [ ] **P12A-05 Revalidate and implement Factory Droid.**
  Confirm `droid exec`, spec-mode default, autonomy flags, structured output,
  account/BYOK evidence, then add adapter, safety warning, and complete tests.

### Phase 12B - Provider-routing adapters

- [ ] **P12B-01 Revalidate and implement Goose.**
  Support `goose run --text`, selected-provider funding inheritance, local
  opt-in classification, and prohibit `goose info --check` during selection.

- [ ] **P12B-02 Revalidate and implement Qwen Code.**
  Distinguish the Coding Plan endpoint from generic API keys, preserve approval
  modes and budgets as native options, and add complete tests.

- [ ] **P12B-03 Revalidate and implement Kimi Code.**
  Distinguish managed membership evidence from generic provider routing,
  preserve print-mode permission behavior, and add complete tests.

- [ ] **P12B-04 Revalidate and implement Cline.**
  Handle `openai-codex` subscription funding separately from Cline credits and
  BYOK, expose headless auto-approval warning, and add complete tests.

### Phase 12C - Side-effect-sensitive adapters

- [ ] **P12C-01 Revalidate and implement Crush.**
  Support `crush run`, keep native permission prompts, never use `login` as a
  status probe, classify selected providers conservatively, and add tests.

- [ ] **P12C-02 Revalidate and implement Mistral Vibe.**
  Support text/structured modes without normalizing them, preserve budgets and
  tool settings as native controls, classify account/profile evidence safely,
  and add tests.

- [ ] **P12C-03 Revalidate and implement Kiro CLI.**
  Support `kiro-cli chat --no-interactive`, document API-key and trust-tool
  requirements, avoid implicit trust flags, and add tests.

- [ ] **P12C-04 Revalidate and implement Aider.**
  Support `aider --message`, prominently report automatic Git commits, classify
  local/Copilot/direct-model paths separately, never change commit defaults,
  and add tests.

### Phase 12 exit gate

- [ ] Each shipped Tier 2 adapter has fresh first-party evidence, the full
  adapter/probe/selection/security matrix, Bash/PowerShell parity, README and
  doctor coverage, and an independent release note.

## Phase 13 - Opt-in quota-aware routing

Dependencies: MVP complete; comparable passive evidence for at least Claude and
Codex; specification review
Deliverable: conservative allowance tie-breaking among otherwise equal included
plans

- [ ] **P13-01 Revalidate quota interfaces and privacy terms.**
  Confirm current Codex rate-limit API and Claude emitted status-line fields;
  record whether collection is documented, zero-cost, and safe to retain.

- [ ] **P13-02 Specify the opt-in surface.**
  Add an explicit configuration/CLI mode, default it off, define consent and
  cache-clearing behavior, and keep static selection unchanged when absent.

- [ ] **P13-03 Define the cache schema.**
  Store only provider ID, normalized percentages, window duration/reset,
  source, and observation time with restrictive permissions; never raw output
  or credentials.

- [ ] **P13-04 Implement Codex rate-limit collection.**
  Use `account/rateLimits/read`, parse primary/secondary/named buckets, retain
  the most constrained active window, and degrade failures to unknown.

- [ ] **P13-05 Implement post-run Claude collection.**
  Ingest documented provider-emitted rate-limit fields only after an actual user
  run; never send a synthetic prompt solely to populate quota data.

- [ ] **P13-06 Implement freshness and TTL.**
  Expired or schema-incompatible observations become unknown; time skew and
  missing reset timestamps cannot make a provider appear exhausted.

- [ ] **P13-07 Define comparability rules.**
  Compare headroom only between included candidates with sufficiently fresh,
  compatible evidence; do not equate different windows, credits, or token
  accounting without an explicit mapping.

- [ ] **P13-08 Insert the quota tie-break.**
  Place `remaining_allowance` after authentication confidence and before user
  priority; known exhaustion may demote, while unknown remains neutral.

- [ ] **P13-09 Add failure and privacy tests.**
  Cover stale data, no cache, malformed values, multiple windows, reset races,
  partial providers, cache permissions, seeded secrets, and zero model probes.

- [ ] **P13-10 Run an opt-in compatibility release.**
  Verify static default behavior is byte-for-byte unaffected and document that
  allowance percentages are provider-specific estimates, not comparable money.

### Phase 13 exit gate

- [ ] Opt-in quota-aware selection passes comparability, freshness, privacy,
  and fallback tests; disabling it produces the exact static selector from
  Phase 8.

## Phase 14 - Structured output and sessions

Dependencies: MVP complete; separate approved schema specification
Deliverable: versioned optional APIs without changing default text passthrough

- [ ] **P14-01 Freeze normalized result schema version 1.**
  Define provider, status, text, session ID, usage, error, and native fields;
  missing data is `null`, never inferred.

- [ ] **P14-02 Decide parser/runtime strategy.**
  Prove whether portable Bash and PowerShell can safely parse each Tier 1 native
  format; if an external runtime is needed, keep it optional and fail clearly.

- [ ] **P14-03 Implement per-provider final-result parsers.**
  Use version-tolerant allowlists, preserve unrecognized fields only under
  `native`, and test malformed/truncated/mixed stdout behavior.

- [ ] **P14-04 Define conservative streaming events.**
  Normalize only `run.started`, `assistant.delta`, `tool.started`,
  `tool.completed`, `run.completed`, and `run.failed`; version every event.

- [ ] **P14-05 Implement structured capability negotiation.**
  Providers lacking a safe native format must fail the structured request or
  use an explicitly selected text fallback; never silently fabricate events.

- [ ] **P14-06 Specify portable session handles.**
  Treat provider-native session IDs as opaque, record provider ownership, and
  reject resume through a different adapter.

- [ ] **P14-07 Implement provider-specific resume plans.**
  Add only documented resume forms with fake fixtures; do not assume continue,
  resume, fork, and last-session semantics are equivalent.

- [ ] **P14-08 Preserve default text behavior.**
  With no structured/session option, stdout, stderr, and exit status must remain
  identical to the MVP contract.

- [ ] **P14-09 Add schema compatibility tests.**
  Snapshot versioned results/events, null behavior, provider-native extensions,
  errors, cancellation, sessions, and backwards compatibility.

### Phase 14 exit gate

- [ ] Structured and session modes are explicitly requested, versioned,
  adapter-capability-aware, tested for schema drift, and leave default text
  passthrough unchanged.

## Phase 15 - Ongoing compatibility and release maintenance

Dependencies: first functional release
Deliverable: repeatable updates without hidden runtime behavior changes

- [ ] **P15-01 Review scheduled drift reports.**
  For changed help/status surfaces, confirm first-party documentation and update
  adapter evidence, fixtures, and compatibility notes before code.

- [ ] **P15-02 Refresh popularity intentionally.**
  At a documented release cadence, collect comparable first-party package and
  repository metrics, store the dated snapshot, explain order changes, and
  never fetch it at runtime.

- [ ] **P15-03 Maintain a provider compatibility table.**
  Record last-tested CLI version, platform, invocation, auth probe confidence,
  structured/session capability, and known safety caveats without publishing
  account data.

- [ ] **P15-04 Keep live tests opt-in.**
  Run real prompts only with explicit credentials, budget, and authorization;
  exclude them from pull-request CI and sanitize all artifacts.

- [ ] **P15-05 Preserve release evidence.**
  For each release retain exact commit, CI run, artifact checksums, install smoke
  platforms, specification changes, completed task IDs, and known limitations.

## MVP acceptance traceability

| Acceptance criterion | Owning tasks and gates |
| --- | --- |
| 1. Tier 1 one-shot adapters on every runner | P1-03 through P1-08, P4-01 through P4-09, P5-01 through P5-09, Phase 5 gate, P11-05 |
| 2. Explicit and automatic formula | P6-06 through P6-08, P8-01 through P8-09, Phase 8 gate |
| 3. Included plan outranks metered API | P7-05, P7-08, P8-02, P8-12 through P8-14 |
| 4. Passive probes fail safely | P7-01 through P7-16, Phase 7 gate |
| 5. Visible nonsecret selection reason | P8-09, P8-10, P10-01, P10-02 |
| 6. Process fidelity | P2-05 through P2-09, P4-01 through P4-09, P5-07, P5-08 |
| 7. No implicit permission escalation | P5-01 through P5-05, P10-07, Phase 10 gate |
| 8. Stable wrapper errors | P1-01, P2-04, P2-08, P3-08, P5-04, P6-05, P8-08, P8-11, P10-12 |
| 9. Safe providers and doctor commands | P7-14 through P7-16, P10-01 through P10-10 |
| 10. Cursor `agent` is not `aagent` | P3-03, P3-07, P10-01 |
| 11. Help, installation, and platform behavior | P2-10, P11-01 through P11-11 |
| 12. Ledger phases and gates complete | Every task and exit gate in Phases 0 through 11 |

## Final MVP sign-off checklist

This is the last checklist used before declaring the MVP complete. It does not
replace the granular tasks above.

- [ ] Phases 0 through 11 have no unchecked or blocked task.

- [ ] Every row in the traceability table links to passing named tests or CI
  jobs at the release commit.

- [ ] `SPEC.md`, all `docs/spec/` contracts, help output, README, installers,
  and implementation agree.

- [ ] No normal or diagnostic code path reads credential material, triggers
  login, sends a probe prompt, escalates permissions, or retries another agent
  after launch.

- [ ] The release artifact is installed and smoke-tested on macOS, Linux,
  Windows Git Bash, and Windows PowerShell.

- [ ] The selected provider and cost rationale are explainable, deterministic,
  nonsecret, and identical across runners for the same discovered state.

- [ ] Deferred work remains deferred: Tier 2 completeness, live quota-aware
  routing, normalized structured output, and portable sessions are not required
  or implied by the MVP release.
