#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
aagent_script="$project_root/aagent.sh"
powershell_script="$project_root/aagent.ps1"
fake_provider="$project_root/tests/helpers/fake-provider.sh"
readme="$project_root/README.md"
cli_contract="$project_root/docs/spec/cli-contract.md"
test_dir="$(mktemp -d)"

cleanup() {
    rm -rf "$test_dir"
}
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_contains() {
    local value="$1"
    local expected="$2"
    local message="$3"
    [[ "$value" == *"$expected"* ]] || fail "$message"
}

bash_help="$(bash "$aagent_script" --help)"
readme_text="$(<"$readme")"
contract_text="$(<"$cli_contract")"

help_contract=(
    'aagent [OPTIONS] [PROMPT...]'
    'aagent providers'
    'aagent doctor [PROVIDER]'
    '-P, --provider ID'
    '-m, --model ID'
    '-C, --cwd DIRECTORY'
    '--auth-policy P'
    '--priority IDS'
    '--allow-local B'
    '--dry-run'
    '--quiet'
    '-h, --help'
    '--version'
    'Treat remaining arguments as provider-native options'
)
for surface in "${help_contract[@]}"; do
    assert_contains "$bash_help" "$surface" "Bash help omitted $surface"
done

public_contract=(
    'aagent providers'
    'aagent doctor'
    '--provider'
    '--model'
    '--cwd'
    '--auth-policy'
    '--priority'
    '--allow-local'
    '--dry-run'
    '--quiet'
    '--help'
    '--version'
    'provider-native'
)
for surface in "${public_contract[@]}"; do
    assert_contains "$readme_text" "$surface" "README omitted $surface"
    assert_contains "$contract_text" "$surface" "CLI specification omitted $surface"
done

documented_examples=(
    'aagent --provider claude --model sonnet "review the current diff"'
    'git diff | aagent --provider gemini'
    'aagent -P codex "fix the tests" -- --sandbox workspace-write'
    'Get-Content -Raw .\issue.md | aagent --provider claude "fix this issue"'
)
for example in "${documented_examples[@]}"; do
    assert_contains "$readme_text" "$example" "README example drifted: $example"
done

if command -v pwsh >/dev/null 2>&1; then
    powershell_help="$(pwsh -NoLogo -NoProfile -File "$powershell_script" --help | tr -d '\r')"
    [[ "$powershell_help" == "$bash_help" ]] || fail "Bash and PowerShell help output differ"
fi

fake_bin="$test_dir/bin with spaces"
record_dir="$test_dir/records"
home_dir="$test_dir/home"
config_dir="$test_dir/config"
mkdir -p "$fake_bin" "$record_dir" "$home_dir" "$config_dir"
cp "$fake_provider" "$fake_bin/gemini"
chmod +x "$fake_bin/gemini"

native_output="$(
    HOME="$home_dir" XDG_CONFIG_HOME="$config_dir" \
    AAGENT_GEMINI_BIN="$fake_bin/gemini" AAGENT_FAKE_RECORD_DIR="$record_dir" \
        bash "$aagent_script" --dry-run -P gemini \
        'apply the refactor' -- --approval-mode auto_edit </dev/null
)"
assert_contains "$native_output" 'provider: gemini' "Bash native-argument example selected the wrong provider"
assert_contains "$native_output" '\<native\> \<native\>' "Bash native-argument example lost redacted argument boundaries"

stdin_output="$(
    printf 'issue context\n' | \
        HOME="$home_dir" XDG_CONFIG_HOME="$config_dir" \
        AAGENT_GEMINI_BIN="$fake_bin/gemini" AAGENT_FAKE_RECORD_DIR="$record_dir" \
            bash "$aagent_script" --dry-run -P gemini 'fix this issue'
)"
assert_contains "$stdin_output" 'provider: gemini' "Bash stdin example selected the wrong provider"
assert_contains "$stdin_output" 'stdin: both' "Bash stdin example lost its input mode"
[[ ! -e "$record_dir/run.count" ]] || fail "documentation examples launched a provider"

while IFS= read -r match; do
    source_file="${match%%:*}"
    rendered_link="${match#*:}"
    target="${rendered_link#*](}"
    target="${target%)}"
    target="${target#<}"
    target="${target%>}"
    case "$target" in
        http://*|https://*|mailto:*|\#*) continue ;;
    esac
    relative_path="${target%%#*}"
    [[ -n "$relative_path" ]] || continue
    [[ -e "$(dirname "$source_file")/$relative_path" ]] || \
        fail "broken local Markdown link: $source_file -> $target"
done < <(grep -rHoE --include='*.md' '\[[^][]+\]\([^)]+\)' "$project_root")

printf 'Documentation Bash tests passed.\n'
