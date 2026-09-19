#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT_DIR"

NESTED_TEST="rewrite/tools/test_java_migration_nested_tmpdir.sh"
TEMP_INPUT="${TMPDIR:-/tmp}"
FIXTURE_TEMP_ROOT=""
FIXTURE_PARENT=""
CLEANUP_DONE=false
ACTIVE_TEST_PID=""
ACTIVE_CHILD_PID=""

for required_command in bash cat chmod kill mkdir mktemp rm sed sleep; do
	command -v "$required_command" >/dev/null 2>&1 || {
		printf 'Missing nested TMPDIR behavior command: %s\n' \
			"$required_command" >&2
		exit 1
	}
done

[[ -x "$NESTED_TEST" ]] || {
	printf 'Missing executable nested TMPDIR test: %s\n' "$NESTED_TEST" >&2
	exit 1
}
[[ -n "$TEMP_INPUT" && "$TEMP_INPUT" != "/" && -d "$TEMP_INPUT" ]] || {
	printf 'Unsafe nested TMPDIR behavior root: %s\n' \
		"${TEMP_INPUT:-<empty>}" >&2
	exit 1
}
FIXTURE_TEMP_ROOT="$(cd "$TEMP_INPUT" && pwd -P)"
[[ "$FIXTURE_TEMP_ROOT" != "/" ]] || {
	printf 'Nested TMPDIR behavior root resolves to filesystem root.\n' >&2
	exit 1
}

is_safe_fixture_parent() {
	local candidate="$1"
	local canonical
	[[ -n "$candidate" && "$candidate" != "/" \
		&& "$candidate" != "$FIXTURE_TEMP_ROOT" ]] || return 1
	case "$candidate" in
		"$FIXTURE_TEMP_ROOT"/open2jam-nested-signal.*) ;;
		*) return 1 ;;
	esac
	if [[ -e "$candidate" ]]; then
		canonical="$(cd "$candidate" && pwd -P)" || return 1
		[[ "$canonical" == "$candidate" ]] || return 1
	fi
}

terminate_probe_pid() {
	local pid="$1"
	local attempt=0
	[[ "$pid" =~ ^[0-9]+$ && "$pid" -gt 1 && "$pid" -ne "$$" ]] || return 0
	if kill -0 "$pid" >/dev/null 2>&1; then
		kill -TERM "$pid" >/dev/null 2>&1 || true
	fi
	while kill -0 "$pid" >/dev/null 2>&1 && [[ "$attempt" -lt 20 ]]; do
		sleep 0.05
		attempt=$((attempt + 1))
	done
}

cleanup() {
	if [[ "$CLEANUP_DONE" == true ]]; then
		return 0
	fi
	if [[ -z "$FIXTURE_PARENT" ]]; then
		CLEANUP_DONE=true
		return 0
	fi
	terminate_probe_pid "$ACTIVE_TEST_PID"
	terminate_probe_pid "$ACTIVE_CHILD_PID"
	ACTIVE_TEST_PID=""
	ACTIVE_CHILD_PID=""
	if ! is_safe_fixture_parent "$FIXTURE_PARENT"; then
		printf 'Refusing unsafe nested signal fixture cleanup: %s\n' \
			"$FIXTURE_PARENT" >&2
		return 1
	fi
	if [[ -e "$FIXTURE_PARENT" ]]; then
		rm -rf "$FIXTURE_PARENT"
	fi
	CLEANUP_DONE=true
}
trap cleanup EXIT

FIXTURE_PARENT="$(mktemp -d "$FIXTURE_TEMP_ROOT/open2jam-nested-signal.XXXXXX")"
FIXTURE_PARENT="$(cd "$FIXTURE_PARENT" && pwd -P)"
is_safe_fixture_parent "$FIXTURE_PARENT" || {
	printf 'Nested signal fixture parent is unsafe.\n' >&2
	exit 1
}

