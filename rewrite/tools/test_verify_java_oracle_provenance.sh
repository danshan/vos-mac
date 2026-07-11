#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT_DIR"

VERIFIER="rewrite/tools/verify_java_oracle_provenance.sh"
TEMP_BASE_INPUT="${TMPDIR:-/tmp}"
TEMP_BASE=""
TEST_ROOT=""
WORKTREE=""

[[ -x "$VERIFIER" ]] || {
	printf 'Missing executable Java oracle provenance verifier.\n' >&2
	exit 1
}
if [[ -z "$TEMP_BASE_INPUT" || "$TEMP_BASE_INPUT" == "/" \
	|| ! -d "$TEMP_BASE_INPUT" ]] \
	|| ! TEMP_BASE="$(cd "$TEMP_BASE_INPUT" && pwd -P)" \
	|| [[ -z "$TEMP_BASE" || "$TEMP_BASE" == "/" ]]; then
	printf 'Unsafe Java oracle test temp root: %s\n' \
		"${TEMP_BASE_INPUT:-<empty>}" >&2
	exit 1
fi

cleanup() {
	if [[ -n "$TEST_ROOT" && "$TEST_ROOT" != "/" \
		&& "$TEST_ROOT" == "$TEMP_BASE"/* ]]; then
		rm -rf "$TEST_ROOT"
	fi
}
trap cleanup EXIT INT TERM HUP

if ! baseline_output="$(bash "$VERIFIER" 2>&1)"; then
	printf 'Java oracle provenance baseline failed:\n%s\n' "$baseline_output" >&2
	exit 1
fi

TEST_ROOT="$(mktemp -d "$TEMP_BASE/open2jam-oracle-provenance.XXXXXX")"
TEST_ROOT="$(cd "$TEST_ROOT" && pwd -P)"
WORKTREE="$TEST_ROOT/worktree"
git clone --quiet --local --no-hardlinks "$ROOT_DIR" "$WORKTREE"

cp "$VERIFIER" "$WORKTREE/$VERIFIER"
cp rewrite/golden/java-migration/manifest.json \
	"$WORKTREE/rewrite/golden/java-migration/manifest.json"
cp rewrite/golden/java-migration/README.md \
	"$WORKTREE/rewrite/golden/java-migration/README.md"
cp rewrite/golden/java-migration/oracle-tree.txt \
	"$WORKTREE/rewrite/golden/java-migration/oracle-tree.txt"
cp rewrite/golden/java-migration/manifest.files \
	"$WORKTREE/rewrite/golden/java-migration/manifest.files"
cp rewrite/golden/java-migration/manifest.sha256 \
	"$WORKTREE/rewrite/golden/java-migration/manifest.sha256"

refresh_corpus_hashes() {
	local corpus="$WORKTREE/rewrite/golden/java-migration"
	local current_manifest="$corpus/manifest.sha256"
	local next_manifest="$corpus/manifest.sha256.next"
	local line
	local relative_path
	: >"$next_manifest"
	while IFS= read -r line; do
		relative_path="${line#*  }"
		(
			cd "$corpus"
			shasum -a 256 "$relative_path"
		) >>"$next_manifest"
	done <"$current_manifest"
	mv "$next_manifest" "$current_manifest"
}

expect_oracle_mutation_failure() {
	local description="$1"
	local relative_path="$2"
	local output

	printf '\nTask 8 mutation: %s\n' "$description" >>"$WORKTREE/$relative_path"
	printf '\nCoordinated corpus regeneration: %s\n' "$description" \
		>>"$WORKTREE/rewrite/golden/java-migration/README.md"
	refresh_corpus_hashes
	if output="$(cd "$WORKTREE" && bash "$VERIFIER" 2>&1)"; then
		printf '%s unexpectedly passed the oracle provenance gate.\n' "$description" >&2
		exit 1
	fi
	if [[ "$output" != *"Oracle production tree differs from pinned overlay"* ]]; then
		printf '%s failed for the wrong reason:\n%s\n' "$description" "$output" >&2
		exit 1
	fi
	git -C "$WORKTREE" show "HEAD:$relative_path" >"$WORKTREE/$relative_path"
	cp rewrite/golden/java-migration/README.md \
		"$WORKTREE/rewrite/golden/java-migration/README.md"
	cp rewrite/golden/java-migration/manifest.sha256 \
		"$WORKTREE/rewrite/golden/java-migration/manifest.sha256"
}

expect_oracle_mutation_failure \
	"exporter plus corpus mutation" \
	src/org/open2jam/export/VosCatalogExporter.java
expect_oracle_mutation_failure \
	"parser plus corpus mutation" \
	parsers/src/org/open2jam/parsers/OsuManiaParser.java
expect_oracle_mutation_failure \
	"resource plus corpus mutation" \
	src/resources/fonts/LICENSE_LIBERATION

untracked_oracle="$WORKTREE/src/org/open2jam/export/UntrackedOracleMutation.java"
printf 'package org.open2jam.export;\n' >"$untracked_oracle"
if output="$(cd "$WORKTREE" && bash "$VERIFIER" 2>&1)"; then
	printf 'Untracked oracle input unexpectedly passed the provenance gate.\n' >&2
	exit 1
fi
if [[ "$output" != *"Oracle production tree contains untracked inputs"* ]]; then
	printf 'Untracked oracle input failed for the wrong reason:\n%s\n' "$output" >&2
	exit 1
fi

printf 'Java oracle provenance behavioral contract passed.\n'
