package org.open2jam.export;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.awt.image.BufferedImage;
import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.LinkedHashMap;
import java.util.Map;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.open2jam.parsers.Event;
import org.open2jam.parsers.EventList;
import org.open2jam.parsers.VosFixtureFactory;
import org.open2jam.parsers.VOSChart;

class VosGameplayExporterTest {
    private static final int VOS_DROID_CHANNEL_COUNT = 17;
    private static final int VOS_DROID_PLAYABLE_CHANNEL_INDEX = 16;
    private static final boolean INCLUDE_DISTRACTOR_NOTE = true;
    private static final double JAVA_RENDER_DELAY_MS = 1500.0;

    @TempDir
    File tempDir;

    @Test
    void exportsLongNoteGameplayTimeline() throws Exception {
        File chartFile = VosFixtureFactory.writeFixture(tempDir, "long.vos", 7, true, true, true);

        String json = new VosGameplayExporter().exportGameplay(chartFile);

        assertEquals(gameplayJson(chartFile, JsonWriter.array(
                note(0, "tap", JAVA_RENDER_DELAY_MS, 1),
                holdNote(0, 2000.0, 2250.0, 2)), JsonWriter.array(measure(JAVA_RENDER_DELAY_MS)),
                JsonWriter.array(visualTiming(JAVA_RENDER_DELAY_MS, 120.0)), JsonWriter.array(),
                JsonWriter.array(), JsonWriter.array()), json);
    }

    @Test
    void exportsAutoPlayEventsSeparatelyFromNotes() throws Exception {
        File chartFile = VosFixtureFactory.writeFixture(tempDir, "droid.vos", 5, VOS_DROID_CHANNEL_COUNT,
                VOS_DROID_PLAYABLE_CHANNEL_INDEX, INCLUDE_DISTRACTOR_NOTE);

        String json = new VosGameplayExporter().exportGameplay(chartFile);

        assertEquals(gameplayJson(chartFile, JsonWriter.array(note(2, "tap", JAVA_RENDER_DELAY_MS, 2)),
                JsonWriter.array(measure(JAVA_RENDER_DELAY_MS)),
                JsonWriter.array(visualTiming(JAVA_RENDER_DELAY_MS, 120.0)),
                JsonWriter.array(autoPlayEvent(JAVA_RENDER_DELAY_MS, 1)), JsonWriter.array(),
                JsonWriter.array()), json);
    }

    @Test
    void exportsBgaEventsFromChartTimeline() throws Exception {
        File chartFile = new File(tempDir, "bga.vos");
        Files.write(chartFile.toPath(), new byte[0]);
        VOSChart chart = new VOSChart();
        chart.setTitle("Canon in D");
        chart.setLevel(0);
        chart.setBPM(120.0);
        chart.setDuration(123);
        EventList events = new EventList();
        events.add(new Event(Event.Channel.BGA, 0, 0.25, 7, Event.Flag.NONE));
        chart.setEvents(events);

        String json = new VosGameplayExporter().exportGameplay(chart, chartFile);

        assertEquals(gameplayJson(chartFile, JsonWriter.array(), JsonWriter.array(measure(JAVA_RENDER_DELAY_MS)),
                JsonWriter.array(visualTiming(JAVA_RENDER_DELAY_MS, 120.0)), JsonWriter.array(),
                JsonWriter.array(bgaEvent(2000.0, 7)), JsonWriter.array()), json);
    }

