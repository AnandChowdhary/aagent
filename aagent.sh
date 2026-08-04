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

aagent_trim_config_whitespace() {
    local value="$1"
    value="${value#"${value%%[!$' \t']*}"}"
    value="${value%"${value##*[!$' \t']}"}"
    printf '%s' "$value"
}

aagent_resolve_config_path() {
    if [[ -n "${XDG_CONFIG_HOME-}" ]]; then
        AAGENT_CONFIG_PATH="$XDG_CONFIG_HOME/aagent/config"
    elif [[ -n "${HOME-}" ]]; then
        AAGENT_CONFIG_PATH="$HOME/.config/aagent/config"
    else
        AAGENT_CONFIG_PATH=""
    fi
}

aagent_reset_config_result() {
    AAGENT_CONFIG_PATH=""
    AAGENT_CONFIG_ERROR=""
    AAGENT_CONFIG_PROVIDER=""
    AAGENT_CONFIG_AUTH_POLICY=""
    AAGENT_CONFIG_PRIORITY=""
    AAGENT_CONFIG_ALLOW_LOCAL=""
    AAGENT_CONFIG_PROVIDER_SET=0
    AAGENT_CONFIG_AUTH_POLICY_SET=0
    AAGENT_CONFIG_PRIORITY_SET=0
    AAGENT_CONFIG_ALLOW_LOCAL_SET=0
    AAGENT_CONFIG_SEEN_KEYS=()
}

aagent_set_config_error() {
    local line_number="$1"
    local key="$2"
    local message="$3"

    if [[ -n "$line_number" && -n "$key" ]]; then
        AAGENT_CONFIG_ERROR="configuration error in $AAGENT_CONFIG_PATH at line $line_number ($key): $message"
    elif [[ -n "$line_number" ]]; then
        AAGENT_CONFIG_ERROR="configuration error in $AAGENT_CONFIG_PATH at line $line_number: $message"
    else
        AAGENT_CONFIG_ERROR="configuration error in $AAGENT_CONFIG_PATH: $message"
    fi
    printf 'aagent: %s\n' "$AAGENT_CONFIG_ERROR" >&2
    return "$AAGENT_EXIT_CONFIG"
}

aagent_config_key_was_seen() {
    local requested="$1"
    local seen
    for seen in "${AAGENT_CONFIG_SEEN_KEYS[@]+"${AAGENT_CONFIG_SEEN_KEYS[@]}"}"; do
        [[ "$seen" == "$requested" ]] && return "$AAGENT_EXIT_OK"
    done
    return 1
}

aagent_validate_priority_value() {
    local value="$1"
    local old_ifs="$IFS"
    local -a ids=()
    local -a seen=()
    local id
    local existing

    [[ -n "$value" && "$value" != ,* && "$value" != *, && "$value" != *,,* ]] || return 1
    IFS=',' read -r -a ids <<<"$value"
    IFS="$old_ifs"
    (( ${#ids[@]} > 0 )) || return 1

    for id in "${ids[@]}"; do
        id="$(aagent_trim_config_whitespace "$id")"
        [[ -n "$id" ]] || return 1
        aagent_get_adapter_index "$id" >/dev/null || return 1
        for existing in "${seen[@]+"${seen[@]}"}"; do
            [[ "$existing" != "$id" ]] || return 1
        done
        seen+=("$id")
    done
}

aagent_validate_config_value() {
    local key="$1"
    local value="$2"

    case "$key" in
        provider)
            [[ -n "$value" ]] && aagent_get_adapter_index "$value" >/dev/null
            ;;
        auth_policy)
            [[ "$value" == "prefer-included" || "$value" == "native" ]]
            ;;
        priority)
            aagent_validate_priority_value "$value"
            ;;
        allow_local)
            [[ "$value" == "true" || "$value" == "false" ]]
            ;;
        *)
            return 1
            ;;
    esac
}

aagent_read_user_config() {
    local unknown_mode="$1"
    local line=""
    local trimmed=""
    local key=""
    local value=""
    local line_number=0

    aagent_reset_config_result
    aagent_resolve_config_path
    [[ -n "$AAGENT_CONFIG_PATH" ]] || return "$AAGENT_EXIT_OK"
    [[ -e "$AAGENT_CONFIG_PATH" ]] || return "$AAGENT_EXIT_OK"
    if [[ ! -f "$AAGENT_CONFIG_PATH" || ! -r "$AAGENT_CONFIG_PATH" ]]; then
        aagent_set_config_error "" "" "configuration file is not a readable regular file"
        return "$AAGENT_EXIT_CONFIG"
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        line_number=$((line_number + 1))
        line="${line%$'\r'}"
        if (( ${#line} > 4096 )); then
            aagent_set_config_error "$line_number" "" "line exceeds 4096 characters"
            return "$AAGENT_EXIT_CONFIG"
        fi
        trimmed="$(aagent_trim_config_whitespace "$line")"
        [[ -n "$trimmed" ]] || continue
        [[ "${trimmed:0:1}" == "#" ]] && continue
        if [[ "$trimmed" != *=* ]]; then
            aagent_set_config_error "$line_number" "" "expected key=value"
            return "$AAGENT_EXIT_CONFIG"
        fi

        key="$(aagent_trim_config_whitespace "${trimmed%%=*}")"
        value="$(aagent_trim_config_whitespace "${trimmed#*=}")"
        if [[ ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
            aagent_set_config_error "$line_number" "" "invalid key name"
            return "$AAGENT_EXIT_CONFIG"
        fi
        if aagent_config_key_was_seen "$key"; then
            aagent_set_config_error "$line_number" "$key" "duplicate key"
            return "$AAGENT_EXIT_CONFIG"
        fi
        AAGENT_CONFIG_SEEN_KEYS+=("$key")

        case "$key" in
            provider|auth_policy|priority|allow_local)
                if ! aagent_validate_config_value "$key" "$value"; then
                    aagent_set_config_error "$line_number" "$key" "invalid value"
                    return "$AAGENT_EXIT_CONFIG"
                fi
                case "$key" in
                    provider)
                        AAGENT_CONFIG_PROVIDER="$value"
                        AAGENT_CONFIG_PROVIDER_SET=1
                        ;;
                    auth_policy)
                        AAGENT_CONFIG_AUTH_POLICY="$value"
                        AAGENT_CONFIG_AUTH_POLICY_SET=1
                        ;;
                    priority)
                        AAGENT_CONFIG_PRIORITY="$value"
                        AAGENT_CONFIG_PRIORITY_SET=1
                        ;;
                    allow_local)
                        AAGENT_CONFIG_ALLOW_LOCAL="$value"
                        AAGENT_CONFIG_ALLOW_LOCAL_SET=1
                        ;;
                esac
                ;;
            *)
                if [[ "$unknown_mode" == "doctor" ]]; then
                    aagent_set_config_error "$line_number" "$key" "unknown key"
                    return "$AAGENT_EXIT_CONFIG"
                fi
                printf "aagent: warning: %s line %s: unknown configuration key '%s' ignored\n" \
                    "$AAGENT_CONFIG_PATH" "$line_number" "$key" >&2
                ;;
        esac
    done <"$AAGENT_CONFIG_PATH"
}

aagent_validate_effective_config_value() {
    local key="$1"
    local value="$2"
    local source_name="$3"
    local source_kind="$4"

    if aagent_validate_config_value "$key" "$value"; then
        return "$AAGENT_EXIT_OK"
    fi
    if [[ "$source_kind" == "cli" ]]; then
        aagent_set_parse_error "invalid $source_name value"
        return "$AAGENT_EXIT_USAGE"
    fi
    printf 'aagent: invalid %s configuration\n' "$source_name" >&2
    return "$AAGENT_EXIT_CONFIG"
}

aagent_resolve_configuration() {
    local mode="${1:-normal}"

    aagent_initialize_registry
    aagent_read_user_config "$mode" || return $?

    if (( AAGENT_CLI_PROVIDER_SET )); then
        AAGENT_EFFECTIVE_PROVIDER="$AAGENT_CLI_PROVIDER"
        AAGENT_PROVIDER_SOURCE="cli"
        AAGENT_PROVIDER_SOURCE_LABEL="explicit --provider"
    elif [[ -n "${AAGENT_PROVIDER+x}" ]]; then
        AAGENT_EFFECTIVE_PROVIDER="$AAGENT_PROVIDER"
        AAGENT_PROVIDER_SOURCE="environment"
        AAGENT_PROVIDER_SOURCE_LABEL="AAGENT_PROVIDER"
        aagent_validate_effective_config_value provider "$AAGENT_EFFECTIVE_PROVIDER" \
            AAGENT_PROVIDER environment || return $?
    elif (( AAGENT_CONFIG_PROVIDER_SET )); then
        AAGENT_EFFECTIVE_PROVIDER="$AAGENT_CONFIG_PROVIDER"
        AAGENT_PROVIDER_SOURCE="config"
        AAGENT_PROVIDER_SOURCE_LABEL="user config"
    else
        AAGENT_EFFECTIVE_PROVIDER=""
        AAGENT_PROVIDER_SOURCE="default"
        AAGENT_PROVIDER_SOURCE_LABEL="automatic selection"
    fi

    if (( AAGENT_CLI_AUTH_POLICY_SET )); then
        AAGENT_EFFECTIVE_AUTH_POLICY="$AAGENT_CLI_AUTH_POLICY"
        AAGENT_AUTH_POLICY_SOURCE="cli"
    elif [[ -n "${AAGENT_AUTH_POLICY+x}" ]]; then
        AAGENT_EFFECTIVE_AUTH_POLICY="$AAGENT_AUTH_POLICY"
        AAGENT_AUTH_POLICY_SOURCE="environment"
        aagent_validate_effective_config_value auth_policy "$AAGENT_EFFECTIVE_AUTH_POLICY" \
            AAGENT_AUTH_POLICY environment || return $?
    elif (( AAGENT_CONFIG_AUTH_POLICY_SET )); then
        AAGENT_EFFECTIVE_AUTH_POLICY="$AAGENT_CONFIG_AUTH_POLICY"
        AAGENT_AUTH_POLICY_SOURCE="config"
    else
        AAGENT_EFFECTIVE_AUTH_POLICY="prefer-included"
        AAGENT_AUTH_POLICY_SOURCE="default"
    fi

    if (( AAGENT_CLI_PRIORITY_SET )); then
        aagent_validate_effective_config_value priority "$AAGENT_CLI_PRIORITY" \
            --priority cli || return $?
        AAGENT_EFFECTIVE_PRIORITY="$AAGENT_CLI_PRIORITY"
        AAGENT_PRIORITY_SOURCE="cli"
    elif [[ -n "${AAGENT_PRIORITY+x}" ]]; then
        AAGENT_EFFECTIVE_PRIORITY="$AAGENT_PRIORITY"
        AAGENT_PRIORITY_SOURCE="environment"
        aagent_validate_effective_config_value priority "$AAGENT_EFFECTIVE_PRIORITY" \
            AAGENT_PRIORITY environment || return $?
    elif (( AAGENT_CONFIG_PRIORITY_SET )); then
        AAGENT_EFFECTIVE_PRIORITY="$AAGENT_CONFIG_PRIORITY"
        AAGENT_PRIORITY_SOURCE="config"
    else
        AAGENT_EFFECTIVE_PRIORITY=""
        AAGENT_PRIORITY_SOURCE="default"
    fi
    AAGENT_PRIORITY_ROLE="tie-break-only"

    if (( AAGENT_CLI_ALLOW_LOCAL_SET )); then
        AAGENT_EFFECTIVE_ALLOW_LOCAL="$AAGENT_CLI_ALLOW_LOCAL"
        AAGENT_ALLOW_LOCAL_SOURCE="cli"
    elif [[ -n "${AAGENT_ALLOW_LOCAL+x}" ]]; then
        AAGENT_EFFECTIVE_ALLOW_LOCAL="$AAGENT_ALLOW_LOCAL"
        AAGENT_ALLOW_LOCAL_SOURCE="environment"
        aagent_validate_effective_config_value allow_local "$AAGENT_EFFECTIVE_ALLOW_LOCAL" \
            AAGENT_ALLOW_LOCAL environment || return $?
    elif (( AAGENT_CONFIG_ALLOW_LOCAL_SET )); then
        AAGENT_EFFECTIVE_ALLOW_LOCAL="$AAGENT_CONFIG_ALLOW_LOCAL"
        AAGENT_ALLOW_LOCAL_SOURCE="config"
    else
        AAGENT_EFFECTIVE_ALLOW_LOCAL="false"
        AAGENT_ALLOW_LOCAL_SOURCE="default"
    fi
}

