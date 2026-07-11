#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

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

TEST_SOURCES=(
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

REPORT_DIR="target/surefire-reports"
CORPUS_DIR="rewrite/golden/java-migration"
MAVEN_SETTINGS_FILE=".mvn/settings.xml"
REPORT_VERIFIER="rewrite/tools/SurefireReportVerifier.java"

require_command() {
	local command_name="$1"
	if ! command -v "$command_name" >/dev/null 2>&1; then
		printf 'Missing required command: %s\n' "$command_name" >&2
		exit 1
	fi
}

require_file() {
	local file_path="$1"
	if [[ ! -f "$file_path" ]]; then
		printf 'Missing required file: %s\n' "$file_path" >&2
		exit 1
	fi
}

for required_command in bash git grep mise rg rm sed shasum tr; do
	require_command "$required_command"
done

for required_file in \
	rewrite/tools/verify_build_workflow.sh \
	rewrite/tools/verify_java_oracle_provenance.sh \
	rewrite/tools/verify_java_migration_package.sh \
	rewrite/tools/test_verify_java_migration_goldens.sh \
	rewrite/tools/test_verify_java_migration_goldens_behavior.sh \
	rewrite/tools/test_verify_java_oracle_provenance.sh \
	rewrite/tools/test_verify_java_migration_package.sh \
	rewrite/tools/test_verify_vos_godot_manifest.sh \
	pom.xml "$MAVEN_SETTINGS_FILE" "$REPORT_VERIFIER" \
	rewrite/tools/JarResourceVerifier.java \
	rewrite/tools/JavaOracleFilesystemVerifier.java \
	"$CORPUS_DIR/manifest.sha256" \
	"$CORPUS_DIR/oracle-files.sha256"; do
	require_file "$required_file"
done

for test_source in "${TEST_SOURCES[@]}"; do
	require_file "$test_source"
done

bash rewrite/tools/test_verify_java_migration_goldens.sh
bash rewrite/tools/test_verify_vos_godot_manifest.sh
bash rewrite/tools/test_verify_java_oracle_provenance.sh
bash rewrite/tools/test_verify_java_migration_package.sh
bash rewrite/tools/verify_java_oracle_provenance.sh

if [[ "${#TEST_CLASSES[@]}" -ne "${#TEST_SOURCES[@]}" ]]; then
	printf 'Golden test class and source manifests have different lengths.\n' >&2
	exit 1
fi

for index in "${!TEST_CLASSES[@]}"; do
	fully_qualified_class="${TEST_CLASSES[$index]}"
	test_source="${TEST_SOURCES[$index]}"
	class_path="$(printf '%s' "$fully_qualified_class" | tr '.' '/')"
	expected_source="src/test/java/$class_path.java"
	package_name="${fully_qualified_class%.*}"
	class_name="${fully_qualified_class##*.}"
	if [[ "$test_source" != "$expected_source" ]]; then
		printf 'Golden test manifest misaligns %s with %s.\n' \
			"$fully_qualified_class" "$test_source" >&2
		exit 1
	fi
	if ! grep -Eq "^package[[:space:]]+${package_name//./\\.};$" "$test_source"; then
		printf 'Declared test package %s is missing from %s.\n' \
			"$package_name" "$test_source" >&2
		exit 1
	fi
	if ! grep -Eq "class[[:space:]]+${class_name}([^[:alnum:]_]|$)" "$test_source"; then
		printf 'Declared test class %s is missing from %s.\n' \
			"$class_name" "$test_source" >&2
		exit 1
	fi
done

if optional_matches="$(rg -n \
	'@([[:alnum:]_$]+\.)*(Disabled|Enabled)[[:alnum:]_$]*|Assumptions\.[[:space:]]*assum(e|ing)[A-Z][[:alnum:]_]*[[:space:]]*\(|Assume\.[[:space:]]*assum(e|ing)[A-Z][[:alnum:]_]*[[:space:]]*\(|(^|[^[:alnum:]_$])assum(e|ing)[A-Z][[:alnum:]_]*[[:space:]]*\(' \
	"${TEST_SOURCES[@]}" 2>&1)"; then
	printf 'Selected migration tests contain conditional execution:\n%s\n' \
		"$optional_matches" >&2
	exit 1
else
	rg_status=$?
	if [[ "$rg_status" -ne 1 ]]; then
		printf 'Unable to inspect selected migration tests:\n%s\n' \
			"$optional_matches" >&2
		exit 1
	fi
fi

mise exec -- bash -lc '
	set -euo pipefail
	command -v java >/dev/null
	command -v mvn >/dev/null
	test -n "${MAVEN_SETTINGS:-}"
	test "$MAVEN_SETTINGS" = "$1"
	test -f "$MAVEN_SETTINGS"
' bash "$MAVEN_SETTINGS_FILE"

tests_csv="$(IFS=,; printf '%s' "${TEST_CLASSES[*]}")"

rm -rf "$REPORT_DIR"
mise exec -- bash -lc 'mvn -s "$MAVEN_SETTINGS" clean test -Dtest="$1"' bash "$tests_csv"

mise exec -- java "$REPORT_VERIFIER" "$REPORT_DIR" "${TEST_CLASSES[@]}"

mise exec -- bash -lc 'mvn -s "$MAVEN_SETTINGS" package -DskipTests'
bash rewrite/tools/verify_java_migration_package.sh

(
	cd "$CORPUS_DIR"
	shasum -a 256 -c manifest.sha256
)

if ! git diff --exit-code -- "$CORPUS_DIR" >/dev/null; then
	printf 'Golden verification modified tracked corpus files.\n' >&2
	exit 1
fi

if ! git diff --cached --exit-code -- "$CORPUS_DIR" >/dev/null; then
	printf 'Golden corpus has staged modifications.\n' >&2
	exit 1
fi

corpus_status="$(git status --porcelain --untracked-files=all -- "$CORPUS_DIR")"
if [[ -n "$corpus_status" ]]; then
	printf 'Golden corpus worktree is not clean:\n%s\n' "$corpus_status" >&2
	exit 1
fi

printf 'Java migration golden gate passed.\n'
