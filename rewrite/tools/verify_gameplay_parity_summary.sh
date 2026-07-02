#!/usr/bin/env bash
set -euo pipefail

SUMMARY_PATH="${1:-}"
COMPONENTS_PATH="${2:-}"

MAX_DIFFERING_PIXELS="${OPEN2JAM_PARITY_MAX_DIFFERING_PIXELS:-300}"
MAX_MEAN_ABS_DELTA="${OPEN2JAM_PARITY_MAX_MEAN_ABS_DELTA:-0.003}"
MAX_CHANNEL_DELTA="${OPEN2JAM_PARITY_MAX_CHANNEL_DELTA:-24}"
MAX_COMPONENT_COUNT="${OPEN2JAM_PARITY_MAX_COMPONENT_COUNT:-30}"
MAX_LARGEST_COMPONENT_PIXELS="${OPEN2JAM_PARITY_MAX_LARGEST_COMPONENT_PIXELS:-25}"
MAX_LARGEST_COMPONENT_SHORT_SIDE="${OPEN2JAM_PARITY_MAX_LARGEST_COMPONENT_SHORT_SIDE:-3}"
PIXEL_TOLERANCE="${OPEN2JAM_PARITY_PIXEL_TOLERANCE:-0}"
EXPECTED_WIDTH="${OPEN2JAM_PARITY_EXPECTED_WIDTH:-800}"
EXPECTED_HEIGHT="${OPEN2JAM_PARITY_EXPECTED_HEIGHT:-600}"

usage() {
	cat >&2 <<'EOF'
Usage: rewrite/tools/verify_gameplay_parity_summary.sh <summary.json> <diff-components.json>

Environment overrides:
  OPEN2JAM_PARITY_MAX_DIFFERING_PIXELS       default: 300
  OPEN2JAM_PARITY_MAX_MEAN_ABS_DELTA         default: 0.003
  OPEN2JAM_PARITY_MAX_CHANNEL_DELTA          default: 24
  OPEN2JAM_PARITY_MAX_COMPONENT_COUNT        default: 30
  OPEN2JAM_PARITY_MAX_LARGEST_COMPONENT_PIXELS default: 25
  OPEN2JAM_PARITY_MAX_LARGEST_COMPONENT_SHORT_SIDE default: 3
  OPEN2JAM_PARITY_PIXEL_TOLERANCE            default: 0
  OPEN2JAM_PARITY_EXPECTED_WIDTH             default: 800
  OPEN2JAM_PARITY_EXPECTED_HEIGHT            default: 600
EOF
}

fail() {
	echo "$1" >&2
	exit 1
}

if [[ -z "$SUMMARY_PATH" || -z "$COMPONENTS_PATH" ]]; then
	usage
	exit 2
fi
if [[ ! -f "$SUMMARY_PATH" ]]; then
	fail "Missing summary file: $SUMMARY_PATH"
fi
if [[ ! -f "$COMPONENTS_PATH" ]]; then
	fail "Missing diff components file: $COMPONENTS_PATH"
fi

json_file_value() {
	local path="$1"
	local key="$2"
	local compact
	local value
	compact="$(tr -d '\n\r\t ' < "$path")"
	value="$(printf '%s' "$compact" | sed -E "s/.*\"$key\":([^,}]+).*/\\1/")"
	if [[ "$value" == "$compact" ]]; then
		fail "Missing JSON key '$key' in $path"
	fi
	printf '%s\n' "${value%\"}" | sed -E 's/^"//'
}

first_component_value() {
	local path="$1"
	local key="$2"
	local compact
	local component
	local value
	compact="$(tr -d '\n\r\t ' < "$path")"
	if [[ "$compact" == *'"components":[]'* ]]; then
		printf '0\n'
		return
	fi
	component="$(printf '%s' "$compact" | sed -E 's/.*"components":\[\{([^}]*)\}.*/\1/')"
	if [[ "$component" == "$compact" ]]; then
		fail "Missing first diff component in $path"
	fi
	value="$(printf '%s' "$component" | sed -E "s/.*\"$key\":([^,}]+).*/\\1/")"
	if [[ "$value" == "$component" ]]; then
		fail "Missing JSON key '$key' in first diff component of $path"
	fi
	printf '%s\n' "$value"
}

assert_equal() {
	local actual="$1"
	local expected="$2"
	local label="$3"
	if [[ "$actual" != "$expected" ]]; then
		fail "Expected $label == $expected, got $actual"
	fi
}

assert_le() {
	local actual="$1"
	local limit="$2"
	local label="$3"
	if ! awk -v actual="$actual" -v limit="$limit" 'BEGIN { exit !(actual <= limit) }'; then
		fail "Expected $label <= $limit, got $actual"
	fi
}

