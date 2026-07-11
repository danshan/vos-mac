# Java-Free Golden Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repair the current migration gates and freeze a hermetic, reproducible Java oracle for VOS, OJN/OJM, and osu!mania before any production Java behavior is replaced.

**Architecture:** Reuse the existing Java fixture builders and exporters to generate small self-authored source files and deterministic expected artifacts under `rewrite/golden/java-migration`. A strict verifier checks provenance, source/output hashes, reproduction, and the absence of optional external-path skips. This phase changes tests and migration artifacts only; it does not introduce Rust or change production runtime behavior.

**Tech Stack:** Java 17, Maven 3.9.9, JUnit Jupiter 5, Bash, existing Open2Jam parsers/exporters, Godot 4.6.3 only for the repaired aggregate gate.

## Global Constraints

- Run Java and Maven through mise and `.mvn/settings.xml`; never use host `java` or `mvn` as the project verdict.
- Golden source files must be self-authored by fixture factories and safe to commit.
- Golden generation uses the fixed canonical work root `/tmp/open2jam-java-golden-v1` so path-derived IDs remain deterministic.
- Golden provenance records Java source commit `05257da` and mise Java tool `zulu-17.66.19.0`.
- Selected migration tests must not use `assumeTrue`, `/Users/...`, downloads, or machine-local song directories.
- Java goldens are generated only by the explicit generator command; normal tests are read-only.
- VOS Java WAV bytes are frozen as historical evidence, but later Rust VOS parity follows ADR 0003 and does not require Java PCM byte equality.
- Do not change production parser/export behavior in this phase.
- Every task follows RED, GREEN, focused regression, and commit.

## File Map

- `rewrite/tools/test_verify_vos_godot_manifest.sh`: statically verifies that aggregate test manifests reference live tests and no retired contract.
- `src/test/java/org/open2jam/parsers/OjnFixtureFactory.java`: creates a minimal OJN plus plain OJM pair.
- `src/test/java/org/open2jam/parsers/OsuFixtureFactory.java`: creates deterministic `.osu`, `.osz`, and referenced audio fixtures.
- `src/test/java/org/open2jam/export/MigrationGoldenCorpusGenerator.java`: explicit Java oracle generator.
- `src/test/java/org/open2jam/export/MigrationGoldenCorpusTest.java`: read-only manifest and reproduction gate.
- `rewrite/golden/java-migration/`: committed sources, expected outputs, hashes, provenance, and usage rules.
- `rewrite/tools/verify_java_migration_goldens.sh`: no-skip Phase 0 verifier.
- `rewrite/tools/test_verify_java_migration_goldens.sh`: contract test for the verifier.

---

### Task 1: Repair stale aggregate verification manifests

**Files:**
- Create: `rewrite/tools/test_verify_vos_godot_manifest.sh`
- Modify: `rewrite/tools/verify_vos_godot_initial.sh:4-56,174-175`
- Modify: `rewrite/tools/verify_vos_godot_java_parity.sh:138`
- Test: `rewrite/tools/test_verify_vos_godot_manifest.sh`

**Interfaces:**
- Consumes: test class names in `JAVA_TESTS`, `run_godot_test res://...` declarations, and fixture-key assertions in existing aggregate scripts.
- Produces: `bash rewrite/tools/test_verify_vos_godot_manifest.sh`, a fast static gate that exits 0 only when every declared test exists and retired Partytime/network-status requirements are absent.

- [ ] **Step 1: Write the failing manifest contract test**

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

INITIAL="rewrite/tools/verify_vos_godot_initial.sh"
PARITY="rewrite/tools/verify_vos_godot_java_parity.sh"

while IFS= read -r resource_path; do
  local_path="rewrite/godot/${resource_path#res://}"
  if [[ ! -f "$local_path" ]]; then
    printf 'Missing declared Godot test: %s\n' "$local_path" >&2
    exit 1
  fi
done < <(sed -n 's/^[[:space:]]*run_godot_test \(res:\/\/[^[:space:]]*\)$/\1/p' "$INITIAL")

for class_name in \
  OsuManiaParserTest ChartModelLoaderTest MusicSelectionSelectionTest \
  ChartDisplayTest ConfigTest JudgmentStrategyOracleFixtureTest; do
  if ! grep -Eq "^[[:space:]]*${class_name}[[:space:]]*$" "$INITIAL"; then
    printf 'Missing Java test from aggregate gate: %s\n' "$class_name" >&2
    exit 1
  fi
done

if grep -Eq 'partytime_(client|server)_test|networkStatusTextLayout' "$INITIAL" "$PARITY"; then
  printf 'Aggregate verification still contains a retired contract.\n' >&2
  exit 1
fi

printf 'Aggregate verification manifest contract passed.\n'
```

- [ ] **Step 2: Run the test and verify RED**

Run: `bash rewrite/tools/test_verify_vos_godot_manifest.sh`

Expected: FAIL, first on `rewrite/godot/scripts/tests/partytime_client_test.gd` or a missing Java test declaration.

- [ ] **Step 3: Repair the aggregate declarations**

Add these existing classes to `JAVA_TESTS`:

```bash
	OsuManiaParserTest
	ChartModelLoaderTest
	MusicSelectionSelectionTest
	ChartDisplayTest
	ConfigTest
	JudgmentStrategyOracleFixtureTest
