# Testing and acceptance

Status: Normative for implementation and release

## Adapter contract tests

Each provider gets a fake executable placed first on `PATH`. Tests record argv,
stdin, cwd, stdout, stderr, child environment names and safe sentinel values,
and exit status without requiring credentials or making network requests.

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

The Bash contract suite sends a real termination signal, checks the
conventional signal-derived status, and proves the fake provider is reaped.
The Windows PowerShell CI environment cannot synthesize a portable console
Ctrl-C; its contract suite therefore verifies preservation of interrupt-like
native statuses while the launcher leaves the provider attached to the same
console for normal Ctrl-C delivery.

## Selection tests

- no providers installed;
- exactly one provider installed;
- several installed providers and the popularity prior;
- synthetic equal-popularity candidates reaching stable registry order;
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

Child authentication policy fixtures additionally verify exact Claude and
Codex set/omit plans, custom-route and helper ambiguity, native-policy
classification, opaque Codex fallback mapping, parent immutability after
success and failure paths, redacted notices, and interruption on Bash.

The selector is also exercised as a pure table-driven comparison in both
runners so prepaid and local funding classes, unlisted priority behavior, and
every decisive tuple field remain testable without adding unsupported provider
fixtures or credentials.

## Security tests

Prompts and configuration values containing shell syntax must remain inert.
Tests must prove that the wrapper never introduces a known approval-bypass
flag, never sources a configuration file, never reads a credential token file,
never sends a model request for probing, never emits token or PII fields from a
status response, and never changes the parent environment.

## Platform matrix

GitHub Actions must run:

- Bash tests on Linux, macOS, and Windows Git Bash;
- PowerShell tests on Windows; and
- equivalent adapter and selection fixtures in both runners.

Live provider tests are opt-in, credentialed, and excluded from pull-request CI
to avoid cost and secret exposure. A scheduled compatibility workflow may
install current CLIs, inspect their documented help output, and flag adapter
drift without running a paid prompt.

## MVP acceptance criteria

The implementation is complete only when:

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
   statuses satisfy the command-line contract.
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
12. Every checkbox in Phases 0 through 11 of [TODO.md](../../TODO.md) is
    complete and each phase exit gate is recorded as passing.

Passing unit tests alone is not sufficient if any acceptance criterion remains
unmet.
