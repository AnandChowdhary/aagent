#!/usr/bin/env bash

set -euo pipefail

aagent_installer_sha256() {
    local path="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$path" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$path" | awk '{print $1}'
    else
        printf 'aagent installer requires sha256sum or shasum for remote installs.\n' >&2
        return 1
    fi
}

aagent_installer_expected_checksum() {
    local checksum_path="$1"
    local asset_name="$2"
    local checksum filename extra expected=""

    while IFS=' ' read -r checksum filename extra; do
        checksum="${checksum%$'\r'}"
        filename="${filename%$'\r'}"
        extra="${extra%$'\r'}"
        [[ -z "$extra" ]] || continue
        filename="${filename#\*}"
        if [[ "$filename" == "$asset_name" && "$checksum" =~ ^[0-9A-Fa-f]{64}$ ]]; then
            [[ -z "$expected" ]] || {
                printf 'aagent installer found duplicate checksums for %s.\n' "$asset_name" >&2
                return 1
            }
            expected="$checksum"
        fi
    done < "$checksum_path"

    if [[ -z "$expected" ]]; then
        printf 'aagent installer could not find a checksum for %s.\n' "$asset_name" >&2
        return 1
    fi
    printf '%s\n' "$expected" | tr '[:upper:]' '[:lower:]'
}

aagent_installer_download() {
    local url="$1"
    local destination="$2"
    if ! command -v curl >/dev/null 2>&1; then
        printf 'aagent installer requires curl for remote installs.\n' >&2
        return 1
    fi
    curl -fsSL "$url" -o "$destination"
}

aagent_installer_verify_runner() {
    local path="$1"
    local expected_version="${AAGENT_EXPECTED_VERSION-}"
    local version_output

    bash "$path" --help >/dev/null
    version_output="$(bash "$path" --version)"
    if [[ ! "$version_output" =~ ^aagent[[:space:]][^[:space:]]+$ ]]; then
        printf 'aagent installer downloaded a runner with an invalid version response.\n' >&2
        return 1
    fi
    if [[ -n "$expected_version" && "$version_output" != "aagent $expected_version" ]]; then
        printf 'aagent installer expected version %s but downloaded %s.\n' \
            "$expected_version" "${version_output#aagent }" >&2
        return 1
    fi
}

aagent_install() (
    local install_dir="${INSTALL_DIR-}"
    local download_base_url="${AAGENT_DOWNLOAD_BASE_URL:-https://raw.githubusercontent.com/AnandChowdhary/aagent/main}"
    local source="${AAGENT_SOURCE:-${download_base_url}/aagent.sh}"
    local checksum_source="${AAGENT_CHECKSUM_SOURCE:-${download_base_url}/SHA256SUMS}"
    local target_path="${install_dir}/aagent"
    local staged_runner=""
    local staged_checksums=""
    local source_is_local=0
    local expected_checksum actual_checksum

    if [[ -z "$install_dir" ]]; then
        : "${HOME:?HOME is required unless INSTALL_DIR is set}"
        install_dir="${HOME}/.local/bin"
    fi

    printf 'Installing aagent...\n'
    mkdir -p "$install_dir"
    staged_runner="$(mktemp "${install_dir}/.aagent.XXXXXX")"
    staged_checksums="$(mktemp "${install_dir}/.aagent-checksums.XXXXXX")"

    # shellcheck disable=SC2329 # Invoked indirectly by the EXIT trap.
    aagent_installer_cleanup() {
        rm -f -- "$staged_runner" "$staged_checksums"
    }
    trap aagent_installer_cleanup EXIT

    if [[ -f "$source" ]]; then
        source_is_local=1
        cp -- "$source" "$staged_runner"
    else
        aagent_installer_download "$source" "$staged_runner"
        aagent_installer_download "$checksum_source" "$staged_checksums"
    fi

    if (( source_is_local == 0 )); then
        expected_checksum="$(aagent_installer_expected_checksum "$staged_checksums" aagent.sh)"
        actual_checksum="$(aagent_installer_sha256 "$staged_runner")"
        if [[ "$actual_checksum" != "$expected_checksum" ]]; then
            printf 'aagent installer checksum verification failed for aagent.sh.\n' >&2
            return 1
        fi
    fi

    chmod 755 "$staged_runner"
    aagent_installer_verify_runner "$staged_runner"
    mv -f -- "$staged_runner" "$target_path"
    staged_runner=""

    printf 'Installed aagent to %s\n' "$target_path"
    if [[ ":${PATH}:": != *":${install_dir}:"* ]]; then
        printf 'Add %s to your PATH to run aagent from anywhere.\n' "$install_dir"
    fi
    printf "Run 'aagent --help' to get started.\n"
)

if [[ -z "${BASH_SOURCE[0]:-}" || "${BASH_SOURCE[0]}" == "$0" ]]; then
    aagent_install
fi
