#!/usr/bin/env bash
# shellcheck disable=SC2034

set -euo pipefail

# The full status vocabulary is defined up front and used as phases land.
readonly \
    AAGENT_EXIT_OK=0 \
    AAGENT_EXIT_USAGE=64 \
    AAGENT_EXIT_UNAVAILABLE=69 \
    AAGENT_EXIT_SOFTWARE=70 \
    AAGENT_EXIT_CONFIG=78
readonly AAGENT_VERSION="0.1.0-dev"
readonly AAGENT_POPULARITY_SNAPSHOT="2026-08-04"

aagent_reset_registry() {
    AAGENT_ADAPTER_IDS=()
    AAGENT_ADAPTER_NAMES=()
    AAGENT_ADAPTER_EXECUTABLES=()
    AAGENT_ADAPTER_OVERRIDES=()
    AAGENT_ADAPTER_TIERS=()
    AAGENT_ADAPTER_COMMANDS=()
    AAGENT_ADAPTER_STDIN=()
    AAGENT_ADAPTER_MODELS=()
    AAGENT_ADAPTER_STRUCTURED=()
    AAGENT_ADAPTER_SESSIONS=()
    AAGENT_ADAPTER_SAFETY=()
    AAGENT_ADAPTER_PROBES=()
    AAGENT_ADAPTER_POPULARITY=()
    AAGENT_ADAPTER_REGISTRY_ORDER=()
}

aagent_register_adapter() {
    AAGENT_ADAPTER_IDS+=("$1")
    AAGENT_ADAPTER_NAMES+=("$2")
    AAGENT_ADAPTER_EXECUTABLES+=("$3")
    AAGENT_ADAPTER_OVERRIDES+=("$4")
    AAGENT_ADAPTER_TIERS+=("$5")
    AAGENT_ADAPTER_COMMANDS+=("$6")
    AAGENT_ADAPTER_STDIN+=("$7")
    AAGENT_ADAPTER_MODELS+=("$8")
    AAGENT_ADAPTER_STRUCTURED+=("$9")
    shift 9
    AAGENT_ADAPTER_SESSIONS+=("$1")
    AAGENT_ADAPTER_SAFETY+=("$2")
    AAGENT_ADAPTER_PROBES+=("$3")
    AAGENT_ADAPTER_POPULARITY+=("$4")
    AAGENT_ADAPTER_REGISTRY_ORDER+=("$5")
}

