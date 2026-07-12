#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT_DIR"

VERIFIER="rewrite/tools/verify_production_soundfont.sh"
RUNNER="rewrite/tools/ProductionSoundFontVerifier.java"
CONTRACT_VERIFIER="rewrite/tools/SoundFontContractVerifier.java"
MANIFEST="rewrite/assets/soundfont/contract.manifest"
PAYLOAD_ROOT="rewrite/assets/soundfont/payload"
ASSET="$PAYLOAD_ROOT/assets/GeneralUser-GS.sf2"
LICENSE="$PAYLOAD_ROOT/licenses/GeneralUser-GS-LICENSE.txt"
APPROVAL="$PAYLOAD_ROOT/approvals/GeneralUser-GS-2.0.3-owner-risk-acceptance.txt"
EXPECTED_ASSET_SIZE=32319396
EXPECTED_ASSET_SHA256="9575028c7a1f589f5770fccc8cff2734566af40cd26ed836944e9a5152688cfe"
EXPECTED_LICENSE_SIZE=2317
EXPECTED_LICENSE_SHA256="7b32efefdf95ce38a043799f0659853ddc00fbaa14d8c50f0aca16b9b8b405be"
EXPECTED_APPROVAL_SIZE=1014
EXPECTED_APPROVAL_SHA256="281e55e71f288e00bc9c85204890256cc4412d5656ef0e8033355106ed744559"
EXPECTED_MANIFEST_SIZE=952
EXPECTED_MANIFEST_SHA256="ba4707b6fae9880f4b719d1da38d2c92aa90c3e6d5f1c7dd4a5cc0fbb358c507"
EXPECTED_SUCCESS="Production SoundFont contract passed: GeneralUser GS 2.0.3 sha256=$EXPECTED_ASSET_SHA256."
TEMP_BASE_INPUT=""
TEMP_BASE=""
TEST_ROOT=""
CREATED_FIXTURE=""
POSITIVE_COUNT=0
NEGATIVE_COUNT=0

if [[ "${TMPDIR+x}" == "x" ]]; then
	TEMP_BASE_INPUT="$TMPDIR"
else
	TEMP_BASE_INPUT="/tmp"
fi

for required_command in \
	awk bash chmod cp find grep mise mktemp mv rg rm shasum tr wc; do
	if ! command -v "$required_command" >/dev/null 2>&1; then
		printf 'Missing production SoundFont test command: %s\n' \
			"$required_command" >&2
		exit 1
	fi
done

[[ -x "$VERIFIER" ]] || {
	printf 'Missing executable production SoundFont verifier.\n' >&2
	exit 1
}
[[ -f "$RUNNER" && ! -L "$RUNNER" ]] || {
	printf 'Missing regular production SoundFont verifier runner.\n' >&2
	exit 1
}
[[ -f "$CONTRACT_VERIFIER" && ! -L "$CONTRACT_VERIFIER" ]] || {
	printf 'Missing regular SoundFont contract verifier.\n' >&2
	exit 1
}
[[ -f "$MANIFEST" && ! -L "$MANIFEST" ]] || {
	printf 'Missing regular production SoundFont manifest.\n' >&2
	exit 1
}
[[ -d "$PAYLOAD_ROOT" && ! -L "$PAYLOAD_ROOT" ]] || {
	printf 'Missing production SoundFont payload root.\n' >&2
	exit 1
}
for payload_file in "$ASSET" "$LICENSE" "$APPROVAL"; do
	[[ -f "$payload_file" && ! -L "$payload_file" ]] || {
		printf 'Missing regular production SoundFont payload: %s\n' \
			"$payload_file" >&2
		exit 1
	}
done

sha256() {
	shasum -a 256 "$1" | awk '{print $1}'
}

file_size() {
	wc -c <"$1" | tr -d '[:space:]'
}

assert_pinned_file() {
	local path="$1"
	local expected_size="$2"
	local expected_sha="$3"
	local actual_size
	local actual_sha
	actual_size="$(file_size "$path")"
	actual_sha="$(sha256 "$path")"
	if [[ "$actual_size" != "$expected_size" || "$actual_sha" != "$expected_sha" ]]; then
		printf 'Pinned production SoundFont input drifted: %s\n' "$path" >&2
		printf 'Expected size/hash: %s %s\n' "$expected_size" "$expected_sha" >&2
		printf 'Actual size/hash: %s %s\n' "$actual_size" "$actual_sha" >&2
		exit 1
	fi
}

