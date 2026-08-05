# Factory Droid revalidation

Status: Normative implementation input for P12A-05
Research snapshot: 2026-08-05

This revalidation freezes the current public interface that the `droid`
adapter may use. It corrects the initial survey's description of Spec Mode:
the safe default is read-only autonomy, while Spec Mode is separately opt-in.

## Evidence and method

Only first-party Factory sources were used:

- [Droid Exec overview](https://docs.factory.ai/droid-exec/overview);
- [CLI reference](https://docs.factory.ai/droid-cli/cli-reference);
- [settings](https://docs.factory.ai/droid-cli/settings);
- [bring your own key](https://docs.factory.ai/model-independence/byok); and
- [individual pricing](https://docs.factory.ai/pricing/individuals).

The current official npm package was installed in an isolated temporary
directory. It reported version `0.188.0`. npm published this integrity value:

```text
sha512-EKDcuuxZ4mQPQJP2ApZo6yd8915pORGbpZABRV4vXKqM2Z9wk+GHnoOPiejv9hYYzNXwQP95NSemK2DsXxf+fw==
```

The installed CLI was invoked only for version and help output. No login,
logout, interactive command, model prompt, tool call, account request, or paid
request was performed. The documented `/status` and `/limits` commands are
interactive surfaces and were not used as passive probes.

## Verified command contract

| Concern | Current first-party behavior | `aagent` consequence |
| --- | --- | --- |
| One shot | `droid exec [PROMPT]` executes once without the interactive UI. | The adapter begins with `droid exec` and preserves the provider's native status. |
| Input | The prompt may be positional or piped through stdin. | Prompt-only uses an argument, stdin-only keeps stdin, and prompt-plus-stdin preserves both channels. |
| Model | `--model ID` selects a model. Settings also select a model. | Wrapper `--model` maps directly to native `--model`; model IDs remain opaque and provider-specific. |
| Output | Text is the default. `--output-format` supports structured output, and stream JSON/JSON-RPC input modes are available. | Text stays native passthrough. JSON, stream JSON, and stream JSON-RPC are recorded as capabilities for the later structured-output phase. |
| Sessions | `--session-id` continues a session and `--fork` creates a branch from one. | Session support is metadata only until the normalized session phase. |
| Working directory | `--cwd` is available. | The shared launcher sets the child working directory directly and adds no duplicate option. |
| Exit | Success is zero and failures are non-zero; no complete stable numeric taxonomy is published. | Preserve stdout, stderr, signals, and exact native status without reinterpretation. |

## Permission boundary

`droid exec` uses read-only autonomy when no autonomy option is supplied. The
current help explicitly describes that default as allowing information
gathering while preventing file or system modification. `--auto low`,
`--auto medium`, and `--auto high` progressively permit more side effects;
`--skip-permissions-unsafe` bypasses permission checks.

Spec Mode is independent. `--use-spec` starts in Spec Mode, while documented
settings default `sessionDefaultSettings.interactionMode` to `auto` and
`sessionDefaultSettings.autonomyLevel` to `off`. Therefore `aagent` must not
describe the default as “read-only spec mode,” and must not generate
`--use-spec`, `--auto`, or `--skip-permissions-unsafe`. Users may still supply
native options explicitly after the wrapper's `--` separator.

The frozen safe base plan is:

```text
droid exec PROMPT
```

## Authentication and funding evidence

Factory documents browser authentication and `FACTORY_API_KEY`. Both
authenticate a Factory account. The variable name does not establish direct
model-provider BYOK, a paid Factory plan, remaining standard usage, or extra
credits. Its presence is therefore low-confidence `ready` evidence with
funding `unknown`, not `payg_byok` or `included_confirmed`.

Factory's individual plans include Pro, Plus, and Max, with rolling usage
windows and optional extra credits. The CLI does not publish a passive,
machine-readable plan or remaining-allowance command. Interactive `/limits`
must not be invoked during discovery, automatic selection, `providers`, or
`doctor`. Browser-token storage also remains private and must not be inspected.

Factory documents user and project settings in `~/.factory` and `.factory`,
including local override files. A selected `custom:...-INDEX` model refers to
`customModels[INDEX]`. Only the non-secret selected `model` and the referenced
custom model's `baseUrl` are needed for funding classification:

| Passive evidence | Classification |
| --- | --- |
| `FACTORY_API_KEY` presence with a Factory-managed or unknown model | `ready`, funding `unknown`, low confidence. |
| Selected custom model with a valid remote HTTP(S) base URL | `payg_byok`; readiness remains independently based on account evidence. |
| Selected custom model with an exact loopback HTTP(S) host | `local`, eligible automatically only with `allow_local=true`. |
| Browser login with no documented passive status | Readiness and funding `unknown`; never inspect its token. |
| Malformed, oversized, unreadable, missing, or unresolved settings | Degrade conservatively to `unknown`; do not guess the route. |

The `apiKey` field may contain a literal secret or an environment reference.
`aagent` neither reads nor emits it. It parses bounded JSON, allowlists only
`model` and the selected `baseUrl`, rejects embedded URL credentials and
invalid authorities, reduces the endpoint to `local` or `remote`, then
discards the raw document.

## Frozen P12A-05 implementation requirements

The implementation PR must:

1. activate `droid` without changing registry or popularity order;
2. build `droid exec`, optional `--model ID`, native arguments, and the
   resolved prompt/stdin channels as array elements;
3. preserve cwd, stdout, stderr, signals, and native status;
4. generate no Spec Mode, autonomy, permission-bypass, session, worktree, or
   structured-output option;
5. classify `FACTORY_API_KEY` as account readiness with unknown funding;
6. parse only bounded, documented settings fields needed to identify the
   selected custom model's local or remote endpoint class;
7. never inspect browser tokens, raw custom-model API keys, `/status`, or
   `/limits`, and never infer a Factory plan or quota;
8. expose the corrected safety and funding caveats in README and diagnostics;
9. add Bash and PowerShell adapter, discovery, probe, selection,
   introspection, security, compatibility, and documentation fixtures; and
10. install the current official `droid` npm package in the weekly/manual
    credential-free GitHub Actions compatibility matrix.

No unresolved interface question blocks P12A-05. Plan tier and remaining
allowance stay unknown by design and may be revisited only through the
quota-aware backlog.