```

Remove only these stale Godot declarations:

```bash
run_godot_test res://scripts/tests/partytime_client_test.gd
run_godot_test res://scripts/tests/partytime_server_test.gd
```

Remove the obsolete `networkStatusTextLayout` fixture assertion from `verify_vos_godot_java_parity.sh`. Keep the remaining render/status assertions unchanged.

- [ ] **Step 4: Run the narrow and syntax gates**

Run: `bash rewrite/tools/test_verify_vos_godot_manifest.sh`

Expected: PASS with `Aggregate verification manifest contract passed.`

Run: `bash -n rewrite/tools/verify_vos_godot_initial.sh rewrite/tools/verify_vos_godot_java_parity.sh rewrite/tools/test_verify_vos_godot_manifest.sh`

Expected: PASS with no output.

- [ ] **Step 5: Commit**

```bash
git add rewrite/tools/test_verify_vos_godot_manifest.sh rewrite/tools/verify_vos_godot_initial.sh rewrite/tools/verify_vos_godot_java_parity.sh
git commit -m "test: repair Godot parity manifests"
```

---

### Task 2: Extract a hermetic OJN/OJM fixture pair

**Files:**
- Create: `src/test/java/org/open2jam/parsers/OjnFixtureFactory.java`
- Create: `src/test/java/org/open2jam/parsers/OjnFixtureFactoryTest.java`
- Modify: `src/test/java/org/open2jam/export/VosCatalogExporterTest.java:177-229`
- Modify: `src/test/java/org/open2jam/export/VosAudioExporterTest.java:56-71`
- Test: `src/test/java/org/open2jam/parsers/OjnFixtureFactoryTest.java`
- Test: `src/test/java/org/open2jam/export/VosCatalogExporterTest.java`
- Test: `src/test/java/org/open2jam/export/VosAudioExporterTest.java`

**Interfaces:**
- Consumes: current OJN header layout from `VosCatalogExporterTest.writeOjnFixture`, plain OJM layout parsed by `OJMParser`, and the existing WAV exporter contract.
- Produces: `OjnFixtureFactory.writeFixture(File directory, String baseName) -> OjnFixture`, where `OjnFixture.chart()` is `<baseName>.ojn` and `OjnFixture.samples()` is `<baseName>.ojm`.

- [ ] **Step 1: Write the failing factory behavior test**

```java
package org.open2jam.parsers;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.File;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.open2jam.parsers.utils.SampleData;

class OjnFixtureFactoryTest {
    @TempDir
    File tempDir;

    @Test
    void writesThreeChartOjnWithOnePlainOjmWavSample() throws Exception {
        OjnFixtureFactory.OjnFixture fixture = OjnFixtureFactory.writeFixture(tempDir, "o2jam");

        ChartList charts = ChartParser.parseFile(fixture.chart());

        assertNotNull(charts);
        assertEquals(3, charts.size());
        assertEquals("O2Jam Fixture", charts.get(0).getTitle());
        assertEquals(3, charts.get(0).getLevel());
        assertEquals(5, charts.get(1).getLevel());
        assertEquals(8, charts.get(2).getLevel());
        assertTrue(fixture.samples().isFile());
        assertTrue(charts.get(0).getSamples().containsKey(0));
        assertEquals(SampleData.Type.WAV, charts.get(0).getSamples().get(0).getType());
    }
}
```

- [ ] **Step 2: Run the test and verify RED**

Run: `mise exec -- bash -lc 'mvn -s "$MAVEN_SETTINGS" -Dtest=OjnFixtureFactoryTest test'`

Expected: FAIL to compile because `OjnFixtureFactory` does not exist.

- [ ] **Step 3: Implement the fixture factory**

Create the public factory and move the existing 300-byte OJN header builder from `VosCatalogExporterTest.writeOjnFixture` into `writeOjn` without changing field values. Parameterize only the base name and OJM file name.

Use this exact public surface and plain OJM writer:

```java
package org.open2jam.parsers;

import java.io.File;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;

public final class OjnFixtureFactory {
    private static final int OJM_SIGNATURE = 0x004D4A4F;

    private OjnFixtureFactory() {
    }

    public record OjnFixture(File chart, File samples) {
    }

    public static OjnFixture writeFixture(File directory, String baseName) throws Exception {
        File chart = new File(directory, baseName + ".ojn");
        File samples = new File(directory, baseName + ".ojm");
        writeOjn(chart, samples.getName());
        writePlainOjm(samples);
        return new OjnFixture(chart, samples);
    }

    private static void writePlainOjm(File file) throws Exception {
        byte[] pcm = new byte[] {0, 0, 0, 0};
        int oggStart = 20 + 56 + pcm.length;
        ByteBuffer buffer = ByteBuffer.allocate(oggStart).order(ByteOrder.LITTLE_ENDIAN);
        buffer.putInt(OJM_SIGNATURE);
        buffer.putShort((short) 0);
        buffer.putShort((short) 0);
        buffer.putInt(20);
        buffer.putInt(oggStart);
        buffer.putInt(oggStart);
        putFixedString(buffer, "fixture.wav", 32);
        buffer.putShort((short) 1);
        buffer.putShort((short) 1);
        buffer.putInt(8000);
        buffer.putInt(16000);
        buffer.putShort((short) 2);
        buffer.putShort((short) 16);
        buffer.putInt(0x61746164);
        buffer.putInt(pcm.length);
        buffer.put(pcm);
        Files.write(file.toPath(), buffer.array());
    }

