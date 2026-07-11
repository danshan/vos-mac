#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

bash rewrite/tools/verify_java_migration_goldens.sh

JAVA_TESTS=(
	JsonWriterTest
	VosCatalogExporterTest
	VosGameplayExporterTest
	VosAudioExporterTest
	VosRenderMetadataExporterTest
	MainVosExportCliTest
	MainVosAudioCliTest
	VOSChartTest
	VOSParserTest
	EventListChannelRandomTest
	OsuManiaParserTest
	ChartModelLoaderTest
	MusicSelectionSelectionTest
	ChartDisplayTest
	ConfigTest
	JudgmentStrategyOracleFixtureTest
	JudgmentResultStringTest
	SpeedMultiplierOracleFixtureTest
	NoteDistanceCalculatorOracleFixtureTest
	LatencyOracleFixtureTest
	RenderTimingCompilerTest
	RenderVosKeysoundTest
	RenderLastSoundBootstrapTest
	LWJGLGameWindowTest
	RenderScoreOracleFixtureTest
	RenderStatusTextOracleFixtureTest
	RenderVisibilityOracleFixtureTest
	RenderHasteOracleFixtureTest
	RenderBufferWindowOracleFixtureTest
	RenderBgaEventOracleFixtureTest
	RenderMeasureEventOracleFixtureTest
	RenderFpsTimerOracleFixtureTest
	RenderLongNoteHoldMissOracleFixtureTest
	RenderLongNoteReleaseOracleFixtureTest
	RenderRejectedKeysoundOracleFixtureTest
	RenderMiscVolumeOracleFixtureTest
	RenderQueueSampleOracleFixtureTest
	ComboCounterEntityTest
	CompositeEntityOracleFixtureTest
	ComboCounterEntityOracleFixtureTest
	BarEntityOracleFixtureTest
	NumberEntityOracleFixtureTest
	JudgmentEntityOracleFixtureTest
	MeasureEntityTest
	MeasureEntityOracleFixtureTest
	NoteEntityOracleFixtureTest
	LongNoteEntityOracleFixtureTest
	ClickEffectEntityOracleFixtureTest
	LongflareEntityOracleFixtureTest
	PressedNoteEntityOracleFixtureTest
	BgaEntityOracleFixtureTest
	SampleEntityOracleFixtureTest
	MidiSampleRendererTest
	JavaSoundPcmDecoderTest
	VOSReferenceAudioRenderTest
)
java_tests_csv="$(IFS=,; printf '%s' "${JAVA_TESTS[*]}")"

mvn -s "${MAVEN_SETTINGS:-.mvn/settings.xml}" -Dtest="$java_tests_csv" test

GODOT_LOG_DIR="${GODOT_LOG_DIR:-target/godot-logs}"
GODOT_USER_HOME_DIR="${GODOT_USER_HOME_DIR:-target/godot-user-home}"
HOST_MISE_DATA_DIR="${MISE_DATA_DIR:-${HOME}/.local/share/mise}"
HOST_MISE_GLOBAL_CONFIG_FILE="${MISE_GLOBAL_CONFIG_FILE:-${HOME}/.config/mise/config.toml}"
mkdir -p "$GODOT_LOG_DIR"
mkdir -p "$GODOT_USER_HOME_DIR"

