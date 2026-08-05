# Cursor CLI revalidation

Status: Normative implementation input for P12A-04
Research snapshot: 2026-08-05

This revalidation freezes the current public interface that the `cursor`
adapter may use. It supersedes the provisional Cursor row from the initial
2026-08-04 survey without changing runtime code by itself.

## Evidence and method

Only first-party Cursor sources were used:

- [CLI overview](https://docs.cursor.com/en/cli/overview);
- [installation](https://docs.cursor.com/en/cli/installation);
- [headless mode](https://docs.cursor.com/en/cli/headless);
- [parameter reference](https://docs.cursor.com/en/cli/reference/parameters);
- [output formats](https://docs.cursor.com/en/cli/reference/output-format);
- [authentication](https://docs.cursor.com/en/cli/reference/authentication);
- [permissions](https://docs.cursor.com/en/cli/reference/permissions); and
- the live [official installer](https://cursor.com/install).

The official installer identified build `2026.07.23-e383d2b` and its
`darwin/arm64` package URL. The package was downloaded to a temporary directory
over HTTPS and produced this SHA-256 digest:

```text
f2eb25851f2079dcdf0558a816e06c402d187abfca93255d35167020439ebbf2
```

Cursor does not publish a digest in the installer, so this is a reproducibility
record rather than independent checksum verification. The extracted binary
reported `2026.07.23-e383d2b`. It was invoked only for version, help,
authentication-status, about-status, and parser-error surfaces. The local
installed build `2026.07.01-41b2de7` was checked in the same read-only way. No
login, logout, update, model prompt, tool call, or paid request was performed.

Status responses were reduced immediately to key names, value types, and the
three authentication booleans. Account strings were never printed or retained.
Inspection of the downloaded first-party package confirmed that successful
status responses may also contain `userInfo` such as an email, user ID, name,
team ID, and creation time. Those fields are outside the adapter allowlist.

## Executable and platform contract

The current installer creates both `~/.local/bin/agent` and
`~/.local/bin/cursor-agent` symlinks to the same `cursor-agent` package entry
point. Its own comments and completion text call `agent` the primary executable
and `cursor-agent` the legacy alias. The current documentation still shows
`cursor-agent`, so the adapter must discover both names in this order:

1. an explicit `AAGENT_CURSOR_BIN` override;
2. `agent`; and
3. `cursor-agent`.

The resolved executable must report Cursor's version/help signature and must
not resolve to the running `aagent` launcher. Name matching alone is not enough.
This validation is required even for an explicit override, because users may
install or symlink the wrapper itself as `agent`.

The installer currently supports macOS and Linux on x64 and arm64. Cursor's
Windows documentation supports the Linux build through WSL rather than a
native Windows package. The PowerShell adapter remains necessary for wrapper
parity and for environments where a compatible command is on `PATH`, while
the official compatibility job must not claim a native Windows Cursor build.

## Verified command contract

| Concern | Current first-party behavior | `aagent` consequence |
| --- | --- | --- |
| One shot | `agent -p PROMPT` and `agent --print PROMPT` run non-interactively. The documented `cursor-agent` alias has the same entry point. | The base plan uses `agent --print --output-format text PROMPT`, substituting the validated resolved executable. It never enters the interactive UI. |
| Input | The positional prompt is variadic. Piped stdin also infers print mode, but the public docs do not define prompt-plus-stdin composition. | `aagent` resolves prompt-only, stdin-only, and prompt-plus-stdin input into one prompt argument before launch; it does not depend on an undocumented merge rule. |
| Model | `--model ID` selects a model; current help also exposes `--list-models`. | Wrapper `--model` maps directly to native `--model`; model identifiers remain provider-specific. Listing models is not part of passive selection because it may require account access. |
| Native options | Current help includes `--mode plan`, `--mode ask`, `--plan`, `--resume`, `--continue`, `--workspace`, `--worktree`, sandbox, MCP, and trust controls. | Arguments after the wrapper's `--` separator remain native array elements. `aagent` generates none of these optional controls. |
| Output | `--output-format text`, `json`, and `stream-json` are documented with print mode. Current build help reports text as the default, while an older reference snapshot says stream JSON. | Tier 2 text passthrough explicitly supplies `--output-format text`. Structured output stays capability metadata for Phase 14 and is not inferred from the changing default. |
| Sessions | `--resume [chatId]`, `--continue`, `ls`, and `resume` are available. | Session behavior remains deferred to Phase 14 and is never generated by this adapter. |
| Working directory | `--workspace PATH` exists, and normal operation uses the current directory. | The shared launcher sets the child cwd directly; it does not add a duplicate workspace option. |
| Exit | JSON/stream-JSON failures are documented as non-zero with stderr diagnostics. The checked build returned `0` for help/version and `1` for parser errors; Cursor publishes no stable numeric taxonomy. | Preserve stdout, stderr, signals, and the native status exactly. Do not assign Cursor-specific meanings to numeric failures. |

## Permission boundary

Cursor's headless documentation says print mode without `--force` proposes
changes instead of applying them. Current help describes `--force` as allowing
commands unless explicitly denied and `--yolo` as its Run Everything alias.
The permissions reference separately states that write permissions in print
mode still require `--force`, and configured deny rules take precedence.

`aagent` must not generate `--force`, `--yolo`, `--trust`, `--approve-mcps`, a
sandbox override, or permission configuration. Native options explicitly
provided by the user remain their responsibility. The frozen safe base plan is:

```text
agent --print --output-format text PROMPT
```

The adapter must retain a clear warning that the CLI has filesystem and shell
tools and that user-supplied autonomy flags can broaden side effects.

## Authentication and plan evidence

Cursor documents browser login and `CURSOR_API_KEY` as authentication paths.
An API key is a Cursor account credential; its name alone does not establish a
direct metered model API. The current CLI also accepts `--api-key`, but
`aagent` never generates credential arguments or reads their values.

`agent status --format json` is the supported machine-readable readiness
surface. Build `2026.07.23-e383d2b` returns these stable authentication fields:

```text
isAuthenticated  boolean
hasAccessToken   boolean
hasRefreshToken  boolean
```

It may additionally return status, message, and `userInfo` data. The official
implementation attempts an account lookup when both stored tokens exist, but
still reports the local token booleans if enrichment fails. The probe therefore
may touch Cursor's account endpoint, must use the shared three-second and
65,536-byte supervisor bounds, and must discard the complete response after
allowlisted parsing. It never logs in, refreshes deliberately, lists models,
or sends a prompt.

The checked JSON contained no endpoint. Cursor's authentication documentation
says status can display endpoint configuration, so a future string endpoint
field may be reduced to the fixed classes `vendor`, `local`, or `custom` after
strict URL parsing. The raw endpoint must never be retained or emitted, and an
endpoint with user information, whitespace, control characters, or an invalid
authority degrades the probe to `unknown`. No undocumented endpoint environment
variable is inspected.

Neither `status --format json` nor `about --format json` exposes a Cursor plan,
subscription tier, balance, quota, or remaining usage. Team/account identifiers
do not prove a paid seat. The adapter therefore applies these ceilings:

| Evidence | Readiness and funding classification |
| --- | --- |
| All three allowlisted status booleans are true | `ready`, `included_account`, machine-readable confidence; never `included_confirmed`. |
| `CURSOR_API_KEY` is present but status cannot confirm stored auth | `ready`, `included_account`, environment-presence confidence; inspect presence only. |
| An authenticated status response also contains unknown account, team, or plan-like fields | Ignore them. Classification remains at most `included_account`. |
| A valid optional endpoint is local | `local` only when `allow_local=true`; otherwise do not automatically select it. |
| A valid optional endpoint is custom/remote | Funding `unknown`; do not guess organization-funded or metered. |
| Status is false, partial, malformed, oversized, timed out, or fails and no API-key signal exists | `unusable` only for a well-formed definitive false result; otherwise `unknown`. |

Remaining Cursor allowance cannot safely break ties with another included
account today. Quota-aware routing remains a backlog feature until Cursor
publishes a passive, machine-readable, comparable allowance interface.

## Frozen P12A-04 implementation requirements

The implementation PR must:

1. activate the existing `cursor` registry entry without changing stable
   registry order;
2. discover `agent` before legacy `cursor-agent`, while honoring
   `AAGENT_CURSOR_BIN` and rejecting the running wrapper or another non-Cursor
   executable;
3. build `--print --output-format text PROMPT`, inserting `--model ID` and
   user-native arguments as array elements;
4. combine stdin with the prompt before launch and preserve cwd, stdout,
   stderr, signals, and native status through the shared launcher;
5. add no force, yolo, trust, MCP approval, sandbox, or permission option;
6. supervise `status --format json`, allowlist only the three booleans and an
   optional endpoint authority/class, and discard PII and arbitrary strings;
7. classify confirmed account readiness no higher than `included_account`,
   classify `CURSOR_API_KEY` by presence only, and never infer plan or quota;
8. expose executable-collision, network-status, permission, funding, and
   platform caveats in providers, doctor, README, and dry-run output; and
9. add Bash and PowerShell adapter, discovery, probe, selection,
   introspection, security, compatibility, and documentation fixtures without
   a real prompt.

No unresolved interface question blocks P12A-04. Cursor plan and remaining
allowance visibility are unavailable by design and must degrade conservatively.
