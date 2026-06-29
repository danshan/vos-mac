# VOS Godot Rewrite Initial Version Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first Godot-based open2jam runtime that completes a full VOS flow from menu and settings through song select, gameplay, result, retry, and back.

**Architecture:** Godot owns the full-screen application runtime and consumes normalized JSON. Java remains the VOS compatibility/export layer and converts existing `VOSParser` / `VOSChart` / `EventList` / `SampleData` output into `catalog.json`, `gameplay.json`, and `audio-manifest.json`. The first implementation uses repository-local fixtures and synthetic VOS fixtures so automated tests do not depend on local absolute paths.

**Tech Stack:** Java 17, Maven, JUnit 5, Godot 4, GDScript, existing open2jam parser/audio classes.

---

## Loop Engineering Rules

Each loop has one deliverable and one commit. Do not start a later loop until the current loop passes its verification command.

For every loop:

- Keep the diff scoped to the listed files.
- Write or update the failing test first.
- Run the narrow test and confirm it fails for the expected reason.
- Implement the smallest code that makes the test pass.
- Run the narrow test again.
- Run the loop-level regression command.
- Commit with the listed message.

Do not add third-party JSON dependencies in the Java exporter. The project currently has no JSON library, and the exporter output shape is small enough for a focused internal writer.

## File Map

### Java Exporter

- `src/org/open2jam/export/JsonWriter.java`: Small JSON string/file writer with deterministic escaping.
- `src/org/open2jam/export/ExportPaths.java`: Output path helpers for selected export directories.
- `src/org/open2jam/export/VosCatalogExporter.java`: Scan one file or directory and produce catalog JSON.
- `src/org/open2jam/export/VosGameplayExporter.java`: Convert selected `VOSChart` events into normalized gameplay JSON.
- `src/org/open2jam/export/VosAudioExporter.java`: Render VOS MIDI samples into WAV assets and produce audio manifest JSON.
- `src/org/open2jam/export/VosExportCli.java`: CLI argument parsing and exporter command dispatch.
- `src/org/open2jam/Main.java`: Route new exporter CLI flags before Swing startup.

### Java Tests

- `src/test/java/org/open2jam/parsers/VosFixtureFactory.java`: Shared synthetic VOS fixture builder extracted from `VOSParserTest`.
- `src/test/java/org/open2jam/parsers/VOSParserTest.java`: Use `VosFixtureFactory` instead of private fixture helpers.
- `src/test/java/org/open2jam/export/JsonWriterTest.java`: JSON escaping and object/array output tests.
- `src/test/java/org/open2jam/export/VosCatalogExporterTest.java`: Catalog shape and metadata tests.
- `src/test/java/org/open2jam/export/VosGameplayExporterTest.java`: Note, hold, and autoplay event export tests.
- `src/test/java/org/open2jam/export/VosAudioExporterTest.java`: WAV asset and audio manifest tests.
- `src/test/java/org/open2jam/MainVosExportCliTest.java`: CLI dispatch tests.

### Godot Runtime

- `rewrite/godot/project.godot`: Godot project settings.
- `rewrite/godot/scenes/main.tscn`: Main app shell scene.
- `rewrite/godot/scripts/app_state.gd`: State machine.
- `rewrite/godot/scripts/settings_store.gd`: `user://settings.cfg` persistence.
- `rewrite/godot/scripts/exporter_client.gd`: Java exporter invocation wrapper.
- `rewrite/godot/scripts/catalog_store.gd`: Catalog loading and filtering.
- `rewrite/godot/scripts/gameplay_loader.gd`: Gameplay JSON validation/loading.
- `rewrite/godot/scripts/audio_manifest_loader.gd`: Audio manifest validation/loading.
- `rewrite/godot/scripts/gameplay_controller.gd`: One-song gameplay state.
- `rewrite/godot/scripts/score_state.gd`: Score, combo, max combo, judgment counts.
- `rewrite/godot/scripts/result_model.gd`: Result snapshot.

### Godot Tests And Fixtures

- `rewrite/godot/test/fixtures/catalog.json`: Minimal VOS catalog fixture.
- `rewrite/godot/test/fixtures/gameplay.json`: Minimal VOS gameplay fixture.
- `rewrite/godot/test/fixtures/audio-manifest.json`: Minimal VOS audio manifest fixture.
- `rewrite/godot/test/fixtures/sample.wav`: Placeholder file used by manifest existence tests.
- `rewrite/godot/scripts/tests/settings_store_test.gd`
- `rewrite/godot/scripts/tests/app_state_test.gd`
- `rewrite/godot/scripts/tests/catalog_store_test.gd`
- `rewrite/godot/scripts/tests/gameplay_loader_test.gd`
- `rewrite/godot/scripts/tests/audio_manifest_loader_test.gd`
- `rewrite/godot/scripts/tests/result_flow_test.gd`

---

## Loop 1: Shared VOS Test Fixture

**Hypothesis:** Exporter tests should not depend on local absolute VOS files. Extracting the existing synthetic VOS fixture builder creates a stable base for every Java exporter loop.

**Scope:** Test-only refactor. No production behavior changes.

**Files:**
- Create: `src/test/java/org/open2jam/parsers/VosFixtureFactory.java`
- Modify: `src/test/java/org/open2jam/parsers/VOSParserTest.java`

