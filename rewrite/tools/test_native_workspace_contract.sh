#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
gate_source="$repo_root/rewrite/tools/test_native_workspace.sh"
temp_base=${TMPDIR:-/tmp}
fixture_root=""

fail() {
  printf 'native workspace self-test failed: %s\n' "$1" >&2
  exit 1
}

[[ -n "$temp_base" && "$temp_base" != "/" && "$temp_base" != "//" ]] \
  || fail "unsafe temporary base"
temp_base=$(cd "$temp_base" && pwd -P)
fixture_root=$(mktemp -d "$temp_base/open2jam-native-workspace-test.XXXXXX")

cleanup() {
  case "$fixture_root" in
    "$temp_base"/open2jam-native-workspace-test.*)
      rm -rf -- "$fixture_root"
      ;;
    *)
      printf 'refusing unsafe fixture cleanup: %s\n' "${fixture_root:-<empty>}" >&2
      return 1
      ;;
  esac
}
trap cleanup EXIT

cargo_tool='car''go'
rustc_tool='rust''c'
expected_json='{"schemaVersion":1,"converterVersion":"0.1.0","protocolSchemaVersion":1,"catalogSchemaVersion":2,"bundleSchemaVersion":2,"catalogFormats":[],"bundleFormats":[]}'
gate_stdout="$fixture_root/gate.stdout"
gate_stderr="$fixture_root/gate.stderr"
probe="$fixture_root/rewrite/tools/probe.sh"

mkdir -p \
  "$fixture_root/bin" \
  "$fixture_root/native/crates/open2jam-core/src" \
  "$fixture_root/native/crates/open2jam-cli/src" \
  "$fixture_root/rewrite/tools" \
  "$fixture_root/tmp"
cp "$gate_source" "$fixture_root/rewrite/tools/test_native_workspace.sh"
chmod +x "$fixture_root/rewrite/tools/test_native_workspace.sh"

printf '%s\n' 'rust = "1.96.1"' >"$fixture_root/mise.toml"
cat >"$fixture_root/native/Cargo.toml" <<'EOF'
[workspace]
members = [
  "crates/open2jam-core",
  "crates/open2jam-cli",
]
resolver = "3"

[workspace.package]
edition = "2024"
EOF
printf '%s\n' '# lockfile fixture' >"$fixture_root/native/Cargo.lock"
printf '%s\n' '#![forbid(unsafe_code)]' \
  >"$fixture_root/native/crates/open2jam-core/src/lib.rs"
printf '%s\n' '#![forbid(unsafe_code)]' \
  >"$fixture_root/native/crates/open2jam-cli/src/main.rs"
printf '%s\n' '# Native fixture' >"$fixture_root/native/README.md"

cat >"$fixture_root/bin/mise" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[[ "${1:-}" == "exec" && "${2:-}" == "--" ]] || exit 2
printf '%b' "${NATIVE_TEST_STDOUT_ESCAPED:-}"
printf '%s' "${NATIVE_TEST_STDERR:-}" >&2
exit "${NATIVE_TEST_EXIT_CODE:-0}"
EOF
chmod +x "$fixture_root/bin/mise"

write_probe() {
  printf '%s\n' "$1" >"$probe"
}

write_allowed_probe() {
  {
    printf 'mise exec -- %s test\n' "$cargo_tool"
    printf 'if mise exec -- %s test; then :; fi\n' "$cargo_tool"
    printf 'result=$(mise exec -- %s --version)\n' "$rustc_tool"
    printf 'MODE=test mise exec -- %s metadata\n' "$cargo_tool"
    printf 'env MODE=test mise exec -- %s --version\n' "$rustc_tool"
  } >"$probe"
}

run_gate() {
  local stdout_escaped="$1"
  local stderr_text="$2"
  local exit_code="${3:-0}"
  local status

  if PATH="$fixture_root/bin:$PATH" \
    TMPDIR="$fixture_root/tmp" \
    NATIVE_TEST_STDOUT_ESCAPED="$stdout_escaped" \
    NATIVE_TEST_STDERR="$stderr_text" \
    NATIVE_TEST_EXIT_CODE="$exit_code" \
    bash "$fixture_root/rewrite/tools/test_native_workspace.sh" \
      >"$gate_stdout" 2>"$gate_stderr"; then
    return 0
  else
    status=$?
  fi
  return "$status"
}

assert_no_temp_leak() {
  if find "$fixture_root/tmp" -mindepth 1 -maxdepth 1 -print -quit \
    | rg -q .; then
    fail "production gate leaked its temporary root"
  fi
}

expect_gate_success() {
  local description="$1"
  local stdout_escaped="$2"
  local stderr_text="${3:-}"

  if ! run_gate "$stdout_escaped" "$stderr_text"; then
    printf '%s: expected success\n' "$description" >&2
    sed -n '1,40p' "$gate_stderr" >&2
    exit 1
  fi
  cmp -s "$gate_stdout" <(printf 'native workspace contract passed\n') \
    || fail "$description produced unexpected stdout"
  [[ ! -s "$gate_stderr" ]] \
    || fail "$description produced unexpected stderr"
  assert_no_temp_leak
}

expect_gate_failure() {
  local description="$1"
  local stdout_escaped="$2"
  local stderr_text="$3"
  local expected_error="$4"

  if run_gate "$stdout_escaped" "$stderr_text"; then
    fail "$description was accepted"
  fi
  rg -Fq "$expected_error" "$gate_stderr" \
    || fail "$description did not report the expected error"
  assert_no_temp_leak
}

expect_source_rejected() {
  local description="$1"
  local source_line="$2"

  write_probe "$source_line"
  expect_gate_failure \
    "$description" \
    "$expected_json\\n" \
    "" \
    "native workspace contract failed: bare Rust tool command found"
}

write_allowed_probe
expect_gate_success "mise-wrapped command forms" "$expected_json\\n"

expect_source_rejected \
  "conditional invocation" \
  "if ${cargo_tool} test; then :; fi"
expect_source_rejected \
  "command substitution invocation" \
  "result=\$(${cargo_tool} --version)"
expect_source_rejected \
  "assignment-prefixed invocation" \
  "MODE=test ${cargo_tool} metadata"
expect_source_rejected \
  "env invocation" \
  "env ${rustc_tool} --version"

write_allowed_probe
expect_gate_success "exact one-LF version output" "$expected_json\\n"
expect_gate_failure \
  "zero-LF version output" \
  "$expected_json" \
  "" \
  "native workspace contract failed: version stdout differs"
expect_gate_failure \
  "multiple-LF version output" \
  "$expected_json\\n\\n" \
  "" \
  "native workspace contract failed: version stdout differs"
expect_gate_failure \
  "non-empty version stderr" \
  "$expected_json\\n" \
  "unexpected stderr" \
  "native workspace contract failed: version stderr is not empty"

printf 'native workspace self-test passed\n'