assert_pinned_file "$ASSET" "$EXPECTED_ASSET_SIZE" "$EXPECTED_ASSET_SHA256"
assert_pinned_file "$LICENSE" "$EXPECTED_LICENSE_SIZE" "$EXPECTED_LICENSE_SHA256"
assert_pinned_file "$APPROVAL" "$EXPECTED_APPROVAL_SIZE" "$EXPECTED_APPROVAL_SHA256"
assert_pinned_file "$MANIFEST" "$EXPECTED_MANIFEST_SIZE" "$EXPECTED_MANIFEST_SHA256"

for approval_line in \
	'owner: Honghao' \
	'accepted-on: 2026-07-12' \
	'decision: GeneralUser GS 2.0.3 is accepted as the production SoundFont.' \
	'acknowledged-risk: The upstream license discloses that some sample origins cannot be established with complete certainty.' \
	'legal-certainty: This record does not claim complete provenance or legal certainty.' \
	'replacement-policy: Any candidate byte, version, source, or license change requires a new owner acceptance.' \
	'cache-policy: Any accepted replacement requires full invalidation of SoundFont-dependent caches.'; do
	if ! grep -Fx -- "$approval_line" "$APPROVAL" >/dev/null; then
		printf 'Owner risk acceptance omits required statement: %s\n' \
			"$approval_line" >&2
		exit 1
	fi
done

if rg -n 'curl|wget|https?://' "$VERIFIER" >/dev/null; then
	printf 'Production SoundFont verifier must remain offline.\n' >&2
	exit 1
fi
if ! grep -Fx '        SoundFontContractVerifier.checkCompletedSnapshot(snapshot);' \
	"$RUNNER" >/dev/null; then
	printf 'Production runner omits the completed-snapshot audit.\n' >&2
	exit 1
fi

if [[ -z "$TEMP_BASE_INPUT" || "$TEMP_BASE_INPUT" == "/" \
	|| ! -d "$TEMP_BASE_INPUT" ]]; then
	printf 'Unsafe production SoundFont test TMPDIR: %s\n' \
		"${TEMP_BASE_INPUT:-<empty>}" >&2
	exit 1
fi
if ! TEMP_BASE="$(cd "$TEMP_BASE_INPUT" 2>/dev/null && pwd -P)" \
	|| [[ -z "$TEMP_BASE" || "$TEMP_BASE" == "/" ]]; then
	printf 'Unable to resolve production SoundFont test TMPDIR.\n' >&2
	exit 1
fi
TEST_ROOT="$(mktemp -d "$TEMP_BASE/open2jam-production-soundfont-test.XXXXXX")"
TEST_ROOT="$(cd "$TEST_ROOT" && pwd -P)"

cleanup() {
	if [[ -z "$TEST_ROOT" || "$TEST_ROOT" == "/" \
		|| ! -d "$TEST_ROOT" || -L "$TEST_ROOT" ]]; then
		printf 'Refusing unsafe production SoundFont test cleanup: %s\n' \
			"${TEST_ROOT:-<empty>}" >&2
		return 1
	fi
	case "$TEST_ROOT" in
		"$TEMP_BASE"/open2jam-production-soundfont-test.*) ;;
		*)
			printf 'Refusing out-of-scope production SoundFont test cleanup: %s\n' \
				"$TEST_ROOT" >&2
			return 1
			;;
	esac
	rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

unsafe_probe_bin="$TEST_ROOT/unsafe-probe-bin"
unsafe_mktemp_marker="$TEST_ROOT/unsafe-mktemp-invoked"
mkdir -p "$unsafe_probe_bin"
printf '%s\n' \
	'#!/usr/bin/env bash' \
	'set -euo pipefail' \
	': "${SOUNDFONT_UNSAFE_MKTEMP_MARKER:?}"' \
	'printf "invoked\n" >"$SOUNDFONT_UNSAFE_MKTEMP_MARKER"' \
	'exit 73' \
	>"$unsafe_probe_bin/mktemp"
chmod +x "$unsafe_probe_bin/mktemp"

expect_unsafe_tmpdir_rejected() {
	local description="$1"
	local unsafe_tmpdir="$2"
	local expected_text="$3"
	local output
	rm -f "$unsafe_mktemp_marker"
	if output="$(PATH="$unsafe_probe_bin:$PATH" \
		SOUNDFONT_UNSAFE_MKTEMP_MARKER="$unsafe_mktemp_marker" \
		TMPDIR="$unsafe_tmpdir" bash "$VERIFIER" 2>&1)"; then
		printf '%s production SoundFont TMPDIR unexpectedly passed.\n' \
			"$description" >&2
		exit 1
	fi
	if [[ "$output" != *"$expected_text"* ]]; then
		printf '%s TMPDIR failed for the wrong reason:\n%s\n' \
			"$description" "$output" >&2
		exit 1
	fi
	if [[ -e "$unsafe_mktemp_marker" ]]; then
		printf '%s TMPDIR reached mktemp before rejection.\n' \
			"$description" >&2
		exit 1
	fi
	NEGATIVE_COUNT=$((NEGATIVE_COUNT + 1))
}