- [ ] **Step 1: Create fixture factory shell**

Create `src/test/java/org/open2jam/parsers/VosFixtureFactory.java` with this public surface:

```java
package org.open2jam.parsers;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;

public final class VosFixtureFactory {
    private VosFixtureFactory() {
    }

    public static File writeFixture(File directory, String fileName, int level, boolean includeLevel,
            boolean includeChannelData, boolean includeLongNote) throws IOException {
        return writeFixture(directory, fileName, level, includeLevel, includeChannelData, includeLongNote,
                "Canon in D");
    }

    public static File writeFixture(File directory, String fileName, int level, boolean includeLevel,
            boolean includeChannelData, boolean includeLongNote, String title) throws IOException {
        byte[] bytes = buildFixture(level, includeLevel, includeChannelData, includeLongNote, title);
        File file = new File(directory, fileName);
        Files.write(file.toPath(), bytes);
        return file;
    }

    public static byte[] buildFixture(int level, boolean includeLevel, boolean includeChannelData,
            boolean includeLongNote, String title) throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        return out.toByteArray();
    }
}
```

- [ ] **Step 2: Switch one parser test to the incomplete factory and verify failure**

In the first `VOSParserTest` case, replace:

```java
File chartFile = writeFixture("known.vos", 7, true, true, false);
```

with:

```java
File chartFile = VosFixtureFactory.writeFixture(tempDir, "known.vos", 7, true, true, false);
```

Run:

```bash
mvn -s .mvn/settings.xml -Dtest=VOSParserTest test
```

Expected: FAIL because `buildFixture` returns an empty file.

- [ ] **Step 3: Move fixture internals**

Move the fixture helper methods from `VOSParserTest` into `VosFixtureFactory`:

```java
private static void writeInt(ByteArrayOutputStream out, int value) {
    out.write(value & 0xff);
    out.write((value >>> 8) & 0xff);
    out.write((value >>> 16) & 0xff);
    out.write((value >>> 24) & 0xff);
}
```

Keep helper names English and package-private or private. The factory must expose only `writeFixture(...)` and `buildFixture(...)`.

- [ ] **Step 4: Replace private fixture calls in `VOSParserTest`**

Replace calls like:

```java
File chartFile = writeFixture("known.vos", 7, true, true, false);
```

with:

```java
File chartFile = VosFixtureFactory.writeFixture(tempDir, "known.vos", 7, true, true, false);
```

- [ ] **Step 5: Verify parser tests pass**

Run:

```bash
mvn -s .mvn/settings.xml -Dtest=VOSParserTest,VOSChartTest test
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/test/java/org/open2jam/parsers/VosFixtureFactory.java src/test/java/org/open2jam/parsers/VOSParserTest.java
git commit -m "test: extract VOS fixture factory"
```

---

## Loop 2: Java JSON Writer And Export Models

**Hypothesis:** A deterministic internal JSON writer reduces exporter risk without adding a dependency.

**Scope:** Add JSON writing infrastructure only. No CLI flags yet.

**Files:**
- Create: `src/org/open2jam/export/JsonWriter.java`
- Create: `src/test/java/org/open2jam/export/JsonWriterTest.java`

- [ ] **Step 1: Write failing JSON writer test**

Create `JsonWriterTest`:

```java
package org.open2jam.export;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class JsonWriterTest {
    @Test
    void escapesStringsDeterministically() {
        assertEquals("\"line\\nquote\\\"slash\\\\\"", JsonWriter.string("line\nquote\"slash\\"));
    }

    @Test
    void writesObjectWithStableFieldOrder() {
        String json = JsonWriter.object(
                JsonWriter.field("schemaVersion", 1),
                JsonWriter.field("format", "VOS"),
                JsonWriter.field("ready", true));

        assertEquals("{\"schemaVersion\":1,\"format\":\"VOS\",\"ready\":true}", json);
    }

    @Test
    void writesArrays() {
        String json = JsonWriter.array(JsonWriter.string("a"), JsonWriter.string("b"));

        assertEquals("[\"a\",\"b\"]", json);
    }
}
```

- [ ] **Step 2: Run failing test**

Run:

```bash
mvn -s .mvn/settings.xml -Dtest=JsonWriterTest test
```

Expected: FAIL because `JsonWriter` does not exist.

- [ ] **Step 3: Implement `JsonWriter`**

Create `JsonWriter.java`:

```java
package org.open2jam.export;

final class JsonWriter {
    private JsonWriter() {
    }

    static String object(String... fields) {
        StringBuilder out = new StringBuilder();
        out.append('{');
        for (int i = 0; i < fields.length; i++) {
            if (i > 0) {
                out.append(',');
            }
            out.append(fields[i]);
        }
        out.append('}');
        return out.toString();
    }

    static String array(String... values) {
        StringBuilder out = new StringBuilder();
        out.append('[');
        for (int i = 0; i < values.length; i++) {
            if (i > 0) {
                out.append(',');
            }
            out.append(values[i]);
        }
        out.append(']');
        return out.toString();
    }

    static String field(String name, String value) {
        return string(name) + ":" + string(value);
    }

    static String field(String name, int value) {
        return string(name) + ":" + value;
    }

    static String field(String name, double value) {
        if (Double.isNaN(value) || Double.isInfinite(value)) {
            return string(name) + ":0.0";
        }
        return string(name) + ":" + value;
    }

    static String field(String name, boolean value) {
        return string(name) + ":" + value;
    }

    static String rawField(String name, String rawJson) {
        return string(name) + ":" + rawJson;
    }

    static String string(String value) {
        StringBuilder out = new StringBuilder();
        out.append('"');
        for (int i = 0; i < value.length(); i++) {
            char c = value.charAt(i);
            switch (c) {
                case '"':
                    out.append("\\\"");
                    break;
                case '\\':
                    out.append("\\\\");
                    break;
                case '\n':
                    out.append("\\n");
                    break;
                case '\r':
                    out.append("\\r");
                    break;
                case '\t':
                    out.append("\\t");
                    break;
                default:
                    if (c < 0x20) {
                        out.append(String.format("\\u%04x", (int) c));
                    } else {
                        out.append(c);
                    }
                    break;
            }
        }
        out.append('"');
        return out.toString();
    }
}
```

