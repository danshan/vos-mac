#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT_DIR"

TEST_CLASSES=(
	org.open2jam.export.MigrationGoldenCorpusGeneratorTest
	org.open2jam.export.MigrationGoldenCorpusTest
)
REPORT_DIR="target/surefire-reports"
REPORT_VERIFIER="rewrite/tools/SurefireReportVerifier.java"
NESTED_TMPDIR=""

cleanup() {
	if [[ -n "$NESTED_TMPDIR" && -d "$NESTED_TMPDIR" ]]; then
		rm -rf "$NESTED_TMPDIR"
	fi
}
trap cleanup EXIT

for required_command in bash mise mktemp rm sed; do
	command -v "$required_command" >/dev/null 2>&1 || {
		printf 'Missing required command: %s\n' "$required_command" >&2
		exit 1
	}
done

[[ -f "$REPORT_VERIFIER" ]] || {
	printf 'Missing Surefire report verifier: %s\n' "$REPORT_VERIFIER" >&2
	exit 1
}

read_java_tmpdir() {
	mise exec -- bash -c '
		java -XshowSettings:properties -version 2>&1 \
			| sed -n "s/^[[:space:]]*java.io.tmpdir = //p"
	'
}

JVM_TEMP_INPUT="$(read_java_tmpdir)"
[[ -n "$JVM_TEMP_INPUT" && -d "$JVM_TEMP_INPUT" ]] || {
	printf 'Unable to resolve the JVM temporary directory: %s\n' \
		"${JVM_TEMP_INPUT:-<empty>}" >&2
	exit 1
}
JVM_TEMP_ROOT="$(cd "$JVM_TEMP_INPUT" && pwd -P)"
[[ "$JVM_TEMP_ROOT" != "/" ]] || {
	printf 'Unsafe JVM temporary directory: %s\n' "$JVM_TEMP_ROOT" >&2
	exit 1
}

NESTED_TMPDIR="$(mktemp -d "$JVM_TEMP_ROOT/open2jam-nested-process-tmp.XXXXXX")"
NESTED_TMPDIR="$(cd "$NESTED_TMPDIR" && pwd -P)"
[[ "$NESTED_TMPDIR" == "$JVM_TEMP_ROOT"/* ]] || {
	printf 'Nested TMPDIR is not a strict JVM temp descendant: %s\n' \
		"$NESTED_TMPDIR" >&2
	exit 1
}

NESTED_JVM_TEMP_INPUT="$(TMPDIR="$NESTED_TMPDIR" read_java_tmpdir)"
[[ -n "$NESTED_JVM_TEMP_INPUT" && -d "$NESTED_JVM_TEMP_INPUT" ]] || {
	printf 'Unable to resolve JVM temp under nested TMPDIR: %s\n' \
		"${NESTED_JVM_TEMP_INPUT:-<empty>}" >&2
	exit 1
}
NESTED_JVM_TEMP_ROOT="$(cd "$NESTED_JVM_TEMP_INPUT" && pwd -P)"
[[ "$NESTED_JVM_TEMP_ROOT" == "$JVM_TEMP_ROOT" ]] || {
	printf 'Nested TMPDIR changed the JVM temp root: %s != %s\n' \
		"$NESTED_JVM_TEMP_ROOT" "$JVM_TEMP_ROOT" >&2
	exit 1
}

tests_csv="$(IFS=,; printf '%s' "${TEST_CLASSES[*]}")"
TMPDIR="$NESTED_TMPDIR" mise exec -- bash -c \
	'mvn -s "$MAVEN_SETTINGS" clean test -Dtest="$1"' bash "$tests_csv"

mise exec -- java "$REPORT_VERIFIER" "$REPORT_DIR" "${TEST_CLASSES[@]}"

printf 'Nested TMPDIR migration tests passed.\n'