expect_unsafe_tmpdir_rejected "empty" "" \
	"Unsafe production SoundFont TMPDIR: <empty>"
expect_unsafe_tmpdir_rejected "root" "/" \
	"Unsafe production SoundFont TMPDIR: /"
expect_unsafe_tmpdir_rejected "nonexistent" "$TEST_ROOT/does-not-exist" \
	"Unsafe production SoundFont TMPDIR: $TEST_ROOT/does-not-exist"

assert_no_wrapper_residue() {
	local temp_root="$1"
	local residue
	residue="$(find "$temp_root" -mindepth 1 -maxdepth 1 \
		-name 'open2jam-production-soundfont.*' -print -quit)"
	if [[ -n "$residue" ]]; then
		printf 'Production SoundFont wrapper left unexpected residue: %s\n' \
			"$residue" >&2
		exit 1
	fi
}

assert_success_location() {
	local output="$1"
	local runtime_tmp="$2"
	local location_line
	local location
	location_line="$(printf '%s\n' "$output" | \
		grep -F 'Production SoundFont completed snapshot audit passed; location=' \
		| grep -v '^$')"
	location="${location_line#*location=}"
	location="${location%.}"
	case "$location" in
		"$runtime_tmp"/open2jam-production-soundfont.*/verified) ;;
		*)
			printf 'Production SoundFont snapshot ignored nested TMPDIR: %s\n' \
				"${location:-<missing>}" >&2
			exit 1
			;;
	esac
	if [[ -e "$location" ]]; then
		printf 'Completed production SoundFont snapshot was not cleaned: %s\n' \
			"$location" >&2
		exit 1
	fi
}

run_wrapper() {
	local fixture_root="$1"
	local runtime_tmp="$fixture_root/runtime-tmp/nested path"
	mkdir -p "$runtime_tmp"
	(
		cd "$fixture_root"
		TMPDIR="$runtime_tmp" bash rewrite/tools/verify_production_soundfont.sh
	)
}

real_runtime="$TEST_ROOT/real-runtime/nested path"
mkdir -p "$real_runtime"
if ! real_output="$(TMPDIR="$real_runtime" bash "$VERIFIER" 2>&1)"; then
	printf 'Real production SoundFont contract unexpectedly failed:\n%s\n' \
		"$real_output" >&2
	exit 1
fi
if [[ "$real_output" != *"$EXPECTED_SUCCESS"* ]]; then
	printf 'Real production SoundFont success identity is not exact:\n%s\n' \
		"$real_output" >&2
	exit 1
fi
assert_success_location "$real_output" "$real_runtime"
assert_no_wrapper_residue "$real_runtime"
POSITIVE_COUNT=$((POSITIVE_COUNT + 1))

write_fixture_manifest() {
	local fixture_root="$1"
	local payload="$fixture_root/rewrite/assets/soundfont/payload"
	local asset_sha
	local license_sha
	local approval_sha
	local asset_size
	local license_size
	local approval_size
	asset_sha="$(sha256 "$payload/assets/GeneralUser-GS.sf2")"
	license_sha="$(sha256 "$payload/licenses/GeneralUser-GS-LICENSE.txt")"
	approval_sha="$(sha256 "$payload/approvals/GeneralUser-GS-2.0.3-owner-risk-acceptance.txt")"
	asset_size="$(file_size "$payload/assets/GeneralUser-GS.sf2")"
	license_size="$(file_size "$payload/licenses/GeneralUser-GS-LICENSE.txt")"
	approval_size="$(file_size "$payload/approvals/GeneralUser-GS-2.0.3-owner-risk-acceptance.txt")"
	printf '%s\n' \
		'soundfont-contract-v1' \
		'asset.path=assets/GeneralUser-GS.sf2' \
		'asset.name=GeneralUser GS' \
		'asset.version=2.0.3' \
		"asset.size=$asset_size" \
		"asset.sha256=$asset_sha" \
		'source.url=https://example.invalid/source/684543d5e5efaef08d02be50dcda8d552478fa60/GeneralUser-GS.sf2' \
		'source.commit=684543d5e5efaef08d02be50dcda8d552478fa60' \
		'license.path=licenses/GeneralUser-GS-LICENSE.txt' \
		"license.size=$license_size" \
		"license.sha256=$license_sha" \
		'license.url=https://example.invalid/LICENSE.txt' \
		'approval.path=approvals/GeneralUser-GS-2.0.3-owner-risk-acceptance.txt' \
		"approval.size=$approval_size" \
		"approval.sha256=$approval_sha" \
		"approval.id=owner-risk-acceptance:sha256:$approval_sha" \
		>"$fixture_root/rewrite/assets/soundfont/contract.manifest"
}

