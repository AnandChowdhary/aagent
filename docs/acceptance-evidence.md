# MVP acceptance evidence

Status: Complete for aagent 0.1.1
Evidence recorded: 2026-08-04

This document is the direct evidence ledger for the twelve MVP acceptance
criteria in [Testing and acceptance](spec/testing.md). It records the exact
release commit, named test suites, GitHub Actions jobs, published artifacts,
and clean-install smoke tests. No live provider credential or paid prompt was
used.

## Release identity

- Release: [aagent 0.1.1](https://github.com/AnandChowdhary/aagent/releases/tag/v0.1.1)
- Tag: `v0.1.1`
- Release commit: `50166f2a268b377e05f952687f59cac179858d28`
- Tag and `origin/main` were independently resolved to that same commit before
  this ledger was written.
- The release is final: GitHub reports `isDraft: false` and
  `isPrerelease: false`.

Version `0.1.1` is the first final release. A never-finalized `0.1.0`
prerelease correctly stopped when its Windows Git Bash remote-install check
found a native drive-letter checksum-path bug. After that prerelease and tag
were removed, GitHub's
[immutable-release policy](https://docs.github.com/en/enterprise-cloud@latest/code-security/concepts/supply-chain-security/immutable-releases)
prevented reuse of the deleted tag name, so the reviewed repair was released
as `0.1.1`. The `0.1.0`
prerelease was never promoted or presented as a functional release.

## Exact-commit CI evidence

| Workflow | Exact evidence |
| --- | --- |
| Main test matrix | [Test run 30981356014](https://github.com/AnandChowdhary/aagent/actions/runs/30981356014) passed at `50166f2a268b377e05f952687f59cac179858d28`: Bash on Ubuntu, macOS, and Windows Git Bash; PowerShell on Windows; and the reproducible release gate on Ubuntu. |
| Release validation | [Release run 30981361645](https://github.com/AnandChowdhary/aagent/actions/runs/30981361645) passed the package validator, exact release gate, three-platform Bash matrix, and Windows PowerShell suite at the same commit without publishing. |
| Tagged release | [v0.1.1 run 30981749311](https://github.com/AnandChowdhary/aagent/actions/runs/30981749311) passed the exact release gate, package validation, Bash on Ubuntu/macOS/Windows, PowerShell on Windows, published-prerelease install smokes on all four runner surfaces, and final release promotion at the same commit. |

The tagged workflow created a prerelease only after the local candidate gates
passed. It then installed from the public release URLs and invoked the
installed wrapper with a deterministic fake Codex executable on Linux, macOS,
Windows Git Bash, and Windows PowerShell. Promotion to a final GitHub Release
depended on all four remote jobs.

## Published artifacts

The final release contains exactly five assets. `SHA256SUMS` was downloaded
from the release and independently verified against all four scripts on the
local macOS machine.

| Asset | SHA-256 |
| --- | --- |
| `aagent.sh` | `28e4fa20271c3e562f74cf88c7cafb93a11d2d618ccf5256591c91a1dba779bd` |
| `aagent.ps1` | `3bda7afa4cf8d2129c2387cdc48b0f65f20d1a60f288d3986e058b79bdd7d027` |
| `install.sh` | `0561c410e4e5f22b9f296d6dcd597adb1b012e2052ef12ffbc064b908dba47cd` |
| `install.ps1` | `ae75ac0a8d0a9c5a6691cdc276c26748a639600544b628ab6a88a23f2aca4f60` |
| `SHA256SUMS` | `3c5705e1c17ee8caabeb46e75d32d81947f42f259c0f68ce4fd4df4324a23b31` |

## Acceptance criteria

Every row names the focused Bash and PowerShell suites that own the behavior.
Those suites are dispatched by `tests/test_aagent.sh` and
`tests/test_aagent.ps1` in the exact-commit jobs above.

| # | Criterion | Direct test and release evidence | Result |
| --- | --- | --- | --- |
| 1 | Tier 1 one-shot adapters on every runner | [`test_adapters.sh`](../tests/test_adapters.sh) and [`test_adapters.ps1`](../tests/test_adapters.ps1) table-test Claude, Codex, OpenCode, Amp, and Gemini prompt, stdin, combined-input, model, native-argument, output, status, and at-most-one-launch shapes. Both suites passed in the main and tagged Linux/macOS/Windows jobs. | Pass |
| 2 | Explicit and automatic formula | [`test_parser.sh`](../tests/test_parser.sh), [`test_parser.ps1`](../tests/test_parser.ps1), [`test_config.sh`](../tests/test_config.sh), [`test_config.ps1`](../tests/test_config.ps1), [`test_selection.sh`](../tests/test_selection.sh), and [`test_selection.ps1`](../tests/test_selection.ps1) cover explicit authority, configuration precedence, and every field in the deterministic lexicographic selector. | Pass |
| 3 | Included plan outranks metered API | Both selection suites run the two primary scenarios: Claude Max over an OpenAI API key and ChatGPT Pro over an Anthropic API key. Pure-table cases also prove the funding-class comparison happens before priority and popularity. | Pass |
| 4 | Passive probes fail safely | [`test_probes.sh`](../tests/test_probes.sh) and [`test_probes.ps1`](../tests/test_probes.ps1) cover timeouts, malformed/truncated/oversized output, missing fields, unsupported versions, and conservative `unknown` degradation. [`test_security.sh`](../tests/test_security.sh) and [`test_security.ps1`](../tests/test_security.ps1) trap credential files/helpers and assert zero model launches. | Pass |
| 5 | Visible nonsecret selection reason | Both selection suites assert the selected provider, funding label/class, and decisive tuple field on stderr, plus `--quiet` suppression of wrapper notices without suppressing provider stderr. The introspection suites assert the same redacted vocabulary. | Pass |
| 6 | Process fidelity | [`test_launch.sh`](../tests/test_launch.sh) and [`test_launch.ps1`](../tests/test_launch.ps1) exercise hostile argv boundaries, exact stdin bytes, cwd, child-only environment, stdout/stderr, native status, and at-most-one launch. The Bash suite additionally sends a real termination signal and proves the child is reaped; the documented Windows console limitation is covered with native interrupt-like statuses. | Pass |
| 7 | No implicit permission escalation | Both security suites audit the generated-argument denylist, reject wrapper-generated bypass flags, and prove a permission flag is forwarded exactly once only when the user places it after `--`. Adapter tests confirm normal generated argv contains no escalation. | Pass |
| 8 | Stable wrapper errors | The parser, config, adapter, selection, and security suites assert status and `aagent:` stderr for usage `64`, unavailable `69`, software `70`, and configuration `78`, while separately proving an identical provider-native status is preserved. | Pass |
| 9 | Safe `providers` and `doctor` | [`test_introspection.sh`](../tests/test_introspection.sh) and [`test_introspection.ps1`](../tests/test_introspection.ps1) cover all/provider-scoped output, bounded probes, redaction, and zero run launches. Both security suites prove the commands do not invoke login/helpers, read credential files, reveal seeded PII/tokens, or send a model prompt. | Pass |
| 10 | Cursor `agent` is not `aagent` | [`test_discovery.sh`](../tests/test_discovery.sh) and [`test_discovery.ps1`](../tests/test_discovery.ps1) discover Cursor's primary and legacy executables only after version/help signature validation, reject wrapper recursion and invalid overrides, and retain distinct `cursor` and `aagent` identities. | Pass |
| 11 | Help, installation, and platform behavior | [`test_docs.sh`](../tests/test_docs.sh), [`test_docs.ps1`](../tests/test_docs.ps1), [`test_install.sh`](../tests/test_install.sh), [`test_install.ps1`](../tests/test_install.ps1), and [`test_release.sh`](../tests/test_release.sh) cover help parity, documented examples, local links, atomic/checksummed installs, version enforcement, and release packaging. Tagged run 30981749311 remotely installed and invoked the public artifacts on all four runner surfaces. | Pass |
| 12 | Ledger phases and gates complete | [TODO.md](../TODO.md) records every task and exit gate in Phases 0 through 11 as complete. This document supplies the required criterion-by-criterion named evidence; Phase 12 and later remain visibly unchecked and deferred. | Pass |

## Independent local release smoke

After the final release was public, a fresh temporary destination on the local
macOS machine downloaded `install.sh` from the `v0.1.1` release, pinned both the
download base URL and expected version, and completed these checks:

```console
aagent --version
aagent --help
aagent providers
aagent --quiet -P codex "say hello"
```

The installed version was exactly `aagent 0.1.1`. The last command used the
repository's fake Codex fixture, returned `release-smoke`, and produced one run
record. No real provider prompt was sent.

## Final sign-off

- Phases 0 through 11 have no unchecked or blocked task.
- The specification, split normative documents, help, README, installers, and
  implementations agree for the released behavior.
- Credential material, login, model probes, implicit permission escalation,
  and post-launch failover are excluded by both implementation and focused
  security tests.
- Selection is deterministic and explainable for the same discovered state in
  Bash and PowerShell.
- Tier 2 completeness, quota-aware routing, normalized structured output, and
  portable sessions remain deferred to Phases 12 through 14.

This evidence ledger was necessarily recorded after the immutable release
facts existed. It does not move or rewrite `v0.1.1`; the released code and all
release-affecting documentation remain the reviewed exact commit identified
above.
