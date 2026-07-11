#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

INITIAL="rewrite/tools/verify_vos_godot_initial.sh"
PARITY="rewrite/tools/verify_vos_godot_java_parity.sh"

for required_file in "$INITIAL" "$PARITY"; do
	if [[ ! -f "$required_file" ]]; then
		printf 'Missing aggregate verifier: %s\n' "$required_file" >&2
		exit 1
	fi
done

while IFS= read -r resource_path; do
	local_path="rewrite/godot/${resource_path#res://}"
	if [[ ! -f "$local_path" ]]; then
		printf 'Missing declared Godot test: %s\n' "$local_path" >&2
		exit 1
	fi
done < <(sed -n 's/^[[:space:]]*run_godot_test \(res:\/\/[^[:space:]]*\)$/\1/p' "$INITIAL")

for class_name in \
	OsuManiaParserTest ChartModelLoaderTest MusicSelectionSelectionTest \
	ChartDisplayTest ConfigTest JudgmentStrategyOracleFixtureTest; do
	if ! grep -Eq "^[[:space:]]*${class_name}[[:space:]]*$" "$INITIAL"; then
		printf 'Missing Java test from aggregate gate: %s\n' "$class_name" >&2
		exit 1
	fi
done

if retired_matches="$(grep -Ein \
	'partytime|networkStatusTextLayout|"startY":64\.0|serverLineHeight|connectionLineHeight' \
	"$INITIAL" "$PARITY" 2>&1)"; then
	printf 'Aggregate verification still contains a retired contract:\n%s\n' \
		"$retired_matches" >&2
	exit 1
else
	grep_status=$?
	if [[ "$grep_status" -ne 1 ]]; then
		printf 'Unable to inspect aggregate verifier contracts:\n%s\n' \
			"$retired_matches" >&2
		exit 1
	fi
fi

printf 'Aggregate verification manifest contract passed.\n'
