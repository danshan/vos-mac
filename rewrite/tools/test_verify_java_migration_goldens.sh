#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

VERIFIER="rewrite/tools/verify_java_migration_goldens.sh"
WORKFLOW=".github/workflows/build.yml"
INITIAL="rewrite/tools/verify_vos_godot_initial.sh"
MISE_CONFIG="mise.toml"

[[ -x "$VERIFIER" ]] || { printf 'Missing executable golden verifier.\n' >&2; exit 1; }
[[ -f "$WORKFLOW" ]] || { printf 'Missing build workflow.\n' >&2; exit 1; }
[[ -f "$INITIAL" ]] || { printf 'Missing aggregate initial verifier.\n' >&2; exit 1; }
[[ -f "$MISE_CONFIG" ]] || { printf 'Missing mise configuration.\n' >&2; exit 1; }

EXPECTED_TEST_CLASSES=(
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

EXPECTED_TEST_SOURCES=(
	src/test/java/org/open2jam/export/MigrationGoldenCorpusGeneratorTest.java
	src/test/java/org/open2jam/export/MigrationGoldenCorpusTest.java
	src/test/java/org/open2jam/parsers/OjnFixtureFactoryTest.java
	src/test/java/org/open2jam/parsers/OsuFixtureFactoryTest.java
	src/test/java/org/open2jam/parsers/VOSParserTest.java
	src/test/java/org/open2jam/parsers/OsuManiaParserTest.java
	src/test/java/org/open2jam/export/VosCatalogExporterTest.java
	src/test/java/org/open2jam/export/VosGameplayExporterTest.java
	src/test/java/org/open2jam/export/VosAudioExporterTest.java
	src/test/java/org/open2jam/export/VosRenderMetadataExporterTest.java
)

extract_array() {
	local array_name="$1"
	sed -n "/^${array_name}=(/,/^)/p" "$VERIFIER" \
		| sed '1d;$d;s/^[[:space:]]*//;s/[[:space:]]*$//;/^$/d'
}

require_literal() {
	local expected_text="$1"
	local input_file="$2"
	local description="$3"
	local matches
	local grep_status

	if matches="$(grep -Fn -- "$expected_text" "$input_file" 2>&1)"; then
		return
	else
		grep_status=$?
	fi
	if [[ "$grep_status" -eq 1 ]]; then
		printf '%s: %s\n' "$description" "$expected_text" >&2
	else
		printf 'Unable to inspect %s:\n%s\n' "$input_file" "$matches" >&2
	fi
	exit 1
}

reject_pattern() {
	local pattern="$1"
	local input_file="$2"
	local description="$3"
	local matches
	local grep_status

	if matches="$(grep -En -- "$pattern" "$input_file" 2>&1)"; then
		printf '%s:\n%s\n' "$description" "$matches" >&2
		exit 1
	else
		grep_status=$?
	fi
	if [[ "$grep_status" -ne 1 ]]; then
		printf 'Unable to inspect %s:\n%s\n' "$input_file" "$matches" >&2
		exit 1
	fi
}

expected_classes="$(printf '%s\n' "${EXPECTED_TEST_CLASSES[@]}")"
actual_classes="$(extract_array TEST_CLASSES)"
if [[ "$actual_classes" != "$expected_classes" ]]; then
	printf 'Golden verifier test class manifest is not exact.\n' >&2
	exit 1
fi

expected_sources="$(printf '%s\n' "${EXPECTED_TEST_SOURCES[@]}")"
actual_sources="$(extract_array TEST_SOURCES)"
if [[ "$actual_sources" != "$expected_sources" ]]; then
	printf 'Golden verifier test source manifest is not exact.\n' >&2
	exit 1
fi

for test_source in "${EXPECTED_TEST_SOURCES[@]}"; do
	[[ -f "$test_source" ]] || {
		printf 'Missing declared golden test source: %s\n' "$test_source" >&2
		exit 1
	}
done

for required_text in \
	'bash rewrite/tools/test_verify_java_migration_goldens.sh' \
	'bash rewrite/tools/test_verify_vos_godot_manifest.sh' \
	'for required_command in bash git grep mise rg sed shasum' \
	'for test_source in "${TEST_SOURCES[@]}"' \
	'expected_source="src/test/java/${fully_qualified_class//./\/}.java"' \
	'rg_status=$?' \
	'if [[ "$rg_status" -ne 1 ]]' \
	'mvn -s "$MAVEN_SETTINGS" clean test' \
	'REPORT_DIR="target/surefire-reports"' \
	'TEST-$class_name.xml' \
	'for attribute in tests failures errors skipped' \
	'if [[ "$attribute" == "tests" && "$value" -eq 0 ]]' \
	'if [[ "$attribute" != "tests" && "$value" -ne 0 ]]' \
	'shasum -a 256 -c manifest.sha256' \
	'git diff --exit-code -- "$CORPUS_DIR"' \
	'git diff --cached --exit-code -- "$CORPUS_DIR"' \
	'git status --porcelain --untracked-files=all -- "$CORPUS_DIR"'; do
	require_literal "$required_text" "$VERIFIER" \
		'Golden verifier omits fail-closed contract'
done

reject_pattern \
	'assumeTrue[[:space:]]*\(|/Users/[[:alnum:]_.-]+|Skipping|\|\|[[:space:]]*true' \
	"$VERIFIER" 'Golden verifier contains optional behavior'

require_literal 'run = "bash rewrite/tools/verify_java_migration_goldens.sh"' \
	"$MISE_CONFIG" 'mise verify-goldens task is missing'
require_literal 'run = "mvn -s $MAVEN_SETTINGS clean verify"' \
	"$MISE_CONFIG" 'mise build task is not clean'

require_literal 'bash rewrite/tools/verify_java_migration_goldens.sh' \
	"$INITIAL" 'Aggregate initial gate does not invoke the golden verifier'

require_literal 'uses: jdx/mise-action@v4' "$WORKFLOW" \
	'Build workflow does not install the project mise runtime'

require_literal 'run: mise run verify-goldens' "$WORKFLOW" \
	'Build workflow does not run the golden verifier'

require_literal 'mvn --batch-mode -s "$MAVEN_SETTINGS" clean verify' \
	"$WORKFLOW" 'Build workflow does not run a clean Maven verification'

reject_pattern 'actions/setup-java|^[[:space:]]*run:[[:space:]]+mvn[[:space:]]' \
	"$WORKFLOW" 'Build workflow bypasses the project mise runtime'

printf 'Java migration golden verifier contract passed.\n'