pin_fixture_manifest() {
	local fixture_root="$1"
	local wrapper="$fixture_root/rewrite/tools/verify_production_soundfont.sh"
	local rewritten="$fixture_root/rewrite/tools/.verify-production-soundfont.rewritten"
	local manifest_sha
	manifest_sha="$(sha256 "$fixture_root/rewrite/assets/soundfont/contract.manifest")"
	awk -v sha="$manifest_sha" '
		/^EXPECTED_MANIFEST_SHA256=/ {
			print "EXPECTED_MANIFEST_SHA256=\"" sha "\""
			next
		}
		{ print }
	' "$wrapper" >"$rewritten"
	mv "$rewritten" "$wrapper"
	chmod +x "$wrapper"
}

create_fixture() {
	local fixture_root
	fixture_root="$(mktemp -d "$TEST_ROOT/fixture.XXXXXX")"
	mkdir -p \
		"$fixture_root/rewrite/tools" \
		"$fixture_root/rewrite/assets/soundfont/payload/assets" \
		"$fixture_root/rewrite/assets/soundfont/payload/licenses" \
		"$fixture_root/rewrite/assets/soundfont/payload/approvals"
	cp "$VERIFIER" "$RUNNER" "$CONTRACT_VERIFIER" \
		"$fixture_root/rewrite/tools/"
	printf 'fixture-soundfont-bytes\n' \
		>"$fixture_root/rewrite/assets/soundfont/payload/assets/GeneralUser-GS.sf2"
	printf 'fixture-license-text\n' \
		>"$fixture_root/rewrite/assets/soundfont/payload/licenses/GeneralUser-GS-LICENSE.txt"
	printf 'fixture-owner-risk-acceptance-v1\n' \
		>"$fixture_root/rewrite/assets/soundfont/payload/approvals/GeneralUser-GS-2.0.3-owner-risk-acceptance.txt"
	write_fixture_manifest "$fixture_root"
	pin_fixture_manifest "$fixture_root"
	CREATED_FIXTURE="$fixture_root"
}

expect_fixture_failure() {
	local description="$1"
	local fixture_root="$2"
	local expected_text="$3"
	local output
	if output="$(run_wrapper "$fixture_root" 2>&1)"; then
		printf '%s unexpectedly passed.\n' "$description" >&2
		exit 1
	fi
	if [[ "$output" != *"$expected_text"* ]]; then
		printf '%s failed for the wrong reason:\n%s\n' \
			"$description" "$output" >&2
		exit 1
	fi
	assert_no_wrapper_residue "$fixture_root/runtime-tmp/nested path"
	NEGATIVE_COUNT=$((NEGATIVE_COUNT + 1))
}

create_fixture
fixture="$CREATED_FIXTURE"
if ! fixture_output="$(run_wrapper "$fixture" 2>&1)"; then
	printf 'Tiny production SoundFont fixture unexpectedly failed:\n%s\n' \
		"$fixture_output" >&2
	exit 1
fi
if [[ "$fixture_output" != *"$EXPECTED_SUCCESS"* ]]; then
	printf 'Tiny fixture success identity is not exact:\n%s\n' \
		"$fixture_output" >&2
	exit 1
fi
assert_success_location "$fixture_output" "$fixture/runtime-tmp/nested path"
assert_no_wrapper_residue "$fixture/runtime-tmp/nested path"
POSITIVE_COUNT=$((POSITIVE_COUNT + 1))

create_fixture
fixture="$CREATED_FIXTURE"
rm "$fixture/rewrite/assets/soundfont/payload/assets/GeneralUser-GS.sf2"
expect_fixture_failure "missing SoundFont asset" "$fixture" \
	"payload tree does not match the exact declared file set"

create_fixture
fixture="$CREATED_FIXTURE"
printf 'Fixture-soundfont-bytes\n' \
	>"$fixture/rewrite/assets/soundfont/payload/assets/GeneralUser-GS.sf2"
expect_fixture_failure "changed SoundFont asset bytes" "$fixture" \
	"SHA-256 mismatch for assets/GeneralUser-GS.sf2"