    @Test
    void appliesOpen2jamEventListFixesBeforeExportingNotes() throws Exception {
        File chartFile = new File(tempDir, "fixed-long-note.vos");
        Files.write(chartFile.toPath(), new byte[0]);
        VOSChart chart = new VOSChart();
        chart.setTitle("Canon in D");
        chart.setLevel(0);
        chart.setBPM(120.0);
        chart.setDuration(123);
        EventList events = new EventList();
        events.add(new Event(Event.Channel.NOTE_1, 0, 0.25, 5, Event.Flag.NONE));
        events.add(new Event(Event.Channel.NOTE_1, 0, 0.50, 5, Event.Flag.RELEASE));
        chart.setEvents(events);

        String json = new VosGameplayExporter().exportGameplay(chart, chartFile);

        assertEquals(gameplayJson(chartFile, JsonWriter.array(holdNote(0, 2000.0, 2500.0, 5)),
                JsonWriter.array(measure(JAVA_RENDER_DELAY_MS)),
                JsonWriter.array(visualTiming(JAVA_RENDER_DELAY_MS, 120.0)), JsonWriter.array(),
                JsonWriter.array(), JsonWriter.array()), json);
    }

    @Test
    void exportsBgaSpriteAssetsFromChartImages() throws Exception {
        File chartFile = new File(tempDir, "bga.vos");
        Files.write(chartFile.toPath(), new byte[0]);
        File imageFile = new File(tempDir, "source-bga.png");
        ImageIO.write(new BufferedImage(2, 2, BufferedImage.TYPE_INT_ARGB), "png", imageFile);
        VOSChart chart = new BgaImageChart(7, imageFile);
        chart.setTitle("Canon in D");
        chart.setLevel(0);
        chart.setBPM(120.0);
        chart.setDuration(123);
        chart.setEvents(new EventList());
        File assetDir = new File(tempDir, "bga-assets");

        String json = new VosGameplayExporter().exportGameplay(chart, chartFile, assetDir);

        File copiedImage = new File(assetDir, "bga-7.png");
        assertTrue(copiedImage.isFile());
        assertEquals(gameplayJson(chartFile, JsonWriter.array(), JsonWriter.array(measure(JAVA_RENDER_DELAY_MS)),
                JsonWriter.array(visualTiming(JAVA_RENDER_DELAY_MS, 120.0)), JsonWriter.array(),
                JsonWriter.array(), JsonWriter.array(bgaSprite(7, copiedImage))), json);
    }

    @Test
    void exportsBgaVideoPathFromChartVideo() throws Exception {
        File chartFile = new File(tempDir, "video.vos");
        Files.write(chartFile.toPath(), new byte[0]);
        File videoFile = new File(tempDir, "intro.ogv");
        Files.write(videoFile.toPath(), new byte[] { 0 });
        VOSChart chart = new BgaVideoChart(videoFile);
        chart.setTitle("Canon in D");
        chart.setLevel(0);
        chart.setBPM(120.0);
        chart.setDuration(123);
        chart.setEvents(new EventList());

        String json = new VosGameplayExporter().exportGameplay(chart, chartFile);

        assertEquals(gameplayJsonWithBgaVideo(chartFile, JsonWriter.array(), JsonWriter.array(measure(JAVA_RENDER_DELAY_MS)),
                JsonWriter.array(visualTiming(JAVA_RENDER_DELAY_MS, 120.0)), JsonWriter.array(),
                JsonWriter.array(), videoFile, JsonWriter.array()), json);
    }

    @Test
    void rejectsInputWithoutVosChart() throws Exception {
        File textFile = new File(tempDir, "notes.txt");
        Files.write(textFile.toPath(), "not a chart".getBytes(StandardCharsets.UTF_8));

        assertThrows(IllegalArgumentException.class, () -> new VosGameplayExporter().exportGameplay(textFile));
    }

