package org.open2jam.export;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.open2jam.parsers.VosFixtureFactory;

class VosGameplayExporterTest {
    private static final int VOS_DROID_CHANNEL_COUNT = 17;
    private static final int VOS_DROID_PLAYABLE_CHANNEL_INDEX = 16;
    private static final boolean INCLUDE_DISTRACTOR_NOTE = true;

    @TempDir
    File tempDir;

    @Test
    void exportsLongNoteGameplayTimeline() throws Exception {
        File chartFile = VosFixtureFactory.writeFixture(tempDir, "long.vos", 7, true, true, true);

        String json = new VosGameplayExporter().exportGameplay(chartFile);

        assertEquals(gameplayJson(chartFile, JsonWriter.array(
                note(0, "tap", 0.0, 1),
                holdNote(0, 500.0, 750.0, 2)), JsonWriter.array()), json);
    }

    @Test
    void exportsAutoPlayEventsSeparatelyFromNotes() throws Exception {
        File chartFile = VosFixtureFactory.writeFixture(tempDir, "droid.vos", 5, VOS_DROID_CHANNEL_COUNT,
                VOS_DROID_PLAYABLE_CHANNEL_INDEX, INCLUDE_DISTRACTOR_NOTE);

        String json = new VosGameplayExporter().exportGameplay(chartFile);

        assertEquals(gameplayJson(chartFile, JsonWriter.array(note(2, "tap", 0.0, 2)),
                JsonWriter.array(autoPlayEvent(0.0, 1))), json);
    }

    @Test
    void rejectsInputWithoutVosChart() throws Exception {
        File textFile = new File(tempDir, "notes.txt");
        Files.write(textFile.toPath(), "not a chart".getBytes(StandardCharsets.UTF_8));

        assertThrows(IllegalArgumentException.class, () -> new VosGameplayExporter().exportGameplay(textFile));
    }

    private static String gameplayJson(File source, String notes, String autoPlayEvents) throws Exception {
        return JsonWriter.object(
                JsonWriter.field("schemaVersion", 1),
                JsonWriter.field("format", "VOS"),
                JsonWriter.field("sourcePath", source.getCanonicalPath()),
                JsonWriter.field("title", "Canon in D"),
                JsonWriter.field("keys", 7),
                JsonWriter.field("bpm", 120.0),
                JsonWriter.field("durationMs", 123000),
                JsonWriter.rawField("notes", notes),
                JsonWriter.rawField("autoPlayEvents", autoPlayEvents));
    }

    private static String note(int lane, String kind, double startMs, int sampleId) {
        return JsonWriter.object(
                JsonWriter.field("lane", lane),
                JsonWriter.field("kind", kind),
                JsonWriter.field("startMs", startMs),
                JsonWriter.field("sampleId", sampleId),
                JsonWriter.field("volume", 1.0),
                JsonWriter.field("pan", 0.0));
    }

    private static String holdNote(int lane, double startMs, double endMs, int sampleId) {
        return JsonWriter.object(
                JsonWriter.field("lane", lane),
                JsonWriter.field("kind", "holdStart"),
                JsonWriter.field("startMs", startMs),
                JsonWriter.field("endMs", endMs),
                JsonWriter.field("sampleId", sampleId),
                JsonWriter.field("volume", 1.0),
                JsonWriter.field("pan", 0.0));
    }

    private static String autoPlayEvent(double startMs, int sampleId) {
        return JsonWriter.object(
                JsonWriter.field("startMs", startMs),
                JsonWriter.field("sampleId", sampleId),
                JsonWriter.field("volume", 1.0),
                JsonWriter.field("pan", 0.0));
    }
}