readonly AAGENT_PROBE_TIMEOUT_SECONDS=3
readonly AAGENT_PROBE_MAX_BYTES=65536

aagent_json_reset() {
    AAGENT_JSON_INPUT=""
    AAGENT_JSON_POS=0
    AAGENT_JSON_LENGTH=0
    AAGENT_JSON_ERROR=""
    AAGENT_JSON_STRING=""
    AAGENT_JSON_ALLOW_PATHS=()
    AAGENT_JSON_RESULT_PATHS=()
    AAGENT_JSON_RESULT_TYPES=()
    AAGENT_JSON_RESULT_VALUES=()
}

aagent_json_make_path() {
    local path=""
    local segment
    for segment in "$@"; do
        path+="#${#segment}:$segment"
    done
    printf '%s' "$path"
}

aagent_json_skip_whitespace() {
    local character
    while (( AAGENT_JSON_POS < AAGENT_JSON_LENGTH )); do
        character="${AAGENT_JSON_INPUT:AAGENT_JSON_POS:1}"
        case "$character" in
            ' '|$'\t'|$'\r'|$'\n') AAGENT_JSON_POS=$((AAGENT_JSON_POS + 1)) ;;
            *) break ;;
        esac
    done
}

aagent_json_fail() {
    AAGENT_JSON_ERROR="invalid JSON"
    return 1
}

# Backslash is deliberately matched as a single-quoted JSON character.
# shellcheck disable=SC1003
aagent_json_parse_string() {
    local character
    local escape
    local hex
    local code

    [[ "${AAGENT_JSON_INPUT:AAGENT_JSON_POS:1}" == '"' ]] || return 1
    AAGENT_JSON_POS=$((AAGENT_JSON_POS + 1))
    AAGENT_JSON_STRING=""

    while (( AAGENT_JSON_POS < AAGENT_JSON_LENGTH )); do
        character="${AAGENT_JSON_INPUT:AAGENT_JSON_POS:1}"
        AAGENT_JSON_POS=$((AAGENT_JSON_POS + 1))
        case "$character" in
            '"') return 0 ;;
            '\\')
                (( AAGENT_JSON_POS < AAGENT_JSON_LENGTH )) || return 1
                escape="${AAGENT_JSON_INPUT:AAGENT_JSON_POS:1}"
                AAGENT_JSON_POS=$((AAGENT_JSON_POS + 1))
                case "$escape" in
                    '"'|'\\'|'/') AAGENT_JSON_STRING+="$escape" ;;
                    b) AAGENT_JSON_STRING+=$'\b' ;;
                    f) AAGENT_JSON_STRING+=$'\f' ;;
                    n) AAGENT_JSON_STRING+=$'\n' ;;
                    r) AAGENT_JSON_STRING+=$'\r' ;;
                    t) AAGENT_JSON_STRING+=$'\t' ;;
                    u)
                        (( AAGENT_JSON_POS + 4 <= AAGENT_JSON_LENGTH )) || return 1
                        hex="${AAGENT_JSON_INPUT:AAGENT_JSON_POS:4}"
                        [[ "$hex" =~ ^[0-9A-Fa-f]{4}$ ]] || return 1
                        AAGENT_JSON_POS=$((AAGENT_JSON_POS + 4))
                        AAGENT_JSON_STRING+='?'
                        ;;
                    *) return 1 ;;
                esac
                ;;
            *)
                LC_ALL=C printf -v code '%d' "'$character"
                (( code >= 32 )) || return 1
                AAGENT_JSON_STRING+="$character"
                ;;
        esac
    done
    return 1
}

aagent_json_path_is_allowed() {
    local requested="$1"
    local allowed
    for allowed in "${AAGENT_JSON_ALLOW_PATHS[@]+"${AAGENT_JSON_ALLOW_PATHS[@]}"}"; do
        [[ "$allowed" == "$requested" ]] && return 0
    done
    return 1
}

aagent_json_record_scalar() {
    local path="$1"
    local type="$2"
    local value="$3"
    local existing

    aagent_json_path_is_allowed "$path" || return 0
    for existing in "${AAGENT_JSON_RESULT_PATHS[@]+"${AAGENT_JSON_RESULT_PATHS[@]}"}"; do
        [[ "$existing" != "$path" ]] || return 1
    done
    AAGENT_JSON_RESULT_PATHS+=("$path")
    AAGENT_JSON_RESULT_TYPES+=("$type")
    AAGENT_JSON_RESULT_VALUES+=("$value")
}

aagent_json_parse_value() {
    local path="$1"
    local depth="$2"
    local character
    local start
    local token

    (( depth <= 32 )) || return 1
    aagent_json_skip_whitespace
    (( AAGENT_JSON_POS < AAGENT_JSON_LENGTH )) || return 1
    character="${AAGENT_JSON_INPUT:AAGENT_JSON_POS:1}"

    case "$character" in
        '{') aagent_json_parse_object "$path" "$depth" ;;
        '[') aagent_json_parse_array "$path" "$depth" ;;
        '"')
            aagent_json_parse_string || return 1
            aagent_json_record_scalar "$path" string "$AAGENT_JSON_STRING"
            ;;
        t)
            [[ "${AAGENT_JSON_INPUT:AAGENT_JSON_POS:4}" == "true" ]] || return 1
            AAGENT_JSON_POS=$((AAGENT_JSON_POS + 4))
            aagent_json_record_scalar "$path" bool true
            ;;
        f)
            [[ "${AAGENT_JSON_INPUT:AAGENT_JSON_POS:5}" == "false" ]] || return 1
            AAGENT_JSON_POS=$((AAGENT_JSON_POS + 5))
            aagent_json_record_scalar "$path" bool false
            ;;
        n)
            [[ "${AAGENT_JSON_INPUT:AAGENT_JSON_POS:4}" == "null" ]] || return 1
            AAGENT_JSON_POS=$((AAGENT_JSON_POS + 4))
            aagent_json_record_scalar "$path" null ""
            ;;
        -|[0-9])
            start="$AAGENT_JSON_POS"
            while (( AAGENT_JSON_POS < AAGENT_JSON_LENGTH )); do
                character="${AAGENT_JSON_INPUT:AAGENT_JSON_POS:1}"
                [[ "$character" =~ [-+0-9.eE] ]] || break
                AAGENT_JSON_POS=$((AAGENT_JSON_POS + 1))
            done
            token="${AAGENT_JSON_INPUT:start:AAGENT_JSON_POS-start}"
            [[ "$token" =~ ^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$ ]] || return 1
            aagent_json_record_scalar "$path" number "$token"
            ;;
        *) return 1 ;;
    esac
}

aagent_json_parse_object() {
    local path="$1"
    local depth="$2"
    local key
    local child_path
    local character

    AAGENT_JSON_POS=$((AAGENT_JSON_POS + 1))
    aagent_json_skip_whitespace
    if [[ "${AAGENT_JSON_INPUT:AAGENT_JSON_POS:1}" == '}' ]]; then
        AAGENT_JSON_POS=$((AAGENT_JSON_POS + 1))
        return 0
    fi

    while (( AAGENT_JSON_POS < AAGENT_JSON_LENGTH )); do
        aagent_json_parse_string || return 1
        key="$AAGENT_JSON_STRING"
        aagent_json_skip_whitespace
        [[ "${AAGENT_JSON_INPUT:AAGENT_JSON_POS:1}" == ':' ]] || return 1
        AAGENT_JSON_POS=$((AAGENT_JSON_POS + 1))
        child_path="$path#${#key}:$key"
        aagent_json_parse_value "$child_path" "$((depth + 1))" || return 1
        aagent_json_skip_whitespace
        character="${AAGENT_JSON_INPUT:AAGENT_JSON_POS:1}"
        case "$character" in
            '}')
                AAGENT_JSON_POS=$((AAGENT_JSON_POS + 1))
                return 0
                ;;
            ',')
                AAGENT_JSON_POS=$((AAGENT_JSON_POS + 1))
                aagent_json_skip_whitespace
                ;;
            *) return 1 ;;
        esac
    done
    return 1
}

aagent_json_parse_array() {
    local path="$1"
    local depth="$2"
    local index=0
    local character

    AAGENT_JSON_POS=$((AAGENT_JSON_POS + 1))
    aagent_json_skip_whitespace
    if [[ "${AAGENT_JSON_INPUT:AAGENT_JSON_POS:1}" == ']' ]]; then
        AAGENT_JSON_POS=$((AAGENT_JSON_POS + 1))
        return 0
    fi

    while (( AAGENT_JSON_POS < AAGENT_JSON_LENGTH )); do
        aagent_json_parse_value "$path#5:array#$index" "$((depth + 1))" || return 1
        index=$((index + 1))
        aagent_json_skip_whitespace
        character="${AAGENT_JSON_INPUT:AAGENT_JSON_POS:1}"
        case "$character" in
            ']')
                AAGENT_JSON_POS=$((AAGENT_JSON_POS + 1))
                return 0
                ;;
            ',')
                AAGENT_JSON_POS=$((AAGENT_JSON_POS + 1))
                aagent_json_skip_whitespace
                ;;
            *) return 1 ;;
        esac
    done
    return 1
}

aagent_json_parse_document() {
    local input="$1"
    shift

    aagent_json_reset
    AAGENT_JSON_INPUT="$input"
    AAGENT_JSON_LENGTH="${#AAGENT_JSON_INPUT}"
    AAGENT_JSON_ALLOW_PATHS=("$@")
    aagent_json_parse_value "" 0 || {
        aagent_json_fail
        return 1
    }
    aagent_json_skip_whitespace
    if (( AAGENT_JSON_POS != AAGENT_JSON_LENGTH )); then
        aagent_json_fail
        return 1
    fi
}