aagent_initialize_registry() {
    aagent_reset_registry

    aagent_register_adapter "codex" "Codex CLI" "codex" "AAGENT_CODEX_BIN" "tier1" \
        "codex exec PROMPT" "argument-and-stdin" "--model" "jsonl" "resume" \
        "Read-only sandbox by default; broader sandboxes are explicit." "app-server account/read" "1" "1"
    aagent_register_adapter "claude" "Claude Code" "claude" "AAGENT_CLAUDE_BIN" "tier1" \
        "claude --print PROMPT" "argument-and-stdin" "--model" "json,stream-json" "resume" \
        "Permission modes are native; never add --bare or a bypass." "auth status --json" "2" "2"
    aagent_register_adapter "opencode" "OpenCode" "opencode" "AAGENT_OPENCODE_BIN" "tier1" \
        "opencode run PROMPT" "argument" "--model" "json-events" "resume,fork" \
        "Native permissions may allow tools; never add --auto." "auth list" "3" "3"
    aagent_register_adapter "copilot" "GitHub Copilot CLI" "copilot" "AAGENT_COPILOT_BIN" "planned" \
        "copilot --prompt PROMPT" "argument" "--model" "none" "unknown" \
        "Automatic tool approval is explicitly privileged." "unknown" "4" "4"
    aagent_register_adapter "gemini" "Gemini CLI" "gemini" "AAGENT_GEMINI_BIN" "tier1" \
        "gemini --prompt PROMPT" "argument-and-stdin" "--model" "json,stream-json" "resume" \
        "Approval and sandbox modes are native; never add yolo." "settings selectedType" "5" "5"
    aagent_register_adapter "cline" "Cline CLI" "cline" "AAGENT_CLINE_BIN" "planned" \
        "cline PROMPT" "argument" "--model" "ndjson" "unknown" \
        "Headless use documents automatic approval behavior." "unknown" "6" "6"
    aagent_register_adapter "goose" "Goose" "goose" "AAGENT_GOOSE_BIN" "planned" \
        "goose run --text PROMPT" "argument" "provider-native" "json,stream-json" "unknown" \
        "Headless automation may use GOOSE_MODE=auto only by user choice." "provider metadata" "7" "7"
    aagent_register_adapter "aider" "Aider" "aider" "AAGENT_AIDER_BIN" "planned" \
        "aider --message PROMPT" "argument" "--model" "none" "unknown" \
        "Automatically commits changes by default." "model metadata" "8" "8"
    aagent_register_adapter "qwen" "Qwen Code" "qwen" "AAGENT_QWEN_BIN" "planned" \
        "qwen --prompt PROMPT" "argument-and-stdin" "--model" "json,stream-json" "resume" \
        "Approval modes and budgets remain native." "auth selection" "9" "9"
    aagent_register_adapter "amp" "Amp" "amp" "AAGENT_AMP_BIN" "tier1" \
        "amp --execute PROMPT" "argument-and-stdin" "none" "stream-json" "continue" \
        "Uses tools without asking by default; no portable read-only promise." "unknown" "10" "10"
    aagent_register_adapter "kimi" "Kimi Code" "kimi" "AAGENT_KIMI_BIN" "planned" \
        "kimi --prompt PROMPT" "argument" "--model" "stream-json" "unknown" \
        "Print mode uses automatic permission handling." "managed-login metadata" "11" "11"
    aagent_register_adapter "droid" "Factory Droid" "droid" "AAGENT_DROID_BIN" "planned" \
        "droid exec PROMPT" "argument" "--model" "json,stream-json,json-rpc" "unknown" \
        "Read-only spec mode by default; autonomy flags are explicit." "account metadata" "12" "12"
    aagent_register_adapter "crush" "Crush" "crush" "AAGENT_CRUSH_BIN" "planned" \
        "crush run PROMPT" "argument" "provider-native" "none" "unknown" \
        "Native permission prompts remain unless user supplies yolo." "unknown" "13" "13"
    aagent_register_adapter "vibe" "Mistral Vibe" "vibe" "AAGENT_VIBE_BIN" "planned" \
        "vibe --prompt PROMPT" "argument" "provider-native" "json,ndjson" "resume" \
        "Auto-approval, tools, and budgets remain native." "profile metadata" "14" "14"
    aagent_register_adapter "kiro" "Kiro CLI" "kiro-cli" "AAGENT_KIRO_BIN" "planned" \
        "kiro-cli chat --no-interactive PROMPT" "argument" "provider-native" "none" "unknown" \
        "Trust flags control pre-approved tools and remain explicit." "unknown" "15" "15"
    aagent_register_adapter "cursor" "Cursor CLI" "agent" "AAGENT_CURSOR_BIN" "planned" \
        "agent --print PROMPT" "argument" "--model" "json,stream-json" "resume" \
        "Changes are proposed unless the user explicitly forces them." "status --format json" "16" "16"
}

