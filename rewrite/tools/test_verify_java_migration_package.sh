#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT_DIR"

PACKAGE_VERIFIER="rewrite/tools/verify_java_migration_package.sh"
JAR_VERIFIER="rewrite/tools/JarResourceVerifier.java"
TEMP_BASE_INPUT="${TMPDIR:-/tmp}"
TEMP_BASE=""
TEST_ROOT=""
REAL_JAVA_PATH="$(mise which java)"
REAL_JAR_PATH="$(mise which jar)"

[[ -x "$PACKAGE_VERIFIER" ]] || {
	printf 'Missing executable Java migration package verifier.\n' >&2
	exit 1
}
[[ -f "$JAR_VERIFIER" ]] || {
	printf 'Missing JAR resource verifier source.\n' >&2
	exit 1
}
if [[ -z "$TEMP_BASE_INPUT" || "$TEMP_BASE_INPUT" == "/" \
	|| ! -d "$TEMP_BASE_INPUT" ]] \
	|| ! TEMP_BASE="$(cd "$TEMP_BASE_INPUT" && pwd -P)" \
	|| [[ -z "$TEMP_BASE" || "$TEMP_BASE" == "/" ]]; then
	printf 'Unsafe package test temp root: %s\n' \
		"${TEMP_BASE_INPUT:-<empty>}" >&2
	exit 1
fi

