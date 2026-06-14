package org.open2jam.parsers;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.Map;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.open2jam.parsers.utils.SampleData;

class OsuManiaParserTest {
    @TempDir
    File tempDir;

    @Test
    void parsesSevenKeyManiaTapAndHoldNotes() throws Exception {
        File chartFile = writeSevenKeyFixture();

        ChartList charts = ChartParser.parseFile(chartFile);

        assertNotNull(charts);
        assertEquals(1, charts.size());

        Chart chart = charts.get(0);
        assertEquals("Seven Key Fixture", chart.getTitle());
        assertEquals("Fixture Artist", chart.getArtist());
        assertEquals("Fixture Creator", chart.getNoter());
        assertEquals(7, chart.getKeys());
        assertEquals(8, chart.getNoteCount());
        assertEquals(8, chart.getLevel());
        assertEquals(3, chart.getDuration());
        assertEquals(120.0, chart.getBPM(), 0.0001);

        EventList events = chart.getEvents();
        assertEquals(1, events.getEventsFromThisChannel(Event.Channel.BPM_CHANGE).size());

        Event.Channel[] channels = Event.Channel.playableChannels();
        for (int i = 0; i < channels.length; i++) {
            EventList laneEvents = events.getEventsFromThisChannel(channels[i]);
            int expectedLaneEvents = i == 3 ? 3 : 1;
            assertEquals(expectedLaneEvents, laneEvents.size(), "lane " + (i + 1));
            assertEquals(Event.Flag.NONE, laneEvents.get(0).getFlag());
            assertEquals(0, laneEvents.get(0).getMeasure());
            assertEquals(i / 8.0, laneEvents.get(0).getPosition(), 0.0001);
        }

        EventList holdLane = events.getEventsFromThisChannel(Event.Channel.NOTE_4);
        assertEquals(3, holdLane.size());
        assertEquals(Event.Flag.HOLD, holdLane.get(1).getFlag());
        assertEquals(Event.Flag.RELEASE, holdLane.get(2).getFlag());
        assertEquals(1, holdLane.get(1).getMeasure());
        assertEquals(0.0, holdLane.get(1).getPosition(), 0.0001);
        assertEquals(1, holdLane.get(2).getMeasure());
        assertEquals(0.5, holdLane.get(2).getPosition(), 0.0001);
    }

    @Test
    void parsesSevenKeyChartsFromOszAndSkipsOtherKeyCounts() throws Exception {
        File archive = new File(tempDir, "beatmapset.osz");
        ZipOutputStream zip = new ZipOutputStream(Files.newOutputStream(archive.toPath()));
        try {
            writeZipEntry(zip, "audio.ogg", new byte[] {'O', 'g', 'g', 'S'});
            writeZipEntry(zip, "four-key.osu", buildFixtureContent(4).getBytes(StandardCharsets.UTF_8));
            writeZipEntry(zip, "seven-key.osu", buildFixtureContent(7).getBytes(StandardCharsets.UTF_8));
        } finally {
            zip.close();
        }

        ChartList charts = ChartParser.parseFile(archive);

        assertNotNull(charts);
        assertEquals(1, charts.size());
        Chart chart = charts.get(0);
        assertEquals("Seven Key Fixture", chart.getTitle());
        assertEquals(7, chart.getKeys());

        Map<Integer, SampleData> samples = chart.getSamples();
        assertEquals(1, samples.size());
        assertEquals(SampleData.Type.OGG, samples.get(1).getType());
    }

    @Test
    void acceptsNumericCircleSizeForSevenKeyManiaCharts() throws Exception {
        File chartFile = new File(tempDir, "numeric-circle-size.osu");
        String content = buildFixtureContent(7).replace("CircleSize:7", "CircleSize:7.0");
        Files.write(chartFile.toPath(), content.getBytes(StandardCharsets.UTF_8));

        ChartList charts = ChartParser.parseFile(chartFile);

        assertNotNull(charts);
        assertEquals(1, charts.size());
        assertEquals(7, charts.get(0).getKeys());
    }

    @Test
    void mapsCustomHitSampleFilenamesToPlayableNotesFromOsz() throws Exception {
        File archive = new File(tempDir, "keysounded.osz");
        ZipOutputStream zip = new ZipOutputStream(Files.newOutputStream(archive.toPath()));
        try {
            String content = buildFixtureContent(7).replace(
                    "36,192,0,1,0,0:0:0:0:",
                    "36,192,0,1,0,0:0:0:75:kick.wav");
            writeZipEntry(zip, "audio.ogg", new byte[] {'O', 'g', 'g', 'S'});
            writeZipEntry(zip, "kick.wav", new byte[] {'R', 'I', 'F', 'F'});
            writeZipEntry(zip, "seven-key.osu", content.getBytes(StandardCharsets.UTF_8));
        } finally {
            zip.close();
        }

        Chart chart = ChartParser.parseFile(archive).get(0);
        Event firstNote = chart.getEvents().getEventsFromThisChannel(Event.Channel.NOTE_1).get(0);

        assertEquals(2, (int) firstNote.getValue());
        assertEquals(0.75f, firstNote.getSample().volume, 0.0001f);
        assertEquals(SampleData.Type.WAV, chart.getSamples().get(2).getType());
        chart.getSamples().get(2).dispose();
    }

