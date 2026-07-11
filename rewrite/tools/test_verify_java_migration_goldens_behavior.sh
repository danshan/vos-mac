#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

REAL_JAVA_PATH="$(mise which java)"
REAL_RG_PATH="$(command -v rg)"
FIXTURE_PARENT="$(mktemp -d)"

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
	cat >"$output_path" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
	chmod +x "$output_path"
}

write_mise_stub() {
	local output_path="$1"
	cat >"$output_path" <<'EOF'
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
	chmod +x "$output_path"
}

write_test_source() {
	local fixture_root="$1"
	local class_name="$2"
	local source_path
	local package_name="${class_name%.*}"
	local simple_name="${class_name##*.}"
	local class_path

	class_path="$(printf '%s' "$class_name" | tr '.' '/')"
	source_path="$fixture_root/src/test/java/$class_path.java"
	mkdir -p "$(dirname "$source_path")"
	printf 'package %s;\n\nclass %s {\n}\n' \
		"$package_name" "$simple_name" >"$source_path"
}

create_fixture() {
	local fixture_root
	local class_name

	fixture_root="$(mktemp -d "$FIXTURE_PARENT/fixture.XXXXXX")"
	mkdir -p \
		"$fixture_root/.github/workflows" \
		"$fixture_root/.mvn" \
		"$fixture_root/bin" \
		"$fixture_root/rewrite/golden/java-migration" \
		"$fixture_root/rewrite/tools"

	cp .github/workflows/build.yml "$fixture_root/.github/workflows/build.yml"
	cp .mvn/settings.xml "$fixture_root/.mvn/settings.xml"
	cp mise.toml pom.xml "$fixture_root/"
	cp rewrite/tools/SurefireReportVerifier.java "$fixture_root/rewrite/tools/"
	cp rewrite/tools/verify_java_migration_goldens.sh "$fixture_root/rewrite/tools/"
	cp rewrite/tools/verify_vos_godot_initial.sh "$fixture_root/rewrite/tools/"
	write_contract_stub "$fixture_root/rewrite/tools/test_verify_java_migration_goldens.sh"
	write_contract_stub "$fixture_root/rewrite/tools/test_verify_java_migration_goldens_behavior.sh"
	write_contract_stub "$fixture_root/rewrite/tools/test_verify_vos_godot_manifest.sh"
	write_mise_stub "$fixture_root/bin/mise"
	ln -s "$REAL_RG_PATH" "$fixture_root/bin/rg"

	for class_name in "${TEST_CLASSES[@]}"; do
		write_test_source "$fixture_root" "$class_name"
	done

	printf 'baseline\n' >"$fixture_root/rewrite/golden/java-migration/data.txt"
	(
		cd "$fixture_root/rewrite/golden/java-migration"
		shasum -a 256 data.txt >manifest.sha256
	)

	git -C "$fixture_root" init -q
	git -C "$fixture_root" config user.email verifier@example.invalid
	git -C "$fixture_root" config user.name "Golden Verifier Test"
	git -C "$fixture_root" add .
	git -C "$fixture_root" commit -qm "test fixture"
	printf '%s\n' "$fixture_root"
}

run_verifier() {
	local fixture_root="$1"
	local mode="${2:-valid}"
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
	printf '%s\n' "$body" >"$source_path"
}

seed_stale_reports() {
	local fixture_root="$1"
	local class_name
	local report_directory="$fixture_root/target/surefire-reports"
	mkdir -p "$report_directory"
	for class_name in "${TEST_CLASSES[@]}"; do
		printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>' \
			"<testsuite name=\"$class_name\" tests=\"1\" failures=\"0\" errors=\"0\" skipped=\"0\"></testsuite>" \
			>"$report_directory/TEST-$class_name.xml"
	done
}

expect_contract_pass() {
	local fixture_root="$1"
	local output
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
	fixture_root="$(mktemp -d "$FIXTURE_PARENT/manifest.XXXXXX")"
	mkdir -p "$fixture_root/rewrite/tools"
	cp rewrite/tools/test_verify_vos_godot_manifest.sh "$fixture_root/rewrite/tools/"
	printf '%s\n' \
		OsuManiaParserTest ChartModelLoaderTest MusicSelectionSelectionTest \
		ChartDisplayTest ConfigTest JudgmentStrategyOracleFixtureTest \
		>"$fixture_root/rewrite/tools/verify_vos_godot_initial.sh"
	: >"$fixture_root/rewrite/tools/verify_vos_godot_java_parity.sh"
	printf '%s\n' "$fixture_root"
}

