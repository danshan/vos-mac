#!/usr/bin/env bash
set -euo pipefail

mvn -s .mvn/settings.xml -Dtest=JsonWriterTest,VosCatalogExporterTest,VosGameplayExporterTest,VosAudioExporterTest,VosRenderMetadataExporterTest,MainVosExportCliTest test

GODOT_LOG_DIR="${GODOT_LOG_DIR:-target/godot-logs}"
mkdir -p "$GODOT_LOG_DIR"

run_godot_test() {
	local script="$1"
	local log_name
	log_name="$(basename "$script" .gd).log"
	godot --headless --log-file "$PWD/$GODOT_LOG_DIR/$log_name" --path rewrite/godot --script "$script"
}

run_godot_test res://scripts/tests/app_state_test.gd
run_godot_test res://scripts/tests/main_ui_test.gd
run_godot_test res://scripts/tests/fullscreen_setting_test.gd
run_godot_test res://scripts/tests/menu_flow_test.gd
run_godot_test res://scripts/tests/main_ui_catalog_export_flow_test.gd
run_godot_test res://scripts/tests/main_ui_export_flow_test.gd
run_godot_test res://scripts/tests/judgment_strategy_test.gd
run_godot_test res://scripts/tests/score_state_java_parity_test.gd
run_godot_test res://scripts/tests/note_distance_java_parity_test.gd
run_godot_test res://scripts/tests/render_entity_model_test.gd
run_godot_test res://scripts/tests/settings_store_test.gd
run_godot_test res://scripts/tests/input_map_store_test.gd
run_godot_test res://scripts/tests/catalog_store_test.gd
run_godot_test res://scripts/tests/gameplay_loader_test.gd
run_godot_test res://scripts/tests/gameplay_input_java_parity_test.gd
run_godot_test res://scripts/tests/gameplay_audio_java_parity_test.gd
run_godot_test res://scripts/tests/gameplay_runtime_test.gd
run_godot_test res://scripts/tests/audio_manifest_loader_test.gd
run_godot_test res://scripts/tests/audio_player_pool_test.gd
run_godot_test res://scripts/tests/exporter_client_test.gd
run_godot_test res://scripts/tests/result_flow_test.gd
