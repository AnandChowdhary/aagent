#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
install_script="$project_root/install.sh"
aagent_script="$project_root/aagent.sh"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_equals() {
    [[ "$1" == "$2" ]] || fail "$3 (expected '$2', got '$1')"
}

assert_contains() {
    [[ "$1" == *"$2"* ]] || fail "$3 (missing '$2')"
}

sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

# shellcheck disable=SC1090
source "$install_script"
for release_asset in aagent.sh aagent.ps1 install.sh install.ps1; do
    expected_release_checksum="$(aagent_installer_expected_checksum \
        "$project_root/SHA256SUMS" "$release_asset")"
    assert_equals "$(sha256_file "$project_root/$release_asset")" "$expected_release_checksum" \
        "repository checksum differs for $release_asset"
done
crlf_checksum_file="$(mktemp)"
printf '%s  aagent.sh\r\n' "$(sha256_file "$aagent_script")" >"$crlf_checksum_file"
assert_equals "$(aagent_installer_expected_checksum "$crlf_checksum_file" aagent.sh)" \
    "$(sha256_file "$aagent_script")" "CRLF checksum parsing differs"
rm -f "$crlf_checksum_file"

test_dir="$(mktemp -d)"
original_path="$PATH"
trap 'export PATH="$original_path"; rm -rf "$test_dir"' EXIT

install_dir="$test_dir/install dir/bin"
remote_dir="$test_dir/remote assets"
fake_bin="$test_dir/fake bin"
mkdir -p "$install_dir" "$remote_dir" "$fake_bin"

run_installer() {
    local prefix="$1"
    shift
    set +e
    env INSTALL_DIR="$install_dir" "$@" bash "$install_script" \
        >"$prefix.stdout" 2>"$prefix.stderr"
    AAGENT_TEST_STATUS=$?
    set -e
}

run_installer "$test_dir/local" AAGENT_SOURCE="$aagent_script" AAGENT_EXPECTED_VERSION=0.1.0
assert_equals "$AAGENT_TEST_STATUS" 0 "local Bash install failed"
[[ -x "$install_dir/aagent" ]] || fail "installed Bash runner is not executable"
assert_equals "$("$install_dir/aagent" --version)" "aagent 0.1.0" "installed version differs"
assert_contains "$("$install_dir/aagent" --help)" "aagent providers" "installed help is incomplete"
assert_equals "$(find "$install_dir" -name '.aagent.*' -o -name '.aagent-checksums.*' | wc -l | tr -d ' ')" \
    0 "successful install left staging files"

pipe_install_dir="$test_dir/pipe install/bin"
env INSTALL_DIR="$pipe_install_dir" AAGENT_SOURCE="$aagent_script" \
    AAGENT_EXPECTED_VERSION=0.1.0 bash <"$install_script" >/dev/null
assert_equals "$("$pipe_install_dir/aagent" --version)" "aagent 0.1.0" \
    "pipe-to-Bash install did not execute"

no_home_install_dir="$test_dir/no home/bin"
env -u HOME INSTALL_DIR="$no_home_install_dir" AAGENT_SOURCE="$aagent_script" \
    bash "$install_script" >/dev/null
assert_equals "$("$no_home_install_dir/aagent" --version)" "aagent 0.1.0" \
    "explicit install directory unexpectedly required HOME"

printf '%s\n' 'old-install' >"$install_dir/aagent"
run_installer "$test_dir/replace" AAGENT_SOURCE="$aagent_script"
assert_equals "$AAGENT_TEST_STATUS" 0 "existing Bash install was not replaced"
assert_equals "$("$install_dir/aagent" --version)" "aagent 0.1.0" "replacement version differs"

invalid_runner="$test_dir/invalid runner.sh"
printf '%s\n' '#!/usr/bin/env bash' 'exit 23' >"$invalid_runner"
cp "$install_dir/aagent" "$test_dir/known-good-aagent"
run_installer "$test_dir/invalid-local" AAGENT_SOURCE="$invalid_runner"
[[ "$AAGENT_TEST_STATUS" != 0 ]] || fail "invalid local runner unexpectedly installed"
assert_equals "$(sha256_file "$install_dir/aagent")" "$(sha256_file "$test_dir/known-good-aagent")" \
    "failed local install changed the existing runner"