run_launcher_catalog_smoke() {
	local demo_directory="${OPEN2JAM_DEMO_DIRECTORY:-/Users/honghao.shan/Music/demo}"
	local jar_path
	local output_path
	local user_home
	if [[ ! -d "$demo_directory" ]]; then
		return
	fi
	jar_path="$(find target -maxdepth 1 -type f -name 'open2jam-*.jar' \
		! -name 'original-*' ! -name '*-sources.jar' ! -name '*-javadoc.jar' \
		| sort | tail -n 1)"
	if [[ -z "$jar_path" ]]; then
		printf 'Launcher catalog smoke requires a packaged open2jam jar in target.\n' >&2
		exit 1
	fi
	output_path="$PWD/$GODOT_LOG_DIR/launcher-catalog-smoke.json"
	user_home="$PWD/$GODOT_USER_HOME_DIR/open2jam-java-launcher"
	mkdir -p "$user_home"
	rm -f "$output_path"
	if ! HOME="$user_home" MISE_DATA_DIR="$HOST_MISE_DATA_DIR" \
		MISE_IGNORED_CONFIG_PATHS="${HOST_MISE_GLOBAL_CONFIG_FILE}${MISE_IGNORED_CONFIG_PATHS:+:${MISE_IGNORED_CONFIG_PATHS}}" \
		bash rewrite/tools/open2jam-java -jar "$jar_path" \
			--export-vos-catalog --output "$output_path" "$demo_directory"; then
		printf 'Launcher catalog smoke failed for %s.\n' "$demo_directory" >&2
		exit 1
	fi
	if ! grep -Fq '"entries"' "$output_path"; then
		printf 'Launcher catalog smoke produced an invalid catalog: %s\n' "$output_path" >&2
		exit 1
	fi
}

run_godot_test() {
	local script="$1"
	local log_name
	local test_name
	local log_path
	local user_home
	log_name="$(basename "$script" .gd).log"
	test_name="$(basename "$script" .gd)"
	log_path="$PWD/$GODOT_LOG_DIR/$log_name"
	user_home="$PWD/$GODOT_USER_HOME_DIR/$test_name"
	mkdir -p "$user_home"
	rm -f "$log_path"
	if ! HOME="$user_home" MISE_DATA_DIR="$HOST_MISE_DATA_DIR" \
		MISE_IGNORED_CONFIG_PATHS="${HOST_MISE_GLOBAL_CONFIG_FILE}${MISE_IGNORED_CONFIG_PATHS:+:${MISE_IGNORED_CONFIG_PATHS}}" \
		OPEN2JAM_JAVA="${OPEN2JAM_JAVA:-}" \
		godot --headless --log-file "$log_path" --path rewrite/godot --script "$script"; then
		printf 'Godot test failed: %s\n' "$script" >&2
		exit 1
	fi
	if [[ ! -f "$log_path" ]]; then
		printf 'Godot log was not created for %s: %s\n' "$script" "$log_path" >&2
		exit 1
	fi
	if grep -E '(^|[[:space:]])(SCRIPT ERROR|ERROR):' "$log_path" \
		| grep -Ev 'ERROR: Condition "ret != noErr" is true\. Returning: ""' >&2; then
		printf 'Godot test logged errors: %s\n' "$script" >&2
		exit 1
	fi
}

run_launcher_catalog_smoke