    private static void writeOjn(File chart, String ojmName) throws Exception {
        ByteBuffer buffer = ByteBuffer.allocate(300).order(ByteOrder.LITTLE_ENDIAN);
        buffer.putInt(100);
        buffer.putInt(0x006E6A6F);
        buffer.putFloat(2.0f);
        buffer.putInt(2);
        buffer.putFloat(130.0f);
        buffer.putShort((short) 3);
        buffer.putShort((short) 5);
        buffer.putShort((short) 8);
        buffer.putShort((short) 0);
        buffer.putInt(0);
        buffer.putInt(0);
        buffer.putInt(0);
        buffer.putInt(10);
        buffer.putInt(20);
        buffer.putInt(30);
        buffer.putInt(0);
        buffer.putInt(0);
        buffer.putInt(0);
        buffer.putInt(0);
        buffer.putInt(0);
        buffer.putInt(0);
        buffer.putShort((short) 0);
        buffer.putShort((short) 0);
        putFixedString(buffer, "", 20);
        buffer.putInt(0);
        buffer.putInt(1);
        putFixedString(buffer, "O2Jam Fixture", 64);
        putFixedString(buffer, "O2 Artist", 32);
        putFixedString(buffer, "O2 Noter", 32);
        putFixedString(buffer, ojmName, 32);
        buffer.putInt(0);
        buffer.putInt(91);
        buffer.putInt(91);
        buffer.putInt(91);
        buffer.putInt(300);
        buffer.putInt(300);
        buffer.putInt(300);
        buffer.putInt(300);
        Files.write(chart.toPath(), buffer.array());
    }

    private static void putFixedString(ByteBuffer buffer, String value, int length) {
        byte[] bytes = value.getBytes(StandardCharsets.US_ASCII);
        int written = Math.min(bytes.length, length);
        buffer.put(bytes, 0, written);
        for (int i = written; i < length; i++) {
            buffer.put((byte) 0);
        }
    }
}
```

- [ ] **Step 4: Replace external OJN setup in exporter tests**

In `VosCatalogExporterTest`, replace the private builder with:

```java
File chartFile = OjnFixtureFactory.writeFixture(tempDir, "o2jam").chart();
```

In `VosAudioExporterTest`, replace `/Users/honghao.shan/Music/demo/o2ma101.*` and `assumeTrue` with:

```java
OjnFixtureFactory.OjnFixture fixture = OjnFixtureFactory.writeFixture(tempDir, "audio-o2jam");
File assetDir = new File(tempDir, "ojn-audio");

String json = new VosAudioExporter().exportAudio(fixture.chart(), assetDir);

assertTrue(json.contains("\"format\":\"OJN\""));
assertTrue(json.contains("\"sampleId\":1"));
assertWavFile(new File(assetDir, "sample-1.wav"));
```

Remove only the now-unused `assumeTrue` import from `VosAudioExporterTest` if no other method uses it.

- [ ] **Step 5: Run focused tests**

Run: `mise exec -- bash -lc 'mvn -s "$MAVEN_SETTINGS" -Dtest=OjnFixtureFactoryTest,VosCatalogExporterTest,VosAudioExporterTest test'`

Expected: PASS, with no skipped OJN/OJM audio case.

- [ ] **Step 6: Commit**

```bash
git add src/test/java/org/open2jam/parsers/OjnFixtureFactory.java src/test/java/org/open2jam/parsers/OjnFixtureFactoryTest.java src/test/java/org/open2jam/export/VosCatalogExporterTest.java src/test/java/org/open2jam/export/VosAudioExporterTest.java
git commit -m "test: add hermetic OJN OJM fixture"
```

---

### Task 3: Extract hermetic osu!mania fixtures

**Files:**
- Create: `src/test/java/org/open2jam/parsers/OsuFixtureFactory.java`
- Create: `src/test/java/org/open2jam/parsers/OsuFixtureFactoryTest.java`
- Modify: `src/test/java/org/open2jam/parsers/OsuManiaParserTest.java:206-249`
- Modify: `src/test/java/org/open2jam/gui/ChartModelLoaderTest.java:16-45`
- Test: `src/test/java/org/open2jam/parsers/OsuFixtureFactoryTest.java`
- Test: `src/test/java/org/open2jam/parsers/OsuManiaParserTest.java`
- Test: `src/test/java/org/open2jam/gui/ChartModelLoaderTest.java`

**Interfaces:**
- Consumes: current `OsuManiaParserTest.buildFixtureContent(7)` and ZIP-writing behavior.
- Produces: `OsuFixtureFactory.writeSevenKeyOsu(File, String) -> File`, `writeSevenKeyOsz(File, String) -> File`, and `sevenKeyContent(String audioFilename) -> String`.

- [ ] **Step 1: Write the failing factory test**

```java
package org.open2jam.parsers;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

