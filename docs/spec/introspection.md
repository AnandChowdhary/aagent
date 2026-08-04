# Introspection commands

Status: Normative for the MVP

## `aagent providers`

Lists every known adapter, resolution path, passive authentication result,
funding class, and selection reason without logging in or contacting the
network:

```text
ID        STATUS   FUNDING               SELECTED  REASON
codex     ready    included_confirmed    yes       ChatGPT Pro
claude    ready    included_confirmed    no        popularity #2
gemini    missing  unknown               no        executable missing
cursor    ready    included_account      no        lower funding class
```

Paths and versions may be included in a verbose form. Account email,
organization, token fingerprints, credential values, and raw status output are
never displayed.

The command exits `0` when inspection completes, including when no provider is
installed. Invalid configuration still follows the configuration error rules
in [cli-contract.md](cli-contract.md).

## `aagent doctor [PROVIDER]`

Runs non-mutating diagnostics:

- wrapper version and platform;
- detected provider paths and versions;
- selected provider and why it won;
- configuration errors;
- readiness, funding class, confidence, safe plan label, and shadowing variable
  names where supported;
- supported model, stdin, structured-output, and session capabilities; and
- provider-specific permission or side-effect warnings.

Authentication is reported as `ready`, `unusable`, or `unknown`. Funding and
authentication confidence are reported separately. `unknown` is valid when a
provider lacks a stable, non-interactive status probe.

Doctor must not open a browser, begin login, display credentials, or send a
model request. With a provider argument, an unknown provider is a usage error;
a known but missing provider is reported diagnostically rather than launched.

## `--dry-run`

Dry-run resolves the same configuration, candidates, selection result, child
environment plan, adapter argv, stdin mode, and working directory as a real
run, but does not start the provider. It prints:

- the selected provider and reason;
- an escaped, copy-oriented representation of the executable and arguments;
- whether prompt data comes from argv, stdin, or both;
- the effective working directory; and
- the names of child environment variables that would be set or omitted.

It never prints environment values, prompt stdin contents, raw probe responses,
or account PII.
