# Passive probe contract

Status: Normative for the MVP

## Result schema

Every installed Tier 1 candidate produces one redacted record with exactly
these logical fields:

| Field | Values |
| --- | --- |
| provider | stable registry ID |
| readiness | `ready`, `unknown`, or `unusable` |
| funding class | a funding class from [selection.md](selection.md) |
| confidence rank | integer `0` through `4` |
| plan label | fixed allowlisted label, never provider text |
| reason code | fixed wrapper-owned identifier |
| shadowing variables | documented environment variable names only |
| source | fixed local evidence source |
| probe status | fixed success, fallback, skip, or degradation identifier |

The record has no raw-output, token, email, organization, account ID, provider
error, or arbitrary-string field.

Confidence ranks are:

| Rank | Evidence |
| ---: | --- |
| 4 | documented machine-readable status or nonsecret configuration |
| 3 | machine-readable current implementation detail with tolerant parsing |
| 2 | documented redacted text status |
| 1 | documented environment-variable presence only |
| 0 | no usable evidence or a degraded probe |

Only ranks 3 and 4 may establish `included_confirmed`, and only when a known
machine-readable plan or subscription signal is present. Text, file existence,
and environment presence can never establish that class.

## Supervisor

CLI probes run with redirected stdin, stdout, and stderr and therefore without
a TTY. The supervisor uses a three-second timeout and a 65,536-byte limit per
output stream. It sends termination on timeout, drains the process, parses only
the selected bounded stream, and discards both streams after classification.

Timeout, crash, invalid UTF-8, excessive output, malformed data, missing fields,
unexpected types, protocol mismatch, and unsupported versions become a valid
`unknown` record. They do not fail a wrapper invocation or start a provider run.

Normal selection uses no network-dependent status endpoint:

- Claude runs `auth status --json`.
- Codex performs the documented local app-server initialization and
  `account/read` request with `refreshToken:false`, then falls back to the
  local `login status` text only when necessary. The wrapper briefly keeps the
  app-server input stream open so its asynchronous account response can arrive
  before end-of-file shuts the server down.
- OpenCode runs its documented local `auth list` command but does not infer
  included funding from OAuth alone.
- Gemini reads only `~/.gemini/settings.json` and projects
  `security.auth.selectedType`; it does not run the CLI.
- Amp does not run `usage` or another account command automatically.

## Provider classifications

Claude subscription types `pro`, `max`, `team`, and `enterprise` are fixed
included plans. Direct Console/API status is `payg_byok`. Bearer, helper,
gateway, Bedrock, Vertex, Foundry, and unknown paths remain `unknown` funding.
The documented subscription OAuth environment variable is at most
`included_account` because presence alone cannot validate a plan.

Codex `account.type=chatgpt` is included; only allowlisted Plus, Pro, Team,
Business, Enterprise, and Edu labels are confirmed plans. Free or unknown plan
types are `included_account`. `apiKey` is `payg_byok`; Bedrock and custom
`requiresOpenaiAuth=false` routes remain funding-unknown. The text fallback
confirms readiness but never invents a ChatGPT tier.

Gemini `oauth-personal` is `included_account`, not a confirmed Google plan.
`gemini-api-key` is `payg_byok`. Vertex, ADC, Cloud Shell, and gateway routes
are ready but funding-unknown. An Amp access token establishes only low-
confidence account readiness, never the funding source.

## Credential boundary

The wrapper never opens provider token files, auth databases, keychains, OS
credential stores, or credential-helper output. It checks documented
environment names for presence without copying or emitting their values. The
official provider process remains the authority for its own cached auth.

Gemini's documented settings file is the only provider-owned file parsed by
the wrapper. Unknown JSON fields are discarded and cannot enter the result.
