#!/usr/bin/env bash

set -euo pipefail

# The full status vocabulary is defined up front and used as phases land.
# shellcheck disable=SC2034
readonly \
    AAGENT_EXIT_OK=0 \
    AAGENT_EXIT_USAGE=64 \
    AAGENT_EXIT_UNAVAILABLE=69 \
    AAGENT_EXIT_SOFTWARE=70 \
    AAGENT_EXIT_CONFIG=78

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
        exit "$AAGENT_EXIT_USAGE"
        ;;
esac
