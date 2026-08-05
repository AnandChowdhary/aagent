#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if (( $# < 1 || $# > 2 )); then
    printf 'Usage: package-release.sh OUTPUT_DIRECTORY [TAG]\n' >&2
    exit 64
fi

output_dir="$1"
release_tag="${2-}"
version_output="$(bash "$project_root/aagent.sh" --version)"
version="${version_output#aagent }"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'aagent release version must be stable SemVer, got %s.\n' "$version" >&2
    exit 1
fi

expected_tag="v$version"
if [[ -n "$release_tag" && "$release_tag" != "$expected_tag" ]]; then
    printf 'aagent release tag %s does not match version %s.\n' "$release_tag" "$version" >&2
    exit 1
fi

if command -v pwsh >/dev/null 2>&1; then
    powershell_version="$(
        pwsh -NoLogo -NoProfile -File "$project_root/aagent.ps1" --version | tr -d '\r'
    )"
    if [[ "$powershell_version" != "$version_output" ]]; then
        printf 'aagent Bash and PowerShell release versions differ.\n' >&2
        exit 1
    fi
fi

release_notes="$project_root/docs/releases/$expected_tag.md"
if [[ ! -f "$release_notes" ]]; then
    printf 'aagent release notes are missing: %s\n' "$release_notes" >&2
    exit 1
fi

sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        printf 'aagent release packaging requires sha256sum or shasum.\n' >&2
        return 1
    fi
}

release_assets=(aagent.sh aagent.ps1 install.sh install.ps1)
checksum_lines=0
while IFS=' ' read -r checksum filename extra; do
    checksum="${checksum%$'\r'}"
    filename="${filename%$'\r'}"
    extra="${extra%$'\r'}"
    [[ -n "$checksum" && -n "$filename" && -z "$extra" ]] || {
        printf 'aagent release checksum manifest contains an invalid line.\n' >&2
        exit 1
    }
    filename="${filename#\*}"
    [[ "$checksum" =~ ^[0-9A-Fa-f]{64}$ ]] || {
        printf 'aagent release checksum for %s is invalid.\n' "$filename" >&2
        exit 1
    }
    asset_known=0
    for asset in "${release_assets[@]}"; do
        if [[ "$filename" == "$asset" ]]; then
            asset_known=1
            break
        fi
    done
    if (( asset_known == 0 )); then
        printf 'aagent release checksum manifest contains unexpected asset %s.\n' "$filename" >&2
        exit 1
    fi
    checksum_lines=$((checksum_lines + 1))
done < "$project_root/SHA256SUMS"

if (( checksum_lines != ${#release_assets[@]} )); then
    printf 'aagent release checksum manifest must contain exactly %s assets.\n' \
        "${#release_assets[@]}" >&2
    exit 1
fi

for asset in "${release_assets[@]}"; do
    matches="$(awk -v name="$asset" '$2 == name || $2 == "*" name { print tolower($1) }' "$project_root/SHA256SUMS")"
    if [[ -z "$matches" || "$matches" == *$'\n'* ]]; then
        printf 'aagent release checksum manifest must contain %s exactly once.\n' "$asset" >&2
        exit 1
    fi
    actual_checksum="$(sha256_file "$project_root/$asset")"
    if [[ "$actual_checksum" != "$matches" ]]; then
        printf 'aagent release checksum differs for %s.\n' "$asset" >&2
        exit 1
    fi
done

mkdir -p "$output_dir"
for asset in "${release_assets[@]}"; do
    cp "$project_root/$asset" "$output_dir/$asset"
done
cp "$project_root/SHA256SUMS" "$output_dir/SHA256SUMS"

printf 'Packaged aagent %s release assets in %s.\n' "$version" "$output_dir"
