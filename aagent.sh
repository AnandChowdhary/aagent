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
