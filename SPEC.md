# aagent specification

Status: MVP released
Research snapshot: 2026-08-04
Implementation status: Functional MVP released as
[v0.1.1](https://github.com/AnandChowdhary/aagent/releases/tag/v0.1.1)

## Summary

`aagent` is a small, cross-platform command-line wrapper that runs an installed
coding-agent CLI in non-interactive mode.

```console
$ aagent "say hello"
Hello!
```

The user may have Claude Code, Codex CLI, OpenCode, Amp, Gemini CLI, or another
supported coding agent installed. `aagent` discovers compatible executables,
classifies their usable authentication paths without reading secrets, chooses
one deterministically, passes it the prompt, and preserves its output and exit
status.

`aagent` is a compatibility layer, not a new agent runtime. Authentication,
models, tools, repository instructions, billing, and provider configuration
remain owned by the selected agent.

## Goals

The first functional release must:

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

## Non-goals for the MVP

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

## Normative documents

The specification is split by responsibility:

| Document | Defines |
| --- | --- |
| [Research conclusions](docs/spec/research.md) | Evidence-based product boundary and interoperability conclusions |
| [CLI contract](docs/spec/cli-contract.md) | Syntax, input, configuration, process, output, status, and signal behavior |
| [Selection and authentication](docs/spec/selection.md) | Explicit precedence, passive probes, cost-aware ranking, and child auth environment |
| [Passive probe contract](docs/spec/probes.md) | Redacted schema, supervisor limits, evidence confidence, and supported-provider classifications |
| [Adapter registry](docs/spec/adapters.md) | Adapter contract, runnable inventory, planned Tier 2 adapters, and exclusions |
| [Permissions, privacy, and safety](docs/spec/security.md) | Permission boundary, secret handling, injection resistance, and future safety policy |
| [Introspection](docs/spec/introspection.md) | `providers`, `doctor`, and `--dry-run` behavior |
| [Testing and acceptance](docs/spec/testing.md) | Required fixtures, platform matrix, and MVP completion gate |
| [MVP acceptance evidence](docs/acceptance-evidence.md) | Exact release commit, CI jobs, checksums, and criterion-by-criterion sign-off |
| [Post-MVP backlog](docs/spec/backlog.md) | Quota-aware routing, structured output, sessions, and other deferred features |
| [Primary sources](docs/spec/sources.md) | First-party research references and popularity snapshot inputs |

All documents marked normative use **must** and **must not** for requirements,
**should** for a preferred behavior that may have a documented platform reason
to differ, and **may** for an optional behavior.

## System boundary

```text
user input + config
        |
        v
parse -> discover -> passive auth/funding probes -> deterministic selection
        |                                         |
        +-----------------------------------------+
                                                  v
                                  adapter argv + child-only environment
                                                  |
                                                  v
                                    installed provider process
                                                  |
                                                  v
                               native stdout/stderr/status/signals
```

The wrapper never places a model request inside discovery or selection. Once a
provider process begins, it owns the run and there is no automatic failover.

## Invariants

These rules cut across every document and phase:

1. User input is passed in argument arrays and is never evaluated as code.
2. Stored credential material is never read; official provider processes are
   the authority for cached authentication state.
3. Included plans outrank direct metered APIs during automatic selection.
4. Unknown funding or quota is represented as unknown, never guessed free,
   exhausted, or unlimited.
5. Authentication environment changes are child-only, narrowly allowlisted,
   and disclosed by variable name without values.
6. The wrapper never adds a permission-escalation flag.
7. Provider output and status stay provider-native in the MVP.
8. Runtime selection does not depend on a network popularity lookup or
   telemetry.
9. Bash and PowerShell implementations must satisfy equivalent observable
   behavior.
10. A scope or behavior change updates the relevant normative document and its
    tests before implementation is considered complete.

## Document precedence and change control

The normative contract in this file and `docs/spec/` takes precedence over the
execution ordering in `TODO.md`. `TODO.md` may decompose a requirement but may
not weaken or silently change it. If implementation reveals a conflict,
ambiguity, unsafe assumption, or provider-interface drift:

1. stop the affected implementation task;
2. update the relevant specification and source evidence;
3. update affected task IDs and tests in `TODO.md`; and
4. resume implementation only after the documentation change is reviewed.

Popularity snapshots and provider commands are versioned research inputs. They
change only through a normal reviewed repository change, never dynamically at
runtime.

## Implementation source of truth

[TODO.md](TODO.md) is the authoritative, ordered implementation ledger. It
defines granular task IDs, dependencies, deliverables, verification commands,
and exit gates for every phase. Implementation work starts there and a phase is
complete only when all of its checkboxes and its exit gate are satisfied.