write_blocking_mise_stub() {
	local output_path="$1"
	if ! cat >"$output_path" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" != "exec" || "${2:-}" != "--" \
	|| "${3:-}" != "bash" || "${4:-}" != "-c" ]]; then
	exit 2
fi

case "${5:-}" in
	*XshowSettings:properties*)
		if [[ "${7:-}" == -Djava.io.tmpdir=* ]]; then
			printf '%s\n' "${7#-Djava.io.tmpdir=}"
		elif [[ "${TMPDIR:-}" == "$NESTED_BEHAVIOR_JVM_ROOT"/* ]]; then
			printf '%s\n' "$TMPDIR"
		else
			printf '%s\n' "${NESTED_BEHAVIOR_JVM_ROOT:?}"
		fi
		;;
	*mvn*)
		[[ "${8:-}" == "$NESTED_BEHAVIOR_JVM_ROOT" ]] || exit 3
		printf '%s\n' "${TMPDIR:?}" >"${NESTED_BEHAVIOR_READY:?}"
		printf '%s\n' "$$" >"${NESTED_BEHAVIOR_CHILD_PID:?}"
		trap 'exit 0' INT TERM HUP
		while :; do
			sleep 1
		done
		;;
	*)
		exit 2
		;;
esac
EOF
	then
		printf 'Unable to write blocking mise stub.\n' >&2
		return 1
	fi
	chmod +x "$output_path"
}

wait_for_file() {
	local path="$1"
	local attempt=0
	while [[ ! -s "$path" && "$attempt" -lt 100 ]]; do
		sleep 0.05
		attempt=$((attempt + 1))
	done
	[[ -s "$path" ]]
}

wait_for_exit() {
	local pid="$1"
	local attempt=0
	while kill -0 "$pid" >/dev/null 2>&1 && [[ "$attempt" -lt 100 ]]; do
		sleep 0.05
		attempt=$((attempt + 1))
	done
	! kill -0 "$pid" >/dev/null 2>&1
}

set -m
for signal_spec in INT:130 TERM:143 HUP:129; do
	signal_name="${signal_spec%%:*}"
	expected_status="${signal_spec##*:}"
	case_root="$FIXTURE_PARENT/$signal_name"
	stub_bin="$case_root/bin"
	jvm_root="$case_root/jvm-temp"
	ready_file="$case_root/ready"
	child_pid_file="$case_root/child.pid"
	output_file="$case_root/output.log"
	mkdir -p "$stub_bin" "$jvm_root"
	write_blocking_mise_stub "$stub_bin/mise"

	PATH="$stub_bin:/usr/bin:/bin" \
		NESTED_BEHAVIOR_JVM_ROOT="$jvm_root" \
		NESTED_BEHAVIOR_READY="$ready_file" \
		NESTED_BEHAVIOR_CHILD_PID="$child_pid_file" \
		bash "$NESTED_TEST" >"$output_file" 2>&1 &
	test_pid=$!
	ACTIVE_TEST_PID="$test_pid"
	if ! wait_for_file "$ready_file"; then
		kill -TERM "$test_pid" >/dev/null 2>&1 || true
		printf '%s signal probe did not reach the blocking command.\n' \
			"$signal_name" >&2
		exit 1
	fi
	ACTIVE_CHILD_PID="$(sed -n '1p' "$child_pid_file")"
	nested_root="$(sed -n '1p' "$ready_file")"
	if [[ -z "$nested_root" || "$nested_root" == "/" \
		|| "$nested_root" == "$jvm_root" \
		|| "$nested_root" != "$jvm_root"/.ctx-mode-open2jam-nested-process-tmp.* \
		|| ! -d "$nested_root" ]]; then
		printf '%s signal probe created an unsafe nested root: %s\n' \
			"$signal_name" "${nested_root:-<empty>}" >&2
		exit 1
	fi

	kill -"$signal_name" "$test_pid"
	if ! wait_for_exit "$test_pid"; then
		kill -TERM "$test_pid" >/dev/null 2>&1 || true
		printf '%s signal probe did not terminate.\n' "$signal_name" >&2
		exit 1
	fi
	set +e
	wait "$test_pid"
	actual_status=$?
	set -e
	ACTIVE_TEST_PID=""
	if [[ "$actual_status" -ne "$expected_status" ]]; then
		printf '%s signal probe exited %s, expected %s.\n' \
			"$signal_name" "$actual_status" "$expected_status" >&2
		exit 1
	fi
	if [[ -e "$nested_root" ]]; then
		printf '%s signal probe left nested temp debris: %s\n' \
			"$signal_name" "$nested_root" >&2
		exit 1
	fi
	terminate_probe_pid "$ACTIVE_CHILD_PID"
	ACTIVE_CHILD_PID=""
done
set +m

printf 'Nested TMPDIR signal cleanup behavior passed.\n'