- [ ] **Step 4: Verify JSON writer**

Run:

```bash
mvn -s .mvn/settings.xml -Dtest=JsonWriterTest test
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/org/open2jam/export/JsonWriter.java src/test/java/org/open2jam/export/JsonWriterTest.java
git commit -m "feat: add exporter JSON writer"
```

---

## Loop 3: VOS Catalog Exporter

**Hypothesis:** Catalog export is the first real Java/Godot bridge. It proves the exporter can scan VOS input without starting Swing.

**Scope:** Produce catalog JSON from `.vos` file or directory. No gameplay or audio export.

**Files:**
- Create: `src/org/open2jam/export/VosCatalogExporter.java`
- Create: `src/test/java/org/open2jam/export/VosCatalogExporterTest.java`

- [ ] **Step 1: Write failing catalog test**

```java
package org.open2jam.export;

import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.File;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.api.Test;
import org.open2jam.parsers.VosFixtureFactory;

class VosCatalogExporterTest {
    @TempDir
    File tempDir;

    @Test
    void exportsVosCatalogEntry() throws Exception {
        File chart = VosFixtureFactory.writeFixture(tempDir, "canon.vos", 7, true, true, false);

        String json = new VosCatalogExporter().exportCatalog(chart);

        assertTrue(json.contains("\"schemaVersion\":1"));
        assertTrue(json.contains("\"format\":\"VOS\""));
        assertTrue(json.contains("\"title\":\"Canon in D\""));
        assertTrue(json.contains("\"artist\":\"Pachelbel\""));
        assertTrue(json.contains("\"level\":7"));
        assertTrue(json.contains("\"levelKnown\":true"));
        assertTrue(json.contains("\"sourcePath\":\"" + chart.getCanonicalPath().replace("\\", "\\\\") + "\""));
    }
}
```

- [ ] **Step 2: Run failing test**

Run:

```bash
mvn -s .mvn/settings.xml -Dtest=VosCatalogExporterTest test
```

Expected: FAIL because `VosCatalogExporter` does not exist.

- [ ] **Step 3: Implement catalog exporter**

Create `VosCatalogExporter` with this public method:

```java
package org.open2jam.export;

import java.io.File;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.List;
import org.open2jam.parsers.Chart;
import org.open2jam.parsers.ChartList;
import org.open2jam.parsers.ChartParser;
import org.open2jam.parsers.VOSChart;

public final class VosCatalogExporter {
    public String exportCatalog(File input) throws Exception {
        List<String> entries = new ArrayList<String>();
        for (Chart chart : loadCharts(input)) {
            if (chart instanceof VOSChart) {
                entries.add(entry((VOSChart) chart));
            }
        }
        return JsonWriter.object(
                JsonWriter.field("schemaVersion", 1),
                JsonWriter.rawField("entries", JsonWriter.array(entries.toArray(new String[0]))));
    }

    private List<Chart> loadCharts(File input) {
        List<Chart> charts = new ArrayList<Chart>();
        if (input.isFile()) {
            ChartList parsed = ChartParser.parseFile(input);
            if (parsed != null) {
                charts.addAll(parsed);
            }
            return charts;
        }
        File[] files = input.listFiles();
        if (files == null) {
            return charts;
        }
        for (File file : files) {
            charts.addAll(loadCharts(file));
        }
        return charts;
    }

    private String entry(VOSChart chart) throws Exception {
        File source = chart.getSource().getCanonicalFile();
        return JsonWriter.object(
                JsonWriter.field("id", idFor(source)),
                JsonWriter.field("format", "VOS"),
                JsonWriter.field("sourcePath", source.getPath()),
                JsonWriter.field("title", chart.getTitle()),
                JsonWriter.field("artist", chart.getArtist()),
                JsonWriter.field("noter", chart.getNoter()),
                JsonWriter.field("genre", chart.getGenre()),
                JsonWriter.field("keys", chart.getKeys()),
                JsonWriter.field("level", chart.getLevel()),
                JsonWriter.field("levelKnown", chart.hasKnownLevel()),
                JsonWriter.field("bpm", chart.getBPM()),
                JsonWriter.field("durationMs", chart.getDuration() * 1000),
                JsonWriter.field("noteCount", chart.getNoteCount()),
                JsonWriter.field("coverAsset", ""),
                JsonWriter.field("exportStatus", "ready"));
    }

    private String idFor(File source) throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        byte[] bytes = source.getCanonicalPath().getBytes(java.nio.charset.StandardCharsets.UTF_8);
        byte[] hash = digest.digest(bytes);
        StringBuilder out = new StringBuilder("vos:sha256:");
        for (int i = 0; i < 8; i++) {
            out.append(String.format("%02x", hash[i]));
        }
        return out.toString();
    }
}
```

