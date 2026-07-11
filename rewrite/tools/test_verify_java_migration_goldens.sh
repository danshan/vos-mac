#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

VERIFIER="rewrite/tools/verify_java_migration_goldens.sh"
[[ -x "$VERIFIER" ]] || { printf 'Missing executable golden verifier.\n' >&2; exit 1; }

for required in \
	MigrationGoldenCorpusGeneratorTest MigrationGoldenCorpusTest \
	OjnFixtureFactoryTest OsuFixtureFactoryTest \
	VosCatalogExporterTest VosGameplayExporterTest VosAudioExporterTest \
	VosRenderMetadataExporterTest; do
	grep -Fq "$required" "$VERIFIER" || {
		printf 'Golden verifier omits %s.\n' "$required" >&2
		exit 1
	}
done

if grep -Eq 'assumeTrue[[:space:]]*\(|/Users/[[:alnum:]_.-]+|Skipping|\|\| true' "$VERIFIER"; then
	printf 'Golden verifier contains an optional or machine-local path.\n' >&2
	exit 1
fi

grep -Fq 'verify-goldens' mise.toml || {
	printf 'mise verify-goldens task is missing.\n' >&2
	exit 1
}

grep -Fq 'bash rewrite/tools/verify_java_migration_goldens.sh' \
	rewrite/tools/verify_vos_godot_initial.sh || {
	printf 'Aggregate initial gate does not invoke the golden verifier.\n' >&2
	exit 1
}

printf 'Java migration golden verifier contract passed.\n'
