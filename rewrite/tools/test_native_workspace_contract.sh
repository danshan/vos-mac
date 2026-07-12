#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
gate_source="$repo_root/rewrite/tools/test_native_workspace.sh"
self_test_source="$repo_root/rewrite/tools/test_native_workspace_contract.sh"
temp_base=${TMPDIR:-/tmp}
fixture_root=""

fail() {
  printf 'native workspace self-test failed: %s\n' "$1" >&2
  exit 1
}

canonicalize_temp_base() {
  local candidate="$1"
  local canonical

  canonical=$(cd "$candidate" && pwd -P) \
    || fail "temporary base is unavailable"
  [[ -n "$canonical" && "$canonical" != "/" && "$canonical" != "//" ]] \
    || fail "unsafe temporary base"
  printf '%s\n' "$canonical"
}

if [[ "${1:-}" == "--temp-base-probe" ]]; then
  temp_base=$(canonicalize_temp_base "$temp_base")
  exit 0
fi

requested_case=${1:-all}
case "$requested_case" in
  all|double-dollar|double-backtick|unquoted-heredoc) ;;
  *) fail "unknown self-test case: $requested_case" ;;
esac

temp_base=$(canonicalize_temp_base "$temp_base")
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

cargo_tool='cargo'
rustc_tool='rustc'
expected_json='{"schemaVersion":1,"converterVersion":"0.1.0","protocolSchemaVersion":1,"catalogSchemaVersion":2,"bundleSchemaVersion":2,"catalogFormats":[],"bundleFormats":[]}'
gate_stdout="$fixture_root/gate.stdout"
gate_stderr="$fixture_root/gate.stderr"
probe="$fixture_root/rewrite/tools/probe.sh"
non_shell_probe="$fixture_root/rewrite/tools/probe.java"
root_link="$fixture_root/root-link"
temp_create_marker="$fixture_root/temp-create.marker"
cleanup_marker="$fixture_root/cleanup.marker"
temp_probe_stdout="$fixture_root/temp-probe.stdout"
temp_probe_stderr="$fixture_root/temp-probe.stderr"

mkdir -p \
  "$fixture_root/bin" \
  "$fixture_root/native/crates/open2jam-core/src" \
  "$fixture_root/native/crates/open2jam-cli/src" \
  "$fixture_root/rewrite/tools" \
  "$fixture_root/temp-probe-bin" \
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

cat >"$fixture_root/temp-probe-bin/mktemp" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

: "${NATIVE_TEMP_CREATE_MARKER:?}"
printf 'called\n' >>"$NATIVE_TEMP_CREATE_MARKER"
exit 1
EOF
chmod +x "$fixture_root/temp-probe-bin/mktemp"

cat >"$fixture_root/temp-probe-bin/rm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

: "${NATIVE_CLEANUP_MARKER:?}"
printf 'called\n' >>"$NATIVE_CLEANUP_MARKER"
exit 1
EOF
chmod +x "$fixture_root/temp-probe-bin/rm"

ln -s / "$root_link"

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

write_comment_probe() {
  printf '# %s test\n' "$cargo_tool" >"$probe"
}

write_non_utf8_comment_probe() {
  printf '# \377\n' >"$probe"
}

write_non_utf8_quoted_probe() {
  printf "message='" >"$probe"
  printf '\377' >>"$probe"
  printf "'\n" >>"$probe"
}

write_quoted_data_probe() {
  printf 'message=' >"$probe"
  printf "'%s test; %s --version'\n" "$cargo_tool" "$rustc_tool" \
    >>"$probe"
}

write_quoted_heredoc_operator_probe() {
  printf 'message="<<NATIVE_DATA"\n' >"$probe"
}

write_heredoc_probe() {
  {
    printf "cat <<'NATIVE_DATA'\n"
    printf '$(%s test)\n' "$cargo_tool"
    printf '`%s --version`\n' "$rustc_tool"
    printf 'NATIVE_DATA\n'
  } >"$probe"
}

write_double_dollar_probe() {
  printf 'message="$(%s test)"\n' "$cargo_tool" >"$probe"
}

write_double_backtick_probe() {
  printf 'message="`%s --version`"\n' "$rustc_tool" >"$probe"
}