- [ ] **Step 4: Verify catalog exporter**

Run:

```bash
mvn -s .mvn/settings.xml -Dtest=VosCatalogExporterTest test
```

Expected: PASS.

- [ ] **Step 5: Run parser regression**

Run:

```bash
mvn -s .mvn/settings.xml -Dtest=VOSParserTest,VOSChartTest,VosCatalogExporterTest test
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/org/open2jam/export/VosCatalogExporter.java src/test/java/org/open2jam/export/VosCatalogExporterTest.java
git commit -m "feat: export VOS catalog JSON"
```

---

## Loop 4: VOS Gameplay Exporter

**Hypothesis:** Godot should consume time-based notes, not legacy measure/position data. Java should compile event timing before export.

**Scope:** Export normalized `notes` and `autoPlayEvents` for one VOS chart. Audio files are not exported in this loop.

**Files:**
- Create: `src/org/open2jam/export/VosGameplayExporter.java`
- Create: `src/test/java/org/open2jam/export/VosGameplayExporterTest.java`

- [ ] **Step 1: Write failing gameplay test**

```java
package org.open2jam.export;

import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.File;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.open2jam.parsers.VosFixtureFactory;

class VosGameplayExporterTest {
    @TempDir
    File tempDir;

    @Test
    void exportsPlayableAndAutoplayEvents() throws Exception {
        File chart = VosFixtureFactory.writeFixture(tempDir, "playable.vos", 7, true, true, true);

        String json = new VosGameplayExporter().exportGameplay(chart);

        assertTrue(json.contains("\"schemaVersion\":1"));
        assertTrue(json.contains("\"format\":\"VOS\""));
        assertTrue(json.contains("\"keys\":7"));
        assertTrue(json.contains("\"notes\":["));
        assertTrue(json.contains("\"lane\":"));
        assertTrue(json.contains("\"startMs\":"));
        assertTrue(json.contains("\"sampleId\":"));
        assertTrue(json.contains("\"autoPlayEvents\":["));
    }
}
```

- [ ] **Step 2: Run failing test**

Run:

```bash
mvn -s .mvn/settings.xml -Dtest=VosGameplayExporterTest test
```

Expected: FAIL because `VosGameplayExporter` does not exist.

- [ ] **Step 3: Implement event export**

`VosGameplayExporter` must:

- Parse the file with `ChartParser.parseFile(file)`.
- Select the first `VOSChart`.
- Compile events with `RenderTimingCompiler.compile(...)`.
- Map `NOTE_1..NOTE_7` to lane `0..6`.
- Map `AUTO_PLAY` to `autoPlayEvents`.
- Include `sampleId`, `volume`, and `pan` from `Event.SoundSample`.

Use this lane helper:

```java
private int laneFor(Event.Channel channel) {
    switch (channel) {
        case NOTE_1:
            return 0;
        case NOTE_2:
            return 1;
        case NOTE_3:
            return 2;
        case NOTE_4:
            return 3;
        case NOTE_5:
            return 4;
        case NOTE_6:
            return 5;
        case NOTE_7:
            return 6;
        default:
            return -1;
    }
}
```

For hold notes, first implementation may export `HOLD` and `RELEASE` as separate records with `kind` set to `holdStart` and `holdEnd`. Godot will merge them in Loop 9.

- [ ] **Step 4: Verify gameplay exporter**

Run:

```bash
mvn -s .mvn/settings.xml -Dtest=VosGameplayExporterTest test
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/org/open2jam/export/VosGameplayExporter.java src/test/java/org/open2jam/export/VosGameplayExporterTest.java
git commit -m "feat: export VOS gameplay JSON"
```

---

## Loop 5: VOS Audio Exporter

**Hypothesis:** Godot should receive ordinary WAV assets, not embedded MIDI bytes.

**Scope:** Render VOS samples into WAV files and emit `audio-manifest.json`. No Godot playback yet.

**Files:**
- Create: `src/org/open2jam/export/VosAudioExporter.java`
- Create: `src/org/open2jam/export/ExportPaths.java`
- Create: `src/test/java/org/open2jam/export/VosAudioExporterTest.java`

- [ ] **Step 1: Write failing audio export test**

```java
package org.open2jam.export;

import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.File;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.open2jam.parsers.VosFixtureFactory;

class VosAudioExporterTest {
    @TempDir
    File tempDir;

    @Test
    void exportsManifestAndWavAssets() throws Exception {
        File chart = VosFixtureFactory.writeFixture(tempDir, "audio.vos", 7, true, true, false);
        File assetDir = new File(tempDir, "assets");

        String json = new VosAudioExporter().exportAudio(chart, assetDir);

        assertTrue(json.contains("\"schemaVersion\":1"));
        assertTrue(json.contains("\"assets\":["));
        assertTrue(json.contains("\"type\":\"wav\""));
        assertTrue(json.contains("\"role\":\""));
        assertTrue(assetDir.isDirectory());
        assertTrue(assetDir.listFiles().length > 0);
    }
}
```

