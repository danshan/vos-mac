#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

VERIFIER="rewrite/tools/verify_java_migration_goldens.sh"
WORKFLOW=".github/workflows/build.yml"
INITIAL="rewrite/tools/verify_vos_godot_initial.sh"
MISE_CONFIG="mise.toml"
BEHAVIOR_TEST="rewrite/tools/test_verify_java_migration_goldens_behavior.sh"
NESTED_TMPDIR_TEST="rewrite/tools/test_java_migration_nested_tmpdir.sh"
NESTED_TMPDIR_BEHAVIOR_TEST="rewrite/tools/test_java_migration_nested_tmpdir_behavior.sh"
ORACLE_BEHAVIOR_TEST="rewrite/tools/test_verify_java_oracle_provenance.sh"
PACKAGE_BEHAVIOR_TEST="rewrite/tools/test_verify_java_migration_package.sh"
REPORT_VERIFIER="rewrite/tools/SurefireReportVerifier.java"
JAR_VERIFIER="rewrite/tools/JarResourceVerifier.java"
ORACLE_FILESYSTEM_VERIFIER="rewrite/tools/JavaOracleFilesystemVerifier.java"
ORACLE_PROVENANCE_VERIFIER="rewrite/tools/verify_java_oracle_provenance.sh"
WORKFLOW_VERIFIER="rewrite/tools/verify_build_workflow.sh"
PRODUCTION_SOUNDFONT_VERIFIER="rewrite/tools/verify_production_soundfont.sh"
PRODUCTION_SOUNDFONT_TEST="rewrite/tools/test_verify_production_soundfont.sh"

[[ -x "$VERIFIER" ]] || { printf 'Missing executable golden verifier.\n' >&2; exit 1; }
[[ -f "$WORKFLOW" ]] || { printf 'Missing build workflow.\n' >&2; exit 1; }
[[ -f "$INITIAL" ]] || { printf 'Missing aggregate initial verifier.\n' >&2; exit 1; }
[[ -f "$MISE_CONFIG" ]] || { printf 'Missing mise configuration.\n' >&2; exit 1; }
[[ -f "$BEHAVIOR_TEST" ]] || { printf 'Missing golden verifier behavioral contract.\n' >&2; exit 1; }
[[ -x "$NESTED_TMPDIR_TEST" ]] || { printf 'Missing nested TMPDIR regression.\n' >&2; exit 1; }
[[ -x "$NESTED_TMPDIR_BEHAVIOR_TEST" ]] || { printf 'Missing nested TMPDIR behavior test.\n' >&2; exit 1; }
[[ -x "$ORACLE_BEHAVIOR_TEST" ]] || { printf 'Missing oracle provenance behavioral contract.\n' >&2; exit 1; }
[[ -x "$PACKAGE_BEHAVIOR_TEST" ]] || { printf 'Missing package behavioral contract.\n' >&2; exit 1; }
[[ -f "$REPORT_VERIFIER" ]] || { printf 'Missing Surefire report verifier.\n' >&2; exit 1; }
[[ -f "$JAR_VERIFIER" ]] || { printf 'Missing JAR resource verifier.\n' >&2; exit 1; }
[[ -f "$ORACLE_FILESYSTEM_VERIFIER" ]] || { printf 'Missing oracle filesystem verifier.\n' >&2; exit 1; }
[[ -x "$ORACLE_PROVENANCE_VERIFIER" ]] || { printf 'Missing oracle provenance verifier.\n' >&2; exit 1; }
[[ -x "$WORKFLOW_VERIFIER" ]] || { printf 'Missing build workflow verifier.\n' >&2; exit 1; }
[[ -x "$PRODUCTION_SOUNDFONT_VERIFIER" ]] || { printf 'Missing production SoundFont verifier.\n' >&2; exit 1; }
[[ -x "$PRODUCTION_SOUNDFONT_TEST" ]] || { printf 'Missing production SoundFont verifier test.\n' >&2; exit 1; }

