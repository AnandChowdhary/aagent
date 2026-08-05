#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
allow_dirty=0
if (( $# > 1 )); then
    printf 'Usage: release-gate.sh [--allow-dirty]\n' >&2
    exit 64
fi
if (( $# == 1 )); then
    [[ "$1" == "--allow-dirty" ]] || {
        printf 'Usage: release-gate.sh [--allow-dirty]\n' >&2
        exit 64
    }
    allow_dirty=1
fi

if (( allow_dirty == 0 )) && [[ -n "$(git -C "$project_root" status --porcelain)" ]]; then
    printf 'aagent release gate requires a clean worktree; commit changes or use --allow-dirty.\n' >&2
    exit 1
fi

gate_dir="$(mktemp -d)"
cleanup() {
    rm -rf "$gate_dir"
}
trap cleanup EXIT

printf '==> Bash syntax\n'
shell_files=()
while IFS= read -r -d '' path; do
    shell_files+=("$path")
done < <(find "$project_root" -path "$project_root/.git" -prune -o -type f -name '*.sh' -print0)
bash -n "${shell_files[@]}"

if command -v shellcheck >/dev/null 2>&1; then
    printf '==> ShellCheck\n'
    shellcheck "${shell_files[@]}"
else
    printf '==> ShellCheck skipped (not installed)\n'
fi

printf '==> Bash aggregate tests\n'
bash "$project_root/tests/test_aagent.sh"

if command -v pwsh >/dev/null 2>&1; then
    printf '==> PowerShell syntax\n'
    # shellcheck disable=SC2016 # This block is evaluated by PowerShell, not Bash.
    AAGENT_GATE_ROOT="$project_root" pwsh -NoLogo -NoProfile -Command '
        $ErrorActionPreference = "Stop"
        foreach ($file in Get-ChildItem -LiteralPath $env:AAGENT_GATE_ROOT -Filter *.ps1 -File -Recurse) {
            $tokens = $null
            $errors = $null
            [Management.Automation.Language.Parser]::ParseFile(
                $file.FullName,
                [ref] $tokens,
                [ref] $errors
            ) | Out-Null
            if ($errors.Count -gt 0) {
                throw "PowerShell syntax check failed for $($file.FullName): $($errors -join "; ")"
            }
        }
    '

    printf '==> PowerShell aggregate tests\n'
    pwsh -NoLogo -NoProfile -File "$project_root/tests/test_aagent.ps1"
else
    printf '==> PowerShell tests skipped (pwsh not installed)\n'
fi

printf '==> Documentation and local links\n'
bash "$project_root/tests/test_docs.sh"
if command -v pwsh >/dev/null 2>&1; then
    pwsh -NoLogo -NoProfile -File "$project_root/tests/test_docs.ps1"
fi

printf '==> Clean-room Bash installation\n'
version_output="$(bash "$project_root/aagent.sh" --version)"
version="${version_output#aagent }"
bash_home="$gate_dir/bash home"
bash_install="$gate_dir/bash bin"
mkdir -p "$bash_home" "$bash_install"
AAGENT_SOURCE="$project_root/aagent.sh" \
AAGENT_EXPECTED_VERSION="$version" \
HOME="$bash_home" INSTALL_DIR="$bash_install" \
    bash "$project_root/install.sh" >/dev/null
[[ -x "$bash_install/aagent" ]]
"$bash_install/aagent" --help >/dev/null
[[ "$("$bash_install/aagent" --version)" == "$version_output" ]]

missing_dir="$gate_dir/missing providers"
provider_overrides=(
    "AAGENT_CLAUDE_BIN=$missing_dir/claude"
    "AAGENT_CODEX_BIN=$missing_dir/codex"
    "AAGENT_OPENCODE_BIN=$missing_dir/opencode"
    "AAGENT_COPILOT_BIN=$missing_dir/copilot"
    "AAGENT_AMP_BIN=$missing_dir/amp"
    "AAGENT_GEMINI_BIN=$missing_dir/gemini"
)
env HOME="$bash_home" XDG_CONFIG_HOME="$gate_dir/bash config" \
    "${provider_overrides[@]}" "$bash_install/aagent" providers >/dev/null

if command -v pwsh >/dev/null 2>&1; then
    printf '==> Clean-room PowerShell installation\n'
    powershell_home="$gate_dir/powershell home"
    powershell_install="$gate_dir/powershell bin"
    powershell_appdata="$gate_dir/powershell appdata"
    mkdir -p "$powershell_home" "$powershell_install" "$powershell_appdata"
    AAGENT_SOURCE="$project_root/aagent.ps1" \
    AAGENT_EXPECTED_VERSION="$version" \
    HOME="$powershell_home" INSTALL_DIR="$powershell_install" \
        pwsh -NoLogo -NoProfile -File "$project_root/install.ps1" >/dev/null
    pwsh -NoLogo -NoProfile -File "$powershell_install/aagent.ps1" --help >/dev/null
    powershell_version="$(
        pwsh -NoLogo -NoProfile -File "$powershell_install/aagent.ps1" --version | tr -d '\r'
    )"
    [[ "$powershell_version" == "$version_output" ]]
    env HOME="$powershell_home" APPDATA="$powershell_appdata" \
        "${provider_overrides[@]}" pwsh -NoLogo -NoProfile \
        -File "$powershell_install/aagent.ps1" providers >/dev/null
fi

printf '==> Repository diff checks\n'
git -C "$project_root" diff --check
if (( allow_dirty == 0 )) && [[ -n "$(git -C "$project_root" status --porcelain)" ]]; then
    printf 'aagent release gate left the worktree dirty.\n' >&2
    exit 1
fi

printf 'Release gate passed for %s.\n' "$version_output"