import java.io.File;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class OsuFixtureFactoryTest {
    @TempDir
    File tempDir;

    @Test
    void writesPlayableDirectoryAndArchiveFixtures() throws Exception {
        File chart = OsuFixtureFactory.writeSevenKeyOsu(tempDir, "seven-key.osu");
        File archive = OsuFixtureFactory.writeSevenKeyOsz(tempDir, "seven-key.osz");

        ChartList chartResult = ChartParser.parseFile(chart);
        ChartList archiveResult = ChartParser.parseFile(archive);

        assertNotNull(chartResult);
        assertNotNull(archiveResult);
        assertEquals(1, chartResult.size());
        assertEquals(1, archiveResult.size());
        assertEquals(7, chartResult.get(0).getKeys());
        assertEquals("Seven Key Fixture", archiveResult.get(0).getTitle());
    }
}
```

- [ ] **Step 2: Run the test and verify RED**

Run: `mise exec -- bash -lc 'mvn -s "$MAVEN_SETTINGS" -Dtest=OsuFixtureFactoryTest test'`

Expected: FAIL to compile because `OsuFixtureFactory` does not exist.

- [ ] **Step 3: Implement the factory using the existing exact chart text**

```java
package org.open2jam.parsers;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

public final class OsuFixtureFactory {
    private OsuFixtureFactory() {
    }

    public static File writeSevenKeyOsu(File directory, String name) throws Exception {
        File audio = new File(directory, "audio.wav");
        writeSilentWav(audio);
        File chart = new File(directory, name);
        Files.writeString(chart.toPath(), sevenKeyContent(audio.getName()), StandardCharsets.UTF_8);
        return chart;
    }

    public static File writeSevenKeyOsz(File directory, String name) throws Exception {
        File archive = new File(directory, name);
        try (ZipOutputStream zip = new ZipOutputStream(Files.newOutputStream(archive.toPath()))) {
            writeEntry(zip, "audio.wav", silentWav());
            writeEntry(zip, "seven-key.osu", sevenKeyContent("audio.wav").getBytes(StandardCharsets.UTF_8));
        }
        return archive;
    }

    public static String sevenKeyContent(String audioFilename) {
        return "osu file format v14\n\n"
                + "[General]\nAudioFilename: " + audioFilename + "\nMode: 3\n\n"
                + "[Metadata]\nTitle:Seven Key Fixture\nArtist:Fixture Artist\n"
                + "Creator:Fixture Creator\nVersion:Test 7K\n\n"
                + "[Difficulty]\nHPDrainRate:5\nCircleSize:7\nOverallDifficulty:8\n\n"
                + "[TimingPoints]\n0,500,4,2,1,60,1,0\n\n"
                + "[HitObjects]\n"
                + "36,192,0,1,0,0:0:0:0:\n"
                + "109,192,250,1,0,0:0:0:0:\n"
                + "182,192,500,1,0,0:0:0:0:\n"
                + "256,192,750,1,0,0:0:0:0:\n"
                + "329,192,1000,1,0,0:0:0:0:\n"
                + "402,192,1250,1,0,0:0:0:0:\n"
                + "475,192,1500,1,0,0:0:0:0:\n"
                + "256,192,2000,128,0,3000:0:0:0:0:\n";
    }

    private static void writeEntry(ZipOutputStream zip, String name, byte[] bytes) throws Exception {
        zip.putNextEntry(new ZipEntry(name));
        zip.write(bytes);
        zip.closeEntry();
    }

    private static void writeSilentWav(File file) throws Exception {
        Files.write(file.toPath(), silentWav());
    }

    private static byte[] silentWav() {
        return new byte[] {
                'R', 'I', 'F', 'F', 38, 0, 0, 0, 'W', 'A', 'V', 'E',
                'f', 'm', 't', ' ', 16, 0, 0, 0, 1, 0, 1, 0,
                64, 31, 0, 0, -128, 62, 0, 0, 2, 0, 16, 0,
                'd', 'a', 't', 'a', 2, 0, 0, 0, 0, 0
        };
    }
}
```

- [ ] **Step 4: Reuse the factory in parser and loader tests**

Replace `writeSevenKeyFixture()` in `OsuManiaParserTest` with `OsuFixtureFactory.writeSevenKeyOsu(tempDir, "seven-key.osu")`. Keep mutation-specific tests using `OsuFixtureFactory.sevenKeyContent("audio.wav")`.

Remove `REFERENCE_OSU_MANIA_DIR` and its `assumeTrue` import. Replace the setup and expected title in `ChartModelLoaderTest.loadsSevenKeyOsuManiaOszFromDirectoryIntoTableModel` with:

```java
import org.open2jam.parsers.OsuFixtureFactory;
```

```java
OsuFixtureFactory.writeSevenKeyOsz(tempDir, "seven-key.osz");
ArrayList<ChartList> charts = ChartModelLoader.loadChartLists(tempDir);

assertEquals(1, charts.size());
Chart chart = charts.get(0).get(0);
assertEquals(Chart.TYPE.OSU, chart.type);
assertEquals(7, chart.getKeys());
assertEquals("Seven Key Fixture", chart.getTitle());
assertEquals("osu!mania", chart.getGenre());

