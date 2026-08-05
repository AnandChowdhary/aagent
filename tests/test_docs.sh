#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
aagent_script="$project_root/aagent.sh"
powershell_script="$project_root/aagent.ps1"
fake_provider="$project_root/tests/helpers/fake-provider.sh"
readme="$project_root/README.md"
cli_contract="$project_root/docs/spec/cli-contract.md"
acceptance_evidence="$project_root/docs/acceptance-evidence.md"
specification="$project_root/SPEC.md"
ledger="$project_root/TODO.md"
copilot_research="$project_root/docs/research/copilot-cli-2026-08-05.md"
cursor_research="$project_root/docs/research/cursor-cli-2026-08-05.md"
droid_research="$project_root/docs/research/factory-droid-2026-08-05.md"
adapter_spec="$project_root/docs/spec/adapters.md"
probe_spec="$project_root/docs/spec/probes.md"
security_spec="$project_root/docs/spec/security.md"
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
acceptance_text="$(<"$acceptance_evidence")"
specification_text="$(<"$specification")"
ledger_text="$(<"$ledger")"
copilot_research_text="$(<"$copilot_research")"
cursor_research_text="$(<"$cursor_research")"
droid_research_text="$(<"$droid_research")"
adapter_spec_text="$(<"$adapter_spec")"
probe_spec_text="$(<"$probe_spec")"
security_spec_text="$(<"$security_spec")"

release_evidence_contract=(
    'Status: Complete for aagent 0.1.1'
    '50166f2a268b377e05f952687f59cac179858d28'
    'actions/runs/30981356014'
    'actions/runs/30981749311'
    'releases/tag/v0.1.1'
    '28e4fa20271c3e562f74cf88c7cafb93a11d2d618ccf5256591c91a1dba779bd'
    'ae75ac0a8d0a9c5a6691cdc276c26748a639600544b628ab6a88a23f2aca4f60'
)
for evidence in "${release_evidence_contract[@]}"; do
    assert_contains "$acceptance_text" "$evidence" "MVP acceptance evidence omitted $evidence"
done
for criterion in {1..12}; do
    assert_contains "$acceptance_text" "| $criterion |" "MVP acceptance criterion $criterion is unrecorded"
done
assert_contains "$specification_text" 'Status: MVP released' "SPEC does not mark the MVP released"
assert_contains "$ledger_text" 'Current milestone: Phase 12 Tier 2 adapters' \
    "implementation ledger does not identify the active backlog phase"

copilot_research_contract=(
    'Status: Normative implementation input for P12A-02'
    'GitHub Copilot CLI 1.0.78'
    '87982a909d52fcf095ee4458d3b5a69bbfd8ae614177115191b977a93df3d807'
    'copilot --prompt PROMPT --silent --no-ask-user'
    'COPILOT_PROVIDER_BASE_URL'
    'no non-mutating'
    'No unresolved interface question blocks P12A-02'
)
for evidence in "${copilot_research_contract[@]}"; do
    assert_contains "$copilot_research_text" "$evidence" "Copilot revalidation omitted $evidence"
done

cursor_research_contract=(
    'Status: Normative implementation input for P12A-04'
    '2026.07.23-e383d2b'
    'f2eb25851f2079dcdf0558a816e06c402d187abfca93255d35167020439ebbf2'
    'agent --print --output-format text PROMPT'
    'isAuthenticated'
    'CURSOR_API_KEY'
    'No unresolved interface question blocks P12A-04'
)
for evidence in "${cursor_research_contract[@]}"; do
    assert_contains "$cursor_research_text" "$evidence" "Cursor revalidation omitted $evidence"
done
assert_contains "$ledger_text" "- [x] **P12A-03 Revalidate Cursor CLI.**" \
    "implementation ledger does not mark Cursor revalidation complete"

copilot_implementation_contract=(
    "GitHub Copilot CLI (\`copilot\`)"
    'copilot --prompt PROMPT --silent --no-ask-user'
    'COPILOT_PROVIDER_BASE_URL'
    'Copilot BYOK'
    'GitHub token presence'
)
for evidence in "${copilot_implementation_contract[@]}"; do
    assert_contains "$readme_text$adapter_spec_text$probe_spec_text" "$evidence" \
        "Copilot implementation documentation omitted $evidence"
done
assert_contains "$security_spec_text" "\`--allow-all-paths\`" \
    "security documentation omitted Copilot permission escalation flags"
assert_contains "$ledger_text" "- [x] **P12A-02 Implement \`copilot\`.**" \
    "implementation ledger does not mark Copilot complete"

cursor_implementation_contract=(
    "Cursor CLI (\`cursor\`)"
    'agent --print --output-format text PROMPT'
    'AAGENT_CURSOR_BIN'
    'status --format json'
    'CURSOR_API_KEY'
    'included_account'
    'cursor-agent'
)
for evidence in "${cursor_implementation_contract[@]}"; do
    assert_contains "$readme_text$adapter_spec_text$probe_spec_text" "$evidence" \
        "Cursor implementation documentation omitted $evidence"
done
assert_contains "$security_spec_text" "\`--approve-mcps\`" \
    "security documentation omitted Cursor permission escalation flags"
assert_contains "$ledger_text" "- [x] **P12A-04 Implement \`cursor\`.**" \
    "implementation ledger does not mark Cursor complete"

droid_research_contract=(
    'Status: Normative implementation input for P12A-05'
    '0.188.0'
    'sha512-EKDcuuxZ4mQPQJP2ApZo6yd8915pORGbpZABRV4vXKqM2Z9wk+GHnoOPiejv9hYYzNXwQP95NSemK2DsXxf+fw=='
    'droid exec PROMPT'
    'FACTORY_API_KEY'
    'read-only autonomy'
    'No unresolved interface question blocks P12A-05'
)
for evidence in "${droid_research_contract[@]}"; do
    assert_contains "$droid_research_text" "$evidence" "Droid revalidation omitted $evidence"
done

droid_implementation_contract=(
    "Factory Droid (\`droid\`)"
    'droid exec PROMPT'
    'AAGENT_DROID_BIN'
    'FACTORY_API_KEY'
    'customModels[INDEX].baseUrl'
    'payg_byok'
)
for evidence in "${droid_implementation_contract[@]}"; do
    assert_contains "$readme_text$adapter_spec_text$probe_spec_text" "$evidence" \
        "Droid implementation documentation omitted $evidence"
done
assert_contains "$security_spec_text" "\`--skip-permissions-unsafe\`" \
    "security documentation omitted Droid permission bypass"
assert_contains "$ledger_text" "- [x] **P12A-05 Revalidate and implement Factory Droid.**" \
    "implementation ledger does not mark Droid complete"

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
