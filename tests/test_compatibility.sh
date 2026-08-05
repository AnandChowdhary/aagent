#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
compatibility_script="$project_root/scripts/check-provider-compatibility.sh"
test_dir="$(mktemp -d)"

cleanup() {
    rm -rf "$test_dir"
}
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_contains() {
    local value="$1"
    local expected="$2"
    local message="$3"
    [[ "$value" == *"$expected"* ]] || fail "$message"
}

fake_cli="$test_dir/current provider cli"
cat >"$fake_cli" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

provider="${AAGENT_FAKE_COMPAT_PROVIDER:?}"
surface="${1-} ${2-}"

if [[ "${AAGENT_FAKE_COMPAT_MISSING-}" == "$provider:$surface" ]]; then
    printf 'intentionally drifted help\n'
    exit 0
fi

case "$surface" in
    '--version ')
        printf '%s 1.0.0\n' "$provider"
        ;;
    '--help ')
        case "$provider" in
            claude) printf '%s\n' 'Usage: claude --print --model' ;;
            codex) printf '%s\n' 'Usage: codex exec app-server login' ;;
            opencode) printf '%s\n' 'Usage: opencode run auth' ;;
            copilot) printf '%s\n' 'Usage: copilot --prompt --model --silent --no-ask-user' ;;
            amp) printf '%s\n' 'Usage: amp --execute --stream-json' ;;
            gemini) printf '%s\n' 'Usage: gemini --prompt --model' ;;
            cursor) printf '%s\n' 'Usage: agent Start the Cursor Agent --print --output-format --model --force status' ;;
            droid) printf '%s\n' 'Usage: droid exec' ;;
            goose) printf '%s\n' 'Usage: goose run' ;;
        esac
        ;;
    'auth --help')
        case "$provider" in
            claude) printf '%s\n' 'auth status' ;;
            opencode) printf '%s\n' 'auth list' ;;
            *) exit 2 ;;
        esac
        ;;
    'exec --help')
        case "$provider" in
            codex) printf '%s\n' 'codex exec --model' ;;
            droid) printf '%s\n' 'droid exec --output-format --model --use-spec --auto --skip-permissions-unsafe Read-only mode' ;;
            *) exit 2 ;;
        esac
        ;;
    'app-server --help') printf '%s\n' 'codex app-server' ;;
    'login --help') printf '%s\n' 'codex login status' ;;
    'run --help')
        case "$provider" in
            opencode) printf '%s\n' 'opencode run --model --format' ;;
            goose) printf '%s\n' 'goose run --text --instructions --model --output-format --provider --no-session' ;;
            *) exit 2 ;;
        esac
        ;;
    'help providers') printf '%s\n' 'COPILOT_PROVIDER_BASE_URL' ;;
    'status --help') printf '%s\n' 'agent status --format json' ;;
    *) exit 2 ;;
esac
EOF
chmod +x "$fake_cli"

for provider in claude codex opencode copilot amp gemini cursor droid goose; do
    output_dir="$test_dir/reports $provider"
    output="$(
        AAGENT_FAKE_COMPAT_PROVIDER="$provider" \
        AAGENT_COMPAT_OUTPUT_DIR="$output_dir" \
            bash "$compatibility_script" "$provider" "$fake_cli"
    )"
    assert_contains "$output" "passed for $provider" "$provider compatibility success differs"
    [[ -s "$output_dir/$provider.txt" ]] || fail "$provider report was not written"
    report="$(<"$output_dir/$provider.txt")"
    assert_contains "$report" "## version" "$provider report omitted version output"
    assert_contains "$report" "## help" "$provider report omitted help output"
done

ln -s "$fake_cli" "$test_dir/agent"
default_cursor_output="$(
    PATH="$test_dir:$PATH" \
    AAGENT_FAKE_COMPAT_PROVIDER=cursor \
    AAGENT_COMPAT_OUTPUT_DIR="$test_dir/default-cursor-report" \
        bash "$compatibility_script" cursor
)"
assert_contains "$default_cursor_output" "passed for cursor" "Cursor default executable is not agent"

ln -s "$fake_cli" "$test_dir/droid"
default_droid_output="$(
    PATH="$test_dir:$PATH" \
    AAGENT_FAKE_COMPAT_PROVIDER=droid \
    AAGENT_COMPAT_OUTPUT_DIR="$test_dir/default-droid-report" \
        bash "$compatibility_script" droid
)"
assert_contains "$default_droid_output" "passed for droid" "Droid default executable differs"

ln -s "$fake_cli" "$test_dir/goose"
default_goose_output="$(
    PATH="$test_dir:$PATH" \
    AAGENT_FAKE_COMPAT_PROVIDER=goose \
    AAGENT_COMPAT_OUTPUT_DIR="$test_dir/default-goose-report" \
        bash "$compatibility_script" goose
)"
assert_contains "$default_goose_output" "passed for goose" "Goose default executable differs"

set +e
AAGENT_FAKE_COMPAT_PROVIDER=amp \
AAGENT_FAKE_COMPAT_MISSING='amp:--help ' \
AAGENT_COMPAT_OUTPUT_DIR="$test_dir/drift-report" \
    bash "$compatibility_script" amp "$fake_cli" \
    >"$test_dir/drift.stdout" 2>"$test_dir/drift.stderr"
drift_status=$?
set -e
[[ "$drift_status" == 1 ]] || fail "command drift did not fail the check"
assert_contains "$(<"$test_dir/drift.stderr")" \
    "amp help no longer advertises --execute" "command drift diagnostic differs"

set +e
bash "$compatibility_script" cline "$fake_cli" \
    >"$test_dir/unknown.stdout" 2>"$test_dir/unknown.stderr"
unknown_status=$?
set -e
[[ "$unknown_status" == 64 ]] || fail "unknown provider did not use status 64"
assert_contains "$(<"$test_dir/unknown.stderr")" \
    "unknown supported provider: cline" "unknown provider diagnostic differs"

printf 'Compatibility workflow Bash tests passed.\n'
