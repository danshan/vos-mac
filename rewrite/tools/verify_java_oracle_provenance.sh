#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT_DIR"

PINNED_OVERLAY_COMMIT="62ece7083ea473f02ecc9a83ee7d3e151905bf0e"
PINNED_TREE_SHA256="206614ef6d5df3ae2cd5f42ea0b1f0499cd7a3137cfbdf11c5a345fb8ff6978e"
CORPUS_DIR="rewrite/golden/java-migration"
TREE_MANIFEST="$CORPUS_DIR/oracle-tree.txt"
PROVENANCE_MANIFEST="$CORPUS_DIR/manifest.json"
ORACLE_PATHS=(
	src/org/open2jam
	parsers/src
	src/resources
)

for required_command in cat git grep sed shasum; do
	if ! command -v "$required_command" >/dev/null 2>&1; then
		printf 'Missing Java oracle verifier command: %s\n' "$required_command" >&2
		exit 1
	fi
done

for required_file in "$TREE_MANIFEST" "$PROVENANCE_MANIFEST"; do
	if [[ ! -f "$required_file" || -L "$required_file" ]]; then
		printf 'Missing regular Java oracle provenance file: %s\n' "$required_file" >&2
		exit 1
	fi
done

if ! git cat-file -e "$PINNED_OVERLAY_COMMIT^{commit}" 2>/dev/null; then
	printf 'Pinned Java determinism overlay commit is unavailable: %s\n' \
		"$PINNED_OVERLAY_COMMIT" >&2
	exit 1
fi

for oracle_path in "${ORACLE_PATHS[@]}"; do
	if [[ ! -d "$oracle_path" || -L "$oracle_path" ]]; then
		printf 'Missing regular Java oracle root: %s\n' "$oracle_path" >&2
		exit 1
	fi
	if ! git cat-file -e "$PINNED_OVERLAY_COMMIT:$oracle_path" 2>/dev/null; then
		printf 'Pinned Java oracle root is absent from overlay: %s\n' "$oracle_path" >&2
		exit 1
	fi
done

required_paths='"javaOraclePaths": ["src/org/open2jam", "parsers/src", "src/resources"]'
required_tree_file='"javaOracleTreeFile": "oracle-tree.txt"'
required_tree_sha="\"javaOracleTreeSha256\": \"$PINNED_TREE_SHA256\""
for required_text in "$required_paths" "$required_tree_file" "$required_tree_sha"; do
	if ! grep -Fq "$required_text" "$PROVENANCE_MANIFEST"; then
		printf 'Java oracle provenance manifest omits: %s\n' "$required_text" >&2
		exit 1
	fi
done

if ! pinned_tree="$(LC_ALL=C git ls-tree -r --full-tree \
	"$PINNED_OVERLAY_COMMIT" -- "${ORACLE_PATHS[@]}")"; then
	printf 'Unable to read pinned Java oracle tree.\n' >&2
	exit 1
fi
if [[ -z "$pinned_tree" ]]; then
	printf 'Pinned Java oracle tree is empty.\n' >&2
	exit 1
fi

recorded_tree="$(cat "$TREE_MANIFEST")"
if [[ "$recorded_tree" != "$pinned_tree" ]]; then
	printf 'Recorded Java oracle tree does not match the pinned overlay.\n' >&2
	exit 1
fi

tree_hash_line="$(printf '%s\n' "$pinned_tree" | shasum -a 256)"
tree_hash="${tree_hash_line%% *}"
if [[ "$tree_hash" != "$PINNED_TREE_SHA256" ]]; then
	printf 'Pinned Java oracle tree digest mismatch: expected %s, got %s\n' \
		"$PINNED_TREE_SHA256" "$tree_hash" >&2
	exit 1
fi

if ! git diff --no-ext-diff --quiet "$PINNED_OVERLAY_COMMIT" -- \
	"${ORACLE_PATHS[@]}"; then
	printf 'Oracle production tree differs from pinned overlay %s.\n' \
		"$PINNED_OVERLAY_COMMIT" >&2
	exit 1
fi

untracked_inputs="$(git ls-files --others --exclude-standard -- "${ORACLE_PATHS[@]}")"
ignored_inputs="$(git ls-files --others --ignored --exclude-standard -- "${ORACLE_PATHS[@]}")"
if [[ -n "$untracked_inputs" || -n "$ignored_inputs" ]]; then
	printf 'Oracle production tree contains untracked inputs:\n%s%s\n' \
		"$untracked_inputs" "${ignored_inputs:+$'\n'$ignored_inputs}" >&2
	exit 1
fi

printf 'Java oracle provenance gate passed: %s (%s).\n' \
	"$PINNED_OVERLAY_COMMIT" "$PINNED_TREE_SHA256"
