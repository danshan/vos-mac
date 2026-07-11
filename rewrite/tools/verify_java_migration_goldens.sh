#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

bash rewrite/tools/test_verify_vos_godot_manifest.sh

TESTS=(
	MigrationGoldenCorpusGeneratorTest
	MigrationGoldenCorpusTest
	OjnFixtureFactoryTest
	OsuFixtureFactoryTest
	VOSParserTest
	OsuManiaParserTest
	VosCatalogExporterTest
	VosGameplayExporterTest
	VosAudioExporterTest
	VosRenderMetadataExporterTest
)
tests_csv="$(IFS=,; printf '%s' "${TESTS[*]}")"

mise exec -- bash -lc 'mvn -s "$MAVEN_SETTINGS" -Dtest="$1" test' bash "$tests_csv"

if rg -n 'assumeTrue|/Users/' \
	src/test/java/org/open2jam/export/MigrationGoldenCorpusGeneratorTest.java \
	src/test/java/org/open2jam/export/MigrationGoldenCorpusTest.java \
	src/test/java/org/open2jam/parsers/OjnFixtureFactoryTest.java \
	src/test/java/org/open2jam/parsers/OsuFixtureFactoryTest.java; then
	printf 'Selected migration tests contain optional machine-local behavior.\n' >&2
	exit 1
fi

printf 'Java migration golden gate passed.\n'