ChartListTableModel model = new ChartListTableModel();
model.setRawList(charts);
assertEquals("osu!mania", model.getValueAt(0, 2));
assertEquals("osu!mania", model.getValueAt(0, 3));
```

- [ ] **Step 5: Run focused tests**

Run: `mise exec -- bash -lc 'mvn -s "$MAVEN_SETTINGS" -Dtest=OsuFixtureFactoryTest,OsuManiaParserTest,ChartModelLoaderTest test'`

Expected: PASS with no skipped osu!mania case.

- [ ] **Step 6: Commit**

```bash
git add src/test/java/org/open2jam/parsers/OsuFixtureFactory.java src/test/java/org/open2jam/parsers/OsuFixtureFactoryTest.java src/test/java/org/open2jam/parsers/OsuManiaParserTest.java src/test/java/org/open2jam/gui/ChartModelLoaderTest.java
git commit -m "test: add hermetic osu mania fixtures"
```

---

### Task 4: Add an explicit Java golden corpus generator

**Files:**
- Create: `src/test/java/org/open2jam/export/MigrationGoldenCorpusGenerator.java`
- Create: `src/test/java/org/open2jam/export/MigrationGoldenCorpusGeneratorTest.java`
- Create: `rewrite/golden/java-migration/README.md`
- Create: generated files under `rewrite/golden/java-migration/sources/`
- Create: generated files under `rewrite/golden/java-migration/expected/`
- Create: `rewrite/golden/java-migration/manifest.json`
- Create: `rewrite/golden/java-migration/manifest.sha256`
- Test: `src/test/java/org/open2jam/export/MigrationGoldenCorpusGeneratorTest.java`

**Interfaces:**
- Consumes: `VosFixtureFactory`, `OjnFixtureFactory`, `OsuFixtureFactory`, `VosCatalogExporter`, `VosGameplayExporter`, `VosAudioExporter`, and `VosRenderMetadataExporter`.
- Produces: `MigrationGoldenCorpusGenerator.generate(Path outputRoot, Path workRoot) -> void` and explicit main arguments `--output <path> --work-root <path>`.

- [ ] **Step 1: Write the failing generator test**

```java
package org.open2jam.export;

import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class MigrationGoldenCorpusGeneratorTest {
    @TempDir
    Path tempDir;

    @Test
    void generatesSourcesExpectedArtifactsAndProvenance() throws Exception {
        Path output = tempDir.resolve("java-migration");
        Path work = Path.of("/tmp/open2jam-java-golden-v1");

        MigrationGoldenCorpusGenerator.generate(output, work);

        assertTrue(output.resolve("sources/vos/canon.vos").toFile().isFile());
        assertTrue(output.resolve("sources/ojn/o2jam.ojn").toFile().isFile());
        assertTrue(output.resolve("sources/ojn/o2jam.ojm").toFile().isFile());
        assertTrue(output.resolve("sources/osu/seven-key.osu").toFile().isFile());
        assertTrue(output.resolve("sources/osu/seven-key.osz").toFile().isFile());
        assertTrue(output.resolve("expected/vos/catalog.json").toFile().isFile());
        assertTrue(output.resolve("expected/vos/gameplay.json").toFile().isFile());
        assertTrue(output.resolve("expected/vos/audio-manifest.json").toFile().isFile());
        assertTrue(output.resolve("expected/ojn/catalog.json").toFile().isFile());
        assertTrue(output.resolve("expected/osu/catalog.json").toFile().isFile());
        assertTrue(output.resolve("manifest.json").toFile().isFile());
        assertTrue(output.resolve("manifest.sha256").toFile().isFile());
    }
}
```

- [ ] **Step 2: Run the test and verify RED**

Run: `mise exec -- bash -lc 'mvn -s "$MAVEN_SETTINGS" -Dtest=MigrationGoldenCorpusGeneratorTest test'`

Expected: FAIL to compile because `MigrationGoldenCorpusGenerator` does not exist.

- [ ] **Step 3: Implement deterministic case generation**

Implement this exact public shell:

```java
public final class MigrationGoldenCorpusGenerator {
    public static final String JAVA_SOURCE_COMMIT = "05257da";
    public static final String JAVA_TOOL = "zulu-17.66.19.0";

    private MigrationGoldenCorpusGenerator() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 4 || !"--output".equals(args[0]) || !"--work-root".equals(args[2])) {
            throw new IllegalArgumentException(
                    "Usage: MigrationGoldenCorpusGenerator --output <path> --work-root <path>");
        }
        generate(Path.of(args[1]), Path.of(args[3]));
    }

    public static void generate(Path outputRoot, Path workRoot) throws Exception {
        resetDirectory(workRoot);
        Path stagedCorpus = workRoot.resolve("corpus");
        Files.createDirectories(stagedCorpus);
        generateVos(stagedCorpus, workRoot);
        generateOjn(stagedCorpus, workRoot);
        generateOsu(stagedCorpus, workRoot);
        generateMalformedCases(stagedCorpus);
        writeReadme(stagedCorpus);
        writeProvenance(stagedCorpus);
        writeHashes(stagedCorpus);
        resetDirectory(outputRoot);
        copyTree(stagedCorpus, outputRoot);
    }
}
```

Implement the case methods with these concrete roots and calls. Every source is created below the fixed `workRoot/sources`; every expected artifact is created below `workRoot/corpus/expected`; after generation, copy the source tree into `workRoot/corpus/sources` before hashing:

```java
File vos = VosFixtureFactory.writeFixture(
        workRoot.resolve("sources/vos").toFile(), "canon.vos", 7, true, true, true);
