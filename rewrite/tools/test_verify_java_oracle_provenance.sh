#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT_DIR"

VERIFIER="rewrite/tools/verify_java_oracle_provenance.sh"
FILESYSTEM_VERIFIER_SOURCE="rewrite/tools/JavaOracleFilesystemVerifier.java"
FILESYSTEM_RACE_TEST_SOURCE="rewrite/tools/JavaOracleFilesystemVerifierRaceTest.java"
PINNED_OVERLAY_COMMIT="62ece7083ea473f02ecc9a83ee7d3e151905bf0e"
TEMP_BASE_INPUT="${TMPDIR:-/tmp}"
TEMP_BASE=""
TEST_ROOT=""
WORKTREE=""
REAL_JAVA_PATH="$(mise which java)"

[[ -x "$VERIFIER" ]] || {
	printf 'Missing executable Java oracle provenance verifier.\n' >&2
	exit 1
}
for required_source in "$FILESYSTEM_VERIFIER_SOURCE" "$FILESYSTEM_RACE_TEST_SOURCE"; do
	if [[ ! -f "$required_source" || -L "$required_source" ]]; then
		printf 'Missing regular Java oracle race source: %s\n' "$required_source" >&2
		exit 1
	fi
done
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
RACE_CLASSES="$TEST_ROOT/race-classes"
mkdir -p "$RACE_CLASSES"
mise exec -- javac -Xlint:all -d "$RACE_CLASSES" \
	"$FILESYSTEM_VERIFIER_SOURCE" "$FILESYSTEM_RACE_TEST_SOURCE"
mise exec -- java -cp "$RACE_CLASSES" JavaOracleFilesystemVerifierRaceTest
WORKTREE="$TEST_ROOT/worktree"
git clone --quiet --local --no-hardlinks "$ROOT_DIR" "$WORKTREE"
git -C "$WORKTREE" config core.fileMode false
git -C "$WORKTREE" config core.autocrlf true

cp "$VERIFIER" "$WORKTREE/$VERIFIER"
cp rewrite/golden/java-migration/manifest.json \
	"$WORKTREE/rewrite/golden/java-migration/manifest.json"
cp rewrite/golden/java-migration/README.md \
	"$WORKTREE/rewrite/golden/java-migration/README.md"
cp rewrite/golden/java-migration/oracle-tree.txt \
	"$WORKTREE/rewrite/golden/java-migration/oracle-tree.txt"
cp rewrite/golden/java-migration/oracle-files.sha256 \
	"$WORKTREE/rewrite/golden/java-migration/oracle-files.sha256"
cp rewrite/golden/java-migration/manifest.files \
	"$WORKTREE/rewrite/golden/java-migration/manifest.files"
cp rewrite/golden/java-migration/manifest.sha256 \
	"$WORKTREE/rewrite/golden/java-migration/manifest.sha256"
cp rewrite/tools/JavaOracleFilesystemVerifier.java \
	"$WORKTREE/rewrite/tools/JavaOracleFilesystemVerifier.java"

mkdir -p "$WORKTREE/.task8-bin"
cat >"$WORKTREE/.task8-bin/mise" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" != "exec" || "${2:-}" != "--" || "${3:-}" != "java" ]]; then
	exit 2
fi
exec "$REAL_JAVA_PATH" "${@:4}"
EOF
chmod +x "$WORKTREE/.task8-bin/mise"

run_worktree_verifier() {
	(
		cd "$WORKTREE"
		PATH="$WORKTREE/.task8-bin:/usr/bin:/bin" \
			REAL_JAVA_PATH="$REAL_JAVA_PATH" \
			bash "$VERIFIER"
	)
}

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

restore_pinned_file() {
	local relative_path="$1"
	local entry
	local metadata
	local object_id
	local mode
	entry="$(git -C "$WORKTREE" ls-tree "$PINNED_OVERLAY_COMMIT" -- "$relative_path")"
	metadata="${entry%%$'\t'*}"
	mode="${metadata%% *}"
	object_id="${metadata##* }"
	git -C "$WORKTREE" cat-file blob "$object_id" >"$WORKTREE/$relative_path"
	if [[ "$mode" == "100755" ]]; then
		chmod 755 "$WORKTREE/$relative_path"
	else
		chmod 644 "$WORKTREE/$relative_path"
	fi
}