expect_manifest_failure() {
	local description="$1"
	local fixture_root="$2"
	local expected_text="$3"
	local output
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

fixture="$(create_fixture)"
expect_verifier_pass "baseline copied verifier" "$fixture"

fixture="$(create_fixture)"
rm "$fixture/pom.xml"
expect_verifier_failure "missing verifier input" "$fixture" valid "Missing required file: pom.xml"

fixture="$(create_fixture)"
rm "$fixture/src/test/java/org/open2jam/export/MigrationGoldenCorpusGeneratorTest.java"
expect_verifier_failure "missing declared source" "$fixture" valid "Missing required file:"

fixture="$(create_fixture)"
rewrite_first_test_source "$fixture" $'package org.open2jam.export;\n\nclass WrongTest {\n}'
expect_verifier_failure "missing declared class" "$fixture" valid "Declared test class"

fixture="$(create_fixture)"
rm "$fixture/bin/rg"
expect_verifier_failure "missing rg" "$fixture" valid "Missing required command: rg"

fixture="$(create_fixture)"
rm "$fixture/bin/rg"
printf '%s\n' '#!/usr/bin/env bash' 'exit 2' >"$fixture/bin/rg"
chmod +x "$fixture/bin/rg"
expect_verifier_failure "rg status greater than one" "$fixture" valid \
	"Unable to inspect selected migration tests"

fixture="$(create_fixture)"
rewrite_first_test_source "$fixture" \
	$'package org.open2jam.export;\n\n@org.junit.jupiter.api.condition.EnabledOnOs\nclass MigrationGoldenCorpusGeneratorTest {\n}'
expect_verifier_failure "fully qualified JUnit condition" "$fixture" valid \
	"conditional execution"

for assumption in \
	assumeTrue assumeFalse assumingThat assumeNotNull assumeNoException assumeThat; do
	fixture="$(create_fixture)"
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

fixture="$(create_fixture)"
expect_verifier_failure "missing Surefire report" "$fixture" missing_report \
	"Missing Surefire report"

fixture="$(create_fixture)"
expect_verifier_failure "malformed Surefire report" "$fixture" malformed_report \
	"SurefireReportVerifier.java"

fixture="$(create_fixture)"
expect_verifier_failure "wrong Surefire suite" "$fixture" wrong_suite \
	"Surefire suite name mismatch"

fixture="$(create_fixture)"
expect_verifier_failure "zero-test Surefire report" "$fixture" zero_tests \
	"No tests executed"

fixture="$(create_fixture)"
expect_verifier_failure "non-numeric Surefire report" "$fixture" non_numeric_tests \
	"Invalid tests count"

for mode in failure_report error_report skipped_report; do
	fixture="$(create_fixture)"
	expect_verifier_failure "$mode Surefire report" "$fixture" "$mode" \
		"Surefire report is not clean"
done

fixture="$(create_fixture)"
seed_stale_reports "$fixture"
expect_verifier_failure "stale Surefire reports" "$fixture" no_reports \
	"Missing Surefire report"

fixture="$(create_fixture)"
expect_verifier_failure "post-test corpus mutation" "$fixture" mutate_corpus "FAILED"

fixture="$(create_fixture)"
expect_verifier_failure "post-test corpus and manifest mutation" "$fixture" \
	mutate_corpus_and_manifest "Golden verification modified tracked corpus files"

fixture="$(create_fixture)"
cp rewrite/tools/test_verify_java_migration_goldens.sh \
	"$fixture/rewrite/tools/test_verify_java_migration_goldens.sh"
expect_contract_pass "$fixture"

fixture="$(create_fixture)"
cp rewrite/tools/test_verify_java_migration_goldens.sh \
	"$fixture/rewrite/tools/test_verify_java_migration_goldens.sh"
sed 's/run: mise run verify-goldens/run: mise run build/' \
	"$fixture/.github/workflows/build.yml" \
	>"$fixture/.github/workflows/build.yml.tmp"
mv "$fixture/.github/workflows/build.yml.tmp" "$fixture/.github/workflows/build.yml"
expect_contract_failure "disabled workflow golden gate" "$fixture" \
	"Build workflow does not run the golden verifier"

fixture="$(create_fixture)"
cp rewrite/tools/test_verify_java_migration_goldens.sh \
	"$fixture/rewrite/tools/test_verify_java_migration_goldens.sh"
rm "$fixture/.github/workflows/build.yml"
expect_contract_failure "missing build workflow" "$fixture" "Missing build workflow"

fixture="$(create_manifest_fixture)"
printf 'LegacyPartytimeDeclaration\n' \
	>>"$fixture/rewrite/tools/verify_vos_godot_java_parity.sh"
expect_manifest_failure "arbitrary Partytime declaration" "$fixture" \
	"Aggregate verification still contains a retired contract"

fixture="$(create_manifest_fixture)"
rm "$fixture/rewrite/tools/verify_vos_godot_java_parity.sh"
expect_manifest_failure "missing parity verifier" "$fixture" \
	"Missing aggregate verifier"

rm -rf "$FIXTURE_PARENT"
printf 'Java migration golden verifier behavioral contract passed.\n'