aagent_json_get() {
    local requested="$1"
    local index
    AAGENT_JSON_VALUE=""
    AAGENT_JSON_TYPE=""
    for ((index = 0; index < ${#AAGENT_JSON_RESULT_PATHS[@]}; index++)); do
        if [[ "${AAGENT_JSON_RESULT_PATHS[$index]}" == "$requested" ]]; then
            AAGENT_JSON_VALUE="${AAGENT_JSON_RESULT_VALUES[$index]}"
            AAGENT_JSON_TYPE="${AAGENT_JSON_RESULT_TYPES[$index]}"
            return 0
        fi
    done
    return 1
}

aagent_reset_probe_result() {
    AAGENT_PROBE_PROVIDER="$1"
    AAGENT_PROBE_READINESS="unknown"
    AAGENT_PROBE_FUNDING_CLASS="unknown"
    AAGENT_PROBE_CONFIDENCE_RANK=0
    AAGENT_PROBE_PLAN_LABEL="Unknown"
    AAGENT_PROBE_REASON_CODE="probe_unavailable"
    AAGENT_PROBE_SHADOWING_VARIABLES=""
    AAGENT_PROBE_SOURCE="none"
    AAGENT_PROBE_STATUS="not_run"
    AAGENT_PROBE_CAPTURE=""
}

aagent_set_probe_result() {
    AAGENT_PROBE_READINESS="$1"
    AAGENT_PROBE_FUNDING_CLASS="$2"
    AAGENT_PROBE_CONFIDENCE_RANK="$3"
    AAGENT_PROBE_PLAN_LABEL="$4"
    AAGENT_PROBE_REASON_CODE="$5"
    AAGENT_PROBE_SOURCE="$6"
    AAGENT_PROBE_STATUS="$7"
    AAGENT_PROBE_SHADOWING_VARIABLES="${8-}"
}

aagent_environment_has() {
    [[ -n "${!1+x}" ]]
}

aagent_collect_present_environment_names() {
    local separator=""
    local name
    AAGENT_PRESENT_ENVIRONMENT_NAMES=""
    for name in "$@"; do
        if aagent_environment_has "$name"; then
            AAGENT_PRESENT_ENVIRONMENT_NAMES+="$separator$name"
            separator=","
        fi
    done
}

aagent_collect_claude_custom_route_environment_names() {
    aagent_collect_present_environment_names \
        CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_MANTLE \
        CLAUDE_CODE_USE_VERTEX CLAUDE_CODE_USE_FOUNDRY \
        CLAUDE_CODE_USE_ANTHROPIC_AWS \
        ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL \
        ANTHROPIC_BEDROCK_BASE_URL ANTHROPIC_BEDROCK_MANTLE_BASE_URL \
        ANTHROPIC_AWS_BASE_URL ANTHROPIC_VERTEX_BASE_URL \
        ANTHROPIC_FOUNDRY_BASE_URL ANTHROPIC_FOUNDRY_RESOURCE \
        ANTHROPIC_FOUNDRY_API_KEY AWS_BEARER_TOKEN_BEDROCK \
        ANTHROPIC_CUSTOM_HEADERS
    AAGENT_CLAUDE_CUSTOM_ROUTE_ENVIRONMENT_NAMES="$AAGENT_PRESENT_ENVIRONMENT_NAMES"
}

aagent_collect_claude_shadowing_environment_names() {
    aagent_collect_present_environment_names \
        CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_MANTLE \
        CLAUDE_CODE_USE_VERTEX CLAUDE_CODE_USE_FOUNDRY \
        CLAUDE_CODE_USE_ANTHROPIC_AWS \
        ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_BASE_URL \
        ANTHROPIC_BEDROCK_BASE_URL ANTHROPIC_BEDROCK_MANTLE_BASE_URL \
        ANTHROPIC_AWS_BASE_URL ANTHROPIC_VERTEX_BASE_URL \
        ANTHROPIC_FOUNDRY_BASE_URL ANTHROPIC_FOUNDRY_RESOURCE \
        ANTHROPIC_FOUNDRY_API_KEY AWS_BEARER_TOKEN_BEDROCK \
        ANTHROPIC_CUSTOM_HEADERS
    AAGENT_CLAUDE_SHADOWING_ENVIRONMENT_NAMES="$AAGENT_PRESENT_ENVIRONMENT_NAMES"
}

aagent_run_probe_process() {
    local executable="$1"
    local input="$2"
    local capture_stream="$3"
    local input_linger_seconds="$4"
    shift 4
    local probe_dir=""
    local process_id=""
    local watchdog_id=""
    local input_writer_id=""
    local stdout_reader_id=""
    local stderr_reader_id=""
    local process_status=0
    local stdout_bytes=0
    local stderr_bytes=0

    AAGENT_PROBE_CAPTURE=""
    AAGENT_PROBE_PROCESS_STATUS="supervisor_failure"
    if ! probe_dir="$(mktemp -d "${TMPDIR:-/tmp}/aagent-probe.XXXXXX")"; then
        return 0
    fi
    if ! mkfifo "$probe_dir/input.pipe" "$probe_dir/stdout.pipe" "$probe_dir/stderr.pipe"; then
        rm -rf -- "$probe_dir"
        return 0
    fi

    (
        printf '%s' "$input"
        if [[ "$input_linger_seconds" != "0" ]]; then
            sleep "$input_linger_seconds"
        fi
    ) >"$probe_dir/input.pipe" &
    input_writer_id=$!

    (
        head -c "$((AAGENT_PROBE_MAX_BYTES + 1))" >"$probe_dir/stdout"
        cat >/dev/null
    ) <"$probe_dir/stdout.pipe" &
    stdout_reader_id=$!
    (
        head -c "$((AAGENT_PROBE_MAX_BYTES + 1))" >"$probe_dir/stderr"
        cat >/dev/null
    ) <"$probe_dir/stderr.pipe" &
    stderr_reader_id=$!

    (
        exec "$executable" "$@" <"$probe_dir/input.pipe" >"$probe_dir/stdout.pipe" 2>"$probe_dir/stderr.pipe"
    ) &
    process_id=$!
    (
        sleep "$AAGENT_PROBE_TIMEOUT_SECONDS"
        if kill -0 "$process_id" 2>/dev/null; then
            : >"$probe_dir/timeout"
            kill -TERM "$process_id" 2>/dev/null || true
            sleep 0.2
            kill -KILL "$process_id" 2>/dev/null || true
        fi
    ) &
    watchdog_id=$!

    if wait "$process_id" 2>/dev/null; then
        process_status=0
    else
        process_status=$?
    fi
    kill "$watchdog_id" 2>/dev/null || true
    wait "$watchdog_id" 2>/dev/null || true
    wait "$input_writer_id" 2>/dev/null || true
    wait "$stdout_reader_id" 2>/dev/null || true
    wait "$stderr_reader_id" 2>/dev/null || true

    stdout_bytes="$(wc -c <"$probe_dir/stdout" | tr -d ' ')"
    stderr_bytes="$(wc -c <"$probe_dir/stderr" | tr -d ' ')"
    if [[ -e "$probe_dir/timeout" ]]; then
        AAGENT_PROBE_PROCESS_STATUS="timeout"
    elif (( stdout_bytes > AAGENT_PROBE_MAX_BYTES || stderr_bytes > AAGENT_PROBE_MAX_BYTES )); then
        AAGENT_PROBE_PROCESS_STATUS="truncated"
    elif (( process_status != 0 )); then
        AAGENT_PROBE_PROCESS_STATUS="nonzero"
    else
        AAGENT_PROBE_PROCESS_STATUS="success"
        case "$capture_stream" in
            stdout) AAGENT_PROBE_CAPTURE="$(dd if="$probe_dir/stdout" bs=65536 count=1 2>/dev/null)" ;;
            stderr) AAGENT_PROBE_CAPTURE="$(dd if="$probe_dir/stderr" bs=65536 count=1 2>/dev/null)" ;;
            *) AAGENT_PROBE_PROCESS_STATUS="supervisor_failure" ;;
        esac
    fi
    rm -rf -- "$probe_dir"
    return 0
}

aagent_ascii_lower() {
    printf '%s' "$1" | LC_ALL=C tr '[:upper:]' '[:lower:]'
}

aagent_probe_claude_from_environment() {
    local probe_status="$1"

    aagent_collect_claude_custom_route_environment_names
    if [[ -n "$AAGENT_CLAUDE_CUSTOM_ROUTE_ENVIRONMENT_NAMES" ]]; then
        aagent_set_probe_result ready unknown 1 "Organization route" \
            claude_custom_route_environment environment "$probe_status" \
            "$AAGENT_CLAUDE_CUSTOM_ROUTE_ENVIRONMENT_NAMES"
        return 0
    fi
    if aagent_environment_has ANTHROPIC_API_KEY; then
        aagent_set_probe_result ready payg_byok 1 "Anthropic API" \
            claude_api_environment environment "$probe_status" ANTHROPIC_API_KEY
        return 0
    fi
    if aagent_environment_has CLAUDE_CODE_OAUTH_TOKEN; then
        aagent_set_probe_result ready included_account 1 "Claude subscription token" \
            claude_oauth_environment environment "$probe_status" CLAUDE_CODE_OAUTH_TOKEN
        return 0
    fi
    return 1
}

