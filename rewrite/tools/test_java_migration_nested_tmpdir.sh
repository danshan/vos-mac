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
JVM_TEMP_ROOT=""
CLEANUP_DONE=false
ACTIVE_CHILD_PID=""

is_safe_nested_tmpdir() {
	local candidate="$1"
	local canonical
	[[ -n "$candidate" && -n "$JVM_TEMP_ROOT" \
		&& "$candidate" != "/" && "$JVM_TEMP_ROOT" != "/" \
		&& "$candidate" != "$JVM_TEMP_ROOT" ]] || return 1
	case "$candidate" in
		"$JVM_TEMP_ROOT"/.ctx-mode-open2jam-nested-process-tmp.*) ;;
		*) return 1 ;;
	esac
	if [[ -e "$candidate" ]]; then
		canonical="$(cd "$candidate" && pwd -P)" || return 1
		[[ "$canonical" == "$candidate" ]] || return 1
	fi
}

cleanup() {
	if [[ "$CLEANUP_DONE" == true ]]; then
		return 0
	fi
	if [[ -z "$NESTED_TMPDIR" ]]; then
		CLEANUP_DONE=true
		return 0
	fi
	if ! is_safe_nested_tmpdir "$NESTED_TMPDIR"; then
		printf 'Refusing unsafe nested TMPDIR cleanup path: %s\n' \
			"$NESTED_TMPDIR" >&2
		return 1
	fi
	if [[ -e "$NESTED_TMPDIR" ]]; then
		rm -rf "$NESTED_TMPDIR"
	fi
	CLEANUP_DONE=true
}

handle_signal() {
	local exit_code="$1"
	trap - EXIT INT TERM HUP
	if [[ -n "$ACTIVE_CHILD_PID" ]] \
		&& kill -0 "$ACTIVE_CHILD_PID" >/dev/null 2>&1; then
		kill -TERM "$ACTIVE_CHILD_PID" >/dev/null 2>&1 || true
		wait "$ACTIVE_CHILD_PID" >/dev/null 2>&1 || true
	fi
	ACTIVE_CHILD_PID=""
	cleanup || true
	exit "$exit_code"
}
trap cleanup EXIT
trap 'handle_signal 130' INT
trap 'handle_signal 143' TERM
trap 'handle_signal 129' HUP

for required_command in bash kill mise mktemp rm sed; do
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

NESTED_TMPDIR="$(mktemp -d "$JVM_TEMP_ROOT/.ctx-mode-open2jam-nested-process-tmp.XXXXXX")"
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
	'mvn -s "$MAVEN_SETTINGS" clean test -Dtest="$1"' bash "$tests_csv" &
ACTIVE_CHILD_PID=$!
if wait "$ACTIVE_CHILD_PID"; then
	ACTIVE_CHILD_PID=""
else
	child_status=$?
	ACTIVE_CHILD_PID=""
	exit "$child_status"
fi

mise exec -- java "$REPORT_VERIFIER" "$REPORT_DIR" "${TEST_CLASSES[@]}"

printf 'Nested TMPDIR migration tests passed.\n'
