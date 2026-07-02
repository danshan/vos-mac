package org.open2jam.export;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.awt.image.BufferedImage;
import java.io.File;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
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
                note(0, "tap", JAVA_RENDER_DELAY_MS, 1, 0),
                holdNote(0, 2000.0, 2250.0, 2, 1, 2)), JsonWriter.array(measure(JAVA_RENDER_DELAY_MS)),
                JsonWriter.array(visualTiming(JAVA_RENDER_DELAY_MS, 120.0)),
                JsonWriter.array(visualTiming(JAVA_RENDER_DELAY_MS, 120.0)),
                JsonWriter.array(), JsonWriter.array(), JsonWriter.array()), json);
    }

    @Test
    void exportsAutoPlayEventsSeparatelyFromNotes() throws Exception {
        File chartFile = VosFixtureFactory.writeFixture(tempDir, "droid.vos", 5, VOS_DROID_CHANNEL_COUNT,
                VOS_DROID_PLAYABLE_CHANNEL_INDEX, INCLUDE_DISTRACTOR_NOTE);

        String json = new VosGameplayExporter().exportGameplay(chartFile);

        assertEquals(gameplayJson(chartFile, JsonWriter.array(note(2, "tap", JAVA_RENDER_DELAY_MS, 2, 0)),
                JsonWriter.array(measure(JAVA_RENDER_DELAY_MS)),
                JsonWriter.array(visualTiming(JAVA_RENDER_DELAY_MS, 120.0)),
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
                JsonWriter.array(visualTiming(JAVA_RENDER_DELAY_MS, 120.0)),
                JsonWriter.array(visualTiming(JAVA_RENDER_DELAY_MS, 120.0)),
                JsonWriter.array(), JsonWriter.array(bgaEvent(2000.0, 7)), JsonWriter.array()), json);
    }

    @Test
    void exportsJudgmentTimingSeparatelyFromVisualTiming() throws Exception {
        File chartFile = new File(tempDir, "scroll-speed.vos");
        Files.write(chartFile.toPath(), new byte[0]);
        VOSChart chart = new VOSChart();
        chart.setTitle("Canon in D");
        chart.setLevel(0);
        chart.setBPM(120.0);
        chart.setDuration(123);
        EventList events = new EventList();
        events.add(new Event(Event.Channel.SCROLL_SPEED, 0, 0.25, 2.0, Event.Flag.NONE));
        chart.setEvents(events);

        String json = new VosGameplayExporter().exportGameplay(chart, chartFile);

        assertEquals(gameplayJson(chartFile, JsonWriter.array(), JsonWriter.array(measure(JAVA_RENDER_DELAY_MS)),
                JsonWriter.array(
                        visualTiming(JAVA_RENDER_DELAY_MS, 120.0),
                        visualTiming(2000.0, 240.0)),
                JsonWriter.array(visualTiming(JAVA_RENDER_DELAY_MS, 120.0)),
                JsonWriter.array(), JsonWriter.array(), JsonWriter.array()), json);
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

        assertEquals(gameplayJson(chartFile, JsonWriter.array(holdNote(0, 2000.0, 2500.0, 5, 0, 1)),
                JsonWriter.array(measure(JAVA_RENDER_DELAY_MS)),
                JsonWriter.array(visualTiming(JAVA_RENDER_DELAY_MS, 120.0)),
                JsonWriter.array(visualTiming(JAVA_RENDER_DELAY_MS, 120.0)),
                JsonWriter.array(), JsonWriter.array(), JsonWriter.array()), json);
    }

    @Test
    void exportsPlayableEventOrderForRandomChannelReleaseParity() throws Exception {
        File chartFile = new File(tempDir, "random-release-order.vos");
        Files.write(chartFile.toPath(), new byte[0]);
        VOSChart chart = new VOSChart();
        chart.setTitle("Canon in D");
        chart.setLevel(0);
        chart.setBPM(120.0);
        chart.setDuration(123);
        EventList events = new EventList();
        events.add(new Event(Event.Channel.NOTE_1, 0, 0.25, 2, Event.Flag.HOLD));
        events.add(new Event(Event.Channel.NOTE_1, 1, 0.50, 2, Event.Flag.RELEASE));
        events.add(new Event(Event.Channel.NOTE_1, 1, 0.50, 3, Event.Flag.NONE));
        chart.setEvents(events);

        String json = new VosGameplayExporter().exportGameplay(chart, chartFile);

        assertEquals(gameplayJson(chartFile, JsonWriter.array(
                holdNote(0, 2000.0, 4500.0, 0, 1, 2, 0, 1),
                note(0, "tap", 4500.0, 1, 3, 2)),
                JsonWriter.array(measure(JAVA_RENDER_DELAY_MS), measure(3500.0)),
                JsonWriter.array(visualTiming(JAVA_RENDER_DELAY_MS, 120.0)),
                JsonWriter.array(visualTiming(JAVA_RENDER_DELAY_MS, 120.0)),
                JsonWriter.array(), JsonWriter.array(), JsonWriter.array()), json);
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
                JsonWriter.array(visualTiming(JAVA_RENDER_DELAY_MS, 120.0)),
                JsonWriter.array(visualTiming(JAVA_RENDER_DELAY_MS, 120.0)),
                JsonWriter.array(), JsonWriter.array(), JsonWriter.array(bgaSprite(7, copiedImage))), json);
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
                JsonWriter.array(visualTiming(JAVA_RENDER_DELAY_MS, 120.0)),
                JsonWriter.array(visualTiming(JAVA_RENDER_DELAY_MS, 120.0)),
                JsonWriter.array(), JsonWriter.array(), videoFile, JsonWriter.array()), json);
    }

    @Test
    void exportsOsuManiaSevenKeyGameplayTimeline() throws Exception {
        File chartFile = writeOsuManiaSevenKeyFixture("seven-key.osu");

        String json = new VosGameplayExporter().exportGameplay(chartFile);

        assertEquals(gameplayJson(chartFile, "OSU", "Seven Key Fixture", 2000, JsonWriter.array(
                note(0, "tap", JAVA_RENDER_DELAY_MS, 0, 2, 0, 0.75f),
                holdNote(3, 2500.0, 3500.0, 0, 1, 3, 1, 2, 0.65f)),
                JsonWriter.array(measure(JAVA_RENDER_DELAY_MS), measure(3500.0)),
                JsonWriter.array(visualTiming(JAVA_RENDER_DELAY_MS, 120.0)),
                JsonWriter.array(visualTiming(JAVA_RENDER_DELAY_MS, 120.0)),
                JsonWriter.array(autoPlayEvent(JAVA_RENDER_DELAY_MS, 1)), JsonWriter.array(),
                JsonWriter.array()), json);
    }

    @Test
    void exportsOjnGameplayTimeline() throws Exception {
        File chartFile = writeOjnGameplayFixture("o2jam.ojn");

        String json = new VosGameplayExporter().exportGameplay(chartFile);

        assertEquals(gameplayJson(chartFile, "OJN", "Ojn Fixture", 130.0, 91000,
                JsonWriter.array(note(0, "tap", JAVA_RENDER_DELAY_MS, 1, 0)),
                JsonWriter.array(measure(JAVA_RENDER_DELAY_MS)),
                JsonWriter.array(visualTiming(JAVA_RENDER_DELAY_MS, 130.0)),
                JsonWriter.array(visualTiming(JAVA_RENDER_DELAY_MS, 130.0)),
                JsonWriter.array(), JsonWriter.array(), JsonWriter.array()), json);
    }

    @Test
    void exportsOjnGameplayByPlayableChartIndex() throws Exception {
        File chartFile = writeOjnMultiDifficultyGameplayFixture("multi.ojn");

        String json = new VosGameplayExporter().exportGameplay(chartFile, 2);

        assertEquals(gameplayJson(chartFile, "OJN", "Ojn Fixture", 130.0, 93000,
                JsonWriter.array(note(0, "tap", JAVA_RENDER_DELAY_MS, 3, 0)),
                JsonWriter.array(measure(JAVA_RENDER_DELAY_MS)),
                JsonWriter.array(visualTiming(JAVA_RENDER_DELAY_MS, 130.0)),
                JsonWriter.array(visualTiming(JAVA_RENDER_DELAY_MS, 130.0)),
                JsonWriter.array(), JsonWriter.array(), JsonWriter.array()), json);
    }

    @Test
    void rejectsInputWithoutVosChart() throws Exception {
        File textFile = new File(tempDir, "notes.txt");
        Files.write(textFile.toPath(), "not a chart".getBytes(StandardCharsets.UTF_8));

        assertThrows(IllegalArgumentException.class, () -> new VosGameplayExporter().exportGameplay(textFile));
    }

    private static String gameplayJson(File source, String notes, String measures, String visualTiming,
            String judgmentTiming, String autoPlayEvents, String bgaEvents, String bgaSprites) throws Exception {
        return gameplayJson(source, "VOS", "Canon in D", notes, measures, visualTiming, judgmentTiming,
                autoPlayEvents, bgaEvents, bgaSprites);
    }

    private static String gameplayJson(File source, String format, String title, String notes, String measures,
            String visualTiming, String judgmentTiming, String autoPlayEvents, String bgaEvents, String bgaSprites)
            throws Exception {
        return gameplayJson(source, format, title, 123000, notes, measures, visualTiming, judgmentTiming,
                autoPlayEvents, bgaEvents, bgaSprites);
    }

    private static String gameplayJson(File source, String format, String title, int durationMs, String notes,
            String measures, String visualTiming, String judgmentTiming, String autoPlayEvents, String bgaEvents,
            String bgaSprites) throws Exception {
        return gameplayJson(source, format, title, 120.0, durationMs, notes, measures, visualTiming, judgmentTiming,
                autoPlayEvents, bgaEvents, bgaSprites);
    }

    private static String gameplayJson(File source, String format, String title, double bpm, int durationMs,
            String notes, String measures, String visualTiming, String judgmentTiming, String autoPlayEvents,
            String bgaEvents, String bgaSprites) throws Exception {
        return JsonWriter.object(
                JsonWriter.field("schemaVersion", 1),
                JsonWriter.field("format", format),
                JsonWriter.field("sourcePath", source.getCanonicalPath()),
                JsonWriter.field("title", title),
                JsonWriter.field("rank", 0),
                JsonWriter.field("speedMultiplier", 1.0),
                JsonWriter.field("speedType", "HiSpeed"),
                JsonWriter.field("keys", 7),
                JsonWriter.field("bpm", bpm),
                JsonWriter.field("durationMs", durationMs),
                JsonWriter.rawField("notes", notes),
                JsonWriter.rawField("measures", measures),
                JsonWriter.rawField("visualTiming", visualTiming),
                JsonWriter.rawField("judgmentTiming", judgmentTiming),
                JsonWriter.rawField("autoPlayEvents", autoPlayEvents),
                JsonWriter.rawField("bgaEvents", bgaEvents),
                JsonWriter.rawField("bgaSprites", bgaSprites));
    }

    private static String gameplayJsonWithBgaVideo(File source, String notes, String measures, String visualTiming,
            String judgmentTiming, String autoPlayEvents, String bgaEvents, File bgaVideo, String bgaSprites)
            throws Exception {
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
                JsonWriter.rawField("judgmentTiming", judgmentTiming),
                JsonWriter.rawField("autoPlayEvents", autoPlayEvents),
                JsonWriter.rawField("bgaEvents", bgaEvents),
                JsonWriter.field("bgaVideoPath", bgaVideo.getCanonicalPath()),
                JsonWriter.rawField("bgaSprites", bgaSprites));
    }

    private static String note(int lane, String kind, double startMs, int sampleId, int eventOrder) {
        return note(lane, kind, startMs, 0, sampleId, eventOrder);
    }

    private static String note(int lane, String kind, double startMs, int measure, int sampleId, int eventOrder) {
        return note(lane, kind, startMs, measure, sampleId, eventOrder, 1.0f);
    }

    private static String note(int lane, String kind, double startMs, int measure, int sampleId, int eventOrder,
            float volume) {
        return JsonWriter.object(
                JsonWriter.field("lane", lane),
                JsonWriter.field("kind", kind),
                JsonWriter.field("startMs", startMs),
                JsonWriter.field("measure", measure),
                JsonWriter.field("eventOrder", eventOrder),
                JsonWriter.field("sampleId", sampleId),
                JsonWriter.field("volume", volume),
                JsonWriter.field("pan", 0.0));
    }

    private static String holdNote(int lane, double startMs, double endMs, int sampleId, int eventOrder,
            int releaseEventOrder) {
        return holdNote(lane, startMs, endMs, 0, 0, sampleId, eventOrder, releaseEventOrder);
    }

    private static String holdNote(int lane, double startMs, double endMs, int measure, int endMeasure, int sampleId,
            int eventOrder, int releaseEventOrder) {
        return holdNote(lane, startMs, endMs, measure, endMeasure, sampleId, eventOrder, releaseEventOrder, 1.0f);
    }

    private static String holdNote(int lane, double startMs, double endMs, int sampleId, int eventOrder,
            int releaseEventOrder, float volume) {
        return holdNote(lane, startMs, endMs, 0, 0, sampleId, eventOrder, releaseEventOrder, volume);
    }

    private static String holdNote(int lane, double startMs, double endMs, int measure, int endMeasure, int sampleId,
            int eventOrder, int releaseEventOrder, float volume) {
        return JsonWriter.object(
                JsonWriter.field("lane", lane),
                JsonWriter.field("kind", "holdStart"),
                JsonWriter.field("startMs", startMs),
                JsonWriter.field("measure", measure),
                JsonWriter.field("endMs", endMs),
                JsonWriter.field("endMeasure", endMeasure),
                JsonWriter.field("eventOrder", eventOrder),
                JsonWriter.field("releaseEventOrder", releaseEventOrder),
                JsonWriter.field("sampleId", sampleId),
                JsonWriter.field("volume", volume),
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

    private File writeOsuManiaSevenKeyFixture(String name) throws Exception {
        File chartFile = new File(tempDir, name);
        String content = ""
                + "osu file format v14\n"
                + "\n"
                + "[General]\n"
                + "AudioFilename: audio.ogg\n"
                + "Mode: 3\n"
                + "\n"
                + "[Metadata]\n"
                + "Title:Seven Key Fixture\n"
                + "Artist:Fixture Artist\n"
                + "Creator:Fixture Creator\n"
                + "Version:Test 7K\n"
                + "\n"
                + "[Difficulty]\n"
                + "CircleSize:7\n"
                + "OverallDifficulty:8\n"
                + "\n"
                + "[TimingPoints]\n"
                + "0,500,4,2,1,60,1,0\n"
                + "\n"
                + "[HitObjects]\n"
                + "36,192,0,1,0,0:0:0:75:kick.wav\n"
                + "256,192,1000,128,0,2000:0:0:0:65:hold.wav\n";
        Files.write(chartFile.toPath(), content.getBytes(StandardCharsets.UTF_8));
        return chartFile;
    }

    private File writeOjnGameplayFixture(String name) throws Exception {
        File chartFile = new File(tempDir, name);
        ByteBuffer buffer = ByteBuffer.allocate(312).order(ByteOrder.LITTLE_ENDIAN);
        buffer.putInt(100);
        buffer.putInt(0x006E6A6F);
        buffer.putFloat(2.0f);
        buffer.putInt(2);
        buffer.putFloat(130.0f);
        buffer.putShort((short) 4);
        buffer.putShort((short) 6);
        buffer.putShort((short) 8);
        buffer.putShort((short) 0);
        buffer.putInt(1);
        buffer.putInt(0);
        buffer.putInt(0);
        buffer.putInt(1);
        buffer.putInt(0);
        buffer.putInt(0);
        buffer.putInt(1);
        buffer.putInt(0);
        buffer.putInt(0);
        buffer.putInt(1);
        buffer.putInt(0);
        buffer.putInt(0);
        buffer.putShort((short) 0);
        buffer.putShort((short) 0);
        putFixedString(buffer, "", 20);
        buffer.putInt(0);
        buffer.putInt(1);
        putFixedString(buffer, "Ojn Fixture", 64);
        putFixedString(buffer, "Ojn Artist", 32);
        putFixedString(buffer, "Ojn Noter", 32);
        putFixedString(buffer, "o2jam.ojm", 32);
        buffer.putInt(0);
        buffer.putInt(91);
        buffer.putInt(91);
        buffer.putInt(91);
        buffer.putInt(300);
        buffer.putInt(312);
        buffer.putInt(312);
        buffer.putInt(312);
        buffer.putInt(0);
        buffer.putShort((short) 2);
        buffer.putShort((short) 1);
        buffer.putShort((short) 1);
        buffer.put((byte) 0);
        buffer.put((byte) 0);
        Files.write(chartFile.toPath(), buffer.array());
        return chartFile;
    }

    private File writeOjnMultiDifficultyGameplayFixture(String name) throws Exception {
        File chartFile = new File(tempDir, name);
        ByteBuffer buffer = ByteBuffer.allocate(336).order(ByteOrder.LITTLE_ENDIAN);
        buffer.putInt(100);
        buffer.putInt(0x006E6A6F);
        buffer.putFloat(2.0f);
        buffer.putInt(2);
        buffer.putFloat(130.0f);
        buffer.putShort((short) 4);
        buffer.putShort((short) 6);
        buffer.putShort((short) 8);
        buffer.putShort((short) 0);
        buffer.putInt(1);
        buffer.putInt(1);
        buffer.putInt(1);
        buffer.putInt(1);
        buffer.putInt(1);
        buffer.putInt(1);
        buffer.putInt(1);
        buffer.putInt(1);
        buffer.putInt(1);
        buffer.putInt(1);
        buffer.putInt(1);
        buffer.putInt(1);
        buffer.putShort((short) 0);
        buffer.putShort((short) 0);
        putFixedString(buffer, "", 20);
        buffer.putInt(0);
        buffer.putInt(1);
        putFixedString(buffer, "Ojn Fixture", 64);
        putFixedString(buffer, "Ojn Artist", 32);
        putFixedString(buffer, "Ojn Noter", 32);
        putFixedString(buffer, "o2jam.ojm", 32);
        buffer.putInt(0);
        buffer.putInt(91);
        buffer.putInt(92);
        buffer.putInt(93);
        buffer.putInt(300);
        buffer.putInt(312);
        buffer.putInt(324);
        buffer.putInt(336);
        putOjnNoteBlock(buffer, (short) 1);
        putOjnNoteBlock(buffer, (short) 2);
        putOjnNoteBlock(buffer, (short) 3);
        Files.write(chartFile.toPath(), buffer.array());
        return chartFile;
    }

    private static void putOjnNoteBlock(ByteBuffer buffer, short sampleValue) {
        buffer.putInt(0);
        buffer.putShort((short) 2);
        buffer.putShort((short) 1);
        buffer.putShort(sampleValue);
        buffer.put((byte) 0);
        buffer.put((byte) 0);
    }

    private static void putFixedString(ByteBuffer buffer, String value, int length) {
        byte[] bytes = value.getBytes(StandardCharsets.US_ASCII);
        int written = Math.min(bytes.length, length);
        buffer.put(bytes, 0, written);
        for (int i = written; i < length; i++) {
            buffer.put((byte) 0);
        }
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
