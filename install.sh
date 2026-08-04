#!/usr/bin/env bash

set -euo pipefail

install_dir="${INSTALL_DIR:-${HOME}/.local/bin}"
aagent_source="${AAGENT_SOURCE:-https://raw.githubusercontent.com/AnandChowdhary/aagent/main/aagent.sh}"
target_path="${install_dir}/aagent"

printf 'Installing aagent...\n'
mkdir -p "$install_dir"

if [[ -f "$aagent_source" ]]; then
    cp "$aagent_source" "$target_path"
elif command -v curl >/dev/null 2>&1; then
    curl -fsSL "$aagent_source" -o "$target_path"
else
    printf 'aagent requires curl to install.\n' >&2
    exit 1
fi

chmod +x "$target_path"
printf 'Installed aagent to %s\n' "$target_path"

if [[ ":${PATH}:" != *":${install_dir}:"* ]]; then
    printf 'Add %s to your PATH to run aagent from anywhere.\n' "$install_dir"
fi

printf "Run 'aagent --help' to get started.\n"