cp "$aagent_script" "$remote_dir/aagent.sh"
runner_checksum="$(sha256_file "$remote_dir/aagent.sh")"
printf '%s  %s\n' "$runner_checksum" aagent.sh >"$remote_dir/SHA256SUMS"

# This fixture implements only curl's installer call shape and turns distinct
# HTTPS URLs into local release-asset copies.
# shellcheck disable=SC2016 # Variables are evaluated by the generated fixture.
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'url=""' \
    'destination=""' \
    'while (( $# > 0 )); do' \
    '    case "$1" in' \
    '        -o) destination="$2"; shift 2 ;;' \
    '        -*) shift ;;' \
    '        *) url="$1"; shift ;;' \
    '    esac' \
    'done' \
    'cp -- "$AAGENT_FAKE_REMOTE_DIR/${url##*/}" "$destination"' >"$fake_bin/curl"
chmod +x "$fake_bin/curl"
export AAGENT_FAKE_REMOTE_DIR="$remote_dir"

run_installer "$test_dir/remote" \
    PATH="$fake_bin:$original_path" \
    AAGENT_SOURCE=https://downloads.example.test/aagent.sh \
    AAGENT_CHECKSUM_SOURCE=https://downloads.example.test/SHA256SUMS \
    AAGENT_EXPECTED_VERSION=0.1.0
assert_equals "$AAGENT_TEST_STATUS" 0 "checksummed remote Bash install failed"
assert_equals "$("$install_dir/aagent" --version)" "aagent 0.1.0" "remote installed version differs"

if command -v cygpath >/dev/null 2>&1; then
    posix_windows_install_dir="$test_dir/windows native install/bin"
    windows_install_dir="$(cygpath -w "$posix_windows_install_dir")"
    windows_remote_dir="$(cygpath -m "$remote_dir")"
    previous_install_dir="$install_dir"
    install_dir="$windows_install_dir"
    run_installer "$test_dir/windows-native-path" \
        PATH="$original_path" \
        AAGENT_SOURCE="file:///$windows_remote_dir/aagent.sh" \
        AAGENT_CHECKSUM_SOURCE="file:///$windows_remote_dir/SHA256SUMS" \
        AAGENT_EXPECTED_VERSION=0.1.0
    assert_equals "$AAGENT_TEST_STATUS" 0 \
        "checksummed remote Bash install with a native Windows path failed"
    assert_equals "$("$posix_windows_install_dir/aagent" --version)" "aagent 0.1.0" \
        "native Windows path installed version differs"
    install_dir="$previous_install_dir"
fi

cp "$install_dir/aagent" "$test_dir/remote-known-good"
printf '%064d  aagent.sh\n' 0 >"$remote_dir/SHA256SUMS"
run_installer "$test_dir/bad-checksum" \
    PATH="$fake_bin:$original_path" \
    AAGENT_SOURCE=https://downloads.example.test/aagent.sh \
    AAGENT_CHECKSUM_SOURCE=https://downloads.example.test/SHA256SUMS
[[ "$AAGENT_TEST_STATUS" != 0 ]] || fail "bad checksum unexpectedly installed"
assert_contains "$(<"$test_dir/bad-checksum.stderr")" "checksum verification failed" \
    "bad checksum error differs"
assert_equals "$(sha256_file "$install_dir/aagent")" "$(sha256_file "$test_dir/remote-known-good")" \
    "checksum failure changed the existing runner"

run_installer "$test_dir/version-mismatch" \
    AAGENT_SOURCE="$aagent_script" AAGENT_EXPECTED_VERSION=9.9.9
[[ "$AAGENT_TEST_STATUS" != 0 ]] || fail "version mismatch unexpectedly installed"
assert_contains "$(<"$test_dir/version-mismatch.stderr")" "expected version 9.9.9" \
    "version mismatch error differs"

assert_equals "$(find "$install_dir" -name '.aagent.*' -o -name '.aagent-checksums.*' | wc -l | tr -d ' ')" \
    0 "failed install left staging files"

printf 'Install Bash tests passed.\n'