Path expected = stagedCorpus.resolve("expected/vos");
Files.createDirectories(expected.resolve("audio"));
writeUtf8(expected.resolve("catalog.json"), new VosCatalogExporter().exportCatalog(vos));
writeUtf8(expected.resolve("gameplay.json"), new VosGameplayExporter().exportGameplay(vos));
writeUtf8(expected.resolve("audio-manifest.json"),
        new VosAudioExporter().exportAudio(vos, expected.resolve("audio").toFile()));

OjnFixtureFactory.OjnFixture ojn = OjnFixtureFactory.writeFixture(
        workRoot.resolve("sources/ojn").toFile(), "o2jam");
Path expected = stagedCorpus.resolve("expected/ojn");
Files.createDirectories(expected.resolve("audio"));
writeUtf8(expected.resolve("catalog.json"), new VosCatalogExporter().exportCatalog(ojn.chart()));
writeUtf8(expected.resolve("gameplay.json"), new VosGameplayExporter().exportGameplay(ojn.chart(), 0));
writeUtf8(expected.resolve("audio-manifest.json"),
        new VosAudioExporter().exportAudio(ojn.chart(), expected.resolve("audio").toFile(), 0));

File osu = OsuFixtureFactory.writeSevenKeyOsu(
        workRoot.resolve("sources/osu").toFile(), "seven-key.osu");
File osz = OsuFixtureFactory.writeSevenKeyOsz(
        workRoot.resolve("sources/osu").toFile(), "seven-key.osz");
Path expected = stagedCorpus.resolve("expected/osu");
Files.createDirectories(expected.resolve("audio"));
writeUtf8(expected.resolve("osu-catalog.json"), new VosCatalogExporter().exportCatalog(osu));
writeUtf8(expected.resolve("osz-catalog.json"), new VosCatalogExporter().exportCatalog(osz));
writeUtf8(expected.resolve("gameplay.json"), new VosGameplayExporter().exportGameplay(osu));
writeUtf8(expected.resolve("audio-manifest.json"),
        new VosAudioExporter().exportAudio(osu, expected.resolve("audio").toFile()));
```

Create directories before each factory call. After generation, copy `workRoot/sources` to `outputRoot/sources` while preserving bytes. Create malformed cases as fixed byte arrays:

```java
Files.write(outputRoot.resolve("sources/malformed/truncated.vos"), new byte[] {3, 0, 0, 0});
Files.write(outputRoot.resolve("sources/malformed/truncated.ojn"), new byte[] {1, 2, 3});
Files.writeString(outputRoot.resolve("sources/malformed/non-mania.osu"),
        OsuFixtureFactory.sevenKeyContent("audio.wav").replace("Mode: 3", "Mode: 0"),
        StandardCharsets.UTF_8);
```

`manifest.json` must be exactly this stable logical object, serialized without a wall-clock timestamp:

```json
{
  "schemaVersion": 1,
  "javaSourceCommit": "05257da",
  "javaTool": "zulu-17.66.19.0",
  "canonicalWorkRoot": "/tmp/open2jam-java-golden-v1",
  "cases": [
    {"id": "vos-canon", "format": "VOS", "source": "sources/vos/canon.vos", "expected": "expected/vos"},
    {"id": "ojn-o2jam", "format": "OJN", "source": "sources/ojn/o2jam.ojn", "expected": "expected/ojn"},
    {"id": "osu-seven-key", "format": "OSU", "source": "sources/osu/seven-key.osu", "expected": "expected/osu"},
    {"id": "osz-seven-key", "format": "OSU", "source": "sources/osu/seven-key.osz", "expected": "expected/osu/osz-catalog.json"},
    {"id": "vos-truncated", "format": "VOS", "source": "sources/malformed/truncated.vos", "expectedError": "CORRUPT_CHART"},
    {"id": "ojn-truncated", "format": "OJN", "source": "sources/malformed/truncated.ojn", "expectedError": "CORRUPT_CHART"},
    {"id": "osu-non-mania", "format": "OSU", "source": "sources/malformed/non-mania.osu", "expectedError": "UNSUPPORTED_FORMAT"}
  ]
}
```

Implement helpers with these exact signatures and behavior:

```java
private static void writeUtf8(Path path, String content) throws Exception {
    Files.createDirectories(path.getParent());
    Files.writeString(path, content, StandardCharsets.UTF_8);
}

private static void resetDirectory(Path root) throws Exception {
    if (Files.exists(root)) {
        try (java.util.stream.Stream<Path> paths = Files.walk(root)) {
            for (Path path : paths.sorted(java.util.Comparator.reverseOrder()).toList()) {
                Files.delete(path);
            }
        }
    }
    Files.createDirectories(root);
}