    private static String gameplayJson(File source, String notes, String measures, String visualTiming,
            String autoPlayEvents, String bgaEvents, String bgaSprites) throws Exception {
        return JsonWriter.object(
                JsonWriter.field("schemaVersion", 1),
                JsonWriter.field("format", "VOS"),
                JsonWriter.field("sourcePath", source.getCanonicalPath()),
                JsonWriter.field("title", "Canon in D"),
                JsonWriter.field("rank", 0),
                JsonWriter.field("speedMultiplier", 1.0),
                JsonWriter.field("speedType", "HiSpeed"),
                JsonWriter.field("keys", 7),
                JsonWriter.field("bpm", 120.0),
                JsonWriter.field("durationMs", 123000),
                JsonWriter.rawField("notes", notes),
                JsonWriter.rawField("measures", measures),
                JsonWriter.rawField("visualTiming", visualTiming),
                JsonWriter.rawField("autoPlayEvents", autoPlayEvents),
                JsonWriter.rawField("bgaEvents", bgaEvents),
                JsonWriter.rawField("bgaSprites", bgaSprites));
    }

    private static String gameplayJsonWithBgaVideo(File source, String notes, String measures, String visualTiming,
            String autoPlayEvents, String bgaEvents, File bgaVideo, String bgaSprites) throws Exception {
        return JsonWriter.object(
                JsonWriter.field("schemaVersion", 1),
                JsonWriter.field("format", "VOS"),
                JsonWriter.field("sourcePath", source.getCanonicalPath()),
                JsonWriter.field("title", "Canon in D"),
                JsonWriter.field("rank", 0),
                JsonWriter.field("speedMultiplier", 1.0),
                JsonWriter.field("speedType", "HiSpeed"),
                JsonWriter.field("keys", 7),
                JsonWriter.field("bpm", 120.0),
                JsonWriter.field("durationMs", 123000),
                JsonWriter.rawField("notes", notes),
                JsonWriter.rawField("measures", measures),
                JsonWriter.rawField("visualTiming", visualTiming),
                JsonWriter.rawField("autoPlayEvents", autoPlayEvents),
                JsonWriter.rawField("bgaEvents", bgaEvents),
                JsonWriter.field("bgaVideoPath", bgaVideo.getCanonicalPath()),
                JsonWriter.rawField("bgaSprites", bgaSprites));
    }

    private static String note(int lane, String kind, double startMs, int sampleId) {
        return JsonWriter.object(
                JsonWriter.field("lane", lane),
                JsonWriter.field("kind", kind),
                JsonWriter.field("startMs", startMs),
                JsonWriter.field("measure", 0),
                JsonWriter.field("sampleId", sampleId),
                JsonWriter.field("volume", 1.0),
                JsonWriter.field("pan", 0.0));
    }

    private static String holdNote(int lane, double startMs, double endMs, int sampleId) {
        return JsonWriter.object(
                JsonWriter.field("lane", lane),
                JsonWriter.field("kind", "holdStart"),
                JsonWriter.field("startMs", startMs),
                JsonWriter.field("measure", 0),
                JsonWriter.field("endMs", endMs),
                JsonWriter.field("endMeasure", 0),
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

    private static String bgaEvent(double startMs, int spriteId) {
        return JsonWriter.object(
                JsonWriter.field("startMs", startMs),
                JsonWriter.field("spriteId", spriteId));
    }

    private static String bgaSprite(int spriteId, File image) throws Exception {
        return JsonWriter.object(
                JsonWriter.field("spriteId", spriteId),
                JsonWriter.field("texturePath", image.getCanonicalPath()));
    }

    private static String measure(double startMs) {
        return JsonWriter.object(JsonWriter.field("startMs", startMs));
    }

    private static String visualTiming(double timeMs, double bpm) {
        return JsonWriter.object(
                JsonWriter.field("timeMs", timeMs),
                JsonWriter.field("bpm", bpm));
    }

    private static final class BgaImageChart extends VOSChart {
        private final Map<Integer, File> images = new LinkedHashMap<Integer, File>();

        BgaImageChart(int spriteId, File image) {
            images.put(spriteId, image);
        }

        @Override
        public Map<Integer, File> getImages() {
            return images;
        }
    }

    private static final class BgaVideoChart extends VOSChart {
        BgaVideoChart(File video) {
            this.video = video;
        }
    }
}
