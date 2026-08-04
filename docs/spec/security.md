# Permissions, privacy, and safety

Status: Normative for every release

## MVP permissions policy

For permissions, the MVP uses the provider's installed configuration and native
headless default. The authentication policy may adjust a documented shadowing
API variable in the child process, but it does not change tool permissions. The
MVP does not define a universal `--read-only`, `--edit`, or `--full-access`
flag. Those names would imply equivalence that the underlying sandboxes and tool
policies do not provide.

The wrapper must:

- never append `--yolo`, `--dangerously-skip-permissions`,
  `--skip-permissions-unsafe`, `--allow-all-tools`, `--auto`, or equivalent;
- never answer an approval prompt on the user's behalf;
- display known provider safety notes in `aagent doctor`;
- treat native options after `--` as an explicit user choice;
- avoid silently changing provider configuration files; and
- never retry a failed run with another provider.

## Authentication privacy boundary

The wrapper may call only the passive provider interfaces enumerated in
[selection.md](selection.md). It must not:

- decode, copy, print, hash, or transmit stored authentication tokens;
- open an OS credential store or read a credential token file;
- invoke a credential-producing helper;
- begin a login flow or open a browser;
- send a model request to test authentication or quota;
- retain raw authentication probe responses; or
- emit account email, organization, token fingerprint, or other account PII.

Environment variables are inspected by name and presence only. Any child-only
authentication adjustment reports the variable name, never its value, and must
leave the parent environment unchanged.

## Data and command safety

Prompts, configuration values, executable overrides, model IDs, and native
arguments are always data. Neither runner may use `eval`, source configuration,
or interpolate user input through a command-expression language.

`--dry-run`, diagnostics, test failures, and wrapper errors must redact secrets.
Provider output is passed through unchanged; users remain responsible for what
the selected provider itself prints.

## Future normalized policies

A later release may add capability-aware policy names such as `read-only`,
`workspace`, and `unrestricted`. Each adapter would need a documented mapping
and a fail-closed result when it cannot enforce the requested boundary. Merely
omitting a vendor's yolo flag is not evidence of read-only execution.