EXPECTED_TEST_CLASSES=(
	org.open2jam.export.MigrationGoldenCorpusGeneratorTest
	org.open2jam.export.MigrationGoldenCorpusTest
	org.open2jam.export.MigrationGoldenInputOracleTest
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
	src/test/java/org/open2jam/export/MigrationGoldenInputOracleTest.java
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

require_active_top_level_invocation() {
	local invocation="$1"
	local description="$2"
	local count
	local scan_status
	if count="$(awk -v invocation="$invocation" '
		BEGIN { depth = 0; matches = 0; malformed = 0 }
		{
			line = $0
			sub(/^[[:space:]]+/, "", line)
			sub(/[[:space:]]+$/, "", line)
			if ($0 == invocation && depth == 0) {
				matches++
			}
			if (line ~ /^(if|for|while|until|case|select)([[:space:]]|$)/ || line ~ /^[[:alnum:]_]+\(\)[[:space:]]*\{$/) {
				depth++
			}
			if (line ~ /^(fi|done|esac|\})([[:space:];]|$)/) {
				depth--
				if (depth < 0) {
					malformed = 1
				}
			}
		}
		END {
			if (malformed || depth != 0) {
				exit 2
			}
			print matches
		}
	' "$VERIFIER")"; then
		scan_status=0
	else
		scan_status=$?
	fi
	if [[ "$scan_status" -ne 0 ]]; then
		printf 'Unable to inspect verifier top-level shell structure.\n' >&2
		exit 1
	fi
	if [[ "$count" != "1" ]]; then
		printf '%s invocation is not one active top-level command.\n' \
			"$description" >&2
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
	'bash rewrite/tools/test_verify_java_oracle_provenance.sh' \
	'bash rewrite/tools/test_verify_java_migration_package.sh' \
	'bash rewrite/tools/verify_java_oracle_provenance.sh' \
	'rewrite/tools/JavaOracleFilesystemVerifier.java' \
	'"$CORPUS_DIR/oracle-files.sha256"' \
	'for required_command in awk bash git grep mise rg rm sed shasum tr wc' \
	'for test_source in "${TEST_SOURCES[@]}"' \
	'class_path="$(printf '\''%s'\'' "$fully_qualified_class" | tr '\''.'\'' '\''/'\'')"' \
	'expected_source="src/test/java/$class_path.java"' \
	'rg_status=$?' \
	'if [[ "$rg_status" -ne 1 ]]' \
	'@([[:alnum:]_$]+\.)*(Disabled|Enabled)' \
	'assum(e|ing)[A-Z][[:alnum:]_]*' \
	'mvn -s "$MAVEN_SETTINGS" clean test' \
	'mvn -s "$MAVEN_SETTINGS" package -DskipTests' \
	'REPORT_DIR="target/surefire-reports"' \
	'rm -rf "$REPORT_DIR"' \
	'mise exec -- java "$REPORT_VERIFIER" "$REPORT_DIR" "${TEST_CLASSES[@]}"' \
	'bash rewrite/tools/verify_java_migration_package.sh' \
	'shasum -a 256 -c manifest.sha256' \
	'git diff --exit-code -- "$CORPUS_DIR"' \
	'git diff --cached --exit-code -- "$CORPUS_DIR"' \
	'git status --porcelain --untracked-files=all -- "$CORPUS_DIR"'; do
	require_literal "$required_text" "$VERIFIER" \
		'Golden verifier omits fail-closed contract'
done

require_active_top_level_invocation \
	'bash rewrite/tools/test_java_migration_nested_tmpdir.sh' \
	'Nested TMPDIR verifier'

require_active_top_level_invocation \
	'bash rewrite/tools/verify_production_soundfont.sh' \
	'Production SoundFont verifier'

reject_pattern \
	'assumeTrue[[:space:]]*\(|/Users/[[:alnum:]_.-]+|Skipping|\|\|[[:space:]]*true' \
	"$VERIFIER" 'Golden verifier contains optional behavior'

for required_text in \
	'git cat-file blob "$object_id" | shasum -a 256' \
	'mise exec -- java "$FILESYSTEM_VERIFIER" "$FILES_MANIFEST" "${ORACLE_PATHS[@]}"' \
	'PINNED_FILES_SHA256="b1e093eaf4dd2a28ae918d29afcccff8d40b7ad60410d1caee5219fcec74feca"' \
	'PINNED_MANIFEST_SHA256="5791c29398844fd1add3db4961da3d7a412eab3072ba32a656b70c9cfb162f0a"' \
	'shasum -a 256 "$PROVENANCE_MANIFEST"' \
	'Canonical Java oracle provenance manifest digest mismatch'; do
	require_literal "$required_text" "$ORACLE_PROVENANCE_VERIFIER" \
		'Oracle provenance verifier omits raw filesystem contract'
done
reject_pattern 'git (diff|ls-files)' "$ORACLE_PROVENANCE_VERIFIER" \
	'Oracle provenance verifier depends on Git working-tree normalization'

for required_text in \
	'137052L' \
	'4407L' \
	'long declaredSize = entry.getSize();' \
	'try (InputStream input = jar.getInputStream(entry))' \
	'bytesRead > expected.size() - read' \
	'bytesRead != expected.size()'; do
	require_literal "$required_text" "$JAR_VERIFIER" \
		'JAR verifier omits bounded exact-size resource validation'
done
reject_pattern 'readAllBytes[[:space:]]*\(' "$JAR_VERIFIER" \
	'JAR verifier contains an unbounded resource read'

require_literal 'run = "bash rewrite/tools/verify_java_migration_goldens.sh"' \
	"$MISE_CONFIG" 'mise verify-goldens task is missing'
require_literal 'run = "mvn -s $MAVEN_SETTINGS clean verify"' \
	"$MISE_CONFIG" 'mise build task is not clean'

require_literal 'bash rewrite/tools/verify_java_migration_goldens.sh' \
	"$INITIAL" 'Aggregate initial gate does not invoke the golden verifier'
require_literal 'run: bash rewrite/tools/verify_java_migration_package.sh' \
	"$WORKFLOW" 'Build workflow does not verify the final packaged JAR'
require_literal '"Verify packaged migration resources"' \
	"$WORKFLOW_VERIFIER" 'Build workflow verifier omits the package gate'
require_literal \
	'PINNED_WORKFLOW_SHA256="550c3f00260d028f60bfed8dcb200845f4e6fcf387157c126bc6fa0c807e1408"' \
	"$WORKFLOW_VERIFIER" 'Build workflow verifier omits the canonical digest'
require_literal 'shasum -a 256 <"$WORKFLOW_PATH"' \
	"$WORKFLOW_VERIFIER" 'Build workflow verifier does not hash exact input bytes'
require_literal 'Build workflow does not match the pinned canonical contract.' \
	"$WORKFLOW_VERIFIER" 'Build workflow verifier is not fail-closed on drift'

bash "$WORKFLOW_VERIFIER" "$WORKFLOW"

bash "$NESTED_TMPDIR_BEHAVIOR_TEST"

bash "$PRODUCTION_SOUNDFONT_TEST"

bash "$BEHAVIOR_TEST"

printf 'Java migration golden verifier contract passed.\n'