- [ ] **Step 2: Run failing test**

Run:

```bash
mvn -s .mvn/settings.xml -Dtest=VosAudioExporterTest test
```

Expected: FAIL because `VosAudioExporter` does not exist.

- [ ] **Step 3: Implement WAV export**

Use existing classes:

- `VOSChart.getSamples()`
- `SampleData.copyTo(...)`
- `MidiSampleRenderer.render(...)`

Write WAV assets with a small local method:

```java
private void writeLittleEndianInt(OutputStream out, int value) throws IOException {
    out.write(value & 0xff);
    out.write((value >>> 8) & 0xff);
    out.write((value >>> 16) & 0xff);
    out.write((value >>> 24) & 0xff);
}
```

The exporter must create files named `sample-<id>.wav` under the provided asset directory.

- [ ] **Step 4: Verify audio exporter**

Run:

```bash
mvn -s .mvn/settings.xml -Dtest=VosAudioExporterTest test
```

Expected: PASS.

- [ ] **Step 5: Run VOS audio regression**

Run:

```bash
mvn -s .mvn/settings.xml -Dtest=VosAudioExporterTest,VOSReferenceAudioRenderTest,RenderVosKeysoundTest test
```

Expected: PASS or external-reference tests skipped when reference files are unavailable.

- [ ] **Step 6: Commit**

```bash
git add src/org/open2jam/export/VosAudioExporter.java src/org/open2jam/export/ExportPaths.java src/test/java/org/open2jam/export/VosAudioExporterTest.java
git commit -m "feat: export VOS audio manifest"
```

---

## Loop 6: Export CLI

**Hypothesis:** Godot needs a stable process boundary. Adding CLI flags proves the Java side can run without Swing.

**Scope:** Add CLI flags for catalog, gameplay, audio, and selected export.

**Files:**
- Create: `src/org/open2jam/export/VosExportCli.java`
- Modify: `src/org/open2jam/Main.java`
- Create: `src/test/java/org/open2jam/MainVosExportCliTest.java`

- [ ] **Step 1: Write failing CLI test**

```java
package org.open2jam;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.PrintStream;
import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.open2jam.parsers.VosFixtureFactory;

class MainVosExportCliTest {
    @TempDir
    File tempDir;

    @Test
    void exportsVosCatalogFromCliWithoutStartingGui() throws Exception {
        File chart = VosFixtureFactory.writeFixture(tempDir, "cli.vos", 7, true, true, false);
        File output = new File(tempDir, "catalog.json");
        ByteArrayOutputStream stdout = new ByteArrayOutputStream();
        ByteArrayOutputStream stderr = new ByteArrayOutputStream();

        int status = Main.runCli(new String[] {
                "--export-vos-catalog",
                "--output", output.getAbsolutePath(),
                chart.getAbsolutePath()
        }, new PrintStream(stdout, true, StandardCharsets.UTF_8),
                new PrintStream(stderr, true, StandardCharsets.UTF_8));

        assertEquals(0, status);
        assertTrue(output.isFile());
        assertTrue(new String(java.nio.file.Files.readAllBytes(output.toPath()), StandardCharsets.UTF_8)
                .contains("\"format\":\"VOS\""));
        assertEquals("", stderr.toString(StandardCharsets.UTF_8));
    }
}
```

- [ ] **Step 2: Run failing CLI test**

Run:

```bash
mvn -s .mvn/settings.xml -Dtest=MainVosExportCliTest test
```

Expected: FAIL because `--export-vos-catalog` returns `-1`.

- [ ] **Step 3: Implement `VosExportCli` and route from `Main.runCli`**

Add to `Main.runCli(...)` before existing validate commands:

```java
if (org.open2jam.export.VosExportCli.isExportCommand(args[0])) {
    return org.open2jam.export.VosExportCli.run(args, out, err);
}
```

`VosExportCli` must support:

- `--export-vos-catalog --output <file> <file-or-directory>`
- `--export-vos-gameplay --output <file> <file.vos>`
- `--export-vos-audio --output <manifest> --asset-dir <directory> <file.vos>`
- `--export-vos-selected --out-dir <directory> <file.vos>`

- [ ] **Step 4: Verify CLI tests**

Run:

```bash
mvn -s .mvn/settings.xml -Dtest=MainVosExportCliTest,MainVosAudioCliTest test
```

Expected: PASS or external-reference tests skipped when reference files are unavailable.

- [ ] **Step 5: Commit**

```bash
git add src/org/open2jam/export/VosExportCli.java src/org/open2jam/Main.java src/test/java/org/open2jam/MainVosExportCliTest.java
git commit -m "feat: add VOS export CLI"
```

---

## Loop 7: Godot Project And State Machine

**Hypothesis:** The game experience must be driven by an explicit state machine before UI polish.

**Scope:** Create Godot project, app state script, and headless state transition test. No Java invocation.

**Files:**
- Create: `rewrite/godot/project.godot`
- Create: `rewrite/godot/scenes/main.tscn`
- Create: `rewrite/godot/scripts/app_state.gd`
- Create: `rewrite/godot/scripts/tests/app_state_test.gd`

- [ ] **Step 1: Create failing state test**