aagent_probe_claude() {
    local executable="$1"
    local logged_path auth_path subscription_path provider_path key_source_path
    local logged="" logged_type="" auth_method="" subscription_type="" api_provider="" key_source=""
    local auth_lower="" provider_lower="" key_source_lower="" subscription_lower=""
    local funding="included_account" label="Claude subscription"

    aagent_reset_probe_result claude
    aagent_run_probe_process "$executable" "" stdout 0 auth status --json
    if [[ "$AAGENT_PROBE_PROCESS_STATUS" != "success" ]]; then
        aagent_probe_claude_from_environment "$AAGENT_PROBE_PROCESS_STATUS" || \
            aagent_set_probe_result unknown unknown 0 "Unknown" claude_probe_failed \
                auth_status "$AAGENT_PROBE_PROCESS_STATUS"
        AAGENT_PROBE_CAPTURE=""
        return 0
    fi

    logged_path="$(aagent_json_make_path loggedIn)"
    auth_path="$(aagent_json_make_path authMethod)"
    subscription_path="$(aagent_json_make_path subscriptionType)"
    provider_path="$(aagent_json_make_path apiProvider)"
    key_source_path="$(aagent_json_make_path apiKeySource)"
    if ! aagent_json_parse_document "$AAGENT_PROBE_CAPTURE" \
        "$logged_path" "$auth_path" "$subscription_path" "$provider_path" "$key_source_path"; then
        aagent_probe_claude_from_environment schema_failure || \
            aagent_set_probe_result unknown unknown 0 "Unknown" claude_schema_failure auth_status schema_failure
        AAGENT_PROBE_CAPTURE=""
        return 0
    fi
    AAGENT_PROBE_CAPTURE=""

    if aagent_json_get "$logged_path"; then
        logged="$AAGENT_JSON_VALUE"
        logged_type="$AAGENT_JSON_TYPE"
    fi
    if aagent_json_get "$auth_path" && [[ "$AAGENT_JSON_TYPE" == "string" ]]; then auth_method="$AAGENT_JSON_VALUE"; fi
    if aagent_json_get "$subscription_path" && [[ "$AAGENT_JSON_TYPE" == "string" ]]; then subscription_type="$AAGENT_JSON_VALUE"; fi
    if aagent_json_get "$provider_path" && [[ "$AAGENT_JSON_TYPE" == "string" ]]; then api_provider="$AAGENT_JSON_VALUE"; fi
    if aagent_json_get "$key_source_path" && [[ "$AAGENT_JSON_TYPE" == "string" ]]; then key_source="$AAGENT_JSON_VALUE"; fi

    if [[ "$logged_type" != "bool" ]]; then
        aagent_probe_claude_from_environment schema_failure || \
            aagent_set_probe_result unknown unknown 0 "Unknown" claude_schema_failure auth_status schema_failure
        return 0
    fi
    if [[ "$logged" == "false" ]]; then
        aagent_probe_claude_from_environment success || \
            aagent_set_probe_result unusable unknown 3 "Not signed in" claude_not_logged_in auth_status success
        return 0
    fi

    auth_lower="$(aagent_ascii_lower "$auth_method")"
    provider_lower="$(aagent_ascii_lower "$api_provider")"
    key_source_lower="$(aagent_ascii_lower "$key_source")"
    subscription_lower="$(aagent_ascii_lower "$subscription_type")"
    aagent_collect_claude_shadowing_environment_names

    if [[ "$provider_lower" == *bedrock* || "$provider_lower" == *vertex* || "$provider_lower" == *foundry* ||
        "$auth_lower" == *bedrock* || "$auth_lower" == *vertex* || "$auth_lower" == *foundry* ]]; then
        aagent_set_probe_result ready unknown 3 "Organization route" claude_cloud_status \
            auth_status success "$AAGENT_CLAUDE_SHADOWING_ENVIRONMENT_NAMES"
    elif [[ "$auth_lower" == *bearer* || "$auth_lower" == *gateway* || "$key_source_lower" == *helper* ]]; then
        aagent_set_probe_result ready unknown 3 "Bearer or helper" claude_gateway_status \
            auth_status success "$AAGENT_CLAUDE_SHADOWING_ENVIRONMENT_NAMES"
    elif [[ "$auth_lower" == *api* || "$auth_lower" == *console* || "$provider_lower" == *console* ||
        "$key_source_lower" == *api* ]]; then
        aagent_set_probe_result ready payg_byok 3 "Anthropic API" claude_api_status \
            auth_status success "$AAGENT_CLAUDE_SHADOWING_ENVIRONMENT_NAMES"
    elif [[ -n "$subscription_type" || "$provider_lower" == *claude.ai* || "$auth_lower" == *claude.ai* ||
        "$auth_lower" == *oauth* ]]; then
        case "$subscription_lower" in
            pro*) label="Claude Pro"; funding="included_confirmed" ;;
            max*) label="Claude Max"; funding="included_confirmed" ;;
            team*) label="Claude Team"; funding="included_confirmed" ;;
            enterprise*) label="Claude Enterprise"; funding="included_confirmed" ;;
        esac
        aagent_set_probe_result ready "$funding" 3 "$label" claude_subscription_status \
            auth_status success "$AAGENT_CLAUDE_SHADOWING_ENVIRONMENT_NAMES"
    else
        aagent_set_probe_result ready unknown 3 "Claude account" claude_unknown_status auth_status success \
            "$AAGENT_CLAUDE_SHADOWING_ENVIRONMENT_NAMES"
    fi
}

aagent_codex_plan_label() {
    local plan_lower
    plan_lower="$(aagent_ascii_lower "$1")"
    AAGENT_CODEX_PLAN_FUNDING="included_account"
    case "$plan_lower" in
        plus) AAGENT_CODEX_PLAN_LABEL="ChatGPT Plus"; AAGENT_CODEX_PLAN_FUNDING="included_confirmed" ;;
        pro) AAGENT_CODEX_PLAN_LABEL="ChatGPT Pro"; AAGENT_CODEX_PLAN_FUNDING="included_confirmed" ;;
        team) AAGENT_CODEX_PLAN_LABEL="ChatGPT Team"; AAGENT_CODEX_PLAN_FUNDING="included_confirmed" ;;
        business) AAGENT_CODEX_PLAN_LABEL="ChatGPT Business"; AAGENT_CODEX_PLAN_FUNDING="included_confirmed" ;;
        enterprise) AAGENT_CODEX_PLAN_LABEL="ChatGPT Enterprise"; AAGENT_CODEX_PLAN_FUNDING="included_confirmed" ;;
        edu) AAGENT_CODEX_PLAN_LABEL="ChatGPT Edu"; AAGENT_CODEX_PLAN_FUNDING="included_confirmed" ;;
        free) AAGENT_CODEX_PLAN_LABEL="ChatGPT Free" ;;
        *) AAGENT_CODEX_PLAN_LABEL="ChatGPT account" ;;
    esac
}

aagent_probe_codex_from_environment() {
    local probe_status="$1"
    if aagent_environment_has CODEX_API_KEY; then
        aagent_set_probe_result ready payg_byok 1 "OpenAI API" codex_api_environment \
            environment "$probe_status" CODEX_API_KEY
        return 0
    fi
    if aagent_environment_has OPENAI_API_KEY; then
        aagent_set_probe_result ready payg_byok 1 "OpenAI API" codex_openai_environment \
            environment "$probe_status" OPENAI_API_KEY
        return 0
    fi
    return 1
}

aagent_parse_codex_account_response() {
    local line
    local id_path account_path type_path plan_path requires_path credential_path
    local response_id="" response_id_type=""

    AAGENT_CODEX_ACCOUNT_FOUND=0
    AAGENT_CODEX_ACCOUNT_TYPE=""
    AAGENT_CODEX_ACCOUNT_TYPE_KIND="missing"
    AAGENT_CODEX_PLAN_TYPE=""
    AAGENT_CODEX_REQUIRES_OPENAI=""
    AAGENT_CODEX_REQUIRES_OPENAI_KIND="missing"
    AAGENT_CODEX_CREDENTIAL_SOURCE=""
    id_path="$(aagent_json_make_path id)"
    account_path="$(aagent_json_make_path result account)"
    type_path="$(aagent_json_make_path result account type)"
    plan_path="$(aagent_json_make_path result account planType)"
    requires_path="$(aagent_json_make_path result requiresOpenaiAuth)"
    credential_path="$(aagent_json_make_path result account credentialSource)"

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -n "$line" ]] || continue
        if ! aagent_json_parse_document "$line" \
            "$id_path" "$account_path" "$type_path" "$plan_path" "$requires_path" "$credential_path"; then
            continue
        fi
        response_id=""
        response_id_type=""
        if aagent_json_get "$id_path"; then
            response_id="$AAGENT_JSON_VALUE"
            response_id_type="$AAGENT_JSON_TYPE"
        fi
        [[ "$response_id_type" == "number" && "$response_id" == "1" ]] || continue
        AAGENT_CODEX_ACCOUNT_FOUND=1
        if aagent_json_get "$account_path"; then
            AAGENT_CODEX_ACCOUNT_TYPE_KIND="$AAGENT_JSON_TYPE"
        fi
        if aagent_json_get "$type_path" && [[ "$AAGENT_JSON_TYPE" == "string" ]]; then
            AAGENT_CODEX_ACCOUNT_TYPE="$AAGENT_JSON_VALUE"
            AAGENT_CODEX_ACCOUNT_TYPE_KIND="object"
        fi
        if aagent_json_get "$plan_path" && [[ "$AAGENT_JSON_TYPE" == "string" ]]; then
            AAGENT_CODEX_PLAN_TYPE="$AAGENT_JSON_VALUE"
        fi
        if aagent_json_get "$requires_path"; then
            AAGENT_CODEX_REQUIRES_OPENAI="$AAGENT_JSON_VALUE"
            AAGENT_CODEX_REQUIRES_OPENAI_KIND="$AAGENT_JSON_TYPE"
        fi
        if aagent_json_get "$credential_path" && [[ "$AAGENT_JSON_TYPE" == "string" ]]; then
            AAGENT_CODEX_CREDENTIAL_SOURCE="$AAGENT_JSON_VALUE"
        fi
        return 0
    done <<<"$AAGENT_PROBE_CAPTURE"
    return 1
}

aagent_probe_codex_fallback() {
    local executable="$1"
    local previous_status="$2"
    local text=""

    aagent_run_probe_process "$executable" "" stderr 0 login status
    if [[ "$AAGENT_PROBE_PROCESS_STATUS" != "success" ]]; then
        aagent_probe_codex_from_environment "$AAGENT_PROBE_PROCESS_STATUS" || \
            aagent_set_probe_result unknown unknown 0 "Unknown" codex_probe_failed \
                login_status "$AAGENT_PROBE_PROCESS_STATUS"
        AAGENT_PROBE_CAPTURE=""
        return 0
    fi
    text="$AAGENT_PROBE_CAPTURE"
    AAGENT_PROBE_CAPTURE=""
    case "$text" in
        *"Logged in using ChatGPT"*)
            aagent_collect_present_environment_names CODEX_API_KEY
            aagent_set_probe_result ready unknown 2 "ChatGPT account" codex_login_text_chatgpt \
                login_status fallback_success "$AAGENT_PRESENT_ENVIRONMENT_NAMES"
            ;;
        *"Logged in using an API key"*)
            aagent_set_probe_result ready payg_byok 2 "OpenAI API" codex_login_text_api \
                login_status fallback_success CODEX_API_KEY
            ;;
        *"Not logged in"*)
            aagent_probe_codex_from_environment fallback_success || \
                aagent_set_probe_result unusable unknown 2 "Not signed in" codex_not_logged_in \
                    login_status fallback_success
            ;;
        *)
            aagent_probe_codex_from_environment schema_failure || \
                aagent_set_probe_result unknown unknown 0 "Unknown" codex_fallback_schema_failure \
                    login_status schema_failure
            ;;
    esac
    : "$previous_status"
}

aagent_probe_codex() {
    local executable="$1"
    local protocol_input
    local account_lower=""

    aagent_reset_probe_result codex
    protocol_input=$'{"method":"initialize","id":0,"params":{"clientInfo":{"name":"aagent","title":"aagent","version":"0.1.0"}}}\n{"method":"initialized","params":{}}\n{"method":"account/read","id":1,"params":{"refreshToken":false}}\n'
    aagent_run_probe_process "$executable" "$protocol_input" stdout 0.5 app-server
    if [[ "$AAGENT_PROBE_PROCESS_STATUS" != "success" ]]; then
        aagent_probe_codex_fallback "$executable" "$AAGENT_PROBE_PROCESS_STATUS"
        return 0
    fi
    if ! aagent_parse_codex_account_response; then
        AAGENT_PROBE_CAPTURE=""
        aagent_probe_codex_fallback "$executable" protocol_mismatch
        return 0
    fi
    AAGENT_PROBE_CAPTURE=""

    if [[ "$AAGENT_CODEX_REQUIRES_OPENAI_KIND" != "bool" ]]; then
        aagent_probe_codex_fallback "$executable" schema_failure
        return 0
    fi
    account_lower="$(aagent_ascii_lower "$AAGENT_CODEX_ACCOUNT_TYPE")"
    case "$account_lower" in
        chatgpt)
            aagent_codex_plan_label "$AAGENT_CODEX_PLAN_TYPE"
            aagent_collect_present_environment_names CODEX_API_KEY
            aagent_set_probe_result ready "$AAGENT_CODEX_PLAN_FUNDING" 4 "$AAGENT_CODEX_PLAN_LABEL" \
                codex_chatgpt_account app_server success "$AAGENT_PRESENT_ENVIRONMENT_NAMES"
            ;;
        apikey)
            aagent_set_probe_result ready payg_byok 4 "OpenAI API" codex_api_account app_server success
            ;;
        amazonbedrock)
            aagent_set_probe_result ready unknown 4 "Amazon Bedrock" codex_bedrock_account app_server success
            ;;
        '')
            if [[ "$AAGENT_CODEX_ACCOUNT_TYPE_KIND" == "null" && "$AAGENT_CODEX_REQUIRES_OPENAI" == "true" ]]; then
                aagent_probe_codex_from_environment success || \
                    aagent_set_probe_result unusable unknown 4 "Not signed in" codex_not_logged_in app_server success
            elif [[ "$AAGENT_CODEX_REQUIRES_OPENAI" == "false" ]]; then
                aagent_set_probe_result ready unknown 4 "Custom provider" codex_custom_provider app_server success
            else
                aagent_probe_codex_fallback "$executable" schema_failure
            fi
            ;;
        *)
            aagent_set_probe_result ready unknown 4 "Codex account" codex_unknown_account app_server success
            ;;
    esac
}

