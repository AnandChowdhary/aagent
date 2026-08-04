#!/usr/bin/env bash

set -euo pipefail

: "${AAGENT_FAKE_RECORD_DIR:?AAGENT_FAKE_RECORD_DIR is required}"

mkdir -p "$AAGENT_FAKE_RECORD_DIR"

hex_stream() {
    od -An -v -tx1 | tr -d ' \n'
}

hex_string() {
    printf '%s' "$1" | hex_stream
}

provider="${AAGENT_FAKE_PROVIDER:-$(basename "$0")}"
provider="${provider%.sh}"
provider="${provider%.ps1}"

kind="${AAGENT_FAKE_INVOCATION_KIND:-}"
if [[ -z "$kind" ]]; then
    case "$provider:${1:-}:${2:-}" in
        claude:auth:status|codex:login:status|opencode:auth:list)
            kind="probe"
            ;;
        codex:app-server:*)
            kind="probe"
            ;;
        *)
            kind="run"
            ;;
    esac
fi

case "$kind" in
    run|probe) ;;
    *)
        printf 'fake-provider: invalid invocation kind: %s\n' "$kind" >&2
        exit 64
        ;;
esac

counter_file="$AAGENT_FAKE_RECORD_DIR/$kind.count"
count=0
if [[ -f "$counter_file" ]]; then
    IFS= read -r count < "$counter_file"
fi
count=$((count + 1))
printf '%s\n' "$count" > "$counter_file"

record_file="$AAGENT_FAKE_RECORD_DIR/$provider.$kind.$count.record"
stdin_file="$AAGENT_FAKE_RECORD_DIR/.stdin.$$.tmp"
trap 'rm -f "$stdin_file"' EXIT

if [[ -t 0 ]]; then
    : > "$stdin_file"
else
    cat > "$stdin_file"
fi

{
    printf 'protocol=1\n'
    printf 'provider.hex=%s\n' "$(hex_string "$provider")"
    printf 'kind=%s\n' "$kind"
    printf 'cwd.hex=%s\n' "$(hex_string "$PWD")"
    printf 'argc=%s\n' "$#"

    argument_index=0
    for argument in "$@"; do
        printf 'arg.%s.hex=%s\n' "$argument_index" "$(hex_string "$argument")"
        argument_index=$((argument_index + 1))
    done

    printf 'stdin.hex=%s\n' "$(hex_stream < "$stdin_file")"

    presence_list="${AAGENT_FAKE_ENV_PRESENCE:-}"
    if [[ -n "$presence_list" ]]; then
        old_ifs="$IFS"
        IFS=','
        read -r -a presence_names <<< "$presence_list"
        IFS="$old_ifs"
        for name in "${presence_names[@]}"; do
            if [[ "$name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
                if printenv "$name" >/dev/null 2>&1; then
                    printf 'env.%s=present\n' "$name"
                else
                    printf 'env.%s=absent\n' "$name"
                fi
            fi
        done
    fi

    capture_list="${AAGENT_FAKE_ENV_CAPTURE:-}"
    if [[ -n "$capture_list" ]]; then
        old_ifs="$IFS"
        IFS=','
        read -r -a capture_names <<< "$capture_list"
        IFS="$old_ifs"
        for name in "${capture_names[@]}"; do
            if [[ "$name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
                if printenv "$name" >/dev/null 2>&1; then
                    value="${!name}"
                    printf 'env.%s.hex=%s\n' "$name" "$(hex_string "$value")"
                else
                    printf 'env.%s.hex=ABSENT\n' "$name"
                fi
            fi
        done
    fi
} > "$record_file"

if [[ "$kind" == "probe" ]]; then
    delay="${AAGENT_FAKE_PROBE_DELAY:-0}"
    stdout="${AAGENT_FAKE_PROBE_STDOUT:-}"
    stderr="${AAGENT_FAKE_PROBE_STDERR:-}"
    status="${AAGENT_FAKE_PROBE_STATUS:-0}"
else
    delay="${AAGENT_FAKE_RUN_DELAY:-0}"
    stdout="${AAGENT_FAKE_RUN_STDOUT:-}"
    stderr="${AAGENT_FAKE_RUN_STDERR:-}"
    status="${AAGENT_FAKE_RUN_STATUS:-0}"
fi

if [[ "$delay" != "0" ]]; then
    sleep "$delay"
fi

printf '%s' "$stdout"
printf '%s' "$stderr" >&2

if [[ ! "$status" =~ ^[0-9]+$ ]] || (( status > 255 )); then
    printf 'fake-provider: invalid exit status: %s\n' "$status" >&2
    exit 64
fi

exit "$status"