```gdscript
extends SceneTree

const AppState := preload("res://scripts/app_state.gd")

func _init() -> void:
    var state := AppState.new()
    assert(state.current() == "boot")
    state.transition_to("main_menu")
    assert(state.current() == "main_menu")
    state.transition_to("song_select")
    assert(state.current() == "song_select")
    state.transition_to("loading")
    state.transition_to("gameplay")
    state.transition_to("result")
    state.transition_to("song_select")
    assert(state.current() == "song_select")
    quit(0)
```

- [ ] **Step 2: Run failing Godot test**

Run:

```bash
godot --headless --path rewrite/godot --script res://scripts/tests/app_state_test.gd
```

Expected: FAIL because the Godot project or script does not exist.

- [ ] **Step 3: Implement project and `app_state.gd`**

`app_state.gd`:

```gdscript
extends RefCounted

const BOOT := "boot"
const MAIN_MENU := "main_menu"
const SETTINGS := "settings"
const SONG_SELECT := "song_select"
const LOADING := "loading"
const GAMEPLAY := "gameplay"
const RESULT := "result"

var _current := BOOT

func current() -> String:
    return _current

func transition_to(next: String) -> void:
    if not _can_transition(_current, next):
        push_error("Invalid app state transition: %s -> %s" % [_current, next])
        return
    _current = next

func _can_transition(from: String, to: String) -> bool:
    var allowed := {
        BOOT: [MAIN_MENU],
        MAIN_MENU: [SETTINGS, SONG_SELECT],
        SETTINGS: [MAIN_MENU],
        SONG_SELECT: [MAIN_MENU, LOADING],
        LOADING: [GAMEPLAY, SONG_SELECT],
        GAMEPLAY: [RESULT, SONG_SELECT],
        RESULT: [LOADING, SONG_SELECT, MAIN_MENU],
    }
    return allowed.get(from, []).has(to)
```

- [ ] **Step 4: Verify state test**

Run:

```bash
godot --headless --path rewrite/godot --script res://scripts/tests/app_state_test.gd
```

Expected: PASS with exit code `0`.

- [ ] **Step 5: Commit**

```bash
git add rewrite/godot/project.godot rewrite/godot/scenes/main.tscn rewrite/godot/scripts/app_state.gd rewrite/godot/scripts/tests/app_state_test.gd
git commit -m "feat: add Godot app state machine"
```

---

## Loop 8: Godot Settings And Catalog Loading

**Hypothesis:** Settings and catalog loading can be verified headlessly before UI exists.

**Scope:** Add settings persistence, catalog fixture, catalog loading, and filtering.

**Files:**
- Create: `rewrite/godot/scripts/settings_store.gd`
- Create: `rewrite/godot/scripts/catalog_store.gd`
- Create: `rewrite/godot/test/fixtures/catalog.json`
- Create: `rewrite/godot/scripts/tests/settings_store_test.gd`
- Create: `rewrite/godot/scripts/tests/catalog_store_test.gd`

- [ ] **Step 1: Add fixture catalog**

`rewrite/godot/test/fixtures/catalog.json`:

```json
{"schemaVersion":1,"entries":[{"id":"vos:fixture","format":"VOS","sourcePath":"/tmp/fixture.vos","title":"Canon in D","artist":"Pachelbel","noter":"ReVanTis","genre":"Classical","keys":7,"level":7,"levelKnown":true,"bpm":120.0,"durationMs":123000,"noteCount":2,"coverAsset":"","exportStatus":"ready"}]}
```

- [ ] **Step 2: Write settings and catalog tests**

`catalog_store_test.gd`:

```gdscript
extends SceneTree

const CatalogStore := preload("res://scripts/catalog_store.gd")

func _init() -> void:
    var store := CatalogStore.new()
    var ok := store.load_from_file("res://test/fixtures/catalog.json")
    assert(ok)
    assert(store.count() == 1)
    assert(store.filter("canon").size() == 1)
    assert(store.filter("missing").size() == 0)
    quit(0)
```

`settings_store_test.gd`:

```gdscript
extends SceneTree

const SettingsStore := preload("res://scripts/settings_store.gd")

func _init() -> void:
    var store := SettingsStore.new()
    store.set_song_directories(["/tmp/vos"])
    store.set_fullscreen_enabled(true)
    assert(store.song_directories()[0] == "/tmp/vos")
    assert(store.fullscreen_enabled())
    quit(0)
```

- [ ] **Step 3: Run failing tests**

Run:

```bash
godot --headless --path rewrite/godot --script res://scripts/tests/catalog_store_test.gd
godot --headless --path rewrite/godot --script res://scripts/tests/settings_store_test.gd
```

Expected: FAIL because scripts do not exist.

- [ ] **Step 4: Implement stores**

`settings_store.gd`:

```gdscript
extends RefCounted

var _song_directories: Array[String] = []
var _fullscreen_enabled := false

func set_song_directories(paths: Array[String]) -> void:
    _song_directories = paths

func song_directories() -> Array[String]:
    return _song_directories

func set_fullscreen_enabled(enabled: bool) -> void:
    _fullscreen_enabled = enabled

func fullscreen_enabled() -> bool:
    return _fullscreen_enabled
```

`catalog_store.gd`:

