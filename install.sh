#!/usr/bin/env bash

set -euo pipefail

install_dir="${INSTALL_DIR:-${HOME}/.local/bin}"
agent_source="${AGENT_SOURCE:-https://raw.githubusercontent.com/AnandChowdhary/agent/main/agent.sh}"
target_path="${install_dir}/agent"

printf 'Installing Agent...\n'
mkdir -p "$install_dir"

if [[ -f "$agent_source" ]]; then
    cp "$agent_source" "$target_path"
elif command -v curl >/dev/null 2>&1; then
    curl -fsSL "$agent_source" -o "$target_path"
else
    printf 'Agent requires curl to install.\n' >&2
    exit 1
fi

chmod +x "$target_path"
printf 'Installed Agent to %s\n' "$target_path"

if [[ ":${PATH}:" != *":${install_dir}:"* ]]; then
    printf 'Add %s to your PATH to run agent from anywhere.\n' "$install_dir"
fi

printf "Run 'agent --help' to get started.\n"
