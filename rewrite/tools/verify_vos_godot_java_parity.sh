#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

INITIAL_VERIFIER="rewrite/tools/verify_vos_godot_initial.sh"
MANUAL_ACCEPTANCE="docs/rewrite/godot-java-parity-manual-acceptance.md"
GAMEPLAY_FIXTURE="rewrite/godot/test/fixtures/gameplay.json"
AUDIO_FIXTURE="rewrite/godot/test/fixtures/audio-manifest.json"
RENDER_FIXTURE="rewrite/godot/test/fixtures/render-metadata.json"

require_file() {
	local path="$1"
	if [[ ! -f "$path" ]]; then
		printf 'Missing required file: %s\n' "$path" >&2
		exit 1
	fi
}

require_text() {
	local path="$1"
	local text="$2"
	local label="$3"
	if ! grep -Fq "$text" "$path"; then
		printf 'Missing %s in %s\n' "$label" "$path" >&2
		exit 1
	fi
}

require_file "$INITIAL_VERIFIER"
require_file "$MANUAL_ACCEPTANCE"
require_file "$GAMEPLAY_FIXTURE"
require_file "$AUDIO_FIXTURE"
require_file "$RENDER_FIXTURE"

require_text "$RENDER_FIXTURE" '"format":"VOS_RENDER_METADATA"' "render metadata format marker"
require_text "$RENDER_FIXTURE" '"visibilityLayer":7' "visibility layer metadata"
require_text "$RENDER_FIXTURE" '"id":"JUDGMENT_LINE"' "judgment line entity"
require_text "$RENDER_FIXTURE" '"id":"COMBO_COUNTER"' "combo counter entity"
require_text "$RENDER_FIXTURE" '"id":"SCORE_COUNTER"' "score counter entity"
require_text "$RENDER_FIXTURE" '"id":"LIFE_BAR"' "life bar entity"
require_text "$RENDER_FIXTURE" '"id":"EFFECT_JUDGMENT_COOL"' "judgment effect entity"
require_text "$RENDER_FIXTURE" '"id":"EFFECT_LONGFLARE"' "long flare entity"
require_text "$GAMEPLAY_FIXTURE" '"judgmentTiming"' "judgment timing export"
require_text "$GAMEPLAY_FIXTURE" '"visualTiming"' "visual timing export"
require_text "$GAMEPLAY_FIXTURE" '"autoPlayEvents"' "autoplay export"
require_text "$AUDIO_FIXTURE" '"assets"' "audio asset manifest"

require_text "$MANUAL_ACCEPTANCE" 'Fullscreen layout' "fullscreen acceptance item"
require_text "$MANUAL_ACCEPTANCE" 'Settings and key bindings' "settings acceptance item"
require_text "$MANUAL_ACCEPTANCE" 'Song select' "song select acceptance item"
require_text "$MANUAL_ACCEPTANCE" 'Gameplay Java parity' "gameplay acceptance item"
require_text "$MANUAL_ACCEPTANCE" 'Result, retry, and back flow' "result flow acceptance item"

bash "$INITIAL_VERIFIER"

cat <<'EOF'
Automated VOS Godot Java parity gate passed.
Manual parity acceptance is still required before claiming gameplay parity complete:
  docs/rewrite/godot-java-parity-manual-acceptance.md
EOF