aagent_probe_opencode_from_environment() {
    local probe_status="$1"
    aagent_collect_present_environment_names \
        OPENAI_API_KEY ANTHROPIC_API_KEY GEMINI_API_KEY GOOGLE_API_KEY
    if [[ -n "$AAGENT_PRESENT_ENVIRONMENT_NAMES" ]]; then
        aagent_set_probe_result ready unknown 1 "Provider credential" opencode_environment_auth \
            environment "$probe_status" "$AAGENT_PRESENT_ENVIRONMENT_NAMES"
        return 0
    fi
    return 1
}

aagent_probe_opencode() {
    local executable="$1"
    local text=""
    aagent_reset_probe_result opencode
    aagent_run_probe_process "$executable" "" stdout 0 auth list
    if [[ "$AAGENT_PROBE_PROCESS_STATUS" != "success" ]]; then
        aagent_probe_opencode_from_environment "$AAGENT_PROBE_PROCESS_STATUS" || \
            aagent_set_probe_result unknown unknown 0 "Unknown" opencode_probe_failed \
                auth_list "$AAGENT_PROBE_PROCESS_STATUS"
        AAGENT_PROBE_CAPTURE=""
        return 0
    fi
    text="$AAGENT_PROBE_CAPTURE"
    AAGENT_PROBE_CAPTURE=""
    if [[ -n "$(aagent_trim_config_whitespace "$text")" && "$text" != *"No credentials"* ]]; then
        aagent_set_probe_result ready unknown 2 "OpenCode credential" opencode_auth_list \
            auth_list success
    else
        aagent_probe_opencode_from_environment success || \
            aagent_set_probe_result unknown unknown 2 "No confirmed credential" opencode_no_auth \
                auth_list success
    fi
}

aagent_read_bounded_file() {
    local path="$1"
    local bytes=0
    AAGENT_PROBE_CAPTURE=""
    AAGENT_PROBE_FILE_STATUS="not_found"
    [[ -e "$path" ]] || return 0
    if [[ ! -f "$path" || ! -r "$path" ]]; then
        AAGENT_PROBE_FILE_STATUS="read_error"
        return 0
    fi
    bytes="$(wc -c <"$path" | tr -d ' ')"
    if (( bytes > AAGENT_PROBE_MAX_BYTES )); then
        AAGENT_PROBE_FILE_STATUS="truncated"
        return 0
    fi
    if ! AAGENT_PROBE_CAPTURE="$(dd if="$path" bs=65536 count=1 2>/dev/null)"; then
        AAGENT_PROBE_CAPTURE=""
        AAGENT_PROBE_FILE_STATUS="read_error"
        return 0
    fi
    AAGENT_PROBE_FILE_STATUS="success"
}

aagent_probe_gemini_from_environment() {
    local probe_status="$1"
    aagent_collect_present_environment_names GEMINI_API_KEY GOOGLE_API_KEY
    if [[ -n "$AAGENT_PRESENT_ENVIRONMENT_NAMES" ]]; then
        aagent_set_probe_result ready payg_byok 1 "Gemini API" gemini_api_environment \
            environment "$probe_status" "$AAGENT_PRESENT_ENVIRONMENT_NAMES"
        return 0
    fi
    aagent_collect_present_environment_names \
        GOOGLE_APPLICATION_CREDENTIALS GOOGLE_GENAI_USE_VERTEXAI GOOGLE_GENAI_USE_GCA \
        GOOGLE_GEMINI_BASE_URL CLOUD_SHELL GEMINI_CLI_USE_COMPUTE_ADC
    if [[ -n "$AAGENT_PRESENT_ENVIRONMENT_NAMES" ]]; then
        aagent_set_probe_result ready unknown 1 "Google organization route" gemini_cloud_environment \
            environment "$probe_status" "$AAGENT_PRESENT_ENVIRONMENT_NAMES"
        return 0
    fi
    return 1
}

aagent_probe_gemini() {
    local settings_path=""
    local selected_path=""
    local selected_type=""
    local selected_lower=""

    aagent_reset_probe_result gemini
    if [[ -n "${HOME-}" ]]; then settings_path="$HOME/.gemini/settings.json"; fi
    if [[ -z "$settings_path" ]]; then
        aagent_probe_gemini_from_environment not_found || \
            aagent_set_probe_result unknown unknown 0 "Unknown" gemini_settings_missing user_settings not_found
        return 0
    fi
    aagent_read_bounded_file "$settings_path"
    if [[ "$AAGENT_PROBE_FILE_STATUS" != "success" ]]; then
        aagent_probe_gemini_from_environment "$AAGENT_PROBE_FILE_STATUS" || \
            aagent_set_probe_result unknown unknown 0 "Unknown" gemini_settings_unavailable \
                user_settings "$AAGENT_PROBE_FILE_STATUS"
        AAGENT_PROBE_CAPTURE=""
        return 0
    fi
    selected_path="$(aagent_json_make_path security auth selectedType)"
    if ! aagent_json_parse_document "$AAGENT_PROBE_CAPTURE" "$selected_path"; then
        AAGENT_PROBE_CAPTURE=""
        aagent_probe_gemini_from_environment schema_failure || \
            aagent_set_probe_result unknown unknown 0 "Unknown" gemini_settings_schema_failure \
                user_settings schema_failure
        return 0
    fi
    AAGENT_PROBE_CAPTURE=""
    if aagent_json_get "$selected_path" && [[ "$AAGENT_JSON_TYPE" == "string" ]]; then
        selected_type="$AAGENT_JSON_VALUE"
    fi
    selected_lower="$(aagent_ascii_lower "$selected_type")"
    case "$selected_lower" in
        oauth-personal)
            aagent_set_probe_result ready included_account 4 "Google account" gemini_oauth_personal \
                user_settings success
            ;;
        gemini-api-key)
            aagent_collect_present_environment_names GEMINI_API_KEY GOOGLE_API_KEY
            aagent_set_probe_result ready payg_byok 4 "Gemini API" gemini_api_key \
                user_settings success "$AAGENT_PRESENT_ENVIRONMENT_NAMES"
            ;;
        vertex-ai|cloud-shell|compute-default-credentials|gateway)
            aagent_collect_present_environment_names \
                GOOGLE_APPLICATION_CREDENTIALS GOOGLE_GENAI_USE_VERTEXAI GOOGLE_GEMINI_BASE_URL
            aagent_set_probe_result ready unknown 4 "Google organization route" gemini_organization_auth \
                user_settings success "$AAGENT_PRESENT_ENVIRONMENT_NAMES"
            ;;
        *)
            aagent_probe_gemini_from_environment schema_failure || \
                aagent_set_probe_result unknown unknown 0 "Unknown" gemini_unknown_auth_type \
                    user_settings schema_failure
            ;;
    esac
}

aagent_probe_amp() {
    aagent_reset_probe_result amp
    if aagent_environment_has AMP_API_KEY; then
        aagent_set_probe_result ready unknown 1 "Amp account credential" amp_environment_auth \
            environment environment_only AMP_API_KEY
    else
        aagent_set_probe_result unknown unknown 0 "Unknown" amp_no_passive_probe none skipped_no_passive
    fi
}

aagent_probe_provider() {
    local provider="$1"
    local executable="$2"
    case "$provider" in
        claude) aagent_probe_claude "$executable" ;;
        codex) aagent_probe_codex "$executable" ;;
        opencode) aagent_probe_opencode "$executable" ;;
        gemini) aagent_probe_gemini ;;
        amp) aagent_probe_amp ;;
        *)
            aagent_reset_probe_result "$provider"
            aagent_set_probe_result unknown unknown 0 "Unknown" unsupported_probe none unsupported
            ;;
    esac
}

aagent_reset_auth_environment_plan() {
    AAGENT_AUTH_ENV_SET_NAME=""
    AAGENT_AUTH_ENV_SET_SOURCE_NAME=""
    AAGENT_AUTH_ENV_UNSET_NAME=""
    AAGENT_AUTH_ADJUSTMENT_NOTICE=""
}