```gdscript
extends RefCounted

var _entries: Array[Dictionary] = []

func load_from_file(path: String) -> bool:
    if not FileAccess.file_exists(path):
        return false
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not (parsed is Dictionary):
        return false
    if int(parsed.get("schemaVersion", 0)) != 1:
        return false
    _entries.clear()
    for item in parsed.get("entries", []):
        if item is Dictionary:
            _entries.append(item)
    return true

func count() -> int:
    return _entries.size()

func filter(text: String) -> Array[Dictionary]:
    var needle := text.to_lower()
    var out: Array[Dictionary] = []
    for entry in _entries:
        var title := String(entry.get("title", "")).to_lower()
        var artist := String(entry.get("artist", "")).to_lower()
        if title.contains(needle) or artist.contains(needle):
            out.append(entry)
    return out
```

- [ ] **Step 5: Verify tests**

Run:

```bash
godot --headless --path rewrite/godot --script res://scripts/tests/catalog_store_test.gd
godot --headless --path rewrite/godot --script res://scripts/tests/settings_store_test.gd
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add rewrite/godot/scripts/settings_store.gd rewrite/godot/scripts/catalog_store.gd rewrite/godot/test/fixtures/catalog.json rewrite/godot/scripts/tests/settings_store_test.gd rewrite/godot/scripts/tests/catalog_store_test.gd
git commit -m "feat: load Godot settings and catalog"
```

---

## Loop 9: Godot Gameplay And Result Fixture Flow

**Hypothesis:** A fixture-driven gameplay flow proves the Godot runtime can complete a song before exporter integration.

**Scope:** Load fixture gameplay JSON, simulate scoring, and support retry/back state transitions.

**Files:**
- Create: `rewrite/godot/test/fixtures/gameplay.json`
- Create: `rewrite/godot/scripts/gameplay_loader.gd`
- Create: `rewrite/godot/scripts/score_state.gd`
- Create: `rewrite/godot/scripts/result_model.gd`
- Create: `rewrite/godot/scripts/gameplay_controller.gd`
- Create: `rewrite/godot/scripts/tests/gameplay_loader_test.gd`
- Create: `rewrite/godot/scripts/tests/result_flow_test.gd`

- [ ] **Step 1: Add gameplay fixture**

`gameplay.json`:

```json
{"schemaVersion":1,"chartId":"vos:fixture","format":"VOS","keys":7,"bpm":120.0,"durationMs":3000,"timingPoints":[{"timeMs":0.0,"bpm":120.0,"meter":4}],"notes":[{"id":1,"lane":0,"startMs":1000.0,"endMs":null,"sampleId":2,"volume":1.0,"pan":0.0,"kind":"tap"}],"autoPlayEvents":[{"timeMs":0.0,"sampleId":1,"volume":1.0,"pan":0.0}]}
```

- [ ] **Step 2: Write failing loader and result tests**

`gameplay_loader_test.gd`:

```gdscript
extends SceneTree

const GameplayLoader := preload("res://scripts/gameplay_loader.gd")

func _init() -> void:
    var loader := GameplayLoader.new()
    var chart := loader.load_from_file("res://test/fixtures/gameplay.json")
    assert(chart.get("chartId") == "vos:fixture")
    assert(chart.get("notes").size() == 1)
    quit(0)
```

`result_flow_test.gd`:

```gdscript
extends SceneTree

const ScoreState := preload("res://scripts/score_state.gd")
const ResultModel := preload("res://scripts/result_model.gd")

func _init() -> void:
    var score := ScoreState.new()
    score.apply_judgment("cool")
    score.apply_judgment("miss")
    var result := ResultModel.from_score("vos:fixture", score)
    assert(result["score"] > 0)
    assert(result["maxCombo"] == 1)
    assert(result["judgments"]["cool"] == 1)
    assert(result["judgments"]["miss"] == 1)
    quit(0)
```

- [ ] **Step 3: Run failing tests**

Run:

```bash
godot --headless --path rewrite/godot --script res://scripts/tests/gameplay_loader_test.gd
godot --headless --path rewrite/godot --script res://scripts/tests/result_flow_test.gd
```

Expected: FAIL because scripts do not exist.

- [ ] **Step 4: Implement loader and score model**

`score_state.gd`:

```gdscript
extends RefCounted

var score := 0
var combo := 0
var max_combo := 0
var judgments := {"cool": 0, "good": 0, "bad": 0, "miss": 0}

func apply_judgment(name: String) -> void:
    judgments[name] = int(judgments.get(name, 0)) + 1
    if name == "miss":
        combo = 0
        return
    combo += 1
    max_combo = max(max_combo, combo)
    if name == "cool":
        score += 1000
    elif name == "good":
        score += 500
    else:
        score += 100
```

`result_model.gd`:

```gdscript
extends RefCounted

static func from_score(chart_id: String, score_state: RefCounted) -> Dictionary:
    return {
        "chartId": chart_id,
        "score": score_state.score,
        "maxCombo": score_state.max_combo,
        "judgments": score_state.judgments.duplicate(true),
    }
```

- [ ] **Step 5: Verify tests**

Run:

```bash
godot --headless --path rewrite/godot --script res://scripts/tests/gameplay_loader_test.gd
godot --headless --path rewrite/godot --script res://scripts/tests/result_flow_test.gd
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add rewrite/godot/test/fixtures/gameplay.json rewrite/godot/scripts/gameplay_loader.gd rewrite/godot/scripts/score_state.gd rewrite/godot/scripts/result_model.gd rewrite/godot/scripts/gameplay_controller.gd rewrite/godot/scripts/tests/gameplay_loader_test.gd rewrite/godot/scripts/tests/result_flow_test.gd
git commit -m "feat: load Godot gameplay result flow"
```

