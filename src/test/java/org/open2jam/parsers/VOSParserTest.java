package org.open2jam.parsers;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class VOSParserTest {
    private static final Charset VOS_CHARSET = Charset.forName("GB2312");

    @TempDir
    File tempDir;

    @Test
    void parsesKnownLevelMetadata() throws Exception {
        File chartFile = writeFixture("known.vos", 7, true, true, false);

        ChartList charts = ChartParser.parseFile(chartFile);

        assertNotNull(charts);
        assertEquals(1, charts.size());
        VOSChart chart = (VOSChart) charts.get(0);
        assertEquals(Chart.TYPE.VOS, chart.type);
        assertEquals("Canon in D", chart.getTitle());
        assertEquals("Pachelbel", chart.getArtist());
        assertEquals("Classical", chart.getGenre());
        assertEquals("ReVanTis", chart.getNoter());
        assertEquals(123, chart.getDuration());
        assertTrue(chart.hasKnownLevel());
        assertEquals(7, chart.getLevel());
        assertFalse(chart.hasCover());
    }

    @Test
    void parsesMissingLevelAsUnknownLevel() throws Exception {
        File chartFile = writeFixture("missing-level.vos", 0, false, false, false);

        ChartList charts = ChartParser.parseFile(chartFile);

        assertNotNull(charts);
        assertEquals(1, charts.size());
        VOSChart chart = (VOSChart) charts.get(0);
        assertFalse(chart.hasKnownLevel());
        assertEquals(0, chart.getLevel());
    }

    @Test
    void parsesDirectoryVosFilesSortedByLevel() throws Exception {
        writeFixture("hard.vos", 9, true, false, false);
        writeFixture("easy.vos", 3, true, false, false);

        ChartList charts = ChartParser.parseFile(tempDir);

        assertNotNull(charts);
        assertEquals(2, charts.size());
        assertEquals(3, charts.get(0).getLevel());
        assertEquals(9, charts.get(1).getLevel());
    }

    @Test
    void fallsBackToFileNameWhenTitleIsMissing() throws Exception {
        File chartFile = writeFixture("untitled-song.vos", 5, true, false, false, "");

        ChartList charts = ChartParser.parseFile(chartFile);

        assertNotNull(charts);
        assertEquals("untitled-song", charts.get(0).getTitle());
    }

    @Test
    void readsMinimalChannelBlocksForNoteCountAndCachedEvents() throws Exception {
        File chartFile = writeFixture("notes.vos", 4, true, true, false);

        ChartList charts = ChartParser.parseFile(chartFile);

        assertNotNull(charts);
        VOSChart chart = (VOSChart) charts.get(0);

        assertEquals(1, chart.getNoteCount());
        assertEquals(1, chart.getEvents().size());
    }

    @Test
    void mapsTapNotesToExistingNoteChannels() throws Exception {
        Event.Channel[] expectedChannels = {
            Event.Channel.NOTE_1,
            Event.Channel.NOTE_2,
            Event.Channel.NOTE_3,
            Event.Channel.NOTE_4,
            Event.Channel.NOTE_5,
            Event.Channel.NOTE_6,
            Event.Channel.NOTE_7
        };

        for (int lane = 0; lane < expectedChannels.length; lane++) {
            File chartFile = writeTapNoteFixture("tap-lane-" + (lane + 1) + ".vos", 5, 0x80 + lane * 0x10);

            VOSChart chart = (VOSChart) ChartParser.parseFile(chartFile).get(0);
            EventList events = chart.getEvents();

            assertEquals(1, events.size());
            Event event = events.get(0);
            assertEquals(expectedChannels[lane], event.getChannel());
            assertEquals(Event.Flag.NONE, event.getFlag());
            assertEquals(0, event.getMeasure());
            assertEquals(0.0, event.getPosition(), 0.0001);
        }
    }

    @Test
    void mapsLongNotesToHoldAndReleaseEvents() throws Exception {
        File chartFile = writeLongNoteFixture("long.vos", 5);

        VOSChart chart = (VOSChart) ChartParser.parseFile(chartFile).get(0);
        EventList allEvents = chart.getEvents();
        assertEquals(2, allEvents.size());

        EventList events = allEvents.getOnlyLongNotes();

        assertEquals(2, events.size());
        assertEquals(Event.Channel.NOTE_1, events.get(0).getChannel());
        assertEquals(Event.Channel.NOTE_1, events.get(1).getChannel());
        assertEquals(Event.Flag.HOLD, events.get(0).getFlag());
        assertEquals(Event.Flag.RELEASE, events.get(1).getFlag());
        assertEquals(1, events.get(0).getMeasure());
        assertEquals(1, events.get(1).getMeasure());
        assertEquals(0.0, events.get(0).getPosition(), 0.0001);
        assertEquals(0.5, events.get(1).getPosition(), 0.0001);
    }

    @Test
    void directoryCanReadRequiresAtLeastOneValidVosHeader() throws Exception {
        Files.write(new File(tempDir, "invalid.vos").toPath(), new byte[] {0, 0, 0, 4});

        assertFalse(VOSParser.canRead(tempDir));
        assertNull(ChartParser.parseFile(tempDir));
    }

    @Test
    void rejectsNegativeChannelNoteCount() throws Exception {
        File chartFile = writeFixtureWithNoteCount("negative-note-count.vos", -1);

        assertNull(ChartParser.parseFile(chartFile));
    }

    @Test
    void malformedVosDoesNotCaptureDirectoryFromBmsParser() throws Exception {
        Files.write(new File(tempDir, "broken.vos").toPath(), new byte[] {0, 0, 0, 3});
        writeMinimalBms("fallback.bms");

        ChartList charts = ChartParser.parseFile(tempDir);

        assertNotNull(charts);
        assertEquals(Chart.TYPE.BMS, charts.get(0).type);
    }

    private File writeFixture(String fileName, int level, boolean includeLevel,
            boolean includeChannelData, boolean includeLongNote) throws IOException {
        return writeFixture(fileName, level, includeLevel, includeChannelData, includeLongNote, "Canon in D");
    }

    private File writeFixture(String fileName, int level, boolean includeLevel,
            boolean includeChannelData, boolean includeLongNote, String title) throws IOException {
        byte[] bytes = buildFixture(level, includeLevel, includeChannelData, includeLongNote, title);
        File file = new File(tempDir, fileName);
        Files.write(file.toPath(), bytes);
        return file;
    }

    private File writeLongNoteFixture(String fileName, int level) throws IOException {
        byte[] bytes = buildFixture(level, true, true, false, "Canon in D", null, true);
        File file = new File(tempDir, fileName);
        Files.write(file.toPath(), bytes);
        return file;
    }

    private File writeTapNoteFixture(String fileName, int level, int keyboard) throws IOException {
        byte[] bytes = buildFixture(level, true, true, false, "Canon in D", null, false, keyboard);
        File file = new File(tempDir, fileName);
        Files.write(file.toPath(), bytes);
        return file;
    }

    private File writeFixtureWithNoteCount(String fileName, int noteCount) throws IOException {
        byte[] bytes = buildFixture(4, true, true, false, "Canon in D", noteCount);
        File file = new File(tempDir, fileName);
        Files.write(file.toPath(), bytes);
        return file;
    }

    private File writeMinimalBms(String fileName) throws IOException {
        File file = new File(tempDir, fileName);
        String content = "#PLAYER 1\n#TITLE fallback\n#ARTIST test\n#PLAYLEVEL 1\n#00115:01\n";
        Files.write(file.toPath(), content.getBytes(StandardCharsets.UTF_8));
        return file;
    }

    private static byte[] buildFixture(int level, boolean includeLevel,
            boolean includeChannelData, boolean includeLongNote, String title) throws IOException {
        return buildFixture(level, includeLevel, includeChannelData, includeLongNote, title, null);
    }

    private static byte[] buildFixture(int level, boolean includeLevel,
            boolean includeChannelData, boolean includeLongNote, String title, Integer noteCountOverride)
            throws IOException {
        return buildFixture(level, includeLevel, includeChannelData, includeLongNote, title, noteCountOverride,
                false);
    }

    private static byte[] buildFixture(int level, boolean includeLevel,
            boolean includeChannelData, boolean includeLongNote, String title, Integer noteCountOverride,
            boolean longNoteOnly) throws IOException {
        return buildFixture(level, includeLevel, includeChannelData, includeLongNote, title, noteCountOverride,
                longNoteOnly, 0x80);
    }

    private static byte[] buildFixture(int level, boolean includeLevel,
            boolean includeChannelData, boolean includeLongNote, String title, Integer noteCountOverride,
            boolean longNoteOnly, int tapKeyboard) throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        writeInt(out, 3);
        writeSegment(out, 0, "INF");
        writeSegment(out, 0, "MID");
        writeSegment(out, 0, "EOF");

        writeString(out, title);
        writeString(out, "Pachelbel");
        writeString(out, "fixture comment");
        writeString(out, "ReVanTis");
        out.write(9);
        out.write(0);
        writeInt(out, 123000);
        if (includeLevel) {
            out.write(level);
        }
        out.write(new byte[1023]);
        if (includeChannelData) {
            writeInt(out, 1);
            int noteCount = noteCountOverride == null ? (longNoteOnly || !includeLongNote ? 1 : 2)
                    : noteCountOverride;
            writeInt(out, noteCount);
            out.write(new byte[14]);
            if (noteCountOverride == null || noteCountOverride > 0) {
                if (!longNoteOnly) {
                    writeNote(out, 0x000, 0x000, 0, 60, 100, tapKeyboard, 0x00);
                }
                if (includeLongNote || longNoteOnly) {
                    writeNote(out, 0x300, 0x180, 0, 62, 100, 0x81, 0x80);
                }
            }
        }

        return patchSegmentAddresses(out.toByteArray());
    }

    private static byte[] patchSegmentAddresses(byte[] bytes) {
        writeInt(bytes, 4, 64);
        writeInt(bytes, 24, bytes.length);
        writeInt(bytes, 44, bytes.length);
        return bytes;
    }

    private static void writeSegment(ByteArrayOutputStream out, int address, String name) throws IOException {
        writeInt(out, address);
        byte[] nameBytes = new byte[16];
        byte[] rawName = name.getBytes(VOS_CHARSET);
        System.arraycopy(rawName, 0, nameBytes, 0, rawName.length);
        out.write(nameBytes);
    }

    private static void writeString(ByteArrayOutputStream out, String value) throws IOException {
        byte[] bytes = value.getBytes(VOS_CHARSET);
        out.write(bytes.length);
        out.write(bytes);
    }

    private static void writeNote(ByteArrayOutputStream out, int sequencer, int duration,
            int channel, int pitch, int volume, int keyboard, int type) throws IOException {
        writeInt(out, sequencer);
        writeInt(out, duration);
        out.write(channel);
        out.write(pitch);
        out.write(volume);
        out.write(keyboard);
        out.write(type);
    }

    private static void writeInt(ByteArrayOutputStream out, int value) throws IOException {
        out.write((value >>> 24) & 0xFF);
        out.write((value >>> 16) & 0xFF);
        out.write((value >>> 8) & 0xFF);
        out.write(value & 0xFF);
    }

    private static void writeInt(byte[] bytes, int offset, int value) {
        bytes[offset] = (byte) ((value >>> 24) & 0xFF);
        bytes[offset + 1] = (byte) ((value >>> 16) & 0xFF);
        bytes[offset + 2] = (byte) ((value >>> 8) & 0xFF);
        bytes[offset + 3] = (byte) (value & 0xFF);
    }
}
