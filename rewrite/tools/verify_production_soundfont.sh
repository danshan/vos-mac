#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT_DIR"

MANIFEST="rewrite/assets/soundfont/contract.manifest"
PAYLOAD_ROOT="rewrite/assets/soundfont/payload"
CONTRACT_VERIFIER="rewrite/tools/SoundFontContractVerifier.java"
PRODUCTION_RUNNER="rewrite/tools/ProductionSoundFontVerifier.java"
EXPECTED_MANIFEST_SHA256="ba4707b6fae9880f4b719d1da38d2c92aa90c3e6d5f1c7dd4a5cc0fbb358c507"
EXPECTED_ASSET_SHA256="9575028c7a1f589f5770fccc8cff2734566af40cd26ed836944e9a5152688cfe"
TEMP_BASE_INPUT=""
TEMP_BASE=""
OWNED_TEMP=""
SNAPSHOT_ROOT=""
CREATED_TEMP=""

if [[ "${TMPDIR+x}" == "x" ]]; then
	TEMP_BASE_INPUT="$TMPDIR"
else
	TEMP_BASE_INPUT="/tmp"
fi

if [[ "$#" -ne 0 ]]; then
	printf 'Production SoundFont verifier does not accept arguments.\n' >&2
	exit 2
fi

for required_file in "$MANIFEST" "$CONTRACT_VERIFIER" "$PRODUCTION_RUNNER"; do
	if [[ ! -f "$required_file" || -L "$required_file" ]]; then
		printf 'Missing regular production SoundFont contract input: %s\n' \
			"$required_file" >&2
		exit 1
	fi
done
if [[ ! -d "$PAYLOAD_ROOT" || -L "$PAYLOAD_ROOT" ]]; then
	printf 'Missing production SoundFont payload root: %s\n' "$PAYLOAD_ROOT" >&2
	exit 1
fi
for required_command in mise mkdir mktemp rm shasum; do
	if ! command -v "$required_command" >/dev/null 2>&1; then
		printf 'Missing required command: %s\n' "$required_command" >&2
		exit 1
	fi
done
manifest_hash="$(shasum -a 256 "$MANIFEST")"
manifest_hash="${manifest_hash%% *}"
if [[ "$manifest_hash" != "$EXPECTED_MANIFEST_SHA256" ]]; then
	printf 'Production SoundFont manifest SHA-256 mismatch: expected %s, got %s.\n' \
		"$EXPECTED_MANIFEST_SHA256" "$manifest_hash" >&2
	exit 1
fi
if [[ -z "$TEMP_BASE_INPUT" || "$TEMP_BASE_INPUT" == "/" \
	|| ! -d "$TEMP_BASE_INPUT" ]]; then
	printf 'Unsafe production SoundFont TMPDIR: %s\n' \
		"${TEMP_BASE_INPUT:-<empty>}" >&2
	exit 1
fi
if ! TEMP_BASE="$(cd "$TEMP_BASE_INPUT" 2>/dev/null && pwd -P)" \
	|| [[ -z "$TEMP_BASE" || "$TEMP_BASE" == "/" ]]; then
	printf 'Unable to resolve a safe production SoundFont TMPDIR.\n' >&2
	exit 1
fi

safe_remove_owned_temp() {
	if [[ -z "$OWNED_TEMP" || "$OWNED_TEMP" == "/" \
		|| ! -d "$OWNED_TEMP" || -L "$OWNED_TEMP" ]]; then
		printf 'Refusing unsafe production SoundFont cleanup: %s\n' \
			"${OWNED_TEMP:-<empty>}" >&2
		return 1
	fi
	case "$OWNED_TEMP" in
		"$TEMP_BASE"/open2jam-production-soundfont.*) ;;
		*)
			printf 'Refusing out-of-scope production SoundFont cleanup: %s\n' \
				"$OWNED_TEMP" >&2
			return 1
			;;
	esac
	rm -rf -- "$OWNED_TEMP"
}

cleanup() {
	local status=$?
	trap - EXIT INT TERM HUP
	if [[ -n "$SNAPSHOT_ROOT" && -d "$SNAPSHOT_ROOT" && "$status" -ne 0 ]]; then
		printf 'Production SoundFont verification failed; incomplete snapshot retained: %s\n' \
			"$SNAPSHOT_ROOT" >&2
	elif [[ -n "$OWNED_TEMP" && -e "$OWNED_TEMP" ]]; then
		if ! safe_remove_owned_temp; then
			status=1
		fi
	fi
	exit "$status"
}

handle_signal() {
	local status="$1"
	exit "$status"
}

trap cleanup EXIT
trap 'handle_signal 130' INT
trap 'handle_signal 143' TERM
trap 'handle_signal 129' HUP

if ! CREATED_TEMP="$(mktemp -d "$TEMP_BASE/open2jam-production-soundfont.XXXXXX")"; then
	printf 'Unable to create production SoundFont verification workspace.\n' >&2
	exit 1
fi
OWNED_TEMP="$CREATED_TEMP"
if ! canonical_temp="$(cd "$OWNED_TEMP" 2>/dev/null && pwd -P)"; then
	printf 'Unable to resolve production SoundFont verification workspace.\n' >&2
	exit 1
fi
OWNED_TEMP="$canonical_temp"
case "$OWNED_TEMP" in
	"$TEMP_BASE"/open2jam-production-soundfont.*) ;;
	*)
		printf 'Production SoundFont verification workspace escaped TMPDIR: %s\n' \
			"$OWNED_TEMP" >&2
		exit 1
		;;
esac
SNAPSHOT_ROOT="$OWNED_TEMP/verified"
CLASSES="$OWNED_TEMP/classes"
mkdir -p "$CLASSES"

mise exec -- javac -d "$CLASSES" "$CONTRACT_VERIFIER" "$PRODUCTION_RUNNER"
mise exec -- java -cp "$CLASSES" ProductionSoundFontVerifier \
	"$MANIFEST" "$PAYLOAD_ROOT" "$SNAPSHOT_ROOT"

printf 'Production SoundFont contract passed: GeneralUser GS 2.0.3 sha256=%s.\n' \
	"$EXPECTED_ASSET_SHA256"
