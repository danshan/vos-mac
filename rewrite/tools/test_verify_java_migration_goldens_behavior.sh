#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

FIXTURE_TEMP_ROOT=""
FIXTURE_PARENT=""
CLEANUP_DONE=false
CREATED_FIXTURE=""
TMPDIR_INPUT=""

if [[ "${TMPDIR+x}" == "x" ]]; then
	TMPDIR_INPUT="$TMPDIR"
else
	TMPDIR_INPUT="/tmp"
fi
if [[ -z "$TMPDIR_INPUT" || "$TMPDIR_INPUT" == "/" \
	|| "$TMPDIR_INPUT" == "//" ]]; then
	printf 'Unsafe verifier TMPDIR: %s\n' "${TMPDIR_INPUT:-<empty>}" >&2
	exit 1
fi
if ! FIXTURE_TEMP_ROOT="$(cd "$TMPDIR_INPUT" 2>/dev/null && pwd -P)"; then
	printf 'Unable to resolve verifier TMPDIR: %s\n' "$TMPDIR_INPUT" >&2
	exit 1
fi
if [[ -z "$FIXTURE_TEMP_ROOT" || "$FIXTURE_TEMP_ROOT" == "/" \
	|| "$FIXTURE_TEMP_ROOT" == "//" ]]; then
	printf 'Unsafe verifier TMPDIR root: %s\n' "$FIXTURE_TEMP_ROOT" >&2
	exit 1
fi

for required_command in \
	awk bash cat chmod cp dirname git grep kill ln mkdir mise mktemp mv rg rm sed shasum tr; do
	if ! command -v "$required_command" >/dev/null 2>&1; then
		printf 'Missing behavioral contract command: %s\n' "$required_command" >&2
		exit 1
	fi
done

REAL_JAVA_PATH="$(mise which java)"
REAL_RG_PATH="$(command -v rg)"

