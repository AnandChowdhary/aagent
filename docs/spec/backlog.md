# Post-MVP backlog

Status: Deferred; not part of MVP acceptance

This document defines future work tightly enough to preserve design intent. It
does not authorize implementation before the MVP gate in
[testing.md](testing.md) is complete.

## Usage-aware routing

Static funding-aware selection is part of the MVP. Live allowance balancing is
a separate, opt-in feature because providers expose incompatible quota windows
and most lack a documented passive API.

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
mode remains outside the default execution path. An opt-in collector could
later ingest Claude's emitted status-line fields after real user runs and
combine them with Codex's passive rate-limit endpoint.

## Structured result and event API

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

## Other deferred decisions

- portable sessions and resume behavior;
- capability-aware permission profiles;
- budget, reasoning-effort, system-prompt, and tool-selection flags;
- successful-provider history as a local tie-breaker;
- project-local configuration;
- automatic compatibility metadata updates; and
- server, SDK, or ACP transports.

Each deferred item must begin with a specification update, threat-model review
where applicable, and explicit acceptance criteria before implementation.
