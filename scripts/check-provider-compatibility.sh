#!/usr/bin/env bash

set -euo pipefail

compat_usage() {
    printf 'Usage: check-provider-compatibility.sh PROVIDER [EXECUTABLE]\n' >&2
}

compat_fail() {
    printf 'aagent compatibility: %s\n' "$1" >&2
    exit 1
}

compat_capture() {
    local label="$1"
    shift
    local output

    if ! output="$("$@" 2>&1)"; then
        compat_fail "$AAGENT_COMPAT_PROVIDER $label command failed"
    fi
    [[ -n "$output" ]] || compat_fail "$AAGENT_COMPAT_PROVIDER $label output was empty"

    AAGENT_COMPAT_LAST_OUTPUT="$output"
    {
        printf '## %s\n' "$label"
        printf '%s\n\n' "$output"
    } >>"$AAGENT_COMPAT_REPORT"
}

compat_require() {
    local label="$1"
    local value="$2"
    local required="$3"

    grep -Fq -- "$required" <<<"$value" || \
        compat_fail "$AAGENT_COMPAT_PROVIDER $label no longer advertises $required"
}

compat_require_version() {
    grep -Eq '[0-9]' <<<"$1" || \
        compat_fail "$AAGENT_COMPAT_PROVIDER version output did not contain a number"
}

if (( $# < 1 || $# > 2 )); then
    compat_usage
    exit 64
fi

readonly AAGENT_COMPAT_PROVIDER="$1"
case "$AAGENT_COMPAT_PROVIDER" in
    claude|codex|opencode|copilot|amp|gemini|cursor|droid) ;;
    *)
        compat_usage
        printf 'aagent compatibility: unknown supported provider: %s\n' "$AAGENT_COMPAT_PROVIDER" >&2
        exit 64
        ;;
esac

