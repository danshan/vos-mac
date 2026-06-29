package org.open2jam.parsers;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
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
    private static final boolean LONG_NOTE_ONLY = true;
    private static final boolean INCLUDE_DISTRACTOR_NOTE = true;
    private static final boolean PLAYABLE_ONLY = false;
    private static final boolean REPEATED_LIVE_SAMPLES = true;
    private static final int VOS_DROID_CHANNEL_COUNT = 17;
    private static final int VOS_DROID_PLAYABLE_CHANNEL_INDEX = 16;
    private static final int EMBEDDED_MIDI_CHANNEL = 0;
    private static final int EMBEDDED_MIDI_PROGRAM = 40;
    private static final int EMBEDDED_MIDI_CONTROLLER = 7;
    private static final int EMBEDDED_MIDI_CONTROLLER_VALUE = 96;

    @TempDir
    File tempDir;

    @Test
    void parsesKnownLevelMetadata() throws Exception {
        File chartFile = VosFixtureFactory.writeFixture(tempDir, "known.vos", 7, true, true, false);

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
        File chartFile = VosFixtureFactory.writeFixture(tempDir, "missing-level.vos", 0, false, false, false);

        ChartList charts = ChartParser.parseFile(chartFile);

        assertNotNull(charts);
        assertEquals(1, charts.size());
        VOSChart chart = (VOSChart) charts.get(0);
        assertFalse(chart.hasKnownLevel());
        assertEquals(0, chart.getLevel());
    }

    @Test
    void doesNotGroupDirectoryVosFilesIntoOneChartList() throws Exception {
        VosFixtureFactory.writeFixture(tempDir, "hard.vos", 9, true, false, false);
        VosFixtureFactory.writeFixture(tempDir, "easy.vos", 3, true, false, false);

        ChartList charts = ChartParser.parseFile(tempDir);

        assertFalse(VOSParser.canRead(tempDir));
        assertNull(charts);
        assertNull(VOSParser.parseFile(tempDir));
    }

    @Test
    void fallsBackToFileNameWhenTitleIsMissing() throws Exception {
        File chartFile = VosFixtureFactory.writeFixture(tempDir, "untitled-song.vos", 5, true, false, false, "");

        ChartList charts = ChartParser.parseFile(chartFile);

        assertNotNull(charts);
        assertEquals("untitled-song", charts.get(0).getTitle());
    }

    @Test
    void readsMinimalChannelBlocksForNoteCountAndCachedEvents() throws Exception {
        File chartFile = VosFixtureFactory.writeFixture(tempDir, "notes.vos", 4, true, true, false);

        ChartList charts = ChartParser.parseFile(chartFile);

        assertNotNull(charts);
        VOSChart chart = (VOSChart) charts.get(0);

        assertEquals(1, chart.getNoteCount());
        assertEquals(1, chart.getEvents().getEventsFromThisChannel(Event.Channel.NOTE_1).size());
    }

    @Test
    void providesGeneratedSamplesForVosEvents() throws Exception {
        File chartFile = VosFixtureFactory.writeFixture(tempDir, "samples.vos", 4, true, true, false);

        VOSChart chart = (VOSChart) ChartParser.parseFile(chartFile).get(0);
        Event event = chart.getEvents().getEventsFromThisChannel(Event.Channel.NOTE_1).get(0);
        Map<Integer, SampleData> samples = chart.getSamples();

        assertFalse(samples.isEmpty());
        assertTrue(samples.containsKey((int) event.getValue()));
        assertEquals(SampleData.Type.MIDI, samples.get((int) event.getValue()).getType());
    }

    @Test
    void readsLittleEndianVosHeaderAndSegmentAddresses() throws Exception {
        byte[] bytes = VosFixtureFactory.buildFixture(4, true, true, false, "Canon in D");
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
            File chartFile = VosFixtureFactory.writeFixture(tempDir, "tap-lane-" + (lane + 1) + ".vos",
                    5, 0x80 + lane * 0x10);

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
        File chartFile = VosFixtureFactory.writeFixture(tempDir, "long.vos", 5, LONG_NOTE_ONLY);

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
        File chartFile = VosFixtureFactory.writeFixture(tempDir, "playable-channel.vos", 5,
                VOS_DROID_CHANNEL_COUNT, VOS_DROID_PLAYABLE_CHANNEL_INDEX, INCLUDE_DISTRACTOR_NOTE);

        VOSChart chart = (VOSChart) ChartParser.parseFile(chartFile).get(0);
        EventList events = chart.getEvents();
        EventList playableEvents = events.getEventsFromThisChannel(Event.Channel.NOTE_3);

        assertEquals(1, playableEvents.size());
        assertEquals(Event.Channel.NOTE_3, playableEvents.get(0).getChannel());
        assertTrue(chart.getSamples().containsKey((int) playableEvents.get(0).getValue()));
    }

    @Test
    void mapsVosSoundChannelsToAutoplayEvents() throws Exception {
        File chartFile = VosFixtureFactory.writeFixture(tempDir, "sound-channel.vos", 5,
                VOS_DROID_CHANNEL_COUNT, VOS_DROID_PLAYABLE_CHANNEL_INDEX, INCLUDE_DISTRACTOR_NOTE);

        VOSChart chart = (VOSChart) ChartParser.parseFile(chartFile).get(0);
        EventList events = chart.getEvents();
        EventList autoplayEvents = events.getEventsFromThisChannel(Event.Channel.AUTO_PLAY);

        assertEquals(1, autoplayEvents.size());
        assertTrue(chart.getSamples().containsKey((int) autoplayEvents.get(0).getValue()));
    }

    @Test
    void preservesEmbeddedMidiNotesInVosDroidBackgroundPlayback() throws Exception {
        File chartFile = VosFixtureFactory.writeFixture(tempDir, "embedded-midi-background.vos", 5,
                VOS_DROID_CHANNEL_COUNT, VOS_DROID_PLAYABLE_CHANNEL_INDEX, PLAYABLE_ONLY,
                EMBEDDED_MIDI_CHANNEL, EMBEDDED_MIDI_PROGRAM, EMBEDDED_MIDI_CONTROLLER,
                EMBEDDED_MIDI_CONTROLLER_VALUE);

        VOSChart chart = (VOSChart) ChartParser.parseFile(chartFile).get(0);
        EventList autoplayEvents = chart.getEvents().getEventsFromThisChannel(Event.Channel.AUTO_PLAY);

        assertEquals(1, autoplayEvents.size());
        assertEquals(1, noteCountForEvent(chart, autoplayEvents.get(0)));
    }

    @Test
    void usesVosDroidFallbackInstrumentForPlayableOnlyLiveMidi() throws Exception {
        File chartFile = VosFixtureFactory.writeFixture(tempDir, "playable-only-live-midi.vos", 5,
                VOS_DROID_CHANNEL_COUNT, VOS_DROID_PLAYABLE_CHANNEL_INDEX, INCLUDE_DISTRACTOR_NOTE,
                EMBEDDED_MIDI_CHANNEL, EMBEDDED_MIDI_PROGRAM, EMBEDDED_MIDI_CONTROLLER,
                EMBEDDED_MIDI_CONTROLLER_VALUE);

        VOSChart chart = (VOSChart) ChartParser.parseFile(chartFile).get(0);
        Event event = chart.getEvents().getEventsFromThisChannel(Event.Channel.NOTE_3).get(0);

        assertEquals(0, firstProgramChangeForEvent(chart, event));
        assertEquals(-1, firstControlChangeForEvent(chart, event, 7));
    }

    @Test
    void usesVosDroidSourceInstrumentForOverlappedLiveMidi() throws Exception {
        File chartFile = VosFixtureFactory.writeFixture(tempDir, "source-overlap-live-midi.vos", 5,
                0x000, 0x000, EMBEDDED_MIDI_CHANNEL, EMBEDDED_MIDI_PROGRAM, EMBEDDED_MIDI_CONTROLLER,
                EMBEDDED_MIDI_CONTROLLER_VALUE);

        VOSChart chart = (VOSChart) ChartParser.parseFile(chartFile).get(0);
        Event event = chart.getEvents().getEventsFromThisChannel(Event.Channel.NOTE_1).get(0);

        assertEquals(1, firstProgramChangeForEvent(chart, event));
        assertEquals(-1, firstControlChangeForEvent(chart, event, 7));
    }

    @Test
    void reusesIdenticalLiveMidiSamplesAcrossVosNotes() throws Exception {
        File chartFile = VosFixtureFactory.writeFixture(tempDir, "repeated-live-samples.vos", 5, 2,
                REPEATED_LIVE_SAMPLES);

        VOSChart chart = (VOSChart) ChartParser.parseFile(chartFile).get(0);
        EventList events = chart.getEvents().getEventsFromThisChannel(Event.Channel.NOTE_1);

        assertEquals(2, events.size());
        assertEquals(events.get(0).getValue(), events.get(1).getValue(), 0.0);
    }

    @Test
    void splitsVosDroidPlayableSourceIntoLiveSampleAtSameSongPosition() throws Exception {
        File chartFile = VosFixtureFactory.writeFixture(tempDir, "source-overlap-live-timing.vos", 5,
                0x300, 0x172);

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
        File chartFile = VosFixtureFactory.writeFixture(tempDir, "tempo.vos", 4, true, true, false);

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
        File chartFile = VosFixtureFactory.writeFixture(tempDir, "negative-note-count.vos", 4, Integer.valueOf(-1));

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

    private File writeMinimalBms(String fileName) throws IOException {
        File file = new File(tempDir, fileName);
        String content = "#PLAYER 1\n#TITLE fallback\n#ARTIST test\n#PLAYLEVEL 1\n#00115:01\n";
        Files.write(file.toPath(), content.getBytes(StandardCharsets.UTF_8));
        return file;
    }
}
