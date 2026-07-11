#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT_DIR"

PINNED_OVERLAY_COMMIT="62ece7083ea473f02ecc9a83ee7d3e151905bf0e"
PINNED_TREE_SHA256="206614ef6d5df3ae2cd5f42ea0b1f0499cd7a3137cfbdf11c5a345fb8ff6978e"
PINNED_FILES_SHA256="b1e093eaf4dd2a28ae918d29afcccff8d40b7ad60410d1caee5219fcec74feca"
PINNED_MANIFEST_SHA256="5791c29398844fd1add3db4961da3d7a412eab3072ba32a656b70c9cfb162f0a"
CORPUS_DIR="rewrite/golden/java-migration"
TREE_MANIFEST="$CORPUS_DIR/oracle-tree.txt"
FILES_MANIFEST="$CORPUS_DIR/oracle-files.sha256"
PROVENANCE_MANIFEST="$CORPUS_DIR/manifest.json"
FILESYSTEM_VERIFIER="rewrite/tools/JavaOracleFilesystemVerifier.java"
ORACLE_PATHS=(
	src/org/open2jam
	parsers/src
	src/resources
)

for required_command in cat git mise sed shasum; do
	if ! command -v "$required_command" >/dev/null 2>&1; then
		printf 'Missing Java oracle verifier command: %s\n' "$required_command" >&2
		exit 1
	fi
done

for required_file in \
	"$TREE_MANIFEST" "$FILES_MANIFEST" "$PROVENANCE_MANIFEST" \
	"$FILESYSTEM_VERIFIER"; do
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

manifest_hash_line="$(shasum -a 256 "$PROVENANCE_MANIFEST")"
manifest_hash="${manifest_hash_line%% *}"
if [[ "$manifest_hash" != "$PINNED_MANIFEST_SHA256" ]]; then
	printf 'Canonical Java oracle provenance manifest digest mismatch: expected %s, got %s\n' \
		"$PINNED_MANIFEST_SHA256" "$manifest_hash" >&2
	exit 1
fi

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

derive_filesystem_manifest() {
	local metadata
	local relative_path
	local mode
	local remainder
	local object_type
	local object_id
	local digest_line
	local digest
	while IFS=$'\t' read -r metadata relative_path; do
		mode="${metadata%% *}"
		remainder="${metadata#* }"
		object_type="${remainder%% *}"
		object_id="${remainder##* }"
		if [[ "$object_type" != "blob" \
			|| ( "$mode" != "100644" && "$mode" != "100755" ) \
			|| -z "$relative_path" ]]; then
			printf 'Unsupported pinned Java oracle tree entry: %s\t%s\n' \
				"$metadata" "$relative_path" >&2
			return 1
		fi
		if ! digest_line="$(git cat-file blob "$object_id" | shasum -a 256)"; then
			printf 'Unable to hash pinned Java oracle blob: %s\n' "$object_id" >&2
			return 1
		fi
		digest="${digest_line%% *}"
		printf '%s %s  %s\n' "$mode" "$digest" "$relative_path"
	done <"$TREE_MANIFEST"
}

expected_files="$(derive_filesystem_manifest)"
recorded_files="$(cat "$FILES_MANIFEST")"
if [[ "$recorded_files" != "$expected_files" ]]; then
	printf 'Recorded Java oracle filesystem manifest does not match pinned raw objects.\n' >&2
	exit 1
fi
files_hash_line="$(printf '%s\n' "$expected_files" | shasum -a 256)"
files_hash="${files_hash_line%% *}"
if [[ "$files_hash" != "$PINNED_FILES_SHA256" ]]; then
	printf 'Pinned Java oracle filesystem manifest digest mismatch: expected %s, got %s\n' \
		"$PINNED_FILES_SHA256" "$files_hash" >&2
	exit 1
fi

mise exec -- java "$FILESYSTEM_VERIFIER" "$FILES_MANIFEST" "${ORACLE_PATHS[@]}"

printf 'Java oracle provenance gate passed: %s (tree %s, files %s).\n' \
	"$PINNED_OVERLAY_COMMIT" "$PINNED_TREE_SHA256" "$PINNED_FILES_SHA256"