aagent_project_probe_for_auth_policy() {
    local provider="$1"

    aagent_reset_auth_environment_plan
    case "$provider" in
        claude)
            aagent_collect_claude_custom_route_environment_names
            if [[ -n "$AAGENT_CLAUDE_CUSTOM_ROUTE_ENVIRONMENT_NAMES" ]]; then
                if [[ "$AAGENT_PROBE_READINESS" == "ready" ]]; then
                    AAGENT_PROBE_FUNDING_CLASS="unknown"
                    AAGENT_PROBE_PLAN_LABEL="Organization route"
                    AAGENT_PROBE_REASON_CODE="claude_ambiguous_shadowing"
                    AAGENT_PROBE_SHADOWING_VARIABLES="$AAGENT_CLAUDE_CUSTOM_ROUTE_ENVIRONMENT_NAMES"
                    if aagent_environment_has ANTHROPIC_API_KEY; then
                        AAGENT_PROBE_SHADOWING_VARIABLES+=",ANTHROPIC_API_KEY"
                    fi
                fi
                return 0
            fi
            if [[ "$AAGENT_PROBE_REASON_CODE" == "claude_cloud_status" ||
                "$AAGENT_PROBE_REASON_CODE" == "claude_gateway_status" ]]; then
                return 0
            fi

            if aagent_environment_has ANTHROPIC_API_KEY; then
                if [[ "$AAGENT_EFFECTIVE_AUTH_POLICY" == "prefer-included" &&
                    "$AAGENT_PROBE_REASON_CODE" == "claude_subscription_status" &&
                    "$AAGENT_PROBE_FUNDING_CLASS" == "included_confirmed" ]]; then
                    AAGENT_AUTH_ENV_UNSET_NAME="ANTHROPIC_API_KEY"
                    AAGENT_AUTH_ADJUSTMENT_NOTICE="using claude subscription; omitting ANTHROPIC_API_KEY from the child process"
                else
                    AAGENT_PROBE_READINESS="ready"
                    AAGENT_PROBE_FUNDING_CLASS="payg_byok"
                    AAGENT_PROBE_PLAN_LABEL="Anthropic API"
                    AAGENT_PROBE_REASON_CODE="claude_native_api_override"
                    AAGENT_PROBE_SHADOWING_VARIABLES="ANTHROPIC_API_KEY"
                fi
            fi
            ;;
        codex)
            if [[ "$AAGENT_PROBE_REASON_CODE" == "codex_custom_provider" ||
                "$AAGENT_PROBE_REASON_CODE" == "codex_bedrock_account" ]]; then
                return 0
            fi
            if aagent_environment_has CODEX_API_KEY; then
                if [[ "$AAGENT_EFFECTIVE_AUTH_POLICY" == "prefer-included" &&
                    "$AAGENT_PROBE_REASON_CODE" == "codex_chatgpt_account" ]]; then
                    AAGENT_AUTH_ENV_UNSET_NAME="CODEX_API_KEY"
                    AAGENT_AUTH_ADJUSTMENT_NOTICE="using codex ChatGPT account; omitting CODEX_API_KEY from the child process"
                else
                    AAGENT_PROBE_READINESS="ready"
                    AAGENT_PROBE_FUNDING_CLASS="payg_byok"
                    AAGENT_PROBE_PLAN_LABEL="OpenAI API"
                    AAGENT_PROBE_REASON_CODE="codex_native_api_override"
                    AAGENT_PROBE_SHADOWING_VARIABLES="CODEX_API_KEY"
                fi
            elif aagent_environment_has OPENAI_API_KEY; then
                if [[ "$AAGENT_EFFECTIVE_AUTH_POLICY" == "prefer-included" &&
                    "$AAGENT_PROBE_FUNDING_CLASS" == "payg_byok" ]]; then
                    AAGENT_AUTH_ENV_SET_NAME="CODEX_API_KEY"
                    AAGENT_AUTH_ENV_SET_SOURCE_NAME="OPENAI_API_KEY"
                    AAGENT_AUTH_ADJUSTMENT_NOTICE="using codex metered API; mapping OPENAI_API_KEY to CODEX_API_KEY for the child process"
                elif [[ "$AAGENT_EFFECTIVE_AUTH_POLICY" == "native" &&
                    "$AAGENT_PROBE_REASON_CODE" == "codex_openai_environment" ]]; then
                    AAGENT_PROBE_READINESS="unknown"
                    AAGENT_PROBE_FUNDING_CLASS="unknown"
                    AAGENT_PROBE_CONFIDENCE_RANK=0
                    AAGENT_PROBE_PLAN_LABEL="Unknown"
                    AAGENT_PROBE_REASON_CODE="codex_native_openai_ignored"
                fi
            fi
            ;;
    esac
}

aagent_reset_selection() {
    AAGENT_SELECTION_ADAPTER_INDEXES=()
    AAGENT_SELECTION_PROVIDER_IDS=()
    AAGENT_SELECTION_PATHS=()
    AAGENT_SELECTION_READINESS=()
    AAGENT_SELECTION_FUNDING_CLASSES=()
    AAGENT_SELECTION_CONFIDENCE_RANKS=()
    AAGENT_SELECTION_PLAN_LABELS=()
    AAGENT_SELECTION_PROBE_REASONS=()
    AAGENT_SELECTION_SHADOWING_VARIABLES=()
    AAGENT_SELECTION_AUTH_SET_NAMES=()
    AAGENT_SELECTION_AUTH_SET_SOURCE_NAMES=()
    AAGENT_SELECTION_AUTH_UNSET_NAMES=()
    AAGENT_SELECTION_AUTH_NOTICES=()
    AAGENT_SELECTION_PRIORITY_POSITIONS=()
    AAGENT_SELECTION_POPULARITY_POSITIONS=()
    AAGENT_SELECTION_REGISTRY_POSITIONS=()
    AAGENT_SELECTION_READINESS_SCORES=()
    AAGENT_SELECTION_FUNDING_SCORES=()
    AAGENT_SELECTION_PRIORITY_SCORES=()
    AAGENT_SELECTION_POPULARITY_SCORES=()
    AAGENT_SELECTION_REGISTRY_SCORES=()
    AAGENT_SELECTION_ELIGIBLE=()
    AAGENT_SELECTION_EXCLUSIONS=()
    AAGENT_SELECTION_INSTALLED_COUNT=0
    AAGENT_SELECTION_ELIGIBLE_COUNT=0
    AAGENT_SELECTION_WINNER_INDEX=-1
    AAGENT_SELECTION_RUNNER_UP_INDEX=-1
    AAGENT_SELECTION_REASON_CODE=""
    AAGENT_SELECTION_REASON_DISPLAY=""
    AAGENT_SELECTION_NOTICE=""
}

aagent_readiness_score() {
    case "$1" in
        ready) AAGENT_SELECTION_VALUE_SCORE=2 ;;
        unknown) AAGENT_SELECTION_VALUE_SCORE=1 ;;
        unusable) AAGENT_SELECTION_VALUE_SCORE=0 ;;
        *) AAGENT_SELECTION_VALUE_SCORE=-1 ;;
    esac
}

aagent_funding_score() {
    case "$1" in
        included_confirmed) AAGENT_SELECTION_VALUE_SCORE=6 ;;
        included_account) AAGENT_SELECTION_VALUE_SCORE=5 ;;
        prepaid_credits) AAGENT_SELECTION_VALUE_SCORE=4 ;;
        local) AAGENT_SELECTION_VALUE_SCORE=3 ;;
        payg_byok) AAGENT_SELECTION_VALUE_SCORE=2 ;;
        unknown) AAGENT_SELECTION_VALUE_SCORE=1 ;;
        *) AAGENT_SELECTION_VALUE_SCORE=0 ;;
    esac
}

aagent_configured_priority_position() {
    local provider="$1"
    local old_ifs="$IFS"
    local -a configured=()
    local item
    local position=0

    AAGENT_SELECTION_VALUE_POSITION=0
    [[ -n "$AAGENT_EFFECTIVE_PRIORITY" ]] || return 0
    IFS=',' read -r -a configured <<<"$AAGENT_EFFECTIVE_PRIORITY"
    IFS="$old_ifs"
    for item in "${configured[@]}"; do
        position=$((position + 1))
        item="$(aagent_trim_config_whitespace "$item")"
        if [[ "$item" == "$provider" ]]; then
            AAGENT_SELECTION_VALUE_POSITION="$position"
            return 0
        fi
    done
}

aagent_add_selection_candidate() {
    local adapter_index="$1"
    local provider="$2"
    local path="$3"
    local readiness="$4"
    local funding="$5"
    local confidence="$6"
    local plan_label="$7"
    local probe_reason="$8"
    local popularity_position="$9"
    shift 9
    local registry_position="$1"
    local shadowing_variables="${2-}"
    local auth_set_name="${3-}"
    local auth_set_source_name="${4-}"
    local auth_unset_name="${5-}"
    local auth_notice="${6-}"
    local readiness_score funding_score priority_position priority_score
    local eligible=1 exclusion=""

    aagent_readiness_score "$readiness"
    readiness_score="$AAGENT_SELECTION_VALUE_SCORE"
    aagent_funding_score "$funding"
    funding_score="$AAGENT_SELECTION_VALUE_SCORE"
    aagent_configured_priority_position "$provider"
    priority_position="$AAGENT_SELECTION_VALUE_POSITION"
    if (( priority_position > 0 )); then
        priority_score=$((1000 - priority_position))
    else
        priority_score=0
    fi

    if [[ "$readiness" == "unusable" ]]; then
        eligible=0
        exclusion="unusable_authentication"
    elif [[ "$funding" == "local" && "$AAGENT_EFFECTIVE_ALLOW_LOCAL" != "true" ]]; then
        eligible=0
        exclusion="local_not_allowed"
    elif (( readiness_score < 0 || funding_score < 1 || confidence < 0 || confidence > 4 )); then
        eligible=0
        exclusion="invalid_probe_record"
    fi

    AAGENT_SELECTION_ADAPTER_INDEXES+=("$adapter_index")
    AAGENT_SELECTION_PROVIDER_IDS+=("$provider")
    AAGENT_SELECTION_PATHS+=("$path")
    AAGENT_SELECTION_READINESS+=("$readiness")
    AAGENT_SELECTION_FUNDING_CLASSES+=("$funding")
    AAGENT_SELECTION_CONFIDENCE_RANKS+=("$confidence")
    AAGENT_SELECTION_PLAN_LABELS+=("$plan_label")
    AAGENT_SELECTION_PROBE_REASONS+=("$probe_reason")
    AAGENT_SELECTION_SHADOWING_VARIABLES+=("$shadowing_variables")
    AAGENT_SELECTION_AUTH_SET_NAMES+=("$auth_set_name")
    AAGENT_SELECTION_AUTH_SET_SOURCE_NAMES+=("$auth_set_source_name")
    AAGENT_SELECTION_AUTH_UNSET_NAMES+=("$auth_unset_name")
    AAGENT_SELECTION_AUTH_NOTICES+=("$auth_notice")
    AAGENT_SELECTION_PRIORITY_POSITIONS+=("$priority_position")
    AAGENT_SELECTION_POPULARITY_POSITIONS+=("$popularity_position")
    AAGENT_SELECTION_REGISTRY_POSITIONS+=("$registry_position")
    AAGENT_SELECTION_READINESS_SCORES+=("$readiness_score")
    AAGENT_SELECTION_FUNDING_SCORES+=("$funding_score")
    AAGENT_SELECTION_PRIORITY_SCORES+=("$priority_score")
    AAGENT_SELECTION_POPULARITY_SCORES+=("$((1000 - popularity_position))")
    AAGENT_SELECTION_REGISTRY_SCORES+=("$((1000 - registry_position))")
    AAGENT_SELECTION_ELIGIBLE+=("$eligible")
    AAGENT_SELECTION_EXCLUSIONS+=("$exclusion")
    AAGENT_SELECTION_INSTALLED_COUNT=$((AAGENT_SELECTION_INSTALLED_COUNT + 1))
}