is_safe_fixture_parent() {
	local candidate="$1"
	local canonical
	[[ -n "$candidate" && "$candidate" != "/" \
		&& "$candidate" != "$FIXTURE_TEMP_ROOT" ]] || return 1
	case "$candidate" in
		"$FIXTURE_TEMP_ROOT"/*) ;;
		*) return 1 ;;
	esac
	case "$candidate" in
		*"/../"*|*"/./"*) return 1 ;;
	esac
	if [[ ! -e "$candidate" ]]; then
		return 0
	fi
	if ! canonical="$(cd "$candidate" 2>/dev/null && pwd -P)"; then
		return 1
	fi
	[[ "$canonical" == "$candidate" ]]
}

cleanup_fixtures() {
	if [[ "$CLEANUP_DONE" == true ]]; then
		return 0
	fi
	if ! is_safe_fixture_parent "$FIXTURE_PARENT"; then
		printf 'Refusing unsafe fixture cleanup path: %s\n' \
			"${FIXTURE_PARENT:-<empty>}" >&2
		return 1
	fi
	if [[ -e "$FIXTURE_PARENT" ]] && ! rm -rf "$FIXTURE_PARENT"; then
		printf 'Unable to clean fixture root: %s\n' "$FIXTURE_PARENT" >&2
		return 1
	fi
	CLEANUP_DONE=true
}

handle_signal() {
	local exit_code="$1"
	trap - EXIT INT TERM HUP
	cleanup_fixtures || true
	exit "$exit_code"
}

if ! FIXTURE_PARENT="$(mktemp -d "$FIXTURE_TEMP_ROOT/open2jam-golden-verifier.XXXXXX")"; then
	printf 'Unable to create the fixture parent.\n' >&2
	exit 1
fi
trap cleanup_fixtures EXIT
trap 'handle_signal 130' INT
trap 'handle_signal 143' TERM
trap 'handle_signal 129' HUP
if ! FIXTURE_PARENT="$(cd "$FIXTURE_PARENT" && pwd -P)" \
	|| ! is_safe_fixture_parent "$FIXTURE_PARENT"; then
	printf 'Fixture parent is not a safe temporary path.\n' >&2
	exit 1
fi
if [[ "${1:-}" == "--interrupt-cleanup-probe" ]]; then
	printf '%s\n' "$FIXTURE_PARENT"
	kill -TERM "$$"
	exit 1
fi

assert_fixture_path() {
	local candidate="$1"
	local canonical
	if ! is_safe_fixture_parent "$FIXTURE_PARENT" \
		|| [[ -z "$candidate" || "$candidate" == "/" \
			|| "$candidate" == "$FIXTURE_PARENT" ]]; then
		printf 'Unsafe fixture path: %s\n' "${candidate:-<empty>}" >&2
		return 1
	fi
	case "$candidate" in
		"$FIXTURE_PARENT"/*) ;;
		*)
			printf 'Fixture path escapes parent: %s\n' "$candidate" >&2
			return 1
			;;
	esac
	case "$candidate" in
		*"/../"*|*"/./"*)
			printf 'Fixture path is not normalized: %s\n' "$candidate" >&2
			return 1
			;;
	esac
	if [[ ! -d "$candidate" ]]; then
		printf 'Fixture path is not a directory: %s\n' "$candidate" >&2
		return 1
	fi
	if ! canonical="$(cd "$candidate" 2>/dev/null && pwd -P)" \
		|| [[ "$canonical" != "$candidate" ]]; then
		printf 'Fixture path is not canonical: %s\n' "$candidate" >&2
		return 1
	fi
}

fixture_git() {
	local fixture_root="$1"
	shift
	assert_fixture_path "$fixture_root" || return 1
	GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
		git -C "$fixture_root" \
		-c core.hooksPath="$fixture_root/.git-hooks-empty" \
		-c commit.gpgSign=false \
		-c user.name="Golden Verifier Test" \
		-c user.email=verifier@example.invalid \
		"$@"
}

TEST_CLASSES=(
	org.open2jam.export.MigrationGoldenCorpusGeneratorTest
	org.open2jam.export.MigrationGoldenCorpusTest
	org.open2jam.parsers.OjnFixtureFactoryTest
	org.open2jam.parsers.OsuFixtureFactoryTest
	org.open2jam.parsers.VOSParserTest
	org.open2jam.parsers.OsuManiaParserTest
	org.open2jam.export.VosCatalogExporterTest
	org.open2jam.export.VosGameplayExporterTest
	org.open2jam.export.VosAudioExporterTest
	org.open2jam.export.VosRenderMetadataExporterTest
)

write_contract_stub() {
	local output_path="$1"
	if ! cat >"$output_path" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
	then
		printf 'Unable to write contract stub: %s\n' "$output_path" >&2
		return 1
	fi
	if ! chmod +x "$output_path"; then
		printf 'Unable to make contract stub executable: %s\n' "$output_path" >&2
		return 1
	fi
}

write_mise_stub() {
	local output_path="$1"
	if ! cat >"$output_path" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" != "exec" || "${2:-}" != "--" ]]; then
	exit 2
fi

if [[ "${3:-}" == "java" ]]; then
	exec "$REAL_JAVA_PATH" "${@:4}"
fi

if [[ "${3:-}" != "bash" || "${4:-}" != "-lc" ]]; then
	exit 2
fi

command_text="${5:-}"
if [[ "$command_text" != *'clean test'* ]]; then
	exit 0
fi

mode="${GOLDEN_FIXTURE_MAVEN_MODE:-valid}"
if [[ "$mode" == "no_reports" ]]; then
	exit 0
fi

report_directory="target/surefire-reports"
mkdir -p "$report_directory"
IFS=',' read -r -a test_classes <<<"${7:-}"
first_report=true
for class_name in "${test_classes[@]}"; do
	if [[ "$mode" == "missing_report" && "$first_report" == true ]]; then
		first_report=false
		continue
	fi

	report_name="$class_name"
	tests=1
	failures=0
	errors=0
	skipped=0
	if [[ "$first_report" == true ]]; then
		case "$mode" in
			wrong_suite) report_name="org.open2jam.WrongSuite" ;;
			zero_tests) tests=0 ;;
			non_numeric_tests) tests="one" ;;
			failure_report) failures=1 ;;
			error_report) errors=1 ;;
			skipped_report) skipped=1 ;;
		esac
	fi

	report_path="$report_directory/TEST-$class_name.xml"
	if [[ "$mode" == "malformed_report" && "$first_report" == true ]]; then
		printf '<testsuite name="%s" tests="1" failures="0" errors="0" skipped="0">\n' \
			"$class_name" >"$report_path"
	else
		printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>' \
			"<testsuite name=\"$report_name\" tests=\"$tests\" failures=\"$failures\" errors=\"$errors\" skipped=\"$skipped\"></testsuite>" \
			>"$report_path"
	fi
	first_report=false
done

if [[ "$mode" == "mutate_corpus" || "$mode" == "mutate_corpus_and_manifest" ]]; then
	printf 'mutated\n' >>rewrite/golden/java-migration/data.txt
fi
if [[ "$mode" == "mutate_corpus_and_manifest" ]]; then
	(
		cd rewrite/golden/java-migration
		shasum -a 256 data.txt >manifest.sha256
	)
fi
EOF
	then
		printf 'Unable to write mise stub: %s\n' "$output_path" >&2
		return 1
	fi
	if ! chmod +x "$output_path"; then
		printf 'Unable to make mise stub executable: %s\n' "$output_path" >&2
		return 1
	fi
}

write_test_source() {
	local fixture_root="$1"
	local class_name="$2"
	local source_path
	local package_name="${class_name%.*}"
	local simple_name="${class_name##*.}"
	local class_path
	local source_directory

	assert_fixture_path "$fixture_root" || return 1
	if ! class_path="$(printf '%s' "$class_name" | tr '.' '/')"; then
		printf 'Unable to map fixture test class: %s\n' "$class_name" >&2
		return 1
	fi
	source_path="$fixture_root/src/test/java/$class_path.java"
	source_directory="${source_path%/*}"
	if ! mkdir -p "$source_directory"; then
		printf 'Unable to create test source directory: %s\n' "$source_path" >&2
		return 1
	fi
	if ! printf 'package %s;\n\nclass %s {\n}\n' \
		"$package_name" "$simple_name" >"$source_path"; then
		printf 'Unable to write test source: %s\n' "$source_path" >&2
		return 1
	fi
}

create_fixture() {
	local fixture_root
	local class_name

	CREATED_FIXTURE=""
	if ! fixture_root="$(mktemp -d "$FIXTURE_PARENT/fixture.XXXXXX")"; then
		printf 'Unable to create verifier fixture.\n' >&2
		return 1
	fi
	if ! fixture_root="$(cd "$fixture_root" && pwd -P)" \
		|| ! assert_fixture_path "$fixture_root"; then
		printf 'Verifier fixture path is unsafe.\n' >&2
		return 1
	fi
	if ! mkdir -p \
		"$fixture_root/.github/workflows" \
		"$fixture_root/.mvn" \
		"$fixture_root/bin" \
		"$fixture_root/.git-hooks-empty" \
		"$fixture_root/rewrite/golden/java-migration" \
		"$fixture_root/rewrite/tools"; then
		printf 'Unable to create verifier fixture directories.\n' >&2
		return 1
	fi

	if ! cp .github/workflows/build.yml "$fixture_root/.github/workflows/build.yml" \
		|| ! cp .mvn/settings.xml "$fixture_root/.mvn/settings.xml" \
		|| ! cp mise.toml pom.xml "$fixture_root/" \
		|| ! cp rewrite/tools/SurefireReportVerifier.java \
			"$fixture_root/rewrite/tools/" \
		|| ! cp rewrite/tools/JarResourceVerifier.java \
			"$fixture_root/rewrite/tools/" \
		|| ! cp rewrite/tools/JavaOracleFilesystemVerifier.java \
			"$fixture_root/rewrite/tools/" \
		|| ! cp rewrite/tools/verify_build_workflow.sh \
			"$fixture_root/rewrite/tools/" \
		|| ! cp rewrite/tools/verify_java_migration_goldens.sh \
			"$fixture_root/rewrite/tools/" \
		|| ! cp rewrite/tools/verify_vos_godot_initial.sh \
			"$fixture_root/rewrite/tools/"; then
		printf 'Unable to copy verifier fixture inputs.\n' >&2
		return 1
	fi
	if ! write_contract_stub \
		"$fixture_root/rewrite/tools/test_verify_java_migration_goldens.sh" \
		|| ! write_contract_stub \
			"$fixture_root/rewrite/tools/test_verify_java_migration_goldens_behavior.sh" \
		|| ! write_contract_stub \
			"$fixture_root/rewrite/tools/test_verify_vos_godot_manifest.sh" \
		|| ! write_contract_stub \
			"$fixture_root/rewrite/tools/test_verify_java_oracle_provenance.sh" \
		|| ! write_contract_stub \
			"$fixture_root/rewrite/tools/test_verify_java_migration_package.sh" \
		|| ! write_contract_stub \
			"$fixture_root/rewrite/tools/verify_java_oracle_provenance.sh" \
		|| ! write_contract_stub \
			"$fixture_root/rewrite/tools/verify_java_migration_package.sh" \
		|| ! write_mise_stub "$fixture_root/bin/mise" \
		|| ! ln -s "$REAL_RG_PATH" "$fixture_root/bin/rg"; then
		printf 'Unable to install verifier fixture stubs.\n' >&2
		return 1
	fi

	for class_name in "${TEST_CLASSES[@]}"; do
		if ! write_test_source "$fixture_root" "$class_name"; then
			return 1
		fi
	done

	if ! printf 'baseline\n' \
		>"$fixture_root/rewrite/golden/java-migration/data.txt"; then
		printf 'Unable to write fixture corpus.\n' >&2
		return 1
	fi
	if ! printf 'fixture oracle manifest\n' \
		>"$fixture_root/rewrite/golden/java-migration/oracle-files.sha256"; then
		printf 'Unable to write fixture oracle manifest.\n' >&2
		return 1
	fi
	if ! (
		cd "$fixture_root/rewrite/golden/java-migration"
		shasum -a 256 data.txt >manifest.sha256
	); then
		printf 'Unable to hash fixture corpus.\n' >&2
		return 1
	fi

	if ! fixture_git "$fixture_root" init -q \
		|| ! fixture_git "$fixture_root" add . \
		|| ! fixture_git "$fixture_root" commit --no-gpg-sign --no-verify \
			-qm "test fixture"; then
		printf 'Unable to initialize fixture repository.\n' >&2
		return 1
	fi
	CREATED_FIXTURE="$fixture_root"
}

run_verifier() {
	local fixture_root="$1"
	local mode="${2:-valid}"
	assert_fixture_path "$fixture_root" || return 1
	(
		cd "$fixture_root"
		PATH="$fixture_root/bin:/usr/bin:/bin" \
			REAL_JAVA_PATH="$REAL_JAVA_PATH" \
			GOLDEN_FIXTURE_MAVEN_MODE="$mode" \
			bash rewrite/tools/verify_java_migration_goldens.sh
	)
}

expect_verifier_pass() {
	local description="$1"
	local fixture_root="$2"
	local output

	if ! output="$(run_verifier "$fixture_root" 2>&1)"; then
		printf '%s unexpectedly failed:\n%s\n' "$description" "$output" >&2
		exit 1
	fi
}

expect_verifier_failure() {
	local description="$1"
	local fixture_root="$2"
	local mode="$3"
	local expected_text="$4"
	local output

	if output="$(run_verifier "$fixture_root" "$mode" 2>&1)"; then
		printf '%s unexpectedly passed.\n' "$description" >&2
		exit 1
	fi
	if [[ "$output" != *"$expected_text"* ]]; then
		printf '%s failed for the wrong reason:\n%s\n' "$description" "$output" >&2
		exit 1
	fi
}

rewrite_first_test_source() {
	local fixture_root="$1"
	local body="$2"
	local source_path="$fixture_root/src/test/java/org/open2jam/export/MigrationGoldenCorpusGeneratorTest.java"
	assert_fixture_path "$fixture_root" || return 1
	if ! printf '%s\n' "$body" >"$source_path"; then
		printf 'Unable to rewrite fixture source: %s\n' "$source_path" >&2
		return 1
	fi
}

seed_stale_reports() {
	local fixture_root="$1"
	local class_name
	local report_directory="$fixture_root/target/surefire-reports"
	assert_fixture_path "$fixture_root" || return 1
	if ! mkdir -p "$report_directory"; then
		printf 'Unable to create stale report directory.\n' >&2
		return 1
	fi
	for class_name in "${TEST_CLASSES[@]}"; do
		if ! printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>' \
			"<testsuite name=\"$class_name\" tests=\"1\" failures=\"0\" errors=\"0\" skipped=\"0\"></testsuite>" \
			>"$report_directory/TEST-$class_name.xml"; then
			printf 'Unable to seed stale report for %s.\n' "$class_name" >&2
			return 1
		fi
	done
}

expect_contract_pass() {
	local fixture_root="$1"
	local output
	assert_fixture_path "$fixture_root" || return 1
	if ! output="$(cd "$fixture_root" && bash rewrite/tools/test_verify_java_migration_goldens.sh 2>&1)"; then
		printf 'Contract fixture unexpectedly failed:\n%s\n' "$output" >&2
		exit 1
	fi
}

expect_contract_failure() {
	local description="$1"
	local fixture_root="$2"
	local expected_text="$3"
	local output
	assert_fixture_path "$fixture_root" || return 1
	if output="$(cd "$fixture_root" && bash rewrite/tools/test_verify_java_migration_goldens.sh 2>&1)"; then
		printf '%s unexpectedly passed.\n' "$description" >&2
		exit 1
	fi
	if [[ "$output" != *"$expected_text"* ]]; then
		printf '%s failed for the wrong reason:\n%s\n' "$description" "$output" >&2
		exit 1
	fi
}

create_manifest_fixture() {
	local fixture_root
	CREATED_FIXTURE=""
	if ! fixture_root="$(mktemp -d "$FIXTURE_PARENT/manifest.XXXXXX")"; then
		printf 'Unable to create manifest fixture.\n' >&2
		return 1
	fi
	if ! fixture_root="$(cd "$fixture_root" && pwd -P)" \
		|| ! assert_fixture_path "$fixture_root"; then
		printf 'Manifest fixture path is unsafe.\n' >&2
		return 1
	fi
	if ! mkdir -p "$fixture_root/rewrite/tools" \
		|| ! cp rewrite/tools/test_verify_vos_godot_manifest.sh \
			"$fixture_root/rewrite/tools/"; then
		printf 'Unable to set up manifest fixture.\n' >&2
		return 1
	fi
	if ! printf '%s\n' \
		OsuManiaParserTest ChartModelLoaderTest MusicSelectionSelectionTest \
		ChartDisplayTest ConfigTest JudgmentStrategyOracleFixtureTest \
		>"$fixture_root/rewrite/tools/verify_vos_godot_initial.sh" \
		|| ! : >"$fixture_root/rewrite/tools/verify_vos_godot_java_parity.sh"; then
		printf 'Unable to write manifest fixture.\n' >&2
		return 1
	fi
	CREATED_FIXTURE="$fixture_root"
}

expect_manifest_failure() {
	local description="$1"
	local fixture_root="$2"
	local expected_text="$3"
	local output
	assert_fixture_path "$fixture_root" || return 1
	if output="$(cd "$fixture_root" && \
		bash rewrite/tools/test_verify_vos_godot_manifest.sh 2>&1)"; then
		printf '%s unexpectedly passed.\n' "$description" >&2
		exit 1
	fi
	if [[ "$output" != *"$expected_text"* ]]; then
		printf '%s failed for the wrong reason:\n%s\n' "$description" "$output" >&2
		exit 1
	fi
}

assert_no_root_fixture_artifacts() {
	local root_path
	for root_path in \
		/.github/workflows/build.yml \
		/rewrite/tools/verify_java_migration_goldens.sh \
		/pom.xml /mise.toml; do
		if [[ -e "$root_path" ]]; then
			printf 'Unexpected root-level fixture artifact: %s\n' "$root_path" >&2
			exit 1
		fi
	done
}

root_temp_snapshot() {
	local root_path
	for root_path in /open2jam-golden-verifier.*; do
		if [[ -e "$root_path" || -L "$root_path" ]]; then
			printf '%s\n' "$root_path"
		fi
	done
}

create_unsafe_tmpdir_probe() {
	local probe_root
	CREATED_FIXTURE=""
	if ! probe_root="$(mktemp -d "$FIXTURE_PARENT/tmpdir-probe.XXXXXX")" \
		|| ! probe_root="$(cd "$probe_root" && pwd -P)" \
		|| ! assert_fixture_path "$probe_root" \
		|| ! mkdir -p "$probe_root/bin"; then
		printf 'Unable to create unsafe TMPDIR probe.\n' >&2
		return 1
	fi
	if ! cat >"$probe_root/bin/mktemp" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'mktemp-called\n' >"$UNSAFE_TMPDIR_MARKER"
exit 97
EOF
	then
		printf 'Unable to write unsafe TMPDIR mktemp probe.\n' >&2
		return 1
	fi
	if ! chmod +x "$probe_root/bin/mktemp"; then
		printf 'Unable to make unsafe TMPDIR probe executable.\n' >&2
		return 1
	fi
	CREATED_FIXTURE="$probe_root"
}

expect_unsafe_tmpdir_rejected() {
	local description="$1"
	local tmpdir_value="$2"
	local probe_root="$3"
	local marker="$probe_root/$description.marker"
	local root_before
	local root_after
	local output
	assert_fixture_path "$probe_root" || return 1
	root_before="$(root_temp_snapshot)"
	if output="$(TMPDIR="$tmpdir_value" \
		UNSAFE_TMPDIR_MARKER="$marker" \
		PATH="$probe_root/bin:$PATH" \
		/bin/bash "$ROOT_DIR/rewrite/tools/test_verify_java_migration_goldens_behavior.sh" \
		--unsafe-temp-root-probe 2>&1)"; then
		printf 'Unsafe TMPDIR unexpectedly passed: %s\n' "$description" >&2
		exit 1
	fi
	root_after="$(root_temp_snapshot)"
	if [[ "$output" != *"Unsafe verifier TMPDIR"* || -e "$marker" \
		|| "$root_after" != "$root_before" ]]; then
		printf 'Unsafe TMPDIR probe had write side effects: %s\n' "$description" >&2
		exit 1
	fi
}

install_hostile_git_environment() {
	local hostile_root="$1"
	local hook_path="$hostile_root/hooks/pre-commit"
	local config_path="$hostile_root/global.gitconfig"
	assert_fixture_path "$hostile_root" || return 1
	if ! mkdir -p "$hostile_root/hooks"; then
		printf 'Unable to create hostile Git hook directory.\n' >&2
		return 1
	fi
	if ! printf '%s\n' '#!/usr/bin/env bash' 'exit 91' >"$hook_path" \
		|| ! chmod +x "$hook_path"; then
		printf 'Unable to create hostile Git hook.\n' >&2
		return 1
	fi
	if ! printf '%s\n' \
		'[commit]' '    gpgSign = true' \
		'[core]' "    hooksPath = $hostile_root/hooks" \
		>"$config_path"; then
		printf 'Unable to create hostile Git configuration.\n' >&2
		return 1
	fi
}

comment_golden_run() {
	local fixture_root="$1"
	local workflow="$fixture_root/.github/workflows/build.yml"
	assert_fixture_path "$fixture_root" || return 1
	if ! sed 's/^        run: mise run verify-goldens$/        # run: mise run verify-goldens/' \
		"$workflow" >"$workflow.tmp" \
		|| ! mv "$workflow.tmp" "$workflow"; then
		printf 'Unable to comment fixture golden step.\n' >&2
		return 1
	fi
}

disable_golden_step() {
	local fixture_root="$1"
	local workflow="$fixture_root/.github/workflows/build.yml"
	assert_fixture_path "$fixture_root" || return 1
	if ! awk '{ print; if ($0 == "        run: mise run verify-goldens") print "        if: false" }' \
		"$workflow" >"$workflow.tmp" \
		|| ! mv "$workflow.tmp" "$workflow"; then
		printf 'Unable to disable fixture golden step.\n' >&2
		return 1
	fi
}

continue_on_error_golden_step() {
	local fixture_root="$1"
	local workflow="$fixture_root/.github/workflows/build.yml"
	assert_fixture_path "$fixture_root" || return 1
	if ! awk '{ print; if ($0 == "        run: mise run verify-goldens") print "        continue-on-error: true" }' \
		"$workflow" >"$workflow.tmp" \
		|| ! mv "$workflow.tmp" "$workflow"; then
		printf 'Unable to weaken fixture golden step.\n' >&2
		return 1
	fi
}

comment_package_run() {
	local fixture_root="$1"
	local workflow="$fixture_root/.github/workflows/build.yml"
	assert_fixture_path "$fixture_root" || return 1
	if ! sed 's|^        run: bash rewrite/tools/verify_java_migration_package.sh$|        # run: bash rewrite/tools/verify_java_migration_package.sh|' \
		"$workflow" >"$workflow.tmp" \
		|| ! mv "$workflow.tmp" "$workflow"; then
		printf 'Unable to comment fixture package gate.\n' >&2
		return 1
	fi
}

disable_package_step() {
	local fixture_root="$1"
	local workflow="$fixture_root/.github/workflows/build.yml"
	assert_fixture_path "$fixture_root" || return 1
	if ! awk '{ print; if ($0 == "        run: bash rewrite/tools/verify_java_migration_package.sh") print "        if: false" }' \
		"$workflow" >"$workflow.tmp" \
		|| ! mv "$workflow.tmp" "$workflow"; then
		printf 'Unable to disable fixture package gate.\n' >&2
		return 1
	fi
}

continue_on_error_package_step() {
	local fixture_root="$1"
	local workflow="$fixture_root/.github/workflows/build.yml"
	assert_fixture_path "$fixture_root" || return 1
	if ! awk '{ print; if ($0 == "        run: bash rewrite/tools/verify_java_migration_package.sh") print "        continue-on-error: true" }' \
		"$workflow" >"$workflow.tmp" \
		|| ! mv "$workflow.tmp" "$workflow"; then
		printf 'Unable to weaken fixture package gate.\n' >&2
		return 1
	fi
}

inject_required_step_line() {
	local fixture_root="$1"
	local target_line="$2"
	local injected_line="$3"
	local workflow="$fixture_root/.github/workflows/build.yml"
	assert_fixture_path "$fixture_root" || return 1
	if ! awk -v target="$target_line" -v injected="$injected_line" \
		'{ print; if ($0 == target) print injected }' \
		"$workflow" >"$workflow.tmp" \
		|| ! mv "$workflow.tmp" "$workflow"; then
		printf 'Unable to inject required workflow step configuration.\n' >&2
		return 1
	fi
}

duplicate_package_step() {
	local fixture_root="$1"
	local workflow="$fixture_root/.github/workflows/build.yml"
	assert_fixture_path "$fixture_root" || return 1
	if ! awk '{
		print
		if ($0 == "        run: bash rewrite/tools/verify_java_migration_package.sh") {
			print ""
			print "      - name: Verify packaged migration resources"
			print "        run: bash rewrite/tools/verify_java_migration_package.sh"
		}
	}' "$workflow" >"$workflow.tmp" \
		|| ! mv "$workflow.tmp" "$workflow"; then
		printf 'Unable to duplicate fixture package gate.\n' >&2
		return 1
	fi
}

write_reordered_workflow() {
	local fixture_root="$1"
	local workflow="$fixture_root/.github/workflows/build.yml"
	assert_fixture_path "$fixture_root" || return 1
	if ! cat >"$workflow" <<'EOF'
name: Build

jobs:
  maven:
    steps:
      - name: Install project runtime
        uses: jdx/mise-action@v4
      - name: Build and test
        run: mise exec -- bash -lc 'mvn --batch-mode -s "$MAVEN_SETTINGS" clean verify'
      - name: Verify packaged migration resources
        run: bash rewrite/tools/verify_java_migration_package.sh
      - name: Verify migration goldens
        run: mise run verify-goldens
EOF
	then
		printf 'Unable to write reordered fixture workflow.\n' >&2
		return 1
	fi
}

remove_fixture_entry() {
	local fixture_root="$1"
	local relative_path="$2"
	assert_fixture_path "$fixture_root" || return 1
	case "$relative_path" in
		""|/*|*"../"*|*"/.."*)
			printf 'Unsafe fixture-relative path: %s\n' "$relative_path" >&2
			return 1
			;;
	esac
	if ! rm "$fixture_root/$relative_path"; then
		printf 'Unable to remove fixture entry: %s\n' "$relative_path" >&2
		return 1
	fi
}

install_real_contract() {
	local fixture_root="$1"
	assert_fixture_path "$fixture_root" || return 1
	if ! cp rewrite/tools/test_verify_java_migration_goldens.sh \
		"$fixture_root/rewrite/tools/test_verify_java_migration_goldens.sh" \
		|| ! cp rewrite/tools/verify_java_oracle_provenance.sh \
			"$fixture_root/rewrite/tools/verify_java_oracle_provenance.sh"; then
		printf 'Unable to install real contract in fixture.\n' >&2
		return 1
	fi
}

write_rg_error_stub() {
	local fixture_root="$1"
	local output_path="$fixture_root/bin/rg"
	assert_fixture_path "$fixture_root" || return 1
	if ! printf '%s\n' '#!/usr/bin/env bash' 'exit 2' >"$output_path" \
		|| ! chmod +x "$output_path"; then
		printf 'Unable to install failing rg stub.\n' >&2
		return 1
	fi
}

append_partytime_declaration() {
	local fixture_root="$1"
	assert_fixture_path "$fixture_root" || return 1
	if ! printf 'LegacyPartytimeDeclaration\n' \
		>>"$fixture_root/rewrite/tools/verify_vos_godot_java_parity.sh"; then
		printf 'Unable to append Partytime fixture declaration.\n' >&2
		return 1
	fi
}

assert_no_root_fixture_artifacts
create_unsafe_tmpdir_probe
tmpdir_probe="$CREATED_FIXTURE"
if ! ln -s / "$tmpdir_probe/root-link"; then
	printf 'Unable to create root-equivalent TMPDIR symlink.\n' >&2
	exit 1
fi
expect_unsafe_tmpdir_rejected empty "" "$tmpdir_probe"
expect_unsafe_tmpdir_rejected root / "$tmpdir_probe"
expect_unsafe_tmpdir_rejected double-root // "$tmpdir_probe"
expect_unsafe_tmpdir_rejected normalized-root /./ "$tmpdir_probe"
expect_unsafe_tmpdir_rejected symlink-root "$tmpdir_probe/root-link" "$tmpdir_probe"
assert_no_root_fixture_artifacts

for unsafe_path in \
	"" / "$FIXTURE_TEMP_ROOT" "$FIXTURE_PARENT" \
	"$FIXTURE_PARENT/../escape" /private/tmp/outside-fixture; do
	if assert_fixture_path "$unsafe_path" >/dev/null 2>&1; then
		printf 'Unsafe fixture path was accepted: %s\n' "${unsafe_path:-<empty>}" >&2
		exit 1
	fi
done

probe_status=0
if probe_output="$(bash "$ROOT_DIR/rewrite/tools/test_verify_java_migration_goldens_behavior.sh" \
	--interrupt-cleanup-probe 2>&1)"; then
	printf 'Interrupted cleanup probe unexpectedly passed.\n' >&2
	exit 1
else
	probe_status=$?
fi
probe_root="${probe_output##*$'\n'}"
if [[ "$probe_status" -ne 143 || -z "$probe_root" || "$probe_root" == "/" \
	|| "$probe_root" != "$FIXTURE_TEMP_ROOT"/* || -e "$probe_root" ]]; then
	printf 'Interrupted cleanup probe did not safely remove its fixture root.\n' >&2
	exit 1
fi

mktemp() {
	return 73
}
if create_fixture 2>/dev/null; then
	printf 'Forced fixture setup failure unexpectedly passed.\n' >&2
	exit 1
fi
unset -f mktemp
if [[ -n "$CREATED_FIXTURE" ]]; then
	printf 'Failed fixture setup returned a usable path.\n' >&2
	exit 1
fi
assert_no_root_fixture_artifacts

if ! hostile_root="$(mktemp -d "$FIXTURE_PARENT/hostile-git.XXXXXX")" \
	|| ! hostile_root="$(cd "$hostile_root" && pwd -P)" \
	|| ! assert_fixture_path "$hostile_root" \
	|| ! install_hostile_git_environment "$hostile_root"; then
	printf 'Unable to prepare hostile Git environment.\n' >&2
	exit 1
fi
if ! hostile_signing="$(GIT_CONFIG_GLOBAL="$hostile_root/global.gitconfig" \
	GIT_CONFIG_NOSYSTEM=1 git config --global --bool commit.gpgSign)" \
	|| [[ "$hostile_signing" != "true" ]]; then
	printf 'Hostile Git signing control was not active.\n' >&2
	exit 1
fi
GIT_CONFIG_GLOBAL="$hostile_root/global.gitconfig" create_fixture
fixture="$CREATED_FIXTURE"
expect_verifier_pass "globally hostile Git configuration" "$fixture"

create_fixture
fixture="$CREATED_FIXTURE"
expect_verifier_pass "baseline copied verifier" "$fixture"

create_fixture
fixture="$CREATED_FIXTURE"
remove_fixture_entry "$fixture" pom.xml
expect_verifier_failure "missing verifier input" "$fixture" valid "Missing required file: pom.xml"

create_fixture
fixture="$CREATED_FIXTURE"
remove_fixture_entry "$fixture" \
	src/test/java/org/open2jam/export/MigrationGoldenCorpusGeneratorTest.java
expect_verifier_failure "missing declared source" "$fixture" valid "Missing required file:"

create_fixture
fixture="$CREATED_FIXTURE"
rewrite_first_test_source "$fixture" $'package org.open2jam.export;\n\nclass WrongTest {\n}'
expect_verifier_failure "missing declared class" "$fixture" valid "Declared test class"

create_fixture
fixture="$CREATED_FIXTURE"
remove_fixture_entry "$fixture" bin/rg
expect_verifier_failure "missing rg" "$fixture" valid "Missing required command: rg"

create_fixture
fixture="$CREATED_FIXTURE"
remove_fixture_entry "$fixture" bin/rg
write_rg_error_stub "$fixture"
expect_verifier_failure "rg status greater than one" "$fixture" valid \
	"Unable to inspect selected migration tests"

create_fixture
fixture="$CREATED_FIXTURE"
rewrite_first_test_source "$fixture" \
	$'package org.open2jam.export;\n\n@org.junit.jupiter.api.condition.EnabledOnOs\nclass MigrationGoldenCorpusGeneratorTest {\n}'
expect_verifier_failure "fully qualified JUnit condition" "$fixture" valid \
	"conditional execution"

for assumption in \
	assumeTrue assumeFalse assumingThat assumeNotNull assumeNoException assumeThat; do
	create_fixture
	fixture="$CREATED_FIXTURE"
	rewrite_first_test_source "$fixture" \
		"package org.open2jam.export;

class MigrationGoldenCorpusGeneratorTest {
    void condition() {
        $assumption(false);
    }
}"
	expect_verifier_failure "static $assumption assumption" "$fixture" valid \
		"conditional execution"
done

create_fixture
fixture="$CREATED_FIXTURE"
expect_verifier_failure "missing Surefire report" "$fixture" missing_report \
	"Missing Surefire report"

create_fixture
fixture="$CREATED_FIXTURE"
expect_verifier_failure "malformed Surefire report" "$fixture" malformed_report \
	"SurefireReportVerifier.java"

create_fixture
fixture="$CREATED_FIXTURE"
expect_verifier_failure "wrong Surefire suite" "$fixture" wrong_suite \
	"Surefire suite name mismatch"

create_fixture
fixture="$CREATED_FIXTURE"
expect_verifier_failure "zero-test Surefire report" "$fixture" zero_tests \
	"No tests executed"

create_fixture
fixture="$CREATED_FIXTURE"
expect_verifier_failure "non-numeric Surefire report" "$fixture" non_numeric_tests \
	"Invalid tests count"

for mode in failure_report error_report skipped_report; do
	create_fixture
	fixture="$CREATED_FIXTURE"
	expect_verifier_failure "$mode Surefire report" "$fixture" "$mode" \
		"Surefire report is not clean"
done

create_fixture
fixture="$CREATED_FIXTURE"
seed_stale_reports "$fixture"
expect_verifier_failure "stale Surefire reports" "$fixture" no_reports \
	"Missing Surefire report"

create_fixture
fixture="$CREATED_FIXTURE"
expect_verifier_failure "post-test corpus mutation" "$fixture" mutate_corpus "FAILED"

create_fixture
fixture="$CREATED_FIXTURE"
expect_verifier_failure "post-test corpus and manifest mutation" "$fixture" \
	mutate_corpus_and_manifest "Golden verification modified tracked corpus files"

create_fixture
fixture="$CREATED_FIXTURE"
install_real_contract "$fixture"
expect_contract_pass "$fixture"

create_fixture
fixture="$CREATED_FIXTURE"
install_real_contract "$fixture"
comment_golden_run "$fixture"
expect_contract_failure "commented workflow golden gate" "$fixture" \
	"Required workflow step contains unexpected configuration"

create_fixture
fixture="$CREATED_FIXTURE"
install_real_contract "$fixture"
disable_golden_step "$fixture"
expect_contract_failure "disabled workflow golden gate" "$fixture" \
	"Required workflow step must be unconditional"

create_fixture
fixture="$CREATED_FIXTURE"
install_real_contract "$fixture"
continue_on_error_golden_step "$fixture"
expect_contract_failure "continue-on-error workflow golden gate" "$fixture" \
	"Required workflow step cannot set continue-on-error"

create_fixture
fixture="$CREATED_FIXTURE"
install_real_contract "$fixture"
write_reordered_workflow "$fixture"
expect_contract_failure "reordered workflow gates" "$fixture" \
	"Build workflow steps must run runtime, goldens, clean build, then package verification in order"

create_fixture
fixture="$CREATED_FIXTURE"
install_real_contract "$fixture"
comment_package_run "$fixture"
expect_contract_failure "commented workflow package gate" "$fixture" \
	"Required workflow step contains unexpected configuration"

create_fixture
fixture="$CREATED_FIXTURE"
install_real_contract "$fixture"
disable_package_step "$fixture"
expect_contract_failure "disabled workflow package gate" "$fixture" \
	"Required workflow step must be unconditional"

create_fixture
fixture="$CREATED_FIXTURE"
install_real_contract "$fixture"
continue_on_error_package_step "$fixture"
expect_contract_failure "continue-on-error workflow package gate" "$fixture" \
	"Required workflow step cannot set continue-on-error"

for required_line in \
	'        uses: jdx/mise-action@v4' \
	'        run: mise run verify-goldens' \
	'        run: mise exec -- bash -lc '\''mvn --batch-mode -s "$MAVEN_SETTINGS" clean verify'\''' \
	'        run: bash rewrite/tools/verify_java_migration_package.sh'; do
	create_fixture
	fixture="$CREATED_FIXTURE"
	install_real_contract "$fixture"
	inject_required_step_line "$fixture" "$required_line" '        if : false'
	expect_contract_failure "whitespace-equivalent disabled required workflow step" \
		"$fixture" "Required workflow step contains unexpected configuration"
done

for injected_line in \
	'        "if": false' \
	"        'if' : false" \
	'        continue-on-error : true' \
	'        "continue-on-error": true'; do
	create_fixture
	fixture="$CREATED_FIXTURE"
	install_real_contract "$fixture"
	inject_required_step_line "$fixture" \
		'        run: bash rewrite/tools/verify_java_migration_package.sh' \
		"$injected_line"
	expect_contract_failure "quoted or whitespace package-step bypass" \
		"$fixture" "Required workflow step contains unexpected configuration"
done

create_fixture
fixture="$CREATED_FIXTURE"
install_real_contract "$fixture"
duplicate_package_step "$fixture"
expect_contract_failure "duplicate workflow package gate" "$fixture" \
	"Build workflow required step name is missing or duplicated"

create_fixture
fixture="$CREATED_FIXTURE"
install_real_contract "$fixture"
remove_fixture_entry "$fixture" .github/workflows/build.yml
expect_contract_failure "missing build workflow" "$fixture" "Missing build workflow"

create_manifest_fixture
fixture="$CREATED_FIXTURE"
append_partytime_declaration "$fixture"
expect_manifest_failure "arbitrary Partytime declaration" "$fixture" \
	"Aggregate verification still contains a retired contract"

create_manifest_fixture
fixture="$CREATED_FIXTURE"
remove_fixture_entry "$fixture" rewrite/tools/verify_vos_godot_java_parity.sh
expect_manifest_failure "missing parity verifier" "$fixture" \
	"Missing aggregate verifier"

cleanup_fixtures
cleanup_fixtures
printf 'Java migration golden verifier behavioral contract passed.\n'