expect_hostile_git_invisible_mutation_failure() {
	local description="$1"
	local relative_path="$2"
	local mutation="$3"
	local output
	local source="$WORKTREE/$relative_path"

	case "$mutation" in
		crlf)
			awk '{ printf "%s\r\n", $0 }' "$source" >"$source.next"
			mv "$source.next" "$source"
			;;
		executable) chmod 755 "$source" ;;
		*) printf 'Unknown hostile Git mutation: %s\n' "$mutation" >&2; exit 1 ;;
	esac
	if ! git -C "$WORKTREE" diff --quiet "$PINNED_OVERLAY_COMMIT" -- "$relative_path"; then
		printf '%s did not reproduce the Git-normalization bypass.\n' "$description" >&2
		exit 1
	fi
	if output="$(run_worktree_verifier 2>&1)"; then
		printf '%s unexpectedly passed the raw filesystem provenance gate.\n' \
			"$description" >&2
		exit 1
	fi
	if [[ "$output" != *"Java oracle filesystem"* ]]; then
		printf '%s failed for the wrong reason:\n%s\n' "$description" "$output" >&2
		exit 1
	fi
	restore_pinned_file "$relative_path"
}

expect_hostile_git_invisible_mutation_failure \
	"CRLF raw-byte mutation under core.autocrlf=true" \
	src/org/open2jam/export/VosCatalogExporter.java crlf
expect_hostile_git_invisible_mutation_failure \
	"executable-mode mutation under core.fileMode=false" \
	parsers/src/org/open2jam/parsers/OsuManiaParser.java executable

expect_oracle_mutation_failure() {
	local description="$1"
	local relative_path="$2"
	local output

	printf '\nTask 8 mutation: %s\n' "$description" >>"$WORKTREE/$relative_path"
	printf '\nCoordinated corpus regeneration: %s\n' "$description" \
		>>"$WORKTREE/rewrite/golden/java-migration/README.md"
	refresh_corpus_hashes
	if output="$(run_worktree_verifier 2>&1)"; then
		printf '%s unexpectedly passed the oracle provenance gate.\n' "$description" >&2
		exit 1
	fi
	if [[ "$output" != *"Java oracle filesystem"* ]]; then
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
if output="$(run_worktree_verifier 2>&1)"; then
	printf 'Untracked oracle input unexpectedly passed the provenance gate.\n' >&2
	exit 1
fi
if [[ "$output" != *"Java oracle filesystem"* ]]; then
	printf 'Untracked oracle input failed for the wrong reason:\n%s\n' "$output" >&2
	exit 1
fi
rm "$untracked_oracle"

expect_filesystem_failure() {
	local description="$1"
	local output
	if output="$(run_worktree_verifier 2>&1)"; then
		printf '%s unexpectedly passed the filesystem provenance gate.\n' \
			"$description" >&2
		exit 1
	fi
	if [[ "$output" != *"Java oracle filesystem"* ]]; then
		printf '%s failed for the wrong reason:\n%s\n' "$description" "$output" >&2
		exit 1
	fi
}

missing_path="src/org/open2jam/export/VosGameplayExporter.java"
rm "$WORKTREE/$missing_path"
expect_filesystem_failure "missing oracle path"
restore_pinned_file "$missing_path"

symlink_path="src/org/open2jam/export/VosAudioExporter.java"
cp "$WORKTREE/$symlink_path" "$WORKTREE/same-oracle-bytes.java"
rm "$WORKTREE/$symlink_path"
ln -s "$WORKTREE/same-oracle-bytes.java" "$WORKTREE/$symlink_path"
expect_filesystem_failure "same-byte oracle symlink"
rm "$WORKTREE/$symlink_path" "$WORKTREE/same-oracle-bytes.java"
restore_pinned_file "$symlink_path"

special_path="$WORKTREE/src/org/open2jam/export/oracle-fifo"
mkfifo "$special_path"
expect_filesystem_failure "oracle special file"
rm "$special_path"

printf 'Java oracle provenance behavioral contract passed.\n'