---

## Loop 10: Godot Audio Manifest And End-to-End VOS Smoke

**Hypothesis:** The first useful milestone is a full VOS data path: Java exporter writes selected assets, Godot loads the manifest, and the app can complete the fixture flow.

**Scope:** Audio manifest loader, exporter client shell, and end-to-end smoke commands. Visual polish remains outside this loop.

**Files:**
- Create: `rewrite/godot/test/fixtures/audio-manifest.json`
- Create: `rewrite/godot/test/fixtures/sample.wav`
- Create: `rewrite/godot/scripts/audio_manifest_loader.gd`
- Create: `rewrite/godot/scripts/exporter_client.gd`
- Create: `rewrite/godot/scripts/tests/audio_manifest_loader_test.gd`
- Create: `rewrite/tools/verify_vos_godot_initial.sh`

- [ ] **Step 1: Add audio manifest fixture**

`audio-manifest.json`:

```json
{"schemaVersion":1,"chartId":"vos:fixture","assets":[{"sampleId":1,"path":"res://test/fixtures/sample.wav","type":"wav","role":"background","preload":true},{"sampleId":2,"path":"res://test/fixtures/sample.wav","type":"wav","role":"keysound","preload":false}]}
```

Create the placeholder file used by the loader test:

```bash
printf '' > rewrite/godot/test/fixtures/sample.wav
```

- [ ] **Step 2: Write failing audio manifest test**

```gdscript
extends SceneTree

const AudioManifestLoader := preload("res://scripts/audio_manifest_loader.gd")

func _init() -> void:
    var loader := AudioManifestLoader.new()
    var manifest := loader.load_from_file("res://test/fixtures/audio-manifest.json")
    assert(manifest.get("chartId") == "vos:fixture")
    assert(manifest.get("assets").size() == 2)
    quit(0)
```

- [ ] **Step 3: Run failing test**

Run:

```bash
godot --headless --path rewrite/godot --script res://scripts/tests/audio_manifest_loader_test.gd
```

Expected: FAIL because loader script does not exist.

- [ ] **Step 4: Implement manifest loader**

`audio_manifest_loader.gd`:

```gdscript
extends RefCounted

func load_from_file(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not (parsed is Dictionary):
        return {}
    if int(parsed.get("schemaVersion", 0)) != 1:
        return {}
    for asset in parsed.get("assets", []):
        if not (asset is Dictionary):
            return {}
        if not FileAccess.file_exists(String(asset.get("path", ""))):
            return {}
    return parsed
```

- [ ] **Step 5: Add verification script**

`rewrite/tools/verify_vos_godot_initial.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

mvn -s .mvn/settings.xml -Dtest=JsonWriterTest,VosCatalogExporterTest,VosGameplayExporterTest,VosAudioExporterTest,MainVosExportCliTest test
godot --headless --path rewrite/godot --script res://scripts/tests/app_state_test.gd
godot --headless --path rewrite/godot --script res://scripts/tests/settings_store_test.gd
godot --headless --path rewrite/godot --script res://scripts/tests/catalog_store_test.gd
godot --headless --path rewrite/godot --script res://scripts/tests/gameplay_loader_test.gd
godot --headless --path rewrite/godot --script res://scripts/tests/audio_manifest_loader_test.gd
godot --headless --path rewrite/godot --script res://scripts/tests/result_flow_test.gd
```

- [ ] **Step 6: Verify loop**

Run:

```bash
bash rewrite/tools/verify_vos_godot_initial.sh
```

Expected: PASS if `godot` is installed and on `PATH`. If `godot` is missing, Java tests must pass and the missing executable is reported as an environment blocker.

- [ ] **Step 7: Commit**

```bash
git add rewrite/godot/test/fixtures/audio-manifest.json rewrite/godot/test/fixtures/sample.wav rewrite/godot/scripts/audio_manifest_loader.gd rewrite/godot/scripts/exporter_client.gd rewrite/godot/scripts/tests/audio_manifest_loader_test.gd rewrite/tools/verify_vos_godot_initial.sh
git commit -m "feat: verify VOS Godot initial flow"
```

---

## Final Verification

After Loop 10, run:

```bash
mvn -s .mvn/settings.xml test
bash rewrite/tools/verify_vos_godot_initial.sh
```

Expected:

- Maven tests pass.
- Godot headless tests pass when Godot is installed.
- `rewrite/tools/verify_vos_godot_initial.sh` is the single regression command for the VOS initial version.

Manual acceptance after automated verification:

1. Build the jar:

```bash
mvn -s .mvn/settings.xml -DskipTests package
```

2. Export a real VOS chart:

```bash
java -jar target/open2jam-0.1.2.jar --export-vos-selected --out-dir /tmp/open2jam-vos-selected /path/to/song.vos
```

3. Run Godot project:

```bash
godot --path rewrite/godot
```

4. Verify:

- App starts.
- Settings can store a VOS directory.
- SongSelect shows at least one VOS chart.
- Loading accepts exported gameplay and audio manifest.
- Gameplay completes a chart.
- Result shows score and judgment counts.
- Retry restarts the selected chart.
- Back returns to SongSelect with selection preserved.
