# Primary research sources

Initial research snapshot: 2026-08-04

Provider-specific refreshes are dated separately. The current Copilot CLI
evidence is the [2026-08-05 revalidation](../research/copilot-cli-2026-08-05.md).

Only first-party documentation, repositories, and package/download APIs were
used for the interface and selection survey.

- Claude Code: [headless mode](https://code.claude.com/docs/en/headless),
  [CLI reference](https://code.claude.com/docs/en/cli-reference),
  [authentication and precedence](https://code.claude.com/docs/en/iam),
  [environment variables](https://code.claude.com/docs/en/env-vars),
  [status-line rate limits](https://code.claude.com/docs/en/statusline#rate-limit-usage)
- Codex CLI: [non-interactive mode](https://developers.openai.com/codex/noninteractive),
  [CLI reference](https://developers.openai.com/codex/cli/reference),
  [authentication](https://learn.chatgpt.com/docs/auth),
  [app-server account and rate-limit API](https://learn.chatgpt.com/docs/app-server#auth-endpoints),
  [pricing and usage limits](https://learn.chatgpt.com/docs/pricing)
- OpenCode: [CLI](https://opencode.ai/docs/cli/),
  [permissions](https://opencode.ai/docs/permissions/),
  [providers](https://opencode.ai/docs/providers/)
- Amp: [CLI manual](https://ampcode.com/manual#cli),
  [streaming JSON](https://ampcode.com/manual#cli-streaming-json)
- Gemini CLI: [headless mode](https://geminicli.com/docs/cli/headless/),
  [CLI reference](https://geminicli.com/docs/cli/cli-reference/),
  [authentication](https://geminicli.com/docs/get-started/authentication/),
  [quota and pricing](https://geminicli.com/docs/resources/quota-and-pricing/)
- Factory Droid: [headless exec](https://docs.factory.ai/droid-exec/overview),
  [CLI reference](https://docs.factory.ai/droid-cli/cli-reference),
  [BYOK](https://docs.factory.ai/model-independence/byok),
  [pricing](https://docs.factory.ai/pricing/individuals)
- GitHub Copilot CLI: [official repository](https://github.com/github/copilot-cli),
  [programmatic execution](https://docs.github.com/en/copilot/how-tos/copilot-cli/automate-copilot-cli/run-cli-programmatically),
  [programmatic reference](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-programmatic-reference),
  [command reference](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference),
  [authentication](https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/authenticate-copilot-cli),
  [BYOK](https://docs.github.com/en/enterprise-cloud@latest/copilot/how-tos/copilot-cli/customize-copilot/use-byok-models),
  [permissions](https://docs.github.com/en/copilot/how-tos/copilot-cli/use-copilot-cli/allowing-tools),
  [v1.0.78 release](https://github.com/github/copilot-cli/releases/tag/v1.0.78),
  [billing usage API](https://docs.github.com/en/rest/billing/usage)
- Goose: [running tasks](https://goose-docs.ai/docs/guides/running-tasks/),
  [headless tutorial](https://goose-docs.ai/docs/tutorials/headless-goose/),
  [providers](https://goose-docs.ai/docs/getting-started/providers/)
- Qwen Code: [headless mode](https://github.com/QwenLM/qwen-code/blob/main/docs/users/features/headless.md),
  [authentication](https://qwenlm.github.io/qwen-code-docs/en/users/configuration/auth/)
- Kimi Code: [command reference](https://moonshotai.github.io/kimi-code/en/reference/kimi-command),
  [membership](https://www.kimi.com/code/docs/en/kimi-code/membership.html)
- Cline: [CLI reference](https://docs.cline.bot/cli/cli-reference),
  [authorization](https://docs.cline.bot/getting-started/authorizing-with-cline),
  [official repository](https://github.com/cline/cline)
- Crush: [official repository](https://github.com/charmbracelet/crush),
  [`run` command source](https://github.com/charmbracelet/crush/blob/main/internal/cmd/run.go),
  [`login` command source](https://github.com/charmbracelet/crush/blob/main/internal/cmd/login.go)
- Mistral Vibe: [official repository](https://github.com/mistralai/mistral-vibe),
  [API keys and profiles](https://docs.mistral.ai/vibe/code/cli/api-keys-profiles)
- Kiro CLI: [headless mode](https://kiro.dev/docs/cli/headless)
- Aider: [scripting guide](https://aider.chat/docs/scripting.html),
  [options reference](https://aider.chat/docs/config/options.html),
  [Copilot subscription provider](https://aider.chat/docs/llms/github.html)
- Cursor CLI: [headless mode](https://cursor.com/docs/cli/headless),
  [authentication](https://docs.cursor.com/en/cli/reference/authentication),
  [parameter reference](https://cursor.com/docs/cli/reference/parameters)
- OpenHands: [official repository](https://github.com/OpenHands/OpenHands)

## Popularity snapshot inputs

- npm downloads: [`@openai/codex`](https://api.npmjs.org/downloads/point/last-month/%40openai%2Fcodex),
  [`@anthropic-ai/claude-code`](https://api.npmjs.org/downloads/point/last-month/%40anthropic-ai%2Fclaude-code),
  [`opencode-ai`](https://api.npmjs.org/downloads/point/last-month/opencode-ai),
  [`@github/copilot`](https://api.npmjs.org/downloads/point/last-month/%40github%2Fcopilot),
  [`@google/gemini-cli`](https://api.npmjs.org/downloads/point/last-month/%40google%2Fgemini-cli)
- GitHub repositories: [Codex](https://github.com/openai/codex),
  [Claude Code](https://github.com/anthropics/claude-code),
  [OpenCode](https://github.com/anomalyco/opencode),
  [Copilot CLI](https://github.com/github/copilot-cli),
  [Gemini CLI](https://github.com/google-gemini/gemini-cli)

Popularity data is a versioned input to [selection.md](selection.md), not a
runtime dependency. Refreshing it requires a normal reviewed release.
