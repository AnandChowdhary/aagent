#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
package_script="$project_root/scripts/package-release.sh"
release_workflow="$project_root/.github/workflows/release.yml"
test_dir="$(mktemp -d)"

cleanup() {
    rm -rf "$test_dir"
}
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_file_contains() {
    grep -Fq -- "$2" "$1" || fail "$3"
}

release_dir="$test_dir/release assets"
bash "$package_script" "$release_dir" v0.1.0 >/dev/null

expected_assets=(SHA256SUMS aagent.ps1 aagent.sh install.ps1 install.sh)
actual_assets="$(find "$release_dir" -maxdepth 1 -type f -exec basename {} \; | sort | tr '\n' ' ')"
[[ "$actual_assets" == "${expected_assets[*]} " ]] || fail "release asset set differs"
cmp "$project_root/SHA256SUMS" "$release_dir/SHA256SUMS" || fail "packaged checksum manifest differs"
for asset in aagent.sh aagent.ps1 install.sh install.ps1; do
    cmp "$project_root/$asset" "$release_dir/$asset" || fail "packaged $asset differs"
done

set +e
bash "$package_script" "$test_dir/bad-tag" v9.9.9 >"$test_dir/bad-tag.stdout" 2>"$test_dir/bad-tag.stderr"
bad_tag_status=$?
set -e
[[ "$bad_tag_status" == 1 ]] || fail "mismatched release tag did not fail"
assert_file_contains "$test_dir/bad-tag.stderr" \
    "does not match version 0.1.0" "mismatched release tag diagnostic differs"

# shellcheck disable=SC2016 # GitHub evaluates this expression, not Bash.
workflow_contract=(
    'tags: ["v*"]'
    'Release Bash (${{ matrix.os }})'
    'Release PowerShell (windows-latest)'
    'Exact release gate (ubuntu-latest)'
    'gh release create'
    'AAGENT_DOWNLOAD_BASE_URL'
    'AAGENT_EXPECTED_VERSION'
    'aagent providers'
    'say hello'
    '--prerelease=false'
)
for contract in "${workflow_contract[@]}"; do
    assert_file_contains "$release_workflow" "$contract" \
        "release workflow omitted contract: $contract"
done

# shellcheck disable=SC2016 # README documents the literal shell variable.
assert_file_contains "$project_root/README.md" \
    'releases/download/v${AAGENT_VERSION}' "README omitted version-pinned release installation"
assert_file_contains "$project_root/docs/releases/v0.1.0.md" \
    'No paid or model prompts were sent' "release notes overstate live-provider coverage"

printf 'Release packaging Bash tests passed.\n'
