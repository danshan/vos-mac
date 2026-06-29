#!/usr/bin/env bash
set -euo pipefail

mvn -s .mvn/settings.xml -Dtest=JsonWriterTest,VosCatalogExporterTest,VosGameplayExporterTest,VosAudioExporterTest,MainVosExportCliTest test

godot --headless --path rewrite/godot --script res://scripts/tests/app_state_test.gd
godot --headless --path rewrite/godot --script res://scripts/tests/main_ui_test.gd
godot --headless --path rewrite/godot --script res://scripts/tests/judgment_strategy_test.gd
godot --headless --path rewrite/godot --script res://scripts/tests/settings_store_test.gd
godot --headless --path rewrite/godot --script res://scripts/tests/catalog_store_test.gd
godot --headless --path rewrite/godot --script res://scripts/tests/gameplay_loader_test.gd
godot --headless --path rewrite/godot --script res://scripts/tests/audio_manifest_loader_test.gd
godot --headless --path rewrite/godot --script res://scripts/tests/exporter_client_test.gd
godot --headless --path rewrite/godot --script res://scripts/tests/result_flow_test.gd
