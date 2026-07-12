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

expected='{"schemaVersion":1,"converterVersion":"0.1.0","protocolSchemaVersion":1,"catalogSchemaVersion":2,"bundleSchemaVersion":2,"catalogFormats":[],"bundleFormats":[]}'
actual=$(mise exec -- cargo run --quiet --manifest-path native/Cargo.toml -p open2jam-cli --bin open2jam-converter --locked -- version)
[[ "$actual" == "$expected" ]] || fail "version output differs"

if rg -n '^[[:space:]]*(cargo|rustc)[[:space:]]' rewrite/tools native/README.md; then
  fail "bare cargo or rustc command found"
fi

printf 'native workspace contract passed\n'