    @Test
    void mapsCustomHitSampleFilenamesToHoldNotes() throws Exception {
        File chartFile = new File(tempDir, "hold-keysound.osu");
        String content = buildFixtureContent(7).replace(
                "256,192,2000,128,0,3000:0:0:0:0:",
                "256,192,2000,128,0,3000:0:0:0:65:hold.wav");
        Files.write(chartFile.toPath(), content.getBytes(StandardCharsets.UTF_8));
        Files.write(new File(tempDir, "hold.wav").toPath(), new byte[] {'R', 'I', 'F', 'F'});

        Chart chart = ChartParser.parseFile(chartFile).get(0);
        Event hold = chart.getEvents().getEventsFromThisChannel(Event.Channel.NOTE_4).get(1);
        Event release = chart.getEvents().getEventsFromThisChannel(Event.Channel.NOTE_4).get(2);

        assertEquals(2, (int) hold.getValue());
        assertEquals(2, (int) release.getValue());
        assertEquals(0.65f, hold.getSample().volume, 0.0001f);
        assertEquals(SampleData.Type.WAV, chart.getSamples().get(2).getType());
        chart.getSamples().get(2).dispose();
    }

    @Test
    void normalizesNegativeTimingPointsToAudioStart() throws Exception {
        File chartFile = new File(tempDir, "negative-timing.osu");
        String content = buildFixtureContent(7).replace("0,500,4,2,1,60,1,0", "-1000,500,4,2,1,60,1,0");
        Files.write(chartFile.toPath(), content.getBytes(StandardCharsets.UTF_8));

        Chart chart = ChartParser.parseFile(chartFile).get(0);

        Event firstNote = chart.getEvents().getEventsFromThisChannel(Event.Channel.NOTE_1).get(0);
        assertEquals(0, firstNote.getMeasure());
        assertEquals(0.0, firstNote.getPosition(), 0.0001);
    }

    @Test
    void prefersUnicodeMetadataWhenPresent() throws Exception {
        File chartFile = new File(tempDir, "unicode.osu");
        String content = buildFixtureContent(7)
                .replace("Title:Seven Key Fixture", "Title:Seven Key Fixture\nTitleUnicode:\u4e03\u952e\u6d4b\u8bd5")
                .replace("Artist:Fixture Artist", "Artist:Fixture Artist\nArtistUnicode:\u4f5c\u8005");
        Files.write(chartFile.toPath(), content.getBytes(StandardCharsets.UTF_8));

        Chart chart = ChartParser.parseFile(chartFile).get(0);

        assertEquals("\u4e03\u952e\u6d4b\u8bd5", chart.getTitle());
        assertEquals("\u4f5c\u8005", chart.getArtist());
    }

    @Test
    void mapsInheritedTimingPointsToScrollSpeedEvents() throws Exception {
        File chartFile = new File(tempDir, "scroll-speed.osu");
        String content = buildFixtureContent(7).replace(
                "0,500,4,2,1,60,1,0",
                "0,500,4,2,1,60,1,0\n1000,-50,4,2,1,60,0,0");
        Files.write(chartFile.toPath(), content.getBytes(StandardCharsets.UTF_8));

        Chart chart = ChartParser.parseFile(chartFile).get(0);
        EventList scrollEvents = chart.getEvents().getEventsFromThisChannel(Event.Channel.SCROLL_SPEED);

        assertEquals(1, scrollEvents.size());
        assertEquals(0, scrollEvents.get(0).getMeasure());
        assertEquals(0.5, scrollEvents.get(0).getPosition(), 0.0001);
        assertEquals(2.0, scrollEvents.get(0).getValue(), 0.0001);
    }

    @Test
    void mapsTimingPointMeterToTimeSignatureEvents() throws Exception {
        File chartFile = new File(tempDir, "meter.osu");
        String content = buildFixtureContent(7).replace(
                "0,500,4,2,1,60,1,0",
                "0,500,3,2,1,60,1,0");
        Files.write(chartFile.toPath(), content.getBytes(StandardCharsets.UTF_8));

        Chart chart = ChartParser.parseFile(chartFile).get(0);
        EventList signatures = chart.getEvents().getEventsFromThisChannel(Event.Channel.TIME_SIGNATURE);
        Event secondLane = chart.getEvents().getEventsFromThisChannel(Event.Channel.NOTE_2).get(0);

        assertEquals(1, signatures.size());
        assertEquals(0.75, signatures.get(0).getValue(), 0.0001);
        assertEquals(0, secondLane.getMeasure());
        assertEquals(1.0 / 6.0, secondLane.getPosition(), 0.0001);
    }

    private File writeSevenKeyFixture() throws Exception {
        File chartFile = new File(tempDir, "seven-key.osu");
        Files.write(chartFile.toPath(), buildFixtureContent(7).getBytes(StandardCharsets.UTF_8));
        return chartFile;
    }

    private String buildFixtureContent(int keys) {
        return ""
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
                + "HPDrainRate:5\n"
                + "CircleSize:" + keys + "\n"
                + "OverallDifficulty:8\n"
                + "\n"
                + "[TimingPoints]\n"
                + "0,500,4,2,1,60,1,0\n"
                + "\n"
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

    private void writeZipEntry(ZipOutputStream zip, String name, byte[] bytes) throws Exception {
        zip.putNextEntry(new ZipEntry(name));
        zip.write(bytes);
        zip.closeEntry();
    }
}
