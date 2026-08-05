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
            amp) printf '%s\n' 'Usage: amp --execute --stream-json' ;;
            gemini) printf '%s\n' 'Usage: gemini --prompt --model' ;;
        esac
        ;;
    'auth --help')
        case "$provider" in
            claude) printf '%s\n' 'auth status' ;;
            opencode) printf '%s\n' 'auth list' ;;
            *) exit 2 ;;
        esac
        ;;
    'exec --help') printf '%s\n' 'codex exec --model' ;;
    'app-server --help') printf '%s\n' 'codex app-server' ;;
    'login --help') printf '%s\n' 'codex login status' ;;
    'run --help') printf '%s\n' 'opencode run --model --format' ;;
    *) exit 2 ;;
esac
EOF
chmod +x "$fake_cli"

for provider in claude codex opencode amp gemini; do
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
bash "$compatibility_script" cursor "$fake_cli" \
    >"$test_dir/unknown.stdout" 2>"$test_dir/unknown.stderr"
unknown_status=$?
set -e
[[ "$unknown_status" == 64 ]] || fail "unknown provider did not use status 64"
assert_contains "$(<"$test_dir/unknown.stderr")" \
    "unknown Tier 1 provider: cursor" "unknown provider diagnostic differs"

printf 'Compatibility workflow Bash tests passed.\n'