aagent_get_adapter_index() {
    local requested="$1"
    local index

    for ((index = 0; index < ${#AAGENT_ADAPTER_IDS[@]}; index++)); do
        if [[ "${AAGENT_ADAPTER_IDS[$index]}" == "$requested" ]]; then
            printf '%s\n' "$index"
            return "$AAGENT_EXIT_OK"
        fi
    done
    return "$AAGENT_EXIT_USAGE"
}

aagent_resolve_discovery_target() {
    local executable="$1"
    local override_name="$2"
    local requested="$executable"
    local candidate=""

    if [[ -n "${!override_name-}" ]]; then
        requested="${!override_name}"
        AAGENT_DISCOVERY_SOURCE="override"
    else
        AAGENT_DISCOVERY_SOURCE="path"
    fi

    if [[ "$requested" == */* ]]; then
        candidate="$requested"
    else
        candidate="$(type -P "$requested" 2>/dev/null || true)"
    fi

    if [[ -z "$candidate" || ! -f "$candidate" || ! -x "$candidate" ]]; then
        AAGENT_RESOLVED_PATH=""
        if [[ "$AAGENT_DISCOVERY_SOURCE" == "override" ]]; then
            AAGENT_DISCOVERY_REASON="invalid executable override: $override_name"
        else
            AAGENT_DISCOVERY_REASON="executable missing"
        fi
        return "$AAGENT_EXIT_UNAVAILABLE"
    fi

    if [[ -e "${BASH_SOURCE[0]}" && "$candidate" -ef "${BASH_SOURCE[0]}" ]]; then
        AAGENT_RESOLVED_PATH=""
        AAGENT_DISCOVERY_REASON="resolved target is the aagent wrapper"
        return "$AAGENT_EXIT_UNAVAILABLE"
    fi

    AAGENT_RESOLVED_PATH="$candidate"
    AAGENT_DISCOVERY_REASON="executable found"
}

aagent_discover_adapters() {
    aagent_initialize_registry
    AAGENT_DISCOVERY_STATUSES=()
    AAGENT_DISCOVERY_PATHS=()
    AAGENT_DISCOVERY_REASONS=()
    AAGENT_DISCOVERY_SOURCES=()

    local index
    local status
    for ((index = 0; index < ${#AAGENT_ADAPTER_IDS[@]}; index++)); do
        if aagent_resolve_discovery_target \
            "${AAGENT_ADAPTER_EXECUTABLES[$index]}" \
            "${AAGENT_ADAPTER_OVERRIDES[$index]}"; then
            if [[ "${AAGENT_ADAPTER_TIERS[$index]}" == "tier1" ]]; then
                status="installed"
            else
                status="unsupported"
                AAGENT_DISCOVERY_REASON="adapter planned; executable found"
            fi
        else
            status="missing"
        fi

        AAGENT_DISCOVERY_STATUSES+=("$status")
        AAGENT_DISCOVERY_PATHS+=("$AAGENT_RESOLVED_PATH")
        AAGENT_DISCOVERY_REASONS+=("$AAGENT_DISCOVERY_REASON")
        AAGENT_DISCOVERY_SOURCES+=("$AAGENT_DISCOVERY_SOURCE")
    done
}

aagent_reset_launch_plan() {
    AAGENT_LAUNCH_EXECUTABLE=""
    AAGENT_LAUNCH_ARGUMENTS=()
    AAGENT_LAUNCH_CWD=""
    AAGENT_LAUNCH_STDIN_MODE="closed"
    AAGENT_LAUNCH_STDIN=""
    AAGENT_LAUNCH_INPUT_DESCRIPTION="none"
    AAGENT_LAUNCH_ENV_SET_NAMES=()
    AAGENT_LAUNCH_ENV_SET_VALUES=()
    AAGENT_LAUNCH_ENV_UNSET_NAMES=()
    AAGENT_LAUNCH_DISPLAY_ARGUMENTS=()
    AAGENT_LAUNCH_PROVIDER=""
    AAGENT_LAUNCH_REASON=""
    AAGENT_LAUNCH_NOTICE=""
}

aagent_is_environment_name() {
    [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
}

aagent_create_launch_plan() {
    local executable="$1"
    local cwd="$2"
    local stdin_mode="$3"
    local stdin_data="$4"
    local input_description="$5"
    shift 5

    if [[ -z "$executable" || ! -f "$executable" || ! -x "$executable" ]]; then
        printf 'aagent: launch executable is unavailable: %s\n' "$executable" >&2
        return "$AAGENT_EXIT_SOFTWARE"
    fi
    if [[ -z "$cwd" || ! -d "$cwd" ]]; then
        printf 'aagent: launch working directory is unavailable: %s\n' "$cwd" >&2
        return "$AAGENT_EXIT_SOFTWARE"
    fi
    case "$stdin_mode" in
        inherit|closed|data) ;;
        *)
            printf 'aagent: invalid launch stdin mode: %s\n' "$stdin_mode" >&2
            return "$AAGENT_EXIT_SOFTWARE"
            ;;
    esac
    case "$input_description" in
        argv|stdin|both|none) ;;
        *)
            printf 'aagent: invalid launch input description: %s\n' "$input_description" >&2
            return "$AAGENT_EXIT_SOFTWARE"
            ;;
    esac

    aagent_reset_launch_plan
    AAGENT_LAUNCH_EXECUTABLE="$executable"
    AAGENT_LAUNCH_ARGUMENTS=("$@")
    AAGENT_LAUNCH_CWD="$cwd"
    AAGENT_LAUNCH_STDIN_MODE="$stdin_mode"
    AAGENT_LAUNCH_STDIN="$stdin_data"
    AAGENT_LAUNCH_INPUT_DESCRIPTION="$input_description"

    local argument
    for argument in "$@"; do
        AAGENT_LAUNCH_DISPLAY_ARGUMENTS+=("<redacted>")
    done
}

aagent_launch_plan_set_environment() {
    local name="$1"
    local value="$2"
    if ! aagent_is_environment_name "$name"; then
        printf 'aagent: invalid child environment name: %s\n' "$name" >&2
        return "$AAGENT_EXIT_SOFTWARE"
    fi
    AAGENT_LAUNCH_ENV_SET_NAMES+=("$name")
    AAGENT_LAUNCH_ENV_SET_VALUES+=("$value")
}

aagent_launch_plan_unset_environment() {
    local name="$1"
    if ! aagent_is_environment_name "$name"; then
        printf 'aagent: invalid child environment name: %s\n' "$name" >&2
        return "$AAGENT_EXIT_SOFTWARE"
    fi
    AAGENT_LAUNCH_ENV_UNSET_NAMES+=("$name")
}

aagent_launch_plan_set_display_arguments() {
    if (( $# != ${#AAGENT_LAUNCH_ARGUMENTS[@]} )); then
        printf 'aagent: launch display argument count differs from argv\n' >&2
        return "$AAGENT_EXIT_SOFTWARE"
    fi
    AAGENT_LAUNCH_DISPLAY_ARGUMENTS=("$@")
}

aagent_quote_for_display() {
    printf '%q' "$1"
}

aagent_print_environment_names() {
    local label="$1"
    shift
    printf '%s:' "$label"
    if (( $# == 0 )); then
        printf ' (none)\n'
        return
    fi

    local name
    for name in "$@"; do
        printf ' %s' "$name"
    done
    printf '\n'
}

aagent_render_launch_plan() {
    printf 'provider: %s\n' "${AAGENT_LAUNCH_PROVIDER:-unknown}"
    printf 'reason: %s\n' "${AAGENT_LAUNCH_REASON:-not specified}"
    printf 'command: '
    aagent_quote_for_display "$AAGENT_LAUNCH_EXECUTABLE"
    local argument
    local index
    for ((index = 0; index < ${#AAGENT_LAUNCH_DISPLAY_ARGUMENTS[@]}; index++)); do
        argument="${AAGENT_LAUNCH_DISPLAY_ARGUMENTS[$index]}"
        printf ' '
        aagent_quote_for_display "$argument"
    done
    printf '\nworking directory: '
    aagent_quote_for_display "$AAGENT_LAUNCH_CWD"
    printf '\nstdin: %s\n' "$AAGENT_LAUNCH_INPUT_DESCRIPTION"
    if (( ${#AAGENT_LAUNCH_ENV_SET_NAMES[@]} > 0 )); then
        aagent_print_environment_names "set environment" "${AAGENT_LAUNCH_ENV_SET_NAMES[@]}"
    else
        aagent_print_environment_names "set environment"
    fi
    if (( ${#AAGENT_LAUNCH_ENV_UNSET_NAMES[@]} > 0 )); then
        aagent_print_environment_names "unset environment" "${AAGENT_LAUNCH_ENV_UNSET_NAMES[@]}"
    else
        aagent_print_environment_names "unset environment"
    fi
}

aagent_write_notice() {
    local quiet="$1"
    local message="$2"
    if [[ "$quiet" != "1" && -n "$message" ]]; then
        printf 'aagent: %s\n' "$message" >&2
    fi
}

aagent_apply_launch_environment() {
    local name
    local index

    for ((index = 0; index < ${#AAGENT_LAUNCH_ENV_UNSET_NAMES[@]}; index++)); do
        name="${AAGENT_LAUNCH_ENV_UNSET_NAMES[$index]}"
        unset "$name"
    done
    for ((index = 0; index < ${#AAGENT_LAUNCH_ENV_SET_NAMES[@]}; index++)); do
        name="${AAGENT_LAUNCH_ENV_SET_NAMES[$index]}"
        export "$name=${AAGENT_LAUNCH_ENV_SET_VALUES[$index]}"
    done
}

AAGENT_ACTIVE_CHILD_PID=""

aagent_forward_launch_signal() {
    local signal="$1"
    if [[ -n "$AAGENT_ACTIVE_CHILD_PID" ]] && kill -0 "$AAGENT_ACTIVE_CHILD_PID" 2>/dev/null; then
        kill -s "$signal" "$AAGENT_ACTIVE_CHILD_PID" 2>/dev/null || true
    fi
}

aagent_wait_for_launch_child() {
    local status
    while true; do
        if wait "$AAGENT_ACTIVE_CHILD_PID"; then
            status=0
            break
        else
            status=$?
        fi
        if ! kill -0 "$AAGENT_ACTIVE_CHILD_PID" 2>/dev/null; then
            break
        fi
    done
    AAGENT_ACTIVE_CHILD_PID=""
    return "$status"
}

aagent_execute_launch_plan() {
    local dry_run="${1:-0}"
    local quiet="${2:-0}"

    if [[ "$dry_run" == "1" ]]; then
        aagent_render_launch_plan
        return "$AAGENT_EXIT_OK"
    fi

    aagent_write_notice "$quiet" "$AAGENT_LAUNCH_NOTICE"

    case "$AAGENT_LAUNCH_STDIN_MODE" in
        data)
            (
                cd -- "$AAGENT_LAUNCH_CWD" || exit "$AAGENT_EXIT_SOFTWARE"
                aagent_apply_launch_environment
                exec "$AAGENT_LAUNCH_EXECUTABLE" \
                    "${AAGENT_LAUNCH_ARGUMENTS[@]+"${AAGENT_LAUNCH_ARGUMENTS[@]}"}"
            ) < <(printf '%s' "$AAGENT_LAUNCH_STDIN") &
            ;;
        closed)
            (
                cd -- "$AAGENT_LAUNCH_CWD" || exit "$AAGENT_EXIT_SOFTWARE"
                aagent_apply_launch_environment
                exec "$AAGENT_LAUNCH_EXECUTABLE" \
                    "${AAGENT_LAUNCH_ARGUMENTS[@]+"${AAGENT_LAUNCH_ARGUMENTS[@]}"}"
            ) </dev/null &
            ;;
        inherit)
            (
                cd -- "$AAGENT_LAUNCH_CWD" || exit "$AAGENT_EXIT_SOFTWARE"
                aagent_apply_launch_environment
                exec "$AAGENT_LAUNCH_EXECUTABLE" \
                    "${AAGENT_LAUNCH_ARGUMENTS[@]+"${AAGENT_LAUNCH_ARGUMENTS[@]}"}"
            ) <&0 &
            ;;
        *)
            printf 'aagent: invalid launch stdin mode: %s\n' "$AAGENT_LAUNCH_STDIN_MODE" >&2
            return "$AAGENT_EXIT_SOFTWARE"
            ;;
    esac

    AAGENT_ACTIVE_CHILD_PID=$!
    trap 'aagent_forward_launch_signal INT' INT
    trap 'aagent_forward_launch_signal TERM' TERM
    trap 'aagent_forward_launch_signal HUP' HUP

    local status=0
    aagent_wait_for_launch_child || status=$?

    trap - INT TERM HUP
    return "$status"
}

aagent_print_help() {
    cat <<'EOF'
aagent
Run any CLI coding agent with a single command.

Usage:
  aagent [OPTIONS] [PROMPT...]
  aagent providers
  aagent doctor [PROVIDER]
  aagent --help
  aagent --version

Options:
  -P, --provider ID     Use a specific provider
  -m, --model ID        Request a provider-native model ID
  -C, --cwd DIRECTORY   Run from this working directory
      --auth-policy P   Authentication policy: prefer-included or native
      --dry-run         Print the resolved invocation without running it
      --quiet           Do not print the provider-selection notice
  -h, --help            Show this help message
      --version         Show the aagent version
      --                Treat remaining arguments as provider-native options

Input:
  Prompt arguments are joined with one space. With no prompt, piped stdin is
  used. With both, the prompt is the instruction and stdin is extra context.

Examples:
  aagent "say hello"
  aagent --provider codex "explain this repository"
  git diff | aagent "summarize these changes"
  aagent -P codex "fix the tests" -- --sandbox workspace-write
EOF
}

aagent_print_version() {
    printf 'aagent %s\n' "$AAGENT_VERSION"
}

aagent_set_parse_error() {
    AAGENT_PARSE_ERROR="$1"
    return "$AAGENT_EXIT_USAGE"
}

aagent_reset_parse_result() {
    AAGENT_COMMAND="run"
    AAGENT_PROVIDER=""
    AAGENT_MODEL=""
    AAGENT_CWD=""
    AAGENT_AUTH_POLICY="prefer-included"
    AAGENT_DRY_RUN=0
    AAGENT_QUIET=0
    AAGENT_DOCTOR_PROVIDER=""
    AAGENT_PARSE_ERROR=""
    AAGENT_PROMPT=""
    AAGENT_STDIN=""
    AAGENT_INPUT_MODE=""
    AAGENT_PROMPT_ARGS=()
    AAGENT_NATIVE_ARGS=()
}

aagent_require_option_value() {
    local option="$1"
    local count="$2"
    local value="${3-}"

    if (( count < 2 )) || [[ -z "$value" ]]; then
        aagent_set_parse_error "option $option requires a value"
        return "$AAGENT_EXIT_USAGE"
    fi
}

aagent_resolve_cwd() {
    local requested="$1"
    local resolved

    if [[ -z "$requested" ]]; then
        AAGENT_CWD="$PWD"
        return "$AAGENT_EXIT_OK"
    fi

    if [[ ! -d "$requested" ]]; then
        aagent_set_parse_error "working directory does not exist: $requested"
        return "$AAGENT_EXIT_USAGE"
    fi

    if ! resolved="$(cd -- "$requested" 2>/dev/null && pwd -P)"; then
        aagent_set_parse_error "cannot access working directory: $requested"
        return "$AAGENT_EXIT_USAGE"
    fi

    AAGENT_CWD="$resolved"
}

aagent_parse_arguments() {
    aagent_reset_parse_result

    local token

    while (( $# > 0 )); do
        token="$1"

        case "$token" in
            -h|--help)
                AAGENT_COMMAND="help"
                return "$AAGENT_EXIT_OK"
                ;;
            --version)
                AAGENT_COMMAND="version"
                return "$AAGENT_EXIT_OK"
                ;;
            -P|--provider)
                aagent_require_option_value "$token" "$#" "${2-}" || return $?
                AAGENT_PROVIDER="$2"
                shift 2
                ;;
            -m|--model)
                aagent_require_option_value "$token" "$#" "${2-}" || return $?
                AAGENT_MODEL="$2"
                shift 2
                ;;
            -C|--cwd)
                aagent_require_option_value "$token" "$#" "${2-}" || return $?
                AAGENT_CWD="$2"
                shift 2
                ;;
            --auth-policy)
                aagent_require_option_value "$token" "$#" "${2-}" || return $?
                case "$2" in
                    prefer-included|native)
                        AAGENT_AUTH_POLICY="$2"
                        ;;
                    *)
                        aagent_set_parse_error "invalid authentication policy: $2"
                        return "$AAGENT_EXIT_USAGE"
                        ;;
                esac
                shift 2
                ;;
            --dry-run)
                AAGENT_DRY_RUN=1
                shift
                ;;
            --quiet)
                AAGENT_QUIET=1
                shift
                ;;
            --)
                shift
                AAGENT_NATIVE_ARGS=("$@")
                break
                ;;
            providers)
                if (( ${#AAGENT_PROMPT_ARGS[@]} > 0 )); then
                    AAGENT_PROMPT_ARGS+=("$token")
                    shift
                else
                    AAGENT_COMMAND="providers"
                    shift
                    if (( $# > 0 )); then
                        aagent_set_parse_error "providers does not accept arguments"
                        return "$AAGENT_EXIT_USAGE"
                    fi
                    break
                fi
                ;;
            doctor)
                if (( ${#AAGENT_PROMPT_ARGS[@]} > 0 )); then
                    AAGENT_PROMPT_ARGS+=("$token")
                    shift
                else
                    AAGENT_COMMAND="doctor"
                    shift
                    if (( $# > 1 )); then
                        aagent_set_parse_error "doctor accepts at most one provider"
                        return "$AAGENT_EXIT_USAGE"
                    fi
                    if (( $# == 1 )); then
                        if [[ "$1" == -* ]]; then
                            aagent_set_parse_error "unknown option: $1"
                            return "$AAGENT_EXIT_USAGE"
                        fi
                        AAGENT_DOCTOR_PROVIDER="$1"
                    fi
                    break
                fi
                ;;
            -*)
                aagent_set_parse_error "unknown option: $token"
                return "$AAGENT_EXIT_USAGE"
                ;;
            *)
                AAGENT_PROMPT_ARGS+=("$token")
                shift
                ;;
        esac
    done

    aagent_resolve_cwd "$AAGENT_CWD"
}

aagent_join_prompt() {
    AAGENT_PROMPT=""
    local argument
    local separator=""

    if (( ${#AAGENT_PROMPT_ARGS[@]} > 0 )); then
        for argument in "${AAGENT_PROMPT_ARGS[@]}"; do
            AAGENT_PROMPT+="$separator$argument"
            separator=" "
        done
    fi
}

aagent_resolve_input() {
    local stdin_available="$1"
    local stdin_data="$2"

    aagent_join_prompt
    AAGENT_STDIN="$stdin_data"

    if (( ${#AAGENT_PROMPT_ARGS[@]} > 0 )) && [[ -z "$AAGENT_PROMPT" ]]; then
        aagent_set_parse_error "prompt must not be empty"
        return "$AAGENT_EXIT_USAGE"
    fi

    if [[ -n "$AAGENT_PROMPT" && "$stdin_available" == "1" && -n "$AAGENT_STDIN" ]]; then
        AAGENT_INPUT_MODE="both"
    elif [[ -n "$AAGENT_PROMPT" ]]; then
        AAGENT_INPUT_MODE="prompt"
        AAGENT_STDIN=""
    elif [[ "$stdin_available" == "1" && -n "$AAGENT_STDIN" ]]; then
        AAGENT_INPUT_MODE="stdin"
    else
        aagent_set_parse_error "a non-empty prompt or piped stdin is required"
        return "$AAGENT_EXIT_USAGE"
    fi
}

aagent_read_stdin() {
    local marker=$'\036'
    local captured

    if [[ -t 0 ]]; then
        AAGENT_STDIN_AVAILABLE=0
        AAGENT_STDIN_DATA=""
        return "$AAGENT_EXIT_OK"
    fi

    if ! captured="$(cat; printf '%s' "$marker")"; then
        return "$AAGENT_EXIT_SOFTWARE"
    fi
    AAGENT_STDIN_AVAILABLE=1
    AAGENT_STDIN_DATA="${captured%"$marker"}"
}

aagent_print_usage_error() {
    printf 'aagent: %s\n' "$1" >&2
    printf "Try 'aagent --help' for more information.\n" >&2
}

aagent_main() {
    local status

    aagent_parse_arguments "$@" || {
        status=$?
        aagent_print_usage_error "$AAGENT_PARSE_ERROR"
        return "$status"
    }

    case "$AAGENT_COMMAND" in
        help)
            aagent_print_help
            return "$AAGENT_EXIT_OK"
            ;;
        version)
            aagent_print_version
            return "$AAGENT_EXIT_OK"
            ;;
        providers|doctor)
            printf 'aagent: %s is not available in this build yet\n' "$AAGENT_COMMAND" >&2
            return "$AAGENT_EXIT_UNAVAILABLE"
            ;;
    esac

    aagent_read_stdin || {
        status=$?
        printf 'aagent: failed to read stdin\n' >&2
        return "$status"
    }
    aagent_resolve_input "$AAGENT_STDIN_AVAILABLE" "$AAGENT_STDIN_DATA" || {
        status=$?
        aagent_print_usage_error "$AAGENT_PARSE_ERROR"
        return "$status"
    }

    printf 'aagent: provider discovery is not available in this build yet\n' >&2
    return "$AAGENT_EXIT_UNAVAILABLE"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    aagent_main "$@"
fi
