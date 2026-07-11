#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT_DIR"

JAR_VERIFIER="rewrite/tools/JarResourceVerifier.java"
SOURCE_RESOURCES=(
	src/resources/fonts/LiberationSans-Bold.ttf
	src/resources/fonts/LICENSE_LIBERATION
)
EXPECTED_HASHES=(
	361c61b82d575c5c35fd9157fda8b0194bcfcd0d88ea8521a4fb5dd53d33dddc
	3b169ed27ce05b624bc8bf173906286150fc729bad72bda86c98aee7a4631f2f
)

for required_command in grep mise shasum; do
	if ! command -v "$required_command" >/dev/null 2>&1; then
		printf 'Missing package verifier command: %s\n' "$required_command" >&2
		exit 1
	fi
done

if [[ ! -f "$JAR_VERIFIER" || -L "$JAR_VERIFIER" ]]; then
	printf 'Missing regular JAR resource verifier: %s\n' "$JAR_VERIFIER" >&2
	exit 1
fi

for index in 0 1; do
	resource="${SOURCE_RESOURCES[$index]}"
	expected="${EXPECTED_HASHES[$index]}"
	if [[ ! -f "$resource" || -L "$resource" ]]; then
		printf 'Missing regular bundled font resource: %s\n' "$resource" >&2
		exit 1
	fi
	digest_line="$(shasum -a 256 "$resource")"
	digest="${digest_line%% *}"
	if [[ "$digest" != "$expected" ]]; then
		printf 'Source resource digest mismatch for %s: expected %s, got %s\n' \
			"$resource" "$expected" "$digest" >&2
		exit 1
	fi
done

if ! grep -Fq 'SIL OPEN FONT LICENSE Version 1.1 - 26 February 2007' \
	src/resources/fonts/LICENSE_LIBERATION \
	|| ! grep -Fq 'Reserved Font Name Liberation' \
		src/resources/fonts/LICENSE_LIBERATION; then
	printf 'Bundled Liberation license identity mismatch.\n' >&2
	exit 1
fi

shopt -s nullglob
packaged_jars=(target/open2jam-*.jar)
shopt -u nullglob
if [[ "${#packaged_jars[@]}" -ne 1 ]]; then
	printf 'Expected exactly one shaded JAR, found %s.\n' \
		"${#packaged_jars[@]}" >&2
	exit 1
fi

packaged_jar="${packaged_jars[0]}"
if [[ ! -f "$packaged_jar" || -L "$packaged_jar" ]]; then
	printf 'Packaged JAR is not a regular file: %s\n' "$packaged_jar" >&2
	exit 1
fi

mise exec -- java "$JAR_VERIFIER" "$packaged_jar"
printf 'Java migration package gate passed: %s.\n' "$packaged_jar"