cleanup() {
	if [[ -n "$TEST_ROOT" && "$TEST_ROOT" != "/" \
		&& "$TEST_ROOT" == "$TEMP_BASE"/* ]]; then
		rm -rf "$TEST_ROOT"
	fi
}
trap cleanup EXIT INT TERM HUP

TEST_ROOT="$(mktemp -d "$TEMP_BASE/open2jam-package-verifier.XXXXXX")"
TEST_ROOT="$(cd "$TEST_ROOT" && pwd -P)"

write_mise_stub() {
	local output_path="$1"
	cat >"$output_path" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" != "exec" || "${2:-}" != "--" || "${3:-}" != "java" ]]; then
	exit 2
fi
exec "$REAL_JAVA_PATH" "${@:4}"
EOF
	chmod +x "$output_path"
}

create_fixture() {
	local fixture="$1"
	mkdir -p "$fixture/bin" "$fixture/rewrite/tools" \
		"$fixture/src/resources/fonts" "$fixture/target"
	cp "$PACKAGE_VERIFIER" "$fixture/$PACKAGE_VERIFIER"
	cp "$JAR_VERIFIER" "$fixture/$JAR_VERIFIER"
	cp src/resources/fonts/LiberationSans-Bold.ttf \
		"$fixture/src/resources/fonts/LiberationSans-Bold.ttf"
	cp src/resources/fonts/LICENSE_LIBERATION \
		"$fixture/src/resources/fonts/LICENSE_LIBERATION"
	write_mise_stub "$fixture/bin/mise"
	(
		cd "$fixture"
		"$REAL_JAR_PATH" --create --file target/open2jam-fixture.jar \
			-C src resources/fonts/LiberationSans-Bold.ttf \
			-C src resources/fonts/LICENSE_LIBERATION
	)
}

rebuild_fixture_jar() {
	local fixture="$1"
	rm "$fixture/target/open2jam-fixture.jar"
	(
		cd "$fixture"
		"$REAL_JAR_PATH" --create --file target/open2jam-fixture.jar \
			-C src resources/fonts/LiberationSans-Bold.ttf \
			-C src resources/fonts/LICENSE_LIBERATION
	)
}

run_verifier() {
	local fixture="$1"
	(
		cd "$fixture"
		PATH="$fixture/bin:/usr/bin:/bin" \
			REAL_JAVA_PATH="$REAL_JAVA_PATH" \
			bash "$PACKAGE_VERIFIER"
	)
}

expect_pass() {
	local fixture="$1"
	local output
	if ! output="$(run_verifier "$fixture" 2>&1)"; then
		printf 'Package verifier baseline failed:\n%s\n' "$output" >&2
		exit 1
	fi
}

expect_failure() {
	local description="$1"
	local fixture="$2"
	local expected_text="$3"
	local output
	if output="$(run_verifier "$fixture" 2>&1)"; then
		printf '%s unexpectedly passed.\n' "$description" >&2
		exit 1
	fi
	if [[ "$output" != *"$expected_text"* ]]; then
		printf '%s failed for the wrong reason:\n%s\n' "$description" "$output" >&2
		exit 1
	fi
}

fixture="$TEST_ROOT/baseline"
create_fixture "$fixture"
expect_pass "$fixture"

fixture="$TEST_ROOT/package-font-oversized"
create_fixture "$fixture"
printf 'x' >>"$fixture/src/resources/fonts/LiberationSans-Bold.ttf"
rebuild_fixture_jar "$fixture"
git show HEAD:src/resources/fonts/LiberationSans-Bold.ttf \
	>"$fixture/src/resources/fonts/LiberationSans-Bold.ttf"
expect_failure "oversized packaged font" "$fixture" \
	"JAR resource size mismatch"

fixture="$TEST_ROOT/package-font-undersized"
create_fixture "$fixture"
dd if="$fixture/src/resources/fonts/LiberationSans-Bold.ttf" \
	of="$fixture/src/resources/fonts/LiberationSans-Bold.ttf.next" \
	bs=137051 count=1 2>/dev/null
mv "$fixture/src/resources/fonts/LiberationSans-Bold.ttf.next" \
	"$fixture/src/resources/fonts/LiberationSans-Bold.ttf"
rebuild_fixture_jar "$fixture"
git show HEAD:src/resources/fonts/LiberationSans-Bold.ttf \
	>"$fixture/src/resources/fonts/LiberationSans-Bold.ttf"
expect_failure "undersized packaged font" "$fixture" \
	"JAR resource size mismatch"

fixture="$TEST_ROOT/package-font-corrupt-same-size"
create_fixture "$fixture"
printf 'X' | dd of="$fixture/src/resources/fonts/LiberationSans-Bold.ttf" \
	bs=1 seek=0 conv=notrunc 2>/dev/null
rebuild_fixture_jar "$fixture"
git show HEAD:src/resources/fonts/LiberationSans-Bold.ttf \
	>"$fixture/src/resources/fonts/LiberationSans-Bold.ttf"
expect_failure "same-size corrupt packaged font" "$fixture" \
	"JAR resource digest mismatch"

fixture="$TEST_ROOT/source-license-missing"
create_fixture "$fixture"
rm "$fixture/src/resources/fonts/LICENSE_LIBERATION"
expect_failure "missing source license" "$fixture" "Missing regular bundled font resource"

fixture="$TEST_ROOT/source-license-changed"
create_fixture "$fixture"
printf '\nchanged\n' >>"$fixture/src/resources/fonts/LICENSE_LIBERATION"
expect_failure "changed source license" "$fixture" "Source resource digest mismatch"

fixture="$TEST_ROOT/package-license-missing"
create_fixture "$fixture"
rm "$fixture/target/open2jam-fixture.jar"
(
	cd "$fixture"
	"$REAL_JAR_PATH" --create --file target/open2jam-fixture.jar \
		-C src resources/fonts/LiberationSans-Bold.ttf
)
expect_failure "missing packaged license" "$fixture" "Missing JAR resource"

fixture="$TEST_ROOT/package-missing"
create_fixture "$fixture"
rm "$fixture/target/open2jam-fixture.jar"
expect_failure "missing packaged jar" "$fixture" "Expected exactly one shaded JAR"

fixture="$TEST_ROOT/package-wrong"
create_fixture "$fixture"
rm "$fixture/target/open2jam-fixture.jar"
printf 'not a jar\n' >"$fixture/target/open2jam-wrong.jar"
expect_failure "wrong packaged jar" "$fixture" "ZipException"

fixture="$TEST_ROOT/package-license-changed"
create_fixture "$fixture"
printf '\nchanged\n' >>"$fixture/src/resources/fonts/LICENSE_LIBERATION"
rm "$fixture/target/open2jam-fixture.jar"
(
	cd "$fixture"
	"$REAL_JAR_PATH" --create --file target/open2jam-fixture.jar \
		-C src resources/fonts/LiberationSans-Bold.ttf \
		-C src resources/fonts/LICENSE_LIBERATION
)
git show HEAD:src/resources/fonts/LICENSE_LIBERATION \
	>"$fixture/src/resources/fonts/LICENSE_LIBERATION"
expect_failure "changed packaged license" "$fixture" "JAR resource size mismatch"

fixture="$TEST_ROOT/package-font-changed"
create_fixture "$fixture"
printf '\nchanged\n' >>"$fixture/src/resources/fonts/LiberationSans-Bold.ttf"
rm "$fixture/target/open2jam-fixture.jar"
(
	cd "$fixture"
	"$REAL_JAR_PATH" --create --file target/open2jam-fixture.jar \
		-C src resources/fonts/LiberationSans-Bold.ttf \
		-C src resources/fonts/LICENSE_LIBERATION
)
git show HEAD:src/resources/fonts/LiberationSans-Bold.ttf \
	>"$fixture/src/resources/fonts/LiberationSans-Bold.ttf"
expect_failure "changed packaged font" "$fixture" "JAR resource size mismatch"

fixture="$TEST_ROOT/ambiguous-jars"
create_fixture "$fixture"
cp "$fixture/target/open2jam-fixture.jar" "$fixture/target/open2jam-second.jar"
expect_failure "ambiguous packaged jars" "$fixture" "Expected exactly one shaded JAR"

printf 'Java migration package verifier behavioral contract passed.\n'