private static void copyTree(Path source, Path target) throws Exception {
    try (java.util.stream.Stream<Path> paths = Files.walk(source)) {
        for (Path path : paths.toList()) {
            Path destination = target.resolve(source.relativize(path));
            if (Files.isDirectory(path)) {
                Files.createDirectories(destination);
            } else {
                Files.createDirectories(destination.getParent());
                Files.copy(path, destination, java.nio.file.StandardCopyOption.REPLACE_EXISTING);
            }
        }
    }
}
```

`manifest.sha256` must contain sorted lowercase SHA-256 lines for every file below the corpus root except `manifest.sha256` itself:

```text
<sha256><two spaces><relative-path>
```

`README.md` must state that normal tests are read-only, identify the exact generator command from Step 5, and prohibit regeneration after Java deletion.

- [ ] **Step 4: Run the generator test**

Run: `mise exec -- bash -lc 'mvn -s "$MAVEN_SETTINGS" -Dtest=MigrationGoldenCorpusGeneratorTest test'`

Expected: PASS.

- [ ] **Step 5: Generate and inspect the committed corpus**

Run:

```bash
mise exec -- bash -lc 'mvn -s "$MAVEN_SETTINGS" test-compile org.codehaus.mojo:exec-maven-plugin:3.5.0:java -Dexec.classpathScope=test -Dexec.mainClass=org.open2jam.export.MigrationGoldenCorpusGenerator -Dexec.args="--output rewrite/golden/java-migration --work-root /tmp/open2jam-java-golden-v1"'
```

Expected: exit 0 and create the exact source, expected, manifest, hash, and README files listed above.

Run: `du -sh rewrite/golden/java-migration && find rewrite/golden/java-migration -type f | sort`

Expected: a small self-contained corpus with no path outside `rewrite/golden/java-migration` except path values intentionally recorded inside Java expected JSON.

- [ ] **Step 6: Commit**

```bash
git add src/test/java/org/open2jam/export/MigrationGoldenCorpusGenerator.java src/test/java/org/open2jam/export/MigrationGoldenCorpusGeneratorTest.java rewrite/golden/java-migration
git commit -m "test: freeze Java migration goldens"
```

---

### Task 5: Add an immutable golden reproduction test

**Files:**
- Create: `src/test/java/org/open2jam/export/MigrationGoldenCorpusTest.java`
- Test: `src/test/java/org/open2jam/export/MigrationGoldenCorpusTest.java`
- Test fixture: `rewrite/golden/java-migration/manifest.json`
- Test fixture: `rewrite/golden/java-migration/manifest.sha256`

**Interfaces:**
- Consumes: `MigrationGoldenCorpusGenerator.generate(Path, Path)` and committed golden corpus.
- Produces: `MigrationGoldenCorpusTest` with `committedHashesMatchManifest()` and `pinnedJavaReproducesCommittedCorpus()`.

- [ ] **Step 1: Write the failing immutability test**

```java
package org.open2jam.export;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class MigrationGoldenCorpusTest {
    private static final Path COMMITTED = Path.of("rewrite/golden/java-migration");
    private static final Path WORK = Path.of("/tmp/open2jam-java-golden-v1");

    @TempDir
    Path tempDir;

    @Test
    void committedHashesMatchManifest() throws Exception {
        String manifest = Files.readString(COMMITTED.resolve("manifest.json"), StandardCharsets.UTF_8);
        assertTrue(manifest.contains("\"javaSourceCommit\":\"05257da\""));
        assertTrue(manifest.contains("\"javaTool\":\"zulu-17.66.19.0\""));
        assertFalse(manifest.contains("generatedAt"));
        assertEquals(Files.readString(COMMITTED.resolve("manifest.sha256"), StandardCharsets.UTF_8),
                MigrationGoldenCorpusGenerator.hashManifest(COMMITTED));
    }

    @Test
    void pinnedJavaReproducesCommittedCorpus() throws Exception {
        Path regenerated = tempDir.resolve("regenerated");
        MigrationGoldenCorpusGenerator.generate(regenerated, WORK);
        assertEquals(MigrationGoldenCorpusGenerator.hashManifest(COMMITTED),
                MigrationGoldenCorpusGenerator.hashManifest(regenerated));
    }
}
```

- [ ] **Step 2: Run the test and verify RED**

Run: `mise exec -- bash -lc 'mvn -s "$MAVEN_SETTINGS" -Dtest=MigrationGoldenCorpusTest test'`

Expected: FAIL because `hashManifest(Path)` is not public or because the regenerated hash contains a corpus inconsistency.

- [ ] **Step 3: Expose deterministic hash generation and fix reproduction**

Add this public method to the generator and use it from `writeHashes`:

```java
public static String hashManifest(Path root) throws Exception {
    return Files.walk(root)
            .filter(Files::isRegularFile)
            .filter(path -> !path.getFileName().toString().equals("manifest.sha256"))
            .sorted((left, right) -> root.relativize(left).toString()
                    .compareTo(root.relativize(right).toString()))
            .map(path -> sha256(path) + "  " + root.relativize(path).toString() + "\n")
            .collect(java.util.stream.Collectors.joining());
}
```

Ensure generation closes every parser sample stream before resetting the fixed work directory. Ensure JSON and hash files use UTF-8 with `\n` line endings. Do not weaken the comparison or exclude VOS audio artifacts.

- [ ] **Step 4: Run the reproduction and existing exporter tests**

Run: `mise exec -- bash -lc 'mvn -s "$MAVEN_SETTINGS" -Dtest=MigrationGoldenCorpusGeneratorTest,MigrationGoldenCorpusTest,VosCatalogExporterTest,VosGameplayExporterTest,VosAudioExporterTest test'`

Expected: PASS with zero skipped tests.

- [ ] **Step 5: Commit**

```bash
git add src/test/java/org/open2jam/export/MigrationGoldenCorpusGenerator.java src/test/java/org/open2jam/export/MigrationGoldenCorpusTest.java
git commit -m "test: verify immutable migration goldens"
```

---

### Task 6: Add the no-skip Phase 0 verifier

**Files:**
- Create: `rewrite/tools/verify_java_migration_goldens.sh`
- Create: `rewrite/tools/test_verify_java_migration_goldens.sh`
- Modify: `mise.toml:10-24`
- Modify: `rewrite/tools/verify_vos_godot_initial.sh:1-190`
- Test: `rewrite/tools/test_verify_java_migration_goldens.sh`

**Interfaces:**
- Consumes: committed golden corpus, `MigrationGoldenCorpusTest`, hermetic fixture tests, and the repaired aggregate manifest test.
- Produces: `mise run verify-goldens` and `bash rewrite/tools/verify_java_migration_goldens.sh`, both strict and non-optional.

- [ ] **Step 1: Write the failing verifier contract test**

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

VERIFIER="rewrite/tools/verify_java_migration_goldens.sh"
[[ -x "$VERIFIER" ]] || { printf 'Missing executable golden verifier.\n' >&2; exit 1; }

for required in \
  MigrationGoldenCorpusGeneratorTest MigrationGoldenCorpusTest \
  OjnFixtureFactoryTest OsuFixtureFactoryTest \
  VosCatalogExporterTest VosGameplayExporterTest VosAudioExporterTest; do
  grep -Fq "$required" "$VERIFIER" || {
    printf 'Golden verifier omits %s.\n' "$required" >&2
    exit 1
  }
done

if grep -Eq 'assumeTrue|/Users/|Skipping|\|\| true' "$VERIFIER"; then
  printf 'Golden verifier contains an optional or machine-local path.\n' >&2
  exit 1
fi

grep -Fq 'verify-goldens' mise.toml || {
  printf 'mise verify-goldens task is missing.\n' >&2
  exit 1
}

printf 'Java migration golden verifier contract passed.\n'
```

