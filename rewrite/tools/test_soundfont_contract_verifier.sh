#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT_DIR"

VERIFIER_SOURCE="rewrite/tools/SoundFontContractVerifier.java"
TEMP_BASE_INPUT="${TMPDIR:-/tmp}"
TEMP_BASE=""
TEST_ROOT=""
CLASSES=""
POSITIVE_COUNT=0
NEGATIVE_COUNT=0

if [[ ! -f "$VERIFIER_SOURCE" || -L "$VERIFIER_SOURCE" ]]; then
	printf 'Missing regular SoundFont contract verifier source: %s\n' \
		"$VERIFIER_SOURCE" >&2
	exit 1
fi
if [[ -z "$TEMP_BASE_INPUT" || "$TEMP_BASE_INPUT" == "/" \
	|| ! -d "$TEMP_BASE_INPUT" ]] \
	|| ! TEMP_BASE="$(cd "$TEMP_BASE_INPUT" && pwd -P)" \
	|| [[ -z "$TEMP_BASE" || "$TEMP_BASE" == "/" ]]; then
	printf 'Unsafe SoundFont verifier test temp root: %s\n' \
		"${TEMP_BASE_INPUT:-<empty>}" >&2
	exit 1
fi

cleanup() {
	if [[ -n "$TEST_ROOT" && "$TEST_ROOT" != "/" \
		&& "$TEST_ROOT" == "$TEMP_BASE"/* ]]; then
		rm -rf "$TEST_ROOT"
	fi
}
trap cleanup EXIT
trap 'cleanup; exit 129' HUP
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

TEST_ROOT="$(mktemp -d "$TEMP_BASE/open2jam-soundfont-contract.XXXXXX")"
TEST_ROOT="$(cd "$TEST_ROOT" && pwd -P)"
CLASSES="$TEST_ROOT/classes"
mkdir -p "$CLASSES"
mise exec -- javac -Xlint:all -d "$CLASSES" "$VERIFIER_SOURCE"

sha256() {
	shasum -a 256 "$1" | awk '{print $1}'
}

file_size() {
	wc -c <"$1" | tr -d '[:space:]'
}

write_manifest() {
	local fixture="$1"
	local asset="$fixture/payload/assets/fixture.sf2"
	local license="$fixture/payload/licenses/LICENSE.txt"
	local approval="$fixture/payload/approvals/redistribution.txt"
	local commit="0123456789abcdef0123456789abcdef01234567"
	printf '%s\n' \
		'soundfont-contract-v1' \
		'asset.path=assets/fixture.sf2' \
		'asset.name=Hermetic Fixture SoundFont' \
		'asset.version=1.2.3' \
		"asset.size=$(file_size "$asset")" \
		"asset.sha256=$(sha256 "$asset")" \
		"source.url=https://example.invalid/releases/$commit/fixture.sf2" \
		"source.commit=$commit" \
		'license.path=licenses/LICENSE.txt' \
		"license.size=$(file_size "$license")" \
		"license.sha256=$(sha256 "$license")" \
		'https://example.invalid/licenses/fixture-1.2.3.txt' \
		'approval.path=approvals/redistribution.txt' \
		"approval.size=$(file_size "$approval")" \
		"approval.sha256=$(sha256 "$approval")" \
		'approval.id=LEGAL-2026-0001' \
		| sed '12s#^#license.url=#' >"$fixture/contract.manifest"
}

create_fixture() {
	local name="$1"
	local fixture="$TEST_ROOT/$name"
	mkdir -p "$fixture/payload/assets" "$fixture/payload/licenses" \
		"$fixture/payload/approvals"
	printf 'fixture-soundfont-bytes\n' >"$fixture/payload/assets/fixture.sf2"
	printf 'Fixture license terms.\n' >"$fixture/payload/licenses/LICENSE.txt"
	printf 'Approved for redistribution in verifier tests.\n' \
		>"$fixture/payload/approvals/redistribution.txt"
	write_manifest "$fixture"
	printf '%s\n' "$fixture"
}

run_verifier() {
	local fixture="$1"
	mise exec -- java -cp "$CLASSES" SoundFontContractVerifier \
		"$fixture/contract.manifest" "$fixture/payload"
}

expect_pass() {
	local description="$1"
	local fixture="$2"
	local output
	if ! output="$(run_verifier "$fixture" 2>&1)"; then
		printf '%s failed:\n%s\n' "$description" "$output" >&2
		exit 1
	fi
	if [[ "$output" != *"SoundFont contract verified:"* ]]; then
		printf '%s produced unexpected output:\n%s\n' "$description" "$output" >&2
		exit 1
	fi
	POSITIVE_COUNT=$((POSITIVE_COUNT + 1))
}

expect_failure() {
	local description="$1"
	local fixture="$2"
	local output
	if output="$(run_verifier "$fixture" 2>&1)"; then
		printf '%s unexpectedly passed:\n%s\n' "$description" "$output" >&2
		exit 1
	fi
	if [[ "$output" != *"SoundFont contract verification failed:"* ]]; then
		printf '%s failed for the wrong reason:\n%s\n' "$description" "$output" >&2
		exit 1
	fi
	NEGATIVE_COUNT=$((NEGATIVE_COUNT + 1))
}

expect_failure_with_text() {
	local description="$1"
	local fixture="$2"
	local expected_text="$3"
	local output
	if output="$(run_verifier "$fixture" 2>&1)"; then
		printf '%s unexpectedly passed:\n%s\n' "$description" "$output" >&2
		exit 1
	fi
	if [[ "$output" != *"SoundFont contract verification failed:"* \
		|| "$output" != *"$expected_text"* ]]; then
		printf '%s failed for the wrong reason:\n%s\n' "$description" "$output" >&2
		exit 1
	fi
	NEGATIVE_COUNT=$((NEGATIVE_COUNT + 1))
}

replace_line() {
	local fixture="$1"
	local key="$2"
	local replacement="$3"
	awk -v key="$key" -v replacement="$replacement" \
		'index($0, key "=") == 1 { print replacement; next } { print }' \
		"$fixture/contract.manifest" >"$fixture/contract.manifest.next"
	mv "$fixture/contract.manifest.next" "$fixture/contract.manifest"
}

fixture="$(create_fixture baseline)"
expect_pass "canonical contract" "$fixture"

fixture="$(create_fixture bad-header)"
sed '1s/v1/v2/' "$fixture/contract.manifest" >"$fixture/next"
mv "$fixture/next" "$fixture/contract.manifest"
expect_failure "wrong manifest header" "$fixture"

fixture="$(create_fixture missing-key)"
sed '/^license.url=/d' "$fixture/contract.manifest" >"$fixture/next"
mv "$fixture/next" "$fixture/contract.manifest"
expect_failure "missing manifest key" "$fixture"

fixture="$(create_fixture unknown-key)"
awk 'NR == 2 { print "unknown.key=value" } { print }' \
	"$fixture/contract.manifest" >"$fixture/next"
mv "$fixture/next" "$fixture/contract.manifest"
expect_failure "unknown manifest key" "$fixture"

fixture="$(create_fixture duplicate-key)"
sed '2p' "$fixture/contract.manifest" >"$fixture/next"
mv "$fixture/next" "$fixture/contract.manifest"
expect_failure "duplicate manifest key" "$fixture"

fixture="$(create_fixture wrong-order)"
awk 'NR == 3 { third=$0; next } NR == 4 { print; print third; next } { print }' \
	"$fixture/contract.manifest" >"$fixture/next"
mv "$fixture/next" "$fixture/contract.manifest"
expect_failure "out-of-order manifest key" "$fixture"

fixture="$(create_fixture crlf-manifest)"
awk '{printf "%s\r\n", $0}' "$fixture/contract.manifest" >"$fixture/next"
mv "$fixture/next" "$fixture/contract.manifest"
expect_failure "CRLF manifest" "$fixture"

fixture="$(create_fixture missing-final-lf)"
perl -0pe 's/\n\z//' "$fixture/contract.manifest" >"$fixture/next"
mv "$fixture/next" "$fixture/contract.manifest"
expect_failure "manifest without final LF" "$fixture"

fixture="$(create_fixture extra-blank-line)"
printf '\n' >>"$fixture/contract.manifest"
expect_failure "manifest with extra blank line" "$fixture"

fixture="$(create_fixture oversized-manifest)"
dd if=/dev/zero bs=65536 count=1 2>/dev/null \
	| tr '\000' 'x' >>"$fixture/contract.manifest"
expect_failure "manifest above hard cap" "$fixture"

fixture="$(create_fixture invalid-utf8-manifest)"
printf '\377' >>"$fixture/contract.manifest"
expect_failure "non-UTF-8 manifest" "$fixture"

fixture="$(create_fixture bad-name)"
replace_line "$fixture" asset.name 'asset.name= Fixture'
expect_failure "non-canonical asset name" "$fixture"

fixture="$(create_fixture bad-version)"
replace_line "$fixture" asset.version 'asset.version=1 2'
expect_failure "non-canonical asset version" "$fixture"

fixture="$(create_fixture zero-size)"
replace_line "$fixture" asset.size 'asset.size=0'
expect_failure "zero asset size" "$fixture"

fixture="$(create_fixture leading-zero-size)"
replace_line "$fixture" asset.size 'asset.size=023'
expect_failure "leading-zero asset size" "$fixture"

fixture="$(create_fixture overflow-size)"
replace_line "$fixture" asset.size 'asset.size=9223372036854775808'
expect_failure "overflowing asset size" "$fixture"

fixture="$(create_fixture asset-cap)"
replace_line "$fixture" asset.size 'asset.size=536870913'
expect_failure "asset above hard cap" "$fixture"

fixture="$(create_fixture license-cap)"
replace_line "$fixture" license.size 'license.size=1048577'
expect_failure "license above hard cap" "$fixture"

fixture="$(create_fixture approval-cap)"
replace_line "$fixture" approval.size 'approval.size=262145'
expect_failure "approval above hard cap" "$fixture"

fixture="$(create_fixture uppercase-hash)"
replace_line "$fixture" asset.sha256 \
	'asset.sha256=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
expect_failure "uppercase SHA-256" "$fixture"

fixture="$(create_fixture wrong-hash)"
replace_line "$fixture" asset.sha256 \
	'asset.sha256=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
expect_failure "wrong asset SHA-256" "$fixture"

fixture="$(create_fixture wrong-size)"
replace_line "$fixture" asset.size 'asset.size=1'
expect_failure "wrong asset size" "$fixture"

fixture="$(create_fixture extra-file)"
printf 'extra\n' >"$fixture/payload/extra.txt"
expect_failure "extra payload file" "$fixture"

fixture="$(create_fixture extra-directory)"
mkdir "$fixture/payload/unused"
expect_failure "extra payload directory" "$fixture"

fixture="$(create_fixture missing-file)"
rm "$fixture/payload/licenses/LICENSE.txt"
expect_failure "missing declared file" "$fixture"

for entry in \
	'traversal|asset.path=../fixture.sf2' \
	'absolute|asset.path=/tmp/fixture.sf2' \
	'backslash|asset.path=assets\\fixture.sf2' \
	'dot-component|asset.path=assets/./fixture.sf2' \
	'empty-component|asset.path=assets//fixture.sf2'; do
	description="${entry%%|*}"
	replacement="${entry#*|}"
	fixture="$(create_fixture "path-$description")"
	replace_line "$fixture" asset.path "$replacement"
	expect_failure "$description path" "$fixture"
done

fixture="$(create_fixture duplicate-path)"
replace_line "$fixture" license.path 'license.path=assets/fixture.sf2'
expect_failure "duplicate declared path" "$fixture"

fixture="$(create_fixture case-collision)"
mv "$fixture/payload/licenses/LICENSE.txt" \
	"$fixture/payload/assets/FIXTURE.SF2"
replace_line "$fixture" license.path 'license.path=assets/FIXTURE.SF2'
expect_failure "case-colliding declared paths" "$fixture"

fixture="$(create_fixture ancestor-case-collision)"
mkdir -p "$fixture/payload/ASSETS"
mv "$fixture/payload/licenses/LICENSE.txt" \
	"$fixture/payload/ASSETS/LICENSE.txt"
rmdir "$fixture/payload/licenses"
replace_line "$fixture" license.path 'license.path=ASSETS/LICENSE.txt'
expect_failure_with_text "case-colliding ancestor paths" "$fixture" \
	"path components must not collide by case"

fixture="$(create_fixture symlink-file)"
cp "$fixture/payload/assets/fixture.sf2" "$fixture/real.sf2"
rm "$fixture/payload/assets/fixture.sf2"
ln -s "$fixture/real.sf2" "$fixture/payload/assets/fixture.sf2"
expect_failure "symlink payload file" "$fixture"

fixture="$(create_fixture symlink-ancestor)"
mv "$fixture/payload/assets" "$fixture/real-assets"
ln -s "$fixture/real-assets" "$fixture/payload/assets"
expect_failure "symlink payload ancestor" "$fixture"

fixture="$(create_fixture special-file)"
rm "$fixture/payload/assets/fixture.sf2"
mkfifo "$fixture/payload/assets/fixture.sf2"
expect_failure "special payload file" "$fixture"

fixture="$(create_fixture source-http)"
replace_line "$fixture" source.url \
	'source.url=http://example.invalid/releases/0123456789abcdef0123456789abcdef01234567/fixture.sf2'
expect_failure "non-HTTPS source URL" "$fixture"

fixture="$(create_fixture source-query)"
replace_line "$fixture" source.url \
	'source.url=https://example.invalid/releases/0123456789abcdef0123456789abcdef01234567/fixture.sf2?download=1'
expect_failure "source URL query" "$fixture"

fixture="$(create_fixture source-fragment)"
replace_line "$fixture" source.url \
	'source.url=https://example.invalid/releases/0123456789abcdef0123456789abcdef01234567/fixture.sf2#asset'
expect_failure "source URL fragment" "$fixture"

fixture="$(create_fixture source-userinfo)"
replace_line "$fixture" source.url \
	'source.url=https://user@example.invalid/releases/0123456789abcdef0123456789abcdef01234567/fixture.sf2'
expect_failure "source URL userinfo" "$fixture"

fixture="$(create_fixture uppercase-source-host)"
replace_line "$fixture" source.url \
	'source.url=https://EXAMPLE.invalid/releases/0123456789abcdef0123456789abcdef01234567/fixture.sf2'
expect_failure "uppercase source URL host" "$fixture"

fixture="$(create_fixture commit-mismatch)"
replace_line "$fixture" source.commit \
	'source.commit=89abcdef0123456789abcdef0123456789abcdef'
expect_failure "source commit mismatch" "$fixture"

fixture="$(create_fixture commit-substring)"
replace_line "$fixture" source.url \
	'source.url=https://example.invalid/releases/prefix-0123456789abcdef0123456789abcdef01234567/fixture.sf2'
expect_failure "source commit substring" "$fixture"

fixture="$(create_fixture encoded-source-alias)"
replace_line "$fixture" source.url \
	'source.url=https://example.invalid/releases/0123456789abcdef0123456789abcdef01234567/%2e%2e/fixture.sf2'
expect_failure "percent-encoded source URL alias" "$fixture"

fixture="$(create_fixture malformed-commit)"
replace_line "$fixture" source.commit 'source.commit=01234567'
expect_failure "malformed source commit" "$fixture"

fixture="$(create_fixture license-http)"
replace_line "$fixture" license.url \
	'license.url=http://example.invalid/licenses/fixture-1.2.3.txt'
expect_failure "non-HTTPS license URL" "$fixture"

fixture="$(create_fixture license-query)"
replace_line "$fixture" license.url \
	'license.url=https://example.invalid/licenses/fixture-1.2.3.txt?latest=1'
expect_failure "mutable license URL" "$fixture"

fixture="$(create_fixture missing-approval)"
rm "$fixture/payload/approvals/redistribution.txt"
expect_failure "missing approval artifact" "$fixture"

for placeholder_variant in \
	PLACEHOLDER1 \
	1PLACEHOLDER \
	PLACE1HOLDER \
	TESTONLY \
	PLACEHOLDERABC \
	DUMMYFINAL \
	EXAMPLER \
	LEGAL-PLACEHOLDER1-2026 \
	LEGAL-2026-1PENDING; do
	fixture="$(create_fixture "approval-variant-$placeholder_variant")"
	replace_line "$fixture" approval.id "approval.id=$placeholder_variant"
	expect_failure_with_text "placeholder approval id variant $placeholder_variant" \
		"$fixture" "approval.id contains a placeholder token"
done

for placeholder in TBD TODO PENDING PLACEHOLDER UNKNOWN NONE UNAPPROVED TEST-ONLY; do
	fixture="$(create_fixture "approval-$placeholder")"
	replace_line "$fixture" approval.id "approval.id=$placeholder"
	expect_failure "placeholder approval id $placeholder" "$fixture"
done

for legitimate_id in \
	LEGAL-CONTEST-2026 \
	LEGAL-APPENDING-2026; do
	fixture="$(create_fixture "approval-legitimate-$legitimate_id")"
	replace_line "$fixture" approval.id "approval.id=$legitimate_id"
	expect_pass "non-placeholder approval id $legitimate_id" "$fixture"
done

fixture="$(create_fixture duplicate-approval-token)"
replace_line "$fixture" approval.id 'approval.id=LEGAL-LEGAL-0001'
expect_failure "duplicate approval id token" "$fixture"

fixture="$(create_fixture wrong-approval-hash)"
replace_line "$fixture" approval.sha256 \
	'approval.sha256=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
expect_failure "wrong approval SHA-256" "$fixture"

fixture="$(create_fixture manifest-symlink)"
mv "$fixture/contract.manifest" "$fixture/real.manifest"
ln -s "$fixture/real.manifest" "$fixture/contract.manifest"
expect_failure "symlink manifest" "$fixture"

fixture="$(create_fixture root-symlink)"
mv "$fixture/payload" "$fixture/real-payload"
ln -s "$fixture/real-payload" "$fixture/payload"
expect_failure "symlink payload root" "$fixture"

fixture="$(create_fixture manifest-overlap)"
mv "$fixture/contract.manifest" "$fixture/payload/contract.manifest"
if overlap_output="$(mise exec -- java -cp "$CLASSES" SoundFontContractVerifier \
	"$fixture/payload/contract.manifest" "$fixture/payload" 2>&1)"; then
	printf 'manifest and payload overlap unexpectedly passed:\n%s\n' \
		"$overlap_output" >&2
	exit 1
fi
if [[ "$overlap_output" != *"SoundFont contract verification failed:"* ]]; then
	printf 'manifest and payload overlap failed for the wrong reason:\n%s\n' \
		"$overlap_output" >&2
	exit 1
fi
NEGATIVE_COUNT=$((NEGATIVE_COUNT + 1))

RACE_SOURCE="$TEST_ROOT/SoundFontContractVerifierRaceTest.java"
cat >"$RACE_SOURCE" <<'EOF'
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.attribute.FileTime;
import java.security.MessageDigest;
import java.util.HexFormat;

public final class SoundFontContractVerifierRaceTest {
    private static final String COMMIT = "0123456789abcdef0123456789abcdef01234567";
    private static int failuresVerified;

    private SoundFontContractVerifierRaceTest() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 1) {
            throw new IllegalArgumentException("usage: race-test <temp-root>");
        }
        Path root = Path.of(args[0]);
        Files.createDirectories(root);

        Fixture manifestRace = Fixture.create(root.resolve("manifest-race"));
        expectFailure(manifestRace, new SoundFontContractVerifier.VerificationObserver() {
            @Override
            public void afterManifestRead() throws Exception {
                Files.writeString(manifestRace.manifest(), "\n", StandardCharsets.UTF_8,
                        java.nio.file.StandardOpenOption.APPEND);
            }
        });

        Fixture assetRace = Fixture.create(root.resolve("asset-race"));
        expectFailure(assetRace, new SoundFontContractVerifier.VerificationObserver() {
            @Override
            public void afterInitialSnapshot() throws Exception {
                FileTime time = Files.getLastModifiedTime(assetRace.asset());
                Files.writeString(assetRace.asset(), "Fixture-soundfont-bytes\n");
                Files.setLastModifiedTime(assetRace.asset(), time);
            }
        });

        Fixture treeRace = Fixture.create(root.resolve("tree-race"));
        expectFailure(treeRace, new SoundFontContractVerifier.VerificationObserver() {
            @Override
            public void beforeFinalSnapshot() throws Exception {
                Files.writeString(treeRace.payload().resolve("late-file"), "late\n");
            }
        });

        System.out.printf("SoundFont race contract passed: %d negative.%n", failuresVerified);
    }

    private static void expectFailure(
            Fixture fixture, SoundFontContractVerifier.VerificationObserver observer)
            throws Exception {
        try {
            SoundFontContractVerifier.verify(fixture.manifest(), fixture.payload(), observer);
            throw new AssertionError("race unexpectedly passed");
        } catch (IllegalStateException expected) {
            if (!expected.getMessage().startsWith(
                    "SoundFont contract verification failed:")) {
                throw expected;
            }
            failuresVerified++;
        }
    }

    private record Fixture(Path manifest, Path payload, Path asset) {
        static Fixture create(Path base) throws Exception {
            Path payload = base.resolve("payload");
            Path asset = payload.resolve("assets/fixture.sf2");
            Path license = payload.resolve("licenses/LICENSE.txt");
            Path approval = payload.resolve("approvals/redistribution.txt");
            Files.createDirectories(asset.getParent());
            Files.createDirectories(license.getParent());
            Files.createDirectories(approval.getParent());
            Files.writeString(asset, "fixture-soundfont-bytes\n");
            Files.writeString(license, "Fixture license terms.\n");
            Files.writeString(approval,
                    "Approved for redistribution in verifier tests.\n");
            Path manifest = base.resolve("contract.manifest");
            Files.writeString(manifest, String.join("\n",
                    "soundfont-contract-v1",
                    "asset.path=assets/fixture.sf2",
                    "asset.name=Hermetic Fixture SoundFont",
                    "asset.version=1.2.3",
                    "asset.size=" + Files.size(asset),
                    "asset.sha256=" + sha256(asset),
                    "source.url=https://example.invalid/releases/" + COMMIT
                            + "/fixture.sf2",
                    "source.commit=" + COMMIT,
                    "license.path=licenses/LICENSE.txt",
                    "license.size=" + Files.size(license),
                    "license.sha256=" + sha256(license),
                    "license.url=https://example.invalid/licenses/fixture-1.2.3.txt",
                    "approval.path=approvals/redistribution.txt",
                    "approval.size=" + Files.size(approval),
                    "approval.sha256=" + sha256(approval),
                    "approval.id=LEGAL-2026-0001") + "\n");
            return new Fixture(manifest, payload, asset);
        }

        private static String sha256(Path path) throws Exception {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            try (InputStream input = Files.newInputStream(path)) {
                byte[] buffer = new byte[8192];
                int count;
                while ((count = input.read(buffer)) != -1) {
                    if (count != 0) {
                        digest.update(buffer, 0, count);
                    }
                }
            }
            return HexFormat.of().formatHex(digest.digest());
        }
    }
}
EOF
mise exec -- javac -Xlint:all -cp "$CLASSES" -d "$CLASSES" "$RACE_SOURCE"
race_output="$(mise exec -- java -cp "$CLASSES" \
	SoundFontContractVerifierRaceTest "$TEST_ROOT/races" 2>&1)" || {
	printf 'SoundFont race contract failed:\n%s\n' "$race_output" >&2
	exit 1
}
if [[ "$race_output" != *"SoundFont race contract passed: 3 negative."* ]]; then
	printf 'SoundFont race contract produced unexpected output:\n%s\n' \
		"$race_output" >&2
	exit 1
fi
NEGATIVE_COUNT=$((NEGATIVE_COUNT + 3))

printf 'SoundFont contract verifier behavioral contract passed: %d positive, %d negative.\n' \
	"$POSITIVE_COUNT" "$NEGATIVE_COUNT"
