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
        *:--version:*)
            kind="probe"
            ;;
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
delay_pid=""

# shellcheck disable=SC2317,SC2329 # Invoked indirectly by the EXIT trap.
cleanup() {
    rm -f "$stdin_file"
    if [[ -n "$delay_pid" ]] && kill -0 "$delay_pid" 2>/dev/null; then
        kill "$delay_pid" 2>/dev/null || true
        wait "$delay_pid" 2>/dev/null || true
    fi
}
trap cleanup EXIT

if [[ -t 0 ]]; then
    : > "$stdin_file"
else
    cat > "$stdin_file"
fi

{
    printf 'protocol=1\n'
    printf 'pid=%s\n' "$$"
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

output_bytes=0
if [[ "$kind" == "probe" ]]; then
    delay="${AAGENT_FAKE_PROBE_DELAY:-0}"
    stdout="${AAGENT_FAKE_PROBE_STDOUT:-}"
    stderr="${AAGENT_FAKE_PROBE_STDERR:-}"
    status="${AAGENT_FAKE_PROBE_STATUS:-0}"
    probe_profile=""
    case "$provider:${1:-}:${2:-}" in
        *:--version:*) probe_profile="VERSION" ;;
        claude:auth:status) probe_profile="CLAUDE" ;;
        codex:app-server:*) probe_profile="CODEX_APP_SERVER" ;;
        codex:login:status) probe_profile="CODEX_LOGIN" ;;
        opencode:auth:list) probe_profile="OPENCODE" ;;
    esac
    if [[ -n "$probe_profile" ]]; then
        delay_name="AAGENT_FAKE_${probe_profile}_DELAY"
        stdout_name="AAGENT_FAKE_${probe_profile}_STDOUT"
        stderr_name="AAGENT_FAKE_${probe_profile}_STDERR"
        status_name="AAGENT_FAKE_${probe_profile}_STATUS"
        bytes_name="AAGENT_FAKE_${probe_profile}_BYTES"
        if [[ -n "${!delay_name+x}" ]]; then delay="${!delay_name}"; fi
        if [[ -n "${!stdout_name+x}" ]]; then stdout="${!stdout_name}"; fi
        if [[ -n "${!stderr_name+x}" ]]; then stderr="${!stderr_name}"; fi
        if [[ -n "${!status_name+x}" ]]; then status="${!status_name}"; fi
        if [[ -n "${!bytes_name+x}" ]]; then output_bytes="${!bytes_name}"; fi
    fi
    output_bytes="${output_bytes:-${AAGENT_FAKE_PROBE_BYTES:-0}}"
else
    delay="${AAGENT_FAKE_RUN_DELAY:-0}"
    stdout="${AAGENT_FAKE_RUN_STDOUT:-}"
    stderr="${AAGENT_FAKE_RUN_STDERR:-}"
    status="${AAGENT_FAKE_RUN_STATUS:-0}"
fi

if [[ "$delay" != "0" ]]; then
    sleep "$delay" &
    delay_pid=$!
    wait "$delay_pid"
    delay_pid=""
fi

if [[ "$output_bytes" =~ ^[0-9]+$ ]] && (( output_bytes > 0 )); then
    head -c "$output_bytes" /dev/zero | tr '\0' x
fi
printf '%s' "$stdout"
printf '%s' "$stderr" >&2

if [[ ! "$status" =~ ^[0-9]+$ ]] || (( status > 255 )); then
    printf 'fake-provider: invalid exit status: %s\n' "$status" >&2
    exit 64
fi

exit "$status"