- [ ] **Step 2: Run the contract test and verify RED**

Run: `bash rewrite/tools/test_verify_java_migration_goldens.sh`

Expected: FAIL with `Missing executable golden verifier.`

- [ ] **Step 3: Implement the strict verifier**

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

bash rewrite/tools/test_verify_vos_godot_manifest.sh

TESTS=(
  MigrationGoldenCorpusGeneratorTest
  MigrationGoldenCorpusTest
  OjnFixtureFactoryTest
  OsuFixtureFactoryTest
  VOSParserTest
  OsuManiaParserTest
  VosCatalogExporterTest
  VosGameplayExporterTest
  VosAudioExporterTest
)
tests_csv="$(IFS=,; printf '%s' "${TESTS[*]}")"

mise exec -- bash -lc 'mvn -s "$MAVEN_SETTINGS" -Dtest="$1" test' bash "$tests_csv"

if rg -n 'assumeTrue|/Users/' \
  src/test/java/org/open2jam/export/MigrationGoldenCorpusGeneratorTest.java \
  src/test/java/org/open2jam/export/MigrationGoldenCorpusTest.java \
  src/test/java/org/open2jam/parsers/OjnFixtureFactoryTest.java \
  src/test/java/org/open2jam/parsers/OsuFixtureFactoryTest.java; then
  printf 'Selected migration tests contain optional machine-local behavior.\n' >&2
  exit 1
fi

printf 'Java migration golden gate passed.\n'
```

Make both new shell files executable.

Add the exact mise task:

```toml
[tasks.verify-goldens]
description = "Verify hermetic Java migration goldens"
run = "bash rewrite/tools/verify_java_migration_goldens.sh"
```

Invoke `bash rewrite/tools/verify_java_migration_goldens.sh` near the beginning of `verify_vos_godot_initial.sh`, after the script establishes its repository root and before optional recorded/manual checks.

- [ ] **Step 4: Run narrow verifier tests**

Run: `bash rewrite/tools/test_verify_java_migration_goldens.sh`

Expected: PASS with `Java migration golden verifier contract passed.`

Run: `mise run verify-goldens`

Expected: PASS with `Java migration golden gate passed.` and zero skipped tests.

- [ ] **Step 5: Run Phase 0 regression gates**

Run: `bash rewrite/tools/test_verify_vos_godot_manifest.sh`

Expected: PASS.

Run: `mise exec -- bash -lc 'mvn -s "$MAVEN_SETTINGS" verify'`

Expected: Maven build success with no test failures.

Run: `git diff --check`

Expected: PASS with no output.

- [ ] **Step 6: Commit**

```bash
git add rewrite/tools/verify_java_migration_goldens.sh rewrite/tools/test_verify_java_migration_goldens.sh rewrite/tools/verify_vos_godot_initial.sh mise.toml
git commit -m "test: gate Java migration goldens"
```

## Phase 0 Completion Gate

Before marking this plan complete:

- `mise run verify-goldens` passes with zero skips.
- `mise exec -- bash -lc 'mvn -s "$MAVEN_SETTINGS" verify'` passes.
- `bash rewrite/tools/test_verify_vos_godot_manifest.sh` passes.
- `git diff --check` passes.
- `git status --short` contains no uncommitted Phase 0 files.
- The committed corpus contains no proprietary user song files.
- The exact committed corpus and verifier are reviewed with `superpowers:requesting-code-review`.
- Only after review may `superpowers:writing-plans` create Phase 1 from the live tree.