create_fixture
fixture="$CREATED_FIXTURE"
printf 'Fixture-license-text\n' \
	>"$fixture/rewrite/assets/soundfont/payload/licenses/GeneralUser-GS-LICENSE.txt"
expect_fixture_failure "changed SoundFont license bytes" "$fixture" \
	"SHA-256 mismatch for licenses/GeneralUser-GS-LICENSE.txt"

create_fixture
fixture="$CREATED_FIXTURE"
printf 'Fixture-owner-risk-acceptance-v1\n' \
	>"$fixture/rewrite/assets/soundfont/payload/approvals/GeneralUser-GS-2.0.3-owner-risk-acceptance.txt"
expect_fixture_failure "changed owner approval bytes" "$fixture" \
	"SHA-256 mismatch for approvals/GeneralUser-GS-2.0.3-owner-risk-acceptance.txt"

create_fixture
fixture="$CREATED_FIXTURE"
printf '\n' >>"$fixture/rewrite/assets/soundfont/contract.manifest"
expect_fixture_failure "changed production SoundFont manifest" "$fixture" \
	"Production SoundFont manifest SHA-256 mismatch"

create_fixture
fixture="$CREATED_FIXTURE"
rm "$fixture/rewrite/assets/soundfont/contract.manifest"
expect_fixture_failure "missing production SoundFont manifest" "$fixture" \
	"Missing regular production SoundFont contract input"

write_retention_probe_runner() {
	local fixture_root="$1"
	cat >"$fixture_root/rewrite/tools/ProductionSoundFontVerifier.java" <<'EOF'
import java.nio.file.Path;

public final class ProductionSoundFontVerifier {
    private ProductionSoundFontVerifier() {
    }

    public static void main(String[] args) throws Exception {
        Path manifest = Path.of(args[0]).toAbsolutePath().normalize();
        Path payloadRoot = Path.of(args[1]).toAbsolutePath().normalize();
        Path snapshot = Path.of(args[2]).toAbsolutePath().normalize();
        SoundFontContractVerifier.verify(
                manifest,
                payloadRoot,
                snapshot,
                new SoundFontContractVerifier.VerificationObserver() {
                    @Override
                    public void beforeMarkerWrite() {
                        throw new IllegalStateException("retention-probe-before-marker");
                    }
                });
    }
}
EOF
}

create_fixture
fixture="$CREATED_FIXTURE"
write_retention_probe_runner "$fixture"
retention_tmp="$fixture/runtime-tmp/nested path"
if retention_output="$(run_wrapper "$fixture" 2>&1)"; then
	printf 'Post-reservation retention probe unexpectedly passed.\n' >&2
	exit 1
fi
if [[ "$retention_output" != *"retention-probe-before-marker"* ]]; then
	printf 'Post-reservation retention probe failed for the wrong reason:\n%s\n' \
		"$retention_output" >&2
	exit 1
fi
retained_roots="$(find "$retention_tmp" -mindepth 1 -maxdepth 1 -type d \
	-name 'open2jam-production-soundfont.*' -print)"
retained_count="$(printf '%s\n' "$retained_roots" | \
	awk 'NF { count++ } END { print count + 0 }')"
if [[ "$retained_count" != "1" ]]; then
	printf 'Post-reservation failure retained %s workspaces, expected one:\n%s\n' \
		"$retained_count" "$retained_roots" >&2
	exit 1
fi
retained_root="$retained_roots"
retained_snapshot="$retained_root/verified"
case "$retained_snapshot" in
	"$retention_tmp"/open2jam-production-soundfont.*/verified) ;;
	*)
		printf 'Retained snapshot escaped nested TMPDIR: %s\n' \
			"$retained_snapshot" >&2
		exit 1
		;;
esac
if [[ ! -d "$retained_snapshot" \
	|| -e "$retained_snapshot/snapshot.marker" ]]; then
	printf 'Retained snapshot is absent or incorrectly completed: %s\n' \
		"$retained_snapshot" >&2
	exit 1
fi
if [[ "$retention_output" != *"incomplete snapshot retained: $retained_snapshot"* ]]; then
	printf 'Retained snapshot path was not reported exactly:\n%s\n' \
		"$retention_output" >&2
	exit 1
fi
rm -rf -- "$retained_root"
assert_no_wrapper_residue "$retention_tmp"
NEGATIVE_COUNT=$((NEGATIVE_COUNT + 1))

printf 'Production SoundFont verifier behavioral contract passed: %d positive, %d negative.\n' \
	"$POSITIVE_COUNT" "$NEGATIVE_COUNT"
