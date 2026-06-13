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
import java.util.Map;
import javax.sound.midi.MidiSystem;
import javax.sound.midi.Sequence;
import javax.sound.midi.ShortMessage;
import javax.sound.midi.Track;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.open2jam.parsers.utils.SampleData;

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
        assertEquals(1, chart.getEvents().getEventsFromThisChannel(Event.Channel.NOTE_1).size());
    }

    @Test
    void providesGeneratedSamplesForVosEvents() throws Exception {
        File chartFile = writeFixture("samples.vos", 4, true, true, false);

        VOSChart chart = (VOSChart) ChartParser.parseFile(chartFile).get(0);
        Event event = chart.getEvents().getEventsFromThisChannel(Event.Channel.NOTE_1).get(0);
        Map<Integer, SampleData> samples = chart.getSamples();

        assertFalse(samples.isEmpty());
        assertTrue(samples.containsKey((int) event.getValue()));
        assertEquals(SampleData.Type.MIDI, samples.get((int) event.getValue()).getType());
    }

    @Test
    void readsLittleEndianVosHeaderAndSegmentAddresses() throws Exception {
        byte[] bytes = buildFixture(4, true, true, false, "Canon in D");
        assertEquals(3, bytes[0] & 0xFF);
        assertEquals(0, bytes[1] & 0xFF);
        assertEquals(0, bytes[2] & 0xFF);
        assertEquals(0, bytes[3] & 0xFF);

        File chartFile = new File(tempDir, "little-endian.vos");
        Files.write(chartFile.toPath(), bytes);

        ChartList charts = ChartParser.parseFile(chartFile);

        assertNotNull(charts);
        assertEquals("Canon in D", charts.get(0).getTitle());
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
            EventList events = chart.getEvents().getEventsFromThisChannel(expectedChannels[lane]);

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

        EventList events = allEvents.getOnlyLongNotes();

        assertEquals(2, events.size());
        assertEquals(Event.Channel.NOTE_1, events.get(0).getChannel());
        assertEquals(Event.Channel.NOTE_1, events.get(1).getChannel());
        assertEquals(Event.Flag.HOLD, events.get(0).getFlag());
        assertEquals(Event.Flag.RELEASE, events.get(1).getFlag());
        assertEquals(0, events.get(0).getMeasure());
        assertEquals(0, events.get(1).getMeasure());
        assertEquals(0.25, events.get(0).getPosition(), 0.0001);
        assertEquals(0.375, events.get(1).getPosition(), 0.0001);

        allEvents.fixEventList(EventList.FixMethod.OPEN2JAM, true);
        EventList fixedEvents = allEvents.getOnlyLongNotes();
        assertEquals(2, fixedEvents.size());
        assertEquals(Event.Flag.HOLD, fixedEvents.get(0).getFlag());
        assertEquals(Event.Flag.RELEASE, fixedEvents.get(1).getFlag());
    }

    @Test
    void mapsOnlyVosPlayableChannelToEvents() throws Exception {
        File chartFile = writePlayableChannelFixture("playable-channel.vos", 5);

        VOSChart chart = (VOSChart) ChartParser.parseFile(chartFile).get(0);
        EventList events = chart.getEvents();
        EventList playableEvents = events.getEventsFromThisChannel(Event.Channel.NOTE_3);

        assertEquals(1, playableEvents.size());
        assertEquals(Event.Channel.NOTE_3, playableEvents.get(0).getChannel());
        assertTrue(chart.getSamples().containsKey((int) playableEvents.get(0).getValue()));
    }

    @Test
    void mapsVosSoundChannelsToAutoplayEvents() throws Exception {
        File chartFile = writePlayableChannelFixture("sound-channel.vos", 5);

        VOSChart chart = (VOSChart) ChartParser.parseFile(chartFile).get(0);
        EventList events = chart.getEvents();
        EventList autoplayEvents = events.getEventsFromThisChannel(Event.Channel.AUTO_PLAY);

        assertEquals(1, autoplayEvents.size());
        assertTrue(chart.getSamples().containsKey((int) autoplayEvents.get(0).getValue()));
    }

    @Test
    void preservesEmbeddedMidiNotesInVosDroidBackgroundPlayback() throws Exception {
        File chartFile = writePlayableOnlyFixture("embedded-midi-background.vos", 5,
                midiWithChannelState(0, 40, 7, 96));

        VOSChart chart = (VOSChart) ChartParser.parseFile(chartFile).get(0);
        EventList autoplayEvents = chart.getEvents().getEventsFromThisChannel(Event.Channel.AUTO_PLAY);

        assertEquals(1, autoplayEvents.size());
        assertEquals(1, noteCountForEvent(chart, autoplayEvents.get(0)));
    }

    @Test
    void usesVosDroidFallbackInstrumentForPlayableOnlyLiveMidi() throws Exception {
        File chartFile = writePlayableChannelFixture("playable-only-live-midi.vos", 5,
                midiWithChannelState(0, 40, 7, 96));

        VOSChart chart = (VOSChart) ChartParser.parseFile(chartFile).get(0);
        Event event = chart.getEvents().getEventsFromThisChannel(Event.Channel.NOTE_3).get(0);

        assertEquals(0, firstProgramChangeForEvent(chart, event));
        assertEquals(-1, firstControlChangeForEvent(chart, event, 7));
    }

    @Test
    void usesVosDroidSourceInstrumentForOverlappedLiveMidi() throws Exception {
        File chartFile = writeSourceOverlapFixture("source-overlap-live-midi.vos", 5,
                midiWithChannelState(0, 40, 7, 96));

        VOSChart chart = (VOSChart) ChartParser.parseFile(chartFile).get(0);
        Event event = chart.getEvents().getEventsFromThisChannel(Event.Channel.NOTE_1).get(0);

        assertEquals(1, firstProgramChangeForEvent(chart, event));
        assertEquals(-1, firstControlChangeForEvent(chart, event, 7));
    }

    @Test
    void reusesIdenticalLiveMidiSamplesAcrossVosNotes() throws Exception {
        File chartFile = writeRepeatedLiveSampleFixture("repeated-live-samples.vos", 5, minimalMidi());

        VOSChart chart = (VOSChart) ChartParser.parseFile(chartFile).get(0);
        EventList events = chart.getEvents().getEventsFromThisChannel(Event.Channel.NOTE_1);

        assertEquals(2, events.size());
        assertEquals(events.get(0).getValue(), events.get(1).getValue(), 0.0);
    }

    @Test
    void splitsVosDroidPlayableSourceIntoLiveSampleAtSameSongPosition() throws Exception {
        File chartFile = writeSourceOverlapFixture("source-overlap-live-timing.vos", 5,
                minimalMidi(), 0x300, 0x172);

        VOSChart chart = (VOSChart) ChartParser.parseFile(chartFile).get(0);
        Event event = chart.getEvents().getEventsFromThisChannel(Event.Channel.NOTE_1).get(0);

        assertEquals(0, chart.getEvents().getEventsFromThisChannel(Event.Channel.AUTO_PLAY).size());
        assertEquals(0, event.getMeasure());
        assertEquals(0.25, event.getPosition(), 0.0001);
        assertEquals(1, firstProgramChangeForEvent(chart, event));
        assertEquals(0, firstNoteOnTickForEvent(chart, event));
    }

    @Test
    void mapsEmbeddedMidiTempoToBpmEvents() throws Exception {
        File chartFile = writeFixture("tempo.vos", 4, true, true, false);

        VOSChart chart = (VOSChart) ChartParser.parseFile(chartFile).get(0);
        EventList bpmEvents = chart.getEvents().getEventsFromThisChannel(Event.Channel.BPM_CHANGE);

        assertEquals(1, bpmEvents.size());
        assertEquals(120.0, bpmEvents.get(0).getValue(), 0.0001);
    }

    @Test
    void directoryCanReadRequiresAtLeastOneValidVosHeader() throws Exception {
        Files.write(new File(tempDir, "invalid.vos").toPath(), new byte[] {4, 0, 0, 0});

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
        Files.write(new File(tempDir, "broken.vos").toPath(), new byte[] {3, 0, 0, 0});
        writeMinimalBms("fallback.bms");

        ChartList charts = ChartParser.parseFile(tempDir);

        assertNotNull(charts);
        assertEquals(Chart.TYPE.BMS, charts.get(0).type);
    }

    private static int firstProgramChangeForEvent(VOSChart chart, Event event) throws Exception {
        SampleData sample = chart.getSamples().get((int) event.getValue());
        assertNotNull(sample);
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        sample.copyTo(output);
        Sequence sequence = MidiSystem.getSequence(new java.io.ByteArrayInputStream(output.toByteArray()));
        for (Track track : sequence.getTracks()) {
            for (int i = 0; i < track.size(); i++) {
                if (track.get(i).getMessage() instanceof ShortMessage) {
                    ShortMessage message = (ShortMessage) track.get(i).getMessage();
                    if (message.getCommand() == ShortMessage.PROGRAM_CHANGE) {
                        return message.getData1();
                    }
                }
            }
        }
        return -1;
    }

    private static int noteCountForEvent(VOSChart chart, Event event) throws Exception {
        SampleData sample = chart.getSamples().get((int) event.getValue());
        assertNotNull(sample);
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        sample.copyTo(output);
        Sequence sequence = MidiSystem.getSequence(new java.io.ByteArrayInputStream(output.toByteArray()));
        int notes = 0;
        for (Track track : sequence.getTracks()) {
            for (int i = 0; i < track.size(); i++) {
                if (track.get(i).getMessage() instanceof ShortMessage) {
                    ShortMessage message = (ShortMessage) track.get(i).getMessage();
                    if (message.getCommand() == ShortMessage.NOTE_ON && message.getData2() > 0) {
                        notes++;
                    }
                }
            }
        }
        return notes;
    }

    private static long firstNoteOnTickForEvent(VOSChart chart, Event event) throws Exception {
        SampleData sample = chart.getSamples().get((int) event.getValue());
        assertNotNull(sample);
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        sample.copyTo(output);
        Sequence sequence = MidiSystem.getSequence(new java.io.ByteArrayInputStream(output.toByteArray()));
        for (Track track : sequence.getTracks()) {
            for (int i = 0; i < track.size(); i++) {
                if (track.get(i).getMessage() instanceof ShortMessage) {
                    ShortMessage message = (ShortMessage) track.get(i).getMessage();
                    if (message.getCommand() == ShortMessage.NOTE_ON && message.getData2() > 0) {
                        return track.get(i).getTick();
                    }
                }
            }
        }
        return -1;
    }

    private static int firstControlChangeForEvent(VOSChart chart, Event event, int controller) throws Exception {
        SampleData sample = chart.getSamples().get((int) event.getValue());
        assertNotNull(sample);
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        sample.copyTo(output);
        Sequence sequence = MidiSystem.getSequence(new java.io.ByteArrayInputStream(output.toByteArray()));
        for (Track track : sequence.getTracks()) {
            for (int i = 0; i < track.size(); i++) {
                if (track.get(i).getMessage() instanceof ShortMessage) {
                    ShortMessage message = (ShortMessage) track.get(i).getMessage();
                    if (message.getCommand() == ShortMessage.CONTROL_CHANGE
                            && message.getData1() == controller) {
                        return message.getData2();
                    }
                }
            }
        }
        return -1;
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

    private File writePlayableChannelFixture(String fileName, int level) throws IOException {
        return writePlayableChannelFixture(fileName, level, minimalMidi());
    }

    private File writePlayableChannelFixture(String fileName, int level, byte[] embeddedMidi) throws IOException {
        byte[] bytes = buildFixture(level, true, true, false, "Canon in D", null, false, 0x80,
                17, 16, true, embeddedMidi);
        File file = new File(tempDir, fileName);
        Files.write(file.toPath(), bytes);
        return file;
    }

    private File writePlayableOnlyFixture(String fileName, int level, byte[] embeddedMidi) throws IOException {
        byte[] bytes = buildFixture(level, true, true, false, "Canon in D", null, false, 0x80,
                17, 16, false, embeddedMidi);
        File file = new File(tempDir, fileName);
        Files.write(file.toPath(), bytes);
        return file;
    }

    private File writeSourceOverlapFixture(String fileName, int level, byte[] embeddedMidi) throws IOException {
        return writeSourceOverlapFixture(fileName, level, embeddedMidi, 0x000, 0x000);
    }

    private File writeSourceOverlapFixture(String fileName, int level, byte[] embeddedMidi,
            int sequencer, int duration) throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        writeInt(out, 3);
        writeSegment(out, 0, "INF");
        writeSegment(out, 0, "MID");
        writeSegment(out, 0, "EOF");

        writeString(out, "Canon in D");
        writeString(out, "Pachelbel");
        writeString(out, "fixture comment");
        writeString(out, "ReVanTis");
        out.write(9);
        out.write(0);
        writeInt(out, 123000);
        out.write(level);
        out.write(new byte[1023]);

        for (int channel = 0; channel < 17; channel++) {
            writeInt(out, channel + 1);
            writeInt(out, channel == 0 || channel == 16 ? 1 : 0);
            out.write(new byte[14]);
            if (channel == 0) {
                writeNote(out, sequencer, duration, 0, 60, 100, 0x80, 0x00);
            } else if (channel == 16) {
                writeNote(out, sequencer, duration, 0, 60, 100, 0x80, 0x00);
            }
        }

        int channelEnd = out.size();
        out.write(embeddedMidi);
        File file = new File(tempDir, fileName);
        Files.write(file.toPath(), patchSegmentAddresses(out.toByteArray(), channelEnd));
        return file;
    }

    private File writeRepeatedLiveSampleFixture(String fileName, int level, byte[] embeddedMidi)
            throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        writeInt(out, 3);
        writeSegment(out, 0, "INF");
        writeSegment(out, 0, "MID");
        writeSegment(out, 0, "EOF");

        writeString(out, "Canon in D");
        writeString(out, "Pachelbel");
        writeString(out, "fixture comment");
        writeString(out, "ReVanTis");
        out.write(9);
        out.write(0);
        writeInt(out, 123000);
        out.write(level);
        out.write(new byte[1023]);

        for (int channel = 0; channel < 17; channel++) {
            writeInt(out, channel + 1);
            writeInt(out, channel == 16 ? 2 : 0);
            out.write(new byte[14]);
            if (channel == 16) {
                writeNote(out, 0x000, 0x000, 0, 60, 100, 0x80, 0x00);
                writeNote(out, 0x300, 0x000, 0, 60, 100, 0x80, 0x00);
            }
        }

        int channelEnd = out.size();
        out.write(embeddedMidi);
        File file = new File(tempDir, fileName);
        Files.write(file.toPath(), patchSegmentAddresses(out.toByteArray(), channelEnd));
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
        return buildFixture(level, includeLevel, includeChannelData, includeLongNote, title, noteCountOverride,
                longNoteOnly, tapKeyboard, 1, 0, false);
    }

    private static byte[] buildFixture(int level, boolean includeLevel,
            boolean includeChannelData, boolean includeLongNote, String title, Integer noteCountOverride,
            boolean longNoteOnly, int tapKeyboard, int channelCount, int playableChannelIndex,
            boolean includeDistractorNote) throws IOException {
        return buildFixture(level, includeLevel, includeChannelData, includeLongNote, title, noteCountOverride,
                longNoteOnly, tapKeyboard, channelCount, playableChannelIndex, includeDistractorNote, minimalMidi());
    }

    private static byte[] buildFixture(int level, boolean includeLevel,
            boolean includeChannelData, boolean includeLongNote, String title, Integer noteCountOverride,
            boolean longNoteOnly, int tapKeyboard, int channelCount, int playableChannelIndex,
            boolean includeDistractorNote, byte[] embeddedMidi) throws IOException {
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
            for (int channel = 0; channel < channelCount; channel++) {
                writeInt(out, channel + 1);
                int noteCount = noteCountForChannel(channel, playableChannelIndex, noteCountOverride,
                        includeLongNote, longNoteOnly, includeDistractorNote);
                writeInt(out, noteCount);
                out.write(new byte[14]);
                if (noteCountOverride == null || noteCountOverride > 0) {
                    if (includeDistractorNote && channel == 0) {
                        writeNote(out, 0x000, 0x000, 0, 90, 100, 0x80, 0x00);
                    }
                    if (channel == playableChannelIndex) {
                        if (!longNoteOnly) {
                            int pitch = includeDistractorNote ? 61 : 60;
                            int keyboard = includeDistractorNote ? 0xA0 : tapKeyboard;
                            writeNote(out, 0x000, 0x000, 0, pitch, 100, keyboard, 0x00);
                        }
                        if (includeLongNote || longNoteOnly) {
                            writeNote(out, 0x300, 0x172, 0, 62, 100, 0x81, 0x80);
                        }
                    }
                }
            }
        }

        int channelEnd = out.size();
        out.write(embeddedMidi);
        return patchSegmentAddresses(out.toByteArray(), channelEnd);
    }

    private static int noteCountForChannel(int channel, int playableChannelIndex, Integer noteCountOverride,
            boolean includeLongNote, boolean longNoteOnly, boolean includeDistractorNote) {
        if (noteCountOverride != null) {
            return channel == playableChannelIndex ? noteCountOverride : 0;
        }
        if (includeDistractorNote && channel == 0) {
            return 1;
        }
        if (channel != playableChannelIndex) {
            return 0;
        }
        return longNoteOnly || !includeLongNote ? 1 : 2;
    }

    private static byte[] patchSegmentAddresses(byte[] bytes, int midAddress) {
        writeInt(bytes, 4, 64);
        writeInt(bytes, 24, midAddress);
        writeInt(bytes, 44, bytes.length);
        return bytes;
    }

    private static byte[] minimalMidi() throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        out.write("MThd".getBytes(StandardCharsets.US_ASCII));
        writeIntBE(out, 6);
        writeShortBE(out, 1);
        writeShortBE(out, 1);
        writeShortBE(out, 480);
        ByteArrayOutputStream track = new ByteArrayOutputStream();
        track.write(0x00);
        track.write(new byte[] {(byte) 0xFF, 0x51, 0x03, 0x07, (byte) 0xA1, 0x20});
        track.write(0x00);
        track.write(new byte[] {(byte) 0xFF, 0x2F, 0x00});
        out.write("MTrk".getBytes(StandardCharsets.US_ASCII));
        writeIntBE(out, track.size());
        out.write(track.toByteArray());
        return out.toByteArray();
    }

    private static byte[] midiWithChannelState(int channel, int program, int controller, int controllerValue)
            throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        out.write("MThd".getBytes(StandardCharsets.US_ASCII));
        writeIntBE(out, 6);
        writeShortBE(out, 1);
        writeShortBE(out, 1);
        writeShortBE(out, 480);
        ByteArrayOutputStream track = new ByteArrayOutputStream();
        track.write(0x00);
        track.write(new byte[] {(byte) 0xFF, 0x51, 0x03, 0x07, (byte) 0xA1, 0x20});
        track.write(0x00);
        track.write(0xC0 | channel);
        track.write(program);
        track.write(0x00);
        track.write(0xB0 | channel);
        track.write(controller);
        track.write(controllerValue);
        track.write(0x00);
        track.write(0x90 | channel);
        track.write(61);
        track.write(100);
        track.write(0x60);
        track.write(0x80 | channel);
        track.write(61);
        track.write(0);
        track.write(0x00);
        track.write(new byte[] {(byte) 0xFF, 0x2F, 0x00});
        out.write("MTrk".getBytes(StandardCharsets.US_ASCII));
        writeIntBE(out, track.size());
        out.write(track.toByteArray());
        return out.toByteArray();
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
        out.write(value & 0xFF);
        out.write((value >>> 8) & 0xFF);
        out.write((value >>> 16) & 0xFF);
        out.write((value >>> 24) & 0xFF);
    }

    private static void writeIntBE(ByteArrayOutputStream out, int value) throws IOException {
        out.write((value >>> 24) & 0xFF);
        out.write((value >>> 16) & 0xFF);
        out.write((value >>> 8) & 0xFF);
        out.write(value & 0xFF);
    }

    private static void writeShortBE(ByteArrayOutputStream out, int value) throws IOException {
        out.write((value >>> 8) & 0xFF);
        out.write(value & 0xFF);
    }

    private static void writeInt(byte[] bytes, int offset, int value) {
        bytes[offset] = (byte) (value & 0xFF);
        bytes[offset + 1] = (byte) ((value >>> 8) & 0xFF);
        bytes[offset + 2] = (byte) ((value >>> 16) & 0xFF);
        bytes[offset + 3] = (byte) ((value >>> 24) & 0xFF);
    }
}
