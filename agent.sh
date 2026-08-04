#!/usr/bin/env bash

set -euo pipefail

print_help() {
    cat <<'EOF'
Agent
Run any CLI coding agent with a single command.

Usage:
  agent [options]

Options:
  -h, --help  Show this help message
EOF
}

case "${1:-}" in
    ""|-h|--help)
        print_help
        ;;
    *)
        printf 'agent: unknown argument: %s\n' "$1" >&2
        printf "Try 'agent --help' for more information.\n" >&2
        exit 1
        ;;
esac
