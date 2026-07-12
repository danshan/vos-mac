#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
cd "$repo_root"

fail() {
  printf 'native workspace contract failed: %s\n' "$1" >&2
  exit 1
}

rust_count=$(rg -n '^rust = "1\.96\.1"$' mise.toml | wc -l | tr -d ' ')
[[ "$rust_count" == "1" ]] || fail "rust 1.96.1 must appear exactly once"

members=$(awk '
  /^members = \[/ { in_members = 1; next }
  in_members && /^\]/ { in_members = 0; exit }
  in_members {
    gsub(/[",[:space:]]/, "")
    if (length($0) > 0) print
  }
' native/Cargo.toml)
expected_members=$'crates/open2jam-core\ncrates/open2jam-cli'
[[ "$members" == "$expected_members" ]] || fail "workspace members differ"

[[ $(rg -c '^resolver = "3"$' native/Cargo.toml) == "1" ]] || fail "resolver differs"
[[ $(rg -c '^edition = "2024"$' native/Cargo.toml) == "1" ]] || fail "edition differs"
[[ -f native/Cargo.lock ]] || fail "Cargo.lock is missing"

for crate_root in \
  native/crates/open2jam-core/src/lib.rs \
  native/crates/open2jam-cli/src/main.rs; do
  head -n 1 "$crate_root" | rg -qx '#!\[forbid\(unsafe_code\)\]' \
    || fail "unsafe_code is not forbidden in $crate_root"
done

temp_base=${TMPDIR:-/tmp}
temp_root=""
[[ -n "$temp_base" && "$temp_base" != "/" && "$temp_base" != "//" ]] \
  || fail "unsafe temporary base"
temp_base=$(cd "$temp_base" && pwd -P) \
  || fail "temporary base is unavailable"
temp_root=$(mktemp -d "$temp_base/open2jam-native-workspace.XXXXXX") \
  || fail "temporary root creation failed"

cleanup() {
  case "$temp_root" in
    "$temp_base"/open2jam-native-workspace.*)
      rm -rf -- "$temp_root"
      ;;
    *)
      printf 'refusing unsafe temporary cleanup: %s\n' \
        "${temp_root:-<empty>}" >&2
      return 1
      ;;
  esac
}
trap cleanup EXIT

expected_stdout="$temp_root/version.expected.stdout"
actual_stdout="$temp_root/version.actual.stdout"
actual_stderr="$temp_root/version.actual.stderr"
printf '%s\n' \
  '{"schemaVersion":1,"converterVersion":"0.1.0","protocolSchemaVersion":1,"catalogSchemaVersion":2,"bundleSchemaVersion":2,"catalogFormats":[],"bundleFormats":[]}' \
  >"$expected_stdout"

if ! mise exec -- cargo run --quiet --manifest-path native/Cargo.toml -p open2jam-cli --bin open2jam-converter --locked -- version \
  >"$actual_stdout" 2>"$actual_stderr"; then
  fail "version command failed"
fi
cmp -s "$expected_stdout" "$actual_stdout" \
  || fail "version stdout differs"
[[ ! -s "$actual_stderr" ]] \
  || fail "version stderr is not empty"

if ! awk '
  BEGIN {
    cargo_name = "car" "go"
    rustc_name = "rust" "c"
    current_file = ""
    logical_line = ""
    logical_line_number = 0
    invalid = 0
  }

  function is_name_character(character) {
    return character ~ /[[:alnum:]_.-]/
  }

  function inspect_tool(text, tool, file, line_number,
      remaining, offset, position, before, after, absolute, prefix, advance) {
    remaining = text
    offset = 0
    while ((position = index(remaining, tool)) > 0) {
      before = position > 1 ? substr(remaining, position - 1, 1) : ""
      after = substr(remaining, position + length(tool), 1)
      if (!is_name_character(before) && !is_name_character(after)) {
        absolute = offset + position
        prefix = substr(text, 1, absolute - 1)
        if (prefix !~ /(^|[[:space:];|&({!])mise[[:space:]]+exec[[:space:]]+--[[:space:]]*$/) {
          printf "%s:%d: Rust tool command is not launched by mise exec --\n", \
            file, line_number > "/dev/stderr"
          invalid = 1
        }
      }
      advance = position + length(tool) - 1
      offset += advance
      remaining = substr(remaining, advance + 1)
    }
  }

  function inspect(text, file, line_number) {
    inspect_tool(text, cargo_name, file, line_number)
    inspect_tool(text, rustc_name, file, line_number)
  }

  {
    if (current_file != FILENAME) {
      if (logical_line != "") {
        inspect(logical_line, current_file, logical_line_number)
      }
      current_file = FILENAME
      logical_line = ""
    }
    if (logical_line == "") {
      logical_line = $0
      logical_line_number = FNR
    } else {
      logical_line = logical_line "\n" $0
    }
    if ($0 ~ /\\[[:space:]]*$/) {
      sub(/\\[[:space:]]*$/, " ", logical_line)
      next
    }
    inspect(logical_line, FILENAME, logical_line_number)
    logical_line = ""
  }

  END {
    if (logical_line != "") {
      inspect(logical_line, current_file, logical_line_number)
    }
    if (invalid) {
      exit 1
    }
  }
' rewrite/tools/* native/README.md; then
  fail "bare Rust tool command found"
fi

printf 'native workspace contract passed\n'