aagent_compare_selection_indexes() {
    local left="$1"
    local right="$2"

    AAGENT_SELECTION_COMPARISON=0
    AAGENT_SELECTION_COMPARISON_FIELD="stable_registry_order"
    if (( AAGENT_SELECTION_READINESS_SCORES[left] != AAGENT_SELECTION_READINESS_SCORES[right] )); then
        AAGENT_SELECTION_COMPARISON_FIELD="readiness"
        (( AAGENT_SELECTION_READINESS_SCORES[left] > AAGENT_SELECTION_READINESS_SCORES[right] )) && \
            AAGENT_SELECTION_COMPARISON=1 || AAGENT_SELECTION_COMPARISON=-1
    elif (( AAGENT_SELECTION_FUNDING_SCORES[left] != AAGENT_SELECTION_FUNDING_SCORES[right] )); then
        AAGENT_SELECTION_COMPARISON_FIELD="funding_class"
        (( AAGENT_SELECTION_FUNDING_SCORES[left] > AAGENT_SELECTION_FUNDING_SCORES[right] )) && \
            AAGENT_SELECTION_COMPARISON=1 || AAGENT_SELECTION_COMPARISON=-1
    elif (( AAGENT_SELECTION_CONFIDENCE_RANKS[left] != AAGENT_SELECTION_CONFIDENCE_RANKS[right] )); then
        AAGENT_SELECTION_COMPARISON_FIELD="authentication_confidence"
        (( AAGENT_SELECTION_CONFIDENCE_RANKS[left] > AAGENT_SELECTION_CONFIDENCE_RANKS[right] )) && \
            AAGENT_SELECTION_COMPARISON=1 || AAGENT_SELECTION_COMPARISON=-1
    elif (( AAGENT_SELECTION_PRIORITY_SCORES[left] != AAGENT_SELECTION_PRIORITY_SCORES[right] )); then
        AAGENT_SELECTION_COMPARISON_FIELD="configured_priority"
        (( AAGENT_SELECTION_PRIORITY_SCORES[left] > AAGENT_SELECTION_PRIORITY_SCORES[right] )) && \
            AAGENT_SELECTION_COMPARISON=1 || AAGENT_SELECTION_COMPARISON=-1
    elif (( AAGENT_SELECTION_POPULARITY_SCORES[left] != AAGENT_SELECTION_POPULARITY_SCORES[right] )); then
        AAGENT_SELECTION_COMPARISON_FIELD="popularity_prior"
        (( AAGENT_SELECTION_POPULARITY_SCORES[left] > AAGENT_SELECTION_POPULARITY_SCORES[right] )) && \
            AAGENT_SELECTION_COMPARISON=1 || AAGENT_SELECTION_COMPARISON=-1
    elif (( AAGENT_SELECTION_REGISTRY_SCORES[left] != AAGENT_SELECTION_REGISTRY_SCORES[right] )); then
        AAGENT_SELECTION_COMPARISON_FIELD="stable_registry_order"
        (( AAGENT_SELECTION_REGISTRY_SCORES[left] > AAGENT_SELECTION_REGISTRY_SCORES[right] )) && \
            AAGENT_SELECTION_COMPARISON=1 || AAGENT_SELECTION_COMPARISON=-1
    fi
}

aagent_find_best_selection_candidate() {
    local excluded_index="$1"
    local index
    AAGENT_SELECTION_FOUND_INDEX=-1
    for ((index = 0; index < ${#AAGENT_SELECTION_PROVIDER_IDS[@]}; index++)); do
        [[ "${AAGENT_SELECTION_ELIGIBLE[$index]}" == "1" ]] || continue
        (( index != excluded_index )) || continue
        if (( AAGENT_SELECTION_FOUND_INDEX < 0 )); then
            AAGENT_SELECTION_FOUND_INDEX="$index"
            continue
        fi
        aagent_compare_selection_indexes "$index" "$AAGENT_SELECTION_FOUND_INDEX"
        if (( AAGENT_SELECTION_COMPARISON > 0 )); then
            AAGENT_SELECTION_FOUND_INDEX="$index"
        fi
    done
}

aagent_set_selection_reason() {
    local winner="$AAGENT_SELECTION_WINNER_INDEX"
    local runner="$AAGENT_SELECTION_RUNNER_UP_INDEX"

    if (( runner < 0 )); then
        AAGENT_SELECTION_REASON_CODE="only_candidate"
        AAGENT_SELECTION_REASON_DISPLAY="only eligible provider"
        return 0
    fi
    aagent_compare_selection_indexes "$winner" "$runner"
    AAGENT_SELECTION_REASON_CODE="$AAGENT_SELECTION_COMPARISON_FIELD"
    case "$AAGENT_SELECTION_REASON_CODE" in
        readiness)
            AAGENT_SELECTION_REASON_DISPLAY="higher readiness (${AAGENT_SELECTION_READINESS[$winner]})"
            ;;
        funding_class)
            AAGENT_SELECTION_REASON_DISPLAY="higher funding class (${AAGENT_SELECTION_FUNDING_CLASSES[$winner]})"
            ;;
        authentication_confidence)
            AAGENT_SELECTION_REASON_DISPLAY="authentication confidence ${AAGENT_SELECTION_CONFIDENCE_RANKS[$winner]}"
            ;;
        configured_priority)
            AAGENT_SELECTION_REASON_DISPLAY="configured priority #${AAGENT_SELECTION_PRIORITY_POSITIONS[$winner]}"
            ;;
        popularity_prior)
            AAGENT_SELECTION_REASON_DISPLAY="popularity #${AAGENT_SELECTION_POPULARITY_POSITIONS[$winner]}"
            ;;
        stable_registry_order)
            AAGENT_SELECTION_REASON_DISPLAY="registry order #${AAGENT_SELECTION_REGISTRY_POSITIONS[$winner]}"
            ;;
    esac
}

aagent_select_candidates() {
    local index
    local details

    AAGENT_SELECTION_ELIGIBLE_COUNT=0
    for index in "${AAGENT_SELECTION_ELIGIBLE[@]+"${AAGENT_SELECTION_ELIGIBLE[@]}"}"; do
        [[ "$index" == "1" ]] && AAGENT_SELECTION_ELIGIBLE_COUNT=$((AAGENT_SELECTION_ELIGIBLE_COUNT + 1))
    done
    aagent_find_best_selection_candidate -1
    AAGENT_SELECTION_WINNER_INDEX="$AAGENT_SELECTION_FOUND_INDEX"
    if (( AAGENT_SELECTION_WINNER_INDEX < 0 )); then
        return "$AAGENT_EXIT_UNAVAILABLE"
    fi
    aagent_find_best_selection_candidate "$AAGENT_SELECTION_WINNER_INDEX"
    AAGENT_SELECTION_RUNNER_UP_INDEX="$AAGENT_SELECTION_FOUND_INDEX"
    aagent_set_selection_reason

    index="$AAGENT_SELECTION_WINNER_INDEX"
    details="${AAGENT_SELECTION_FUNDING_CLASSES[$index]}"
    if [[ -n "${AAGENT_SELECTION_PLAN_LABELS[$index]}" &&
        "${AAGENT_SELECTION_PLAN_LABELS[$index]}" != "Unknown" ]]; then
        details+=", ${AAGENT_SELECTION_PLAN_LABELS[$index]}"
    fi
    AAGENT_SELECTION_NOTICE="using ${AAGENT_SELECTION_PROVIDER_IDS[$index]} ($details; $AAGENT_SELECTION_REASON_DISPLAY)"
}