run_godot_test res://scripts/tests/app_state_test.gd
run_godot_test res://scripts/tests/main_ui_test.gd
run_godot_test res://scripts/tests/fullscreen_setting_test.gd
run_godot_test res://scripts/tests/fullscreen_layout_test.gd
run_godot_test res://scripts/tests/main_ui_settings_persistence_test.gd
run_godot_test res://scripts/tests/menu_flow_test.gd
run_godot_test res://scripts/tests/main_ui_catalog_export_flow_test.gd
run_godot_test res://scripts/tests/main_ui_real_demo_catalog_test.gd
run_godot_test res://scripts/tests/main_ui_default_real_demo_catalog_test.gd
run_godot_test res://scripts/tests/main_ui_export_flow_test.gd
run_godot_test res://scripts/tests/judgment_strategy_test.gd
run_godot_test res://scripts/tests/judgment_strategy_java_oracle_test.gd
run_godot_test res://scripts/tests/score_state_java_parity_test.gd
run_godot_test res://scripts/tests/score_state_java_oracle_test.gd
run_godot_test res://scripts/tests/combo_counter_java_oracle_test.gd
run_godot_test res://scripts/tests/bar_entity_java_oracle_test.gd
run_godot_test res://scripts/tests/number_entity_java_oracle_test.gd
run_godot_test res://scripts/tests/judgment_entity_java_oracle_test.gd
run_godot_test res://scripts/tests/measure_entity_java_oracle_test.gd
run_godot_test res://scripts/tests/note_entity_java_oracle_test.gd
run_godot_test res://scripts/tests/long_note_entity_java_oracle_test.gd
run_godot_test res://scripts/tests/click_effect_entity_java_oracle_test.gd
run_godot_test res://scripts/tests/longflare_entity_java_oracle_test.gd
run_godot_test res://scripts/tests/pressed_note_entity_java_oracle_test.gd
run_godot_test res://scripts/tests/bga_entity_java_oracle_test.gd
run_godot_test res://scripts/tests/status_text_java_oracle_test.gd
run_godot_test res://scripts/tests/visibility_java_oracle_test.gd
run_godot_test res://scripts/tests/composite_entity_java_oracle_test.gd
run_godot_test res://scripts/tests/haste_mode_java_oracle_test.gd
run_godot_test res://scripts/tests/buffer_window_java_oracle_test.gd
run_godot_test res://scripts/tests/note_distance_java_parity_test.gd
run_godot_test res://scripts/tests/speed_multiplier_java_oracle_test.gd
run_godot_test res://scripts/tests/misc_volume_java_oracle_test.gd
run_godot_test res://scripts/tests/queue_sample_java_oracle_test.gd
run_godot_test res://scripts/tests/latency_model_java_oracle_test.gd
run_godot_test res://scripts/tests/render_entity_model_test.gd
run_godot_test res://scripts/tests/gameplay_view_visual_smoke_test.gd
run_godot_test res://scripts/tests/gameplay_view_texture_cache_test.gd
run_godot_test res://scripts/tests/java_capture_chart_window_test.gd
run_godot_test res://scripts/tests/java_capture_state_model_test.gd
run_godot_test res://scripts/tests/java_capture_resampler_test.gd
run_godot_test res://scripts/tests/java_capture_viewport_config_test.gd
run_godot_test res://scripts/tests/java_texture_loader_test.gd
run_godot_test res://scripts/tests/settings_store_test.gd
run_godot_test res://scripts/tests/input_map_store_test.gd
run_godot_test res://scripts/tests/catalog_store_test.gd
run_godot_test res://scripts/tests/gameplay_loader_test.gd
run_godot_test res://scripts/tests/gameplay_input_java_parity_test.gd
run_godot_test res://scripts/tests/gameplay_long_note_java_oracle_test.gd
run_godot_test res://scripts/tests/gameplay_long_note_release_java_oracle_test.gd
run_godot_test res://scripts/tests/gameplay_bga_event_java_oracle_test.gd
run_godot_test res://scripts/tests/gameplay_measure_event_java_oracle_test.gd
run_godot_test res://scripts/tests/gameplay_fps_timer_java_oracle_test.gd
run_godot_test res://scripts/tests/gameplay_audio_java_parity_test.gd
run_godot_test res://scripts/tests/sample_entity_java_oracle_test.gd
run_godot_test res://scripts/tests/rejected_keysound_java_oracle_test.gd
run_godot_test res://scripts/tests/gameplay_runtime_test.gd
run_godot_test res://scripts/tests/audio_manifest_loader_test.gd
run_godot_test res://scripts/tests/audio_player_pool_test.gd
run_godot_test res://scripts/tests/selected_export_job_test.gd
run_godot_test res://scripts/tests/exporter_client_test.gd
run_godot_test res://scripts/tests/real_vos_selected_bundle_loader_test.gd
run_godot_test res://scripts/tests/real_osu_selected_bundle_loader_test.gd
run_godot_test res://scripts/tests/real_osu_gameplay_runtime_smoke_test.gd
run_godot_test res://scripts/tests/real_ojn_selected_bundle_loader_test.gd
run_godot_test res://scripts/tests/non_vos_gameplay_runtime_smoke_test.gd
run_godot_test res://scripts/tests/real_ojn_gameplay_runtime_smoke_test.gd
run_godot_test res://scripts/tests/result_flow_test.gd