write_unquoted_heredoc_probe() {
  {
    printf 'cat <<NATIVE_DATA\n'
    printf '$(%s test)\n' "$cargo_tool"
    printf '$(%s --version)\n' "$rustc_tool"
    printf 'NATIVE_DATA\n'
  } >"$probe"
}

write_double_mise_probe() {
  printf 'message="$(mise exec -- %s --version)"\n' \
    "$cargo_tool" >"$probe"
}

write_non_shell_probe() {
  printf 'String command = "%s test && %s --version";\n' \
    "$cargo_tool" "$rustc_tool" >"$non_shell_probe"
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

expect_current_probe_rejected() {
  expect_gate_failure \
    "$1" "$expected_json\\n" "" \
    "native workspace contract failed: bare Rust tool command found"
}

expect_source_allowed() {
  local description="$1"

  expect_gate_success "$description" "$expected_json\\n"
}

expect_unsafe_temp_base_rejected() {
  if PATH="$fixture_root/temp-probe-bin:$fixture_root/bin:$PATH" \
    TMPDIR="$root_link" \
    NATIVE_TEMP_CREATE_MARKER="$temp_create_marker" \
    NATIVE_CLEANUP_MARKER="$cleanup_marker" \
    NATIVE_TEST_STDOUT_ESCAPED="$expected_json\\n" \
    NATIVE_TEST_STDERR="" \
    NATIVE_TEST_EXIT_CODE=0 \
    bash "$fixture_root/rewrite/tools/test_native_workspace.sh" \
      >"$temp_probe_stdout" 2>"$temp_probe_stderr"; then
    fail "production gate accepted a temporary base resolving to root"
  fi
  if ! cmp -s "$temp_probe_stderr" \
    <(printf 'native workspace contract failed: unsafe temporary base\n'); then
    sed -n '1,20p' "$temp_probe_stderr" >&2
    fail "production gate did not report exact unsafe temporary base"
  fi
  [[ ! -e "$temp_create_marker" ]] \
    || fail "production gate attempted root-level temporary creation"
  [[ ! -e "$cleanup_marker" ]] \
    || fail "production gate attempted cleanup for an unsafe base"

  if PATH="$fixture_root/temp-probe-bin:$PATH" \
    TMPDIR="$root_link" \
    NATIVE_TEMP_CREATE_MARKER="$temp_create_marker" \
    NATIVE_CLEANUP_MARKER="$cleanup_marker" \
    bash "$self_test_source" --temp-base-probe \
      >"$temp_probe_stdout" 2>"$temp_probe_stderr"; then
    fail "self-test accepted a temporary base resolving to root"
  fi
  if ! cmp -s "$temp_probe_stderr" \
    <(printf 'native workspace self-test failed: unsafe temporary base\n'); then
    sed -n '1,20p' "$temp_probe_stderr" >&2
    fail "self-test did not report exact unsafe temporary base"
  fi
  [[ ! -e "$temp_create_marker" ]] \
    || fail "self-test attempted root-level temporary creation"
  [[ ! -e "$cleanup_marker" ]] \
    || fail "self-test attempted cleanup for an unsafe base"
}

run_expansion_case() {
  case "$1" in
    double-dollar) write_double_dollar_probe ;;
    double-backtick) write_double_backtick_probe ;;
    unquoted-heredoc) write_unquoted_heredoc_probe ;;
  esac
  expect_current_probe_rejected "$1 executable expansion"
}

if [[ "$requested_case" != "all" ]]; then
  run_expansion_case "$requested_case"
  printf 'native workspace self-test passed\n'
  exit 0
fi

write_allowed_probe
expect_gate_success "mise-wrapped command forms" "$expected_json\\n"

expect_unsafe_temp_base_rejected

write_comment_probe
expect_source_allowed "shell comment data"
write_non_utf8_comment_probe
expect_source_allowed "non-UTF8 shell comment data"
write_non_utf8_quoted_probe
expect_source_allowed "non-UTF8 quoted shell data"
write_quoted_data_probe
expect_source_allowed "quoted shell data"
write_quoted_heredoc_operator_probe
expect_source_allowed "quoted heredoc operator data"
write_heredoc_probe
expect_source_allowed "quoted heredoc data"
write_double_mise_probe
expect_source_allowed "double-quoted mise expansion"
write_allowed_probe
write_non_shell_probe
expect_source_allowed "non-shell source data"

run_expansion_case double-dollar
run_expansion_case double-backtick
run_expansion_case unquoted-heredoc

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