aagent_build_automatic_candidates() {
    local index provider

    aagent_discover_adapters
    aagent_reset_selection
    for ((index = 0; index < ${#AAGENT_ADAPTER_IDS[@]}; index++)); do
        [[ "${AAGENT_DISCOVERY_STATUSES[$index]}" == "installed" ]] || continue
        provider="${AAGENT_ADAPTER_IDS[$index]}"
        aagent_probe_provider "$provider" "${AAGENT_DISCOVERY_PATHS[$index]}"
        aagent_project_probe_for_auth_policy "$provider"
        aagent_add_selection_candidate \
            "$index" \
            "$provider" \
            "${AAGENT_DISCOVERY_PATHS[$index]}" \
            "$AAGENT_PROBE_READINESS" \
            "$AAGENT_PROBE_FUNDING_CLASS" \
            "$AAGENT_PROBE_CONFIDENCE_RANK" \
            "$AAGENT_PROBE_PLAN_LABEL" \
            "$AAGENT_PROBE_REASON_CODE" \
            "${AAGENT_ADAPTER_POPULARITY[$index]}" \
            "${AAGENT_ADAPTER_REGISTRY_ORDER[$index]}" \
            "$AAGENT_PROBE_SHADOWING_VARIABLES" \
            "$AAGENT_AUTH_ENV_SET_NAME" \
            "$AAGENT_AUTH_ENV_SET_SOURCE_NAME" \
            "$AAGENT_AUTH_ENV_UNSET_NAME" \
            "$AAGENT_AUTH_ADJUSTMENT_NOTICE"
    done
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
    AAGENT_LAUNCH_ADJUSTMENT_NOTICES=()
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

aagent_apply_auth_environment_plan_to_launch() {
    local set_name="${1-}"
    local set_source_name="${2-}"
    local unset_name="${3-}"
    local notice="${4-}"

    if [[ -n "$set_name" || -n "$set_source_name" ]]; then
        if [[ "$set_name" != "CODEX_API_KEY" || "$set_source_name" != "OPENAI_API_KEY" ||
            -n "$unset_name" ]] || ! aagent_environment_has OPENAI_API_KEY; then
            printf 'aagent: invalid child authentication environment plan\n' >&2
            return "$AAGENT_EXIT_SOFTWARE"
        fi
        aagent_launch_plan_set_environment "$set_name" "$OPENAI_API_KEY" || return $?
    elif [[ -n "$unset_name" ]]; then
        case "$unset_name" in
            ANTHROPIC_API_KEY|CODEX_API_KEY)
                aagent_launch_plan_unset_environment "$unset_name" || return $?
                ;;
            *)
                printf 'aagent: invalid child authentication environment plan\n' >&2
                return "$AAGENT_EXIT_SOFTWARE"
                ;;
        esac
    fi
    if [[ -n "$notice" ]]; then
        AAGENT_LAUNCH_ADJUSTMENT_NOTICES+=("$notice")
    fi
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
    local adjustment_notice
    for adjustment_notice in \
        "${AAGENT_LAUNCH_ADJUSTMENT_NOTICES[@]+"${AAGENT_LAUNCH_ADJUSTMENT_NOTICES[@]}"}"; do
        aagent_write_notice "$quiet" "$adjustment_notice"
    done

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

aagent_reset_adapter_plan() {
    AAGENT_ADAPTER_ARGUMENTS=()
    AAGENT_ADAPTER_DISPLAY_ARGUMENTS=()
    AAGENT_ADAPTER_STDIN_MODE="inherit"
    AAGENT_ADAPTER_STDIN_DATA=""
    AAGENT_ADAPTER_INPUT_DESCRIPTION="argv"
    AAGENT_ADAPTER_ERROR=""
}

aagent_append_adapter_argument() {
    AAGENT_ADAPTER_ARGUMENTS+=("$1")
    AAGENT_ADAPTER_DISPLAY_ARGUMENTS+=("$2")
}

aagent_append_native_arguments() {
    local index
    for ((index = 0; index < ${#AAGENT_NATIVE_ARGS[@]}; index++)); do
        aagent_append_adapter_argument "${AAGENT_NATIVE_ARGS[$index]}" "<native>"
    done
}

aagent_configure_adapter_stdin() {
    case "$AAGENT_INPUT_MODE" in
        prompt)
            AAGENT_ADAPTER_STDIN_MODE="inherit"
            AAGENT_ADAPTER_STDIN_DATA=""
            AAGENT_ADAPTER_INPUT_DESCRIPTION="argv"
            ;;
        stdin)
            AAGENT_ADAPTER_STDIN_MODE="data"
            AAGENT_ADAPTER_STDIN_DATA="$AAGENT_STDIN"
            AAGENT_ADAPTER_INPUT_DESCRIPTION="stdin"
            ;;
        both)
            AAGENT_ADAPTER_STDIN_MODE="data"
            AAGENT_ADAPTER_STDIN_DATA="$AAGENT_STDIN"
            AAGENT_ADAPTER_INPUT_DESCRIPTION="both"
            ;;
        *)
            AAGENT_ADAPTER_ERROR="unsupported resolved input mode: $AAGENT_INPUT_MODE"
            return "$AAGENT_EXIT_SOFTWARE"
            ;;
    esac
}

aagent_append_model_argument() {
    local flag="$1"
    if [[ -n "$AAGENT_MODEL" ]]; then
        aagent_append_adapter_argument "$flag" "$flag"
        aagent_append_adapter_argument "$AAGENT_MODEL" "<model>"
    fi
}

aagent_build_adapter_launch_plan() {
    local provider="$1"
    local executable="$2"
    local display_name="$3"
    local combined_prompt

    aagent_reset_adapter_plan
    aagent_configure_adapter_stdin || return $?

    case "$provider" in
        claude)
            aagent_append_adapter_argument "--print" "--print"
            if [[ "$AAGENT_INPUT_MODE" != "stdin" ]]; then
                aagent_append_adapter_argument "$AAGENT_PROMPT" "<prompt>"
            fi
            aagent_append_model_argument "--model"
            aagent_append_native_arguments
            ;;
        codex)
            aagent_append_adapter_argument "exec" "exec"
            aagent_append_model_argument "--model"
            aagent_append_native_arguments
            if [[ "$AAGENT_INPUT_MODE" == "stdin" ]]; then
                aagent_append_adapter_argument "-" "-"
            else
                aagent_append_adapter_argument "$AAGENT_PROMPT" "<prompt>"
            fi
            ;;
        opencode)
            aagent_append_adapter_argument "run" "run"
            aagent_append_model_argument "--model"
            aagent_append_native_arguments
            case "$AAGENT_INPUT_MODE" in
                prompt)
                    combined_prompt="$AAGENT_PROMPT"
                    ;;
                stdin)
                    combined_prompt="$AAGENT_STDIN"
                    ;;
                both)
                    combined_prompt="$AAGENT_PROMPT"$'\n\n--- stdin context ---\n'"$AAGENT_STDIN"
                    ;;
            esac
            aagent_append_adapter_argument "$combined_prompt" "<prompt>"
            AAGENT_ADAPTER_STDIN_MODE="closed"
            AAGENT_ADAPTER_STDIN_DATA=""
            AAGENT_ADAPTER_INPUT_DESCRIPTION="argv"
            ;;
        amp)
            if [[ -n "$AAGENT_MODEL" ]]; then
                AAGENT_ADAPTER_ERROR="provider amp does not support --model"
                return "$AAGENT_EXIT_USAGE"
            fi
            aagent_append_adapter_argument "--execute" "--execute"
            if [[ "$AAGENT_INPUT_MODE" != "stdin" ]]; then
                aagent_append_adapter_argument "$AAGENT_PROMPT" "<prompt>"
            fi
            aagent_append_native_arguments
            ;;
        gemini)
            aagent_append_model_argument "--model"
            aagent_append_native_arguments
            if [[ "$AAGENT_INPUT_MODE" != "stdin" ]]; then
                aagent_append_adapter_argument "--prompt" "--prompt"
                aagent_append_adapter_argument "$AAGENT_PROMPT" "<prompt>"
            fi
            ;;
        *)
            AAGENT_ADAPTER_ERROR="provider adapter is not implemented: $provider"
            return "$AAGENT_EXIT_USAGE"
            ;;
    esac

    aagent_create_launch_plan \
        "$executable" \
        "$AAGENT_CWD" \
        "$AAGENT_ADAPTER_STDIN_MODE" \
        "$AAGENT_ADAPTER_STDIN_DATA" \
        "$AAGENT_ADAPTER_INPUT_DESCRIPTION" \
        "${AAGENT_ADAPTER_ARGUMENTS[@]+"${AAGENT_ADAPTER_ARGUMENTS[@]}"}" || return $?

    if (( ${#AAGENT_ADAPTER_DISPLAY_ARGUMENTS[@]} > 0 )); then
        aagent_launch_plan_set_display_arguments "${AAGENT_ADAPTER_DISPLAY_ARGUMENTS[@]}" || return $?
    fi
    AAGENT_LAUNCH_PROVIDER="$provider"
    AAGENT_LAUNCH_REASON="$AAGENT_PROVIDER_SOURCE_LABEL"
    AAGENT_LAUNCH_NOTICE="selected $display_name via $AAGENT_PROVIDER_SOURCE_LABEL"
}

aagent_run_explicit_provider() {
    local provider="$1"
    local index
    local status

    aagent_initialize_registry
    if ! index="$(aagent_get_adapter_index "$provider")"; then
        aagent_print_usage_error "unknown provider: $provider"
        return "$AAGENT_EXIT_USAGE"
    fi
    if ! aagent_resolve_discovery_target \
        "${AAGENT_ADAPTER_EXECUTABLES[$index]}" \
        "${AAGENT_ADAPTER_OVERRIDES[$index]}"; then
        printf 'aagent: provider %s selected via %s is unavailable: %s\n' \
            "$provider" "$AAGENT_PROVIDER_SOURCE_LABEL" "$AAGENT_DISCOVERY_REASON" >&2
        return "$AAGENT_EXIT_UNAVAILABLE"
    fi
    if [[ "${AAGENT_ADAPTER_TIERS[$index]}" != "tier1" ]]; then
        aagent_print_usage_error "provider adapter is not implemented: $provider"
        return "$AAGENT_EXIT_USAGE"
    fi

    aagent_reset_auth_environment_plan
    case "$provider" in
        claude|codex)
            aagent_probe_provider "$provider" "$AAGENT_RESOLVED_PATH"
            aagent_project_probe_for_auth_policy "$provider"
            ;;
    esac

    if aagent_build_adapter_launch_plan \
        "$provider" \
        "$AAGENT_RESOLVED_PATH" \
        "${AAGENT_ADAPTER_NAMES[$index]}"; then
        :
    else
        status=$?
        if [[ "$status" == "$AAGENT_EXIT_USAGE" ]]; then
            aagent_print_usage_error "$AAGENT_ADAPTER_ERROR"
        elif [[ -n "$AAGENT_ADAPTER_ERROR" ]]; then
            printf 'aagent: %s\n' "$AAGENT_ADAPTER_ERROR" >&2
        fi
        return "$status"
    fi
    aagent_apply_auth_environment_plan_to_launch \
        "$AAGENT_AUTH_ENV_SET_NAME" \
        "$AAGENT_AUTH_ENV_SET_SOURCE_NAME" \
        "$AAGENT_AUTH_ENV_UNSET_NAME" \
        "$AAGENT_AUTH_ADJUSTMENT_NOTICE" || return $?

    if aagent_execute_launch_plan "$AAGENT_DRY_RUN" "$AAGENT_QUIET"; then
        return "$AAGENT_EXIT_OK"
    else
        return $?
    fi
}

aagent_run_automatic_provider() {
    local winner adapter_index status

    aagent_build_automatic_candidates
    if ! aagent_select_candidates; then
        if (( AAGENT_SELECTION_INSTALLED_COUNT == 0 )); then
            printf 'aagent: no supported coding agent is installed; install a Tier 1 provider or use --provider ID\n' >&2
        else
            printf 'aagent: no installed provider is eligible for automatic selection; use --provider ID or adjust configuration\n' >&2
        fi
        return "$AAGENT_EXIT_UNAVAILABLE"
    fi

    winner="$AAGENT_SELECTION_WINNER_INDEX"
    adapter_index="${AAGENT_SELECTION_ADAPTER_INDEXES[$winner]}"
    if aagent_build_adapter_launch_plan \
        "${AAGENT_SELECTION_PROVIDER_IDS[$winner]}" \
        "${AAGENT_SELECTION_PATHS[$winner]}" \
        "${AAGENT_ADAPTER_NAMES[$adapter_index]}"; then
        :
    else
        status=$?
        if [[ "$status" == "$AAGENT_EXIT_USAGE" ]]; then
            aagent_print_usage_error "$AAGENT_ADAPTER_ERROR"
        elif [[ -n "$AAGENT_ADAPTER_ERROR" ]]; then
            printf 'aagent: %s\n' "$AAGENT_ADAPTER_ERROR" >&2
        fi
        return "$status"
    fi

    AAGENT_LAUNCH_REASON="$AAGENT_SELECTION_REASON_CODE ($AAGENT_SELECTION_REASON_DISPLAY)"
    AAGENT_LAUNCH_NOTICE="$AAGENT_SELECTION_NOTICE"
    aagent_apply_auth_environment_plan_to_launch \
        "${AAGENT_SELECTION_AUTH_SET_NAMES[$winner]}" \
        "${AAGENT_SELECTION_AUTH_SET_SOURCE_NAMES[$winner]}" \
        "${AAGENT_SELECTION_AUTH_UNSET_NAMES[$winner]}" \
        "${AAGENT_SELECTION_AUTH_NOTICES[$winner]}" || return $?
    if aagent_execute_launch_plan "$AAGENT_DRY_RUN" "$AAGENT_QUIET"; then
        return "$AAGENT_EXIT_OK"
    else
        return $?
    fi
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
      --priority IDS    Comma-separated provider tie-break order
      --allow-local B   Allow local models: true or false
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
    AAGENT_CLI_PROVIDER=""
    AAGENT_CLI_PROVIDER_SET=0
    AAGENT_MODEL=""
    AAGENT_CWD=""
    AAGENT_CLI_AUTH_POLICY=""
    AAGENT_CLI_AUTH_POLICY_SET=0
    AAGENT_CLI_PRIORITY=""
    AAGENT_CLI_PRIORITY_SET=0
    AAGENT_CLI_ALLOW_LOCAL=""
    AAGENT_CLI_ALLOW_LOCAL_SET=0
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
                AAGENT_CLI_PROVIDER="$2"
                AAGENT_CLI_PROVIDER_SET=1
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
                        AAGENT_CLI_AUTH_POLICY="$2"
                        AAGENT_CLI_AUTH_POLICY_SET=1
                        ;;
                    *)
                        aagent_set_parse_error "invalid authentication policy: $2"
                        return "$AAGENT_EXIT_USAGE"
                        ;;
                esac
                shift 2
                ;;
            --priority)
                aagent_require_option_value "$token" "$#" "${2-}" || return $?
                AAGENT_CLI_PRIORITY="$2"
                AAGENT_CLI_PRIORITY_SET=1
                shift 2
                ;;
            --allow-local)
                aagent_require_option_value "$token" "$#" "${2-}" || return $?
                case "$2" in
                    true|false)
                        AAGENT_CLI_ALLOW_LOCAL="$2"
                        AAGENT_CLI_ALLOW_LOCAL_SET=1
                        ;;
                    *)
                        aagent_set_parse_error "invalid --allow-local value"
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
    esac

    if [[ "$AAGENT_COMMAND" == "doctor" ]]; then
        if aagent_resolve_configuration doctor; then
            :
        else
            status=$?
            if [[ "$status" == "$AAGENT_EXIT_USAGE" ]]; then
                aagent_print_usage_error "$AAGENT_PARSE_ERROR"
            fi
            return "$status"
        fi
    else
        if aagent_resolve_configuration normal; then
            :
        else
            status=$?
            if [[ "$status" == "$AAGENT_EXIT_USAGE" ]]; then
                aagent_print_usage_error "$AAGENT_PARSE_ERROR"
            fi
            return "$status"
        fi
    fi

    case "$AAGENT_COMMAND" in
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

    if [[ -n "$AAGENT_EFFECTIVE_PROVIDER" ]]; then
        aagent_run_explicit_provider "$AAGENT_EFFECTIVE_PROVIDER" || return $?
        return "$AAGENT_EXIT_OK"
    fi

    aagent_run_automatic_provider
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    aagent_main "$@"
fi