java_width="$(json_file_value "$SUMMARY_PATH" "javaWidth")"
java_height="$(json_file_value "$SUMMARY_PATH" "javaHeight")"
godot_width="$(json_file_value "$SUMMARY_PATH" "godotWidth")"
godot_height="$(json_file_value "$SUMMARY_PATH" "godotHeight")"
compared_width="$(json_file_value "$SUMMARY_PATH" "comparedWidth")"
compared_height="$(json_file_value "$SUMMARY_PATH" "comparedHeight")"
differing_pixels="$(json_file_value "$SUMMARY_PATH" "differingPixels")"
effective_differing_pixels="$differing_pixels"
effective_differing_label="differingPixels"
if awk -v tolerance="$PIXEL_TOLERANCE" 'BEGIN { exit !(tolerance > 0) }'; then
	summary_pixel_tolerance="$(json_file_value "$SUMMARY_PATH" "pixelTolerance")"
	assert_equal "$summary_pixel_tolerance" "$PIXEL_TOLERANCE" "summary pixelTolerance"
	effective_differing_pixels="$(json_file_value "$SUMMARY_PATH" "significantDifferingPixels")"
	effective_differing_label="significantDifferingPixels"
fi
mean_abs_delta="$(json_file_value "$SUMMARY_PATH" "meanAbsDelta")"
effective_mean_abs_delta="$mean_abs_delta"
effective_mean_abs_label="meanAbsDelta"
if awk -v tolerance="$PIXEL_TOLERANCE" 'BEGIN { exit !(tolerance > 0) }'; then
	effective_mean_abs_delta="$(json_file_value "$SUMMARY_PATH" "significantMeanAbsDelta")"
	effective_mean_abs_label="significantMeanAbsDelta"
fi
max_channel_delta="$(json_file_value "$SUMMARY_PATH" "maxChannelDelta")"
component_count="$(json_file_value "$COMPONENTS_PATH" "componentCount")"
largest_component_pixels="$(first_component_value "$COMPONENTS_PATH" "pixels")"
largest_component_width="$(first_component_value "$COMPONENTS_PATH" "width")"
largest_component_height="$(first_component_value "$COMPONENTS_PATH" "height")"
largest_component_short_side="$largest_component_width"
if awk -v width="$largest_component_width" -v height="$largest_component_height" 'BEGIN { exit !(height < width) }'; then
	largest_component_short_side="$largest_component_height"
fi

assert_equal "$java_width" "$EXPECTED_WIDTH" "Java screenshot width"
assert_equal "$java_height" "$EXPECTED_HEIGHT" "Java screenshot height"
assert_equal "$godot_width" "$EXPECTED_WIDTH" "Godot screenshot width"
assert_equal "$godot_height" "$EXPECTED_HEIGHT" "Godot screenshot height"
assert_equal "$compared_width" "$EXPECTED_WIDTH" "compared width"
assert_equal "$compared_height" "$EXPECTED_HEIGHT" "compared height"
assert_le "$effective_differing_pixels" "$MAX_DIFFERING_PIXELS" "$effective_differing_label"
assert_le "$effective_mean_abs_delta" "$MAX_MEAN_ABS_DELTA" "$effective_mean_abs_label"
assert_le "$max_channel_delta" "$MAX_CHANNEL_DELTA" "maxChannelDelta"
assert_le "$component_count" "$MAX_COMPONENT_COUNT" "componentCount"
assert_le "$largest_component_pixels" "$MAX_LARGEST_COMPONENT_PIXELS" "largest component pixels"
assert_le "$largest_component_short_side" "$MAX_LARGEST_COMPONENT_SHORT_SIDE" "largest component short side"

cat <<EOF
Gameplay parity summary verified:
  differingPixels=$differing_pixels
EOF
if [[ "$effective_differing_label" != "differingPixels" ]]; then
	printf '  %s=%s\n' "$effective_differing_label" "$effective_differing_pixels"
fi
cat <<EOF
  pixelTolerance=$PIXEL_TOLERANCE
  meanAbsDelta=$mean_abs_delta
EOF
if [[ "$effective_mean_abs_label" != "meanAbsDelta" ]]; then
	printf '  %s=%s\n' "$effective_mean_abs_label" "$effective_mean_abs_delta"
fi
cat <<EOF
  maxChannelDelta=$max_channel_delta
  componentCount=$component_count
  largestComponentPixels=$largest_component_pixels
  largestComponentShortSide=$largest_component_short_side
EOF
