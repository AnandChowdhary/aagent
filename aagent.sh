#!/usr/bin/env bash

set -euo pipefail

print_help() {
    cat <<'EOF'
aagent
Run any CLI coding agent with a single command.

Usage:
  aagent [options]

Options:
  -h, --help  Show this help message
EOF
}

case "${1:-}" in
    ""|-h|--help)
        print_help
        ;;
    *)
        printf 'aagent: unknown argument: %s\n' "$1" >&2
        printf "Try 'aagent --help' for more information.\n" >&2
        exit 1
        ;;
esac