if (( $# == 2 )); then
    AAGENT_COMPAT_EXECUTABLE="$2"
else
    AAGENT_COMPAT_COMMAND="$AAGENT_COMPAT_PROVIDER"
    if [[ "$AAGENT_COMPAT_PROVIDER" == "cursor" ]]; then
        AAGENT_COMPAT_COMMAND="agent"
    fi
    AAGENT_COMPAT_EXECUTABLE="$(command -v "$AAGENT_COMPAT_COMMAND" || true)"
fi
[[ -n "$AAGENT_COMPAT_EXECUTABLE" ]] || \
    compat_fail "$AAGENT_COMPAT_PROVIDER executable was not found"
[[ -x "$AAGENT_COMPAT_EXECUTABLE" ]] || \
    compat_fail "$AAGENT_COMPAT_PROVIDER executable is not runnable: $AAGENT_COMPAT_EXECUTABLE"

readonly AAGENT_COMPAT_OUTPUT_DIR="${AAGENT_COMPAT_OUTPUT_DIR:-${TMPDIR:-/tmp}/aagent-compatibility}"
mkdir -p "$AAGENT_COMPAT_OUTPUT_DIR"
readonly AAGENT_COMPAT_REPORT="$AAGENT_COMPAT_OUTPUT_DIR/$AAGENT_COMPAT_PROVIDER.txt"
: >"$AAGENT_COMPAT_REPORT"

compat_capture version "$AAGENT_COMPAT_EXECUTABLE" --version
compat_require_version "$AAGENT_COMPAT_LAST_OUTPUT"

case "$AAGENT_COMPAT_PROVIDER" in
    claude)
        compat_capture help "$AAGENT_COMPAT_EXECUTABLE" --help
        compat_require help "$AAGENT_COMPAT_LAST_OUTPUT" "--print"
        compat_require help "$AAGENT_COMPAT_LAST_OUTPUT" "--model"
        compat_capture auth-help "$AAGENT_COMPAT_EXECUTABLE" auth --help
        compat_require auth-help "$AAGENT_COMPAT_LAST_OUTPUT" "status"
        ;;
    codex)
        compat_capture help "$AAGENT_COMPAT_EXECUTABLE" --help
        compat_require help "$AAGENT_COMPAT_LAST_OUTPUT" "exec"
        compat_capture exec-help "$AAGENT_COMPAT_EXECUTABLE" exec --help
        compat_require exec-help "$AAGENT_COMPAT_LAST_OUTPUT" "--model"
        compat_capture app-server-help "$AAGENT_COMPAT_EXECUTABLE" app-server --help
        compat_capture login-help "$AAGENT_COMPAT_EXECUTABLE" login --help
        compat_require login-help "$AAGENT_COMPAT_LAST_OUTPUT" "status"
        ;;
    opencode)
        compat_capture help "$AAGENT_COMPAT_EXECUTABLE" --help
        compat_require help "$AAGENT_COMPAT_LAST_OUTPUT" "run"
        compat_capture run-help "$AAGENT_COMPAT_EXECUTABLE" run --help
        compat_require run-help "$AAGENT_COMPAT_LAST_OUTPUT" "--model"
        compat_require run-help "$AAGENT_COMPAT_LAST_OUTPUT" "--format"
        compat_capture auth-help "$AAGENT_COMPAT_EXECUTABLE" auth --help
        compat_require auth-help "$AAGENT_COMPAT_LAST_OUTPUT" "list"
        ;;
    copilot)
        compat_capture help "$AAGENT_COMPAT_EXECUTABLE" --help
        compat_require help "$AAGENT_COMPAT_LAST_OUTPUT" "--prompt"
        compat_require help "$AAGENT_COMPAT_LAST_OUTPUT" "--model"
        compat_require help "$AAGENT_COMPAT_LAST_OUTPUT" "--silent"
        compat_require help "$AAGENT_COMPAT_LAST_OUTPUT" "--no-ask-user"
        compat_capture providers-help "$AAGENT_COMPAT_EXECUTABLE" help providers
        compat_require providers-help "$AAGENT_COMPAT_LAST_OUTPUT" "COPILOT_PROVIDER_BASE_URL"
        ;;
    amp)
        compat_capture help "$AAGENT_COMPAT_EXECUTABLE" --help
        compat_require help "$AAGENT_COMPAT_LAST_OUTPUT" "--execute"
        compat_require help "$AAGENT_COMPAT_LAST_OUTPUT" "--stream-json"
        ;;
    gemini)
        compat_capture help "$AAGENT_COMPAT_EXECUTABLE" --help
        compat_require help "$AAGENT_COMPAT_LAST_OUTPUT" "--prompt"
        compat_require help "$AAGENT_COMPAT_LAST_OUTPUT" "--model"
        ;;
    cursor)
        compat_capture help "$AAGENT_COMPAT_EXECUTABLE" --help
        compat_require help "$AAGENT_COMPAT_LAST_OUTPUT" "Start the Cursor Agent"
        compat_require help "$AAGENT_COMPAT_LAST_OUTPUT" "--print"
        compat_require help "$AAGENT_COMPAT_LAST_OUTPUT" "--output-format"
        compat_require help "$AAGENT_COMPAT_LAST_OUTPUT" "--model"
        compat_require help "$AAGENT_COMPAT_LAST_OUTPUT" "--force"
        compat_capture status-help "$AAGENT_COMPAT_EXECUTABLE" status --help
        compat_require status-help "$AAGENT_COMPAT_LAST_OUTPUT" "--format"
        ;;
    droid)
        compat_capture help "$AAGENT_COMPAT_EXECUTABLE" --help
        compat_require help "$AAGENT_COMPAT_LAST_OUTPUT" "exec"
        compat_capture exec-help "$AAGENT_COMPAT_EXECUTABLE" exec --help
        compat_require exec-help "$AAGENT_COMPAT_LAST_OUTPUT" "--output-format"
        compat_require exec-help "$AAGENT_COMPAT_LAST_OUTPUT" "--model"
        compat_require exec-help "$AAGENT_COMPAT_LAST_OUTPUT" "--use-spec"
        compat_require exec-help "$AAGENT_COMPAT_LAST_OUTPUT" "--auto"
        compat_require exec-help "$AAGENT_COMPAT_LAST_OUTPUT" "--skip-permissions-unsafe"
        compat_require exec-help "$AAGENT_COMPAT_LAST_OUTPUT" "Read-only mode"
        ;;
esac

printf 'Provider compatibility check passed for %s.\n' "$AAGENT_COMPAT_PROVIDER"
