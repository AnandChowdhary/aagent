# Fake provider protocol

The Bash and PowerShell test entrypoints copy `fake-provider.sh` or
`fake-provider.ps1` under each Tier 1 executable name. These fixtures never
contact a provider, read provider configuration, or require credentials.

`AAGENT_FAKE_RECORD_DIR` selects the output directory. Each invocation creates
`PROVIDER.KIND.NUMBER.record`, where `KIND` is `run` or `probe`, and increments
a separate `run.count` or `probe.count` file.

Record protocol version 1 contains:

- UTF-8 hexadecimal provider ID and working directory;
- invocation kind, child process ID, and argument count;
- one UTF-8 hexadecimal field per argument;
- exact stdin bytes as hexadecimal;
- presence or absence for names in `AAGENT_FAKE_ENV_PRESENCE`; and
- values for explicitly safe test-only names in `AAGENT_FAKE_ENV_CAPTURE`.

Presence-only environment variables are never recorded by value. Tests use
this distinction for authentication variables. The auth-policy mapping fixture
may explicitly capture a seeded fake value to prove byte-for-byte child-only
mapping; the test compares it only inside its private temporary directory and
never prints it.

Run responses are controlled with `AAGENT_FAKE_RUN_STDOUT`,
`AAGENT_FAKE_RUN_STDERR`, `AAGENT_FAKE_RUN_STATUS`, and
`AAGENT_FAKE_RUN_DELAY`. Probe responses use the corresponding
`AAGENT_FAKE_PROBE_*` variables. Tests that exercise multiple commands from one
adapter can override those with `AAGENT_FAKE_CLAUDE_*`,
`AAGENT_FAKE_CODEX_APP_SERVER_*`, `AAGENT_FAKE_CODEX_LOGIN_*`, and
`AAGENT_FAKE_OPENCODE_*`. `AAGENT_FAKE_INVOCATION_KIND` can force a fixture
into `run` or `probe` mode; otherwise documented status command shapes for
Claude, Codex, and OpenCode are recognized automatically.

`AAGENT_FAKE_PROBE_BYTES` and the profile-specific `*_BYTES` variants emit a
generated response of the requested size without placing a huge fixture in the
environment. Probe-supervisor tests use this to verify bounded capture.

This protocol supports valid, missing-field, malformed, delayed, non-zero,
secret-bearing, and PII-bearing probe fixtures while keeping probe counts
separate from actual run counts.

The selection suites combine these responses into isolated multi-provider
matrices. They verify the complete ranking tuple and then confirm through the
recorded `run` file that only the selected provider received the prompt.

The process ID is test-only lifecycle metadata. Launch tests use it to prove a
terminated fake provider is not left running; production diagnostics never
expose provider process IDs.
