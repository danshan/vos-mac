package org.open2jam.sound;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import javax.sound.midi.MidiEvent;
import javax.sound.midi.MidiMessage;
import javax.sound.midi.MidiSystem;
import javax.sound.midi.Sequence;
import javax.sound.midi.ShortMessage;
import javax.sound.midi.Track;
import org.junit.jupiter.api.Test;
import org.open2jam.parsers.ChartParser;
import org.open2jam.parsers.Event;
import org.open2jam.parsers.EventList;
import org.open2jam.parsers.VOSChart;
import org.open2jam.parsers.utils.SampleData;

class VOSReferenceAudioRenderTest {
    private static final File REFERENCE_VOS = new File(
            "/Users/honghao.shan/workspace/opensource/VosDroid/android/assets/Canon in D.vos");

    @Test
    void validatesReferenceVosAudioRuntimePath() throws Exception {
        assumeTrue(REFERENCE_VOS.isFile(), "VosDroid reference chart is not available");

        VosAudioValidator.Result result = VosAudioValidator.validate(REFERENCE_VOS);

        assertEquals(885, result.playableNotes);
        assertEquals(134, result.samples);
        assertEquals(3239, result.backgroundMidiNotes);
        assertEquals(885, result.liveMidiNotes);
        assertTrue(result.performanceSignatureMatches);
        assertEquals(2, result.renderedSamples);
        assertTrue(result.totalPcmBytes > result.backgroundPcmBytes);
    }

    @Test
    void rendersShortReferenceLiveSampleAudibly() throws Exception {
        assumeTrue(REFERENCE_VOS.isFile(), "VosDroid reference chart is not available");
        VOSChart chart = (VOSChart) ChartParser.parseFile(REFERENCE_VOS).get(0);
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        chart.getSamples().get(7).copyTo(output);

        MidiSampleRenderer.RenderedAudio audio = new MidiSampleRenderer().render(output.toByteArray());

        assertTrue(containsNonSilentSample(audio.pcm()));
    }

    @Test
    void splitsReferenceVosDroidPerformanceBetweenBackgroundAndLiveSamples() throws Exception {
        assumeTrue(REFERENCE_VOS.isFile(), "VosDroid reference chart is not available");
        VOSChart chart = (VOSChart) ChartParser.parseFile(REFERENCE_VOS).get(0);

        int backgroundNotes = noteCount(chart, firstEvent(chart.getEvents()
                .getEventsFromThisChannel(Event.Channel.AUTO_PLAY)));
        int liveNotes = 0;
        for (Event.Channel channel : Event.Channel.playableChannels()) {
            EventList events = chart.getEvents().getEventsFromThisChannel(channel);
            for (Event event : events) {
                if (event.getFlag() != Event.Flag.RELEASE) {
                    liveNotes += noteCount(chart, event);
                }
            }
        }

        assertEquals(3239, backgroundNotes);
        assertEquals(885, liveNotes);
        assertEquals(4124, backgroundNotes + liveNotes);
    }

    @Test
    void recomposesReferenceVosDroidPerformanceSignature() throws Exception {
        assumeTrue(REFERENCE_VOS.isFile(), "VosDroid reference chart is not available");
        ReferenceVos reference = readReferenceVos(Files.readAllBytes(REFERENCE_VOS.toPath()));
        VOSChart chart = (VOSChart) ChartParser.parseFile(REFERENCE_VOS).get(0);

        List<NoteSignature> expected = referenceVosDroidSignatures(reference);
        List<NoteSignature> actual = open2jamSplitSignatures(chart, reference.resolution);

        assertSignatureEquals(expected, actual);
    }

    private static boolean containsNonSilentSample(byte[] pcm) {
        for (byte value : pcm) {
            if (value != 0) {
                return true;
            }
        }
        return false;
    }

    private static Event firstEvent(EventList events) {
        assertTrue(events != null && !events.isEmpty());
        return events.get(0);
    }

    private static int noteCount(VOSChart chart, Event event) throws Exception {
        SampleData sample = chart.getSamples().get((int) event.getValue());
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

    private static List<NoteSignature> referenceVosDroidSignatures(ReferenceVos reference) throws Exception {
        List<NoteSignature> signatures = midiSignatures(reference.embeddedMidi, 0);
        int channelLimit = Math.min(16, reference.channels.size());
        for (int i = 0; i < channelLimit; i++) {
            ReferenceChannel channel = reference.channels.get(i);
            for (ReferenceNote note : channel.notes) {
                signatures.add(new NoteSignature(
                        ceilDiv(note.sequencer * reference.resolution, 0x300),
                        note.channel & 0x0F,
                        note.pitch,
                        Math.max(1, note.volume),
                        channel.instrument));
            }
        }
        Collections.sort(signatures);
        return signatures;
    }

    private static List<NoteSignature> open2jamSplitSignatures(VOSChart chart, int resolution) throws Exception {
        List<NoteSignature> signatures = new ArrayList<NoteSignature>();
        EventList backgroundEvents = chart.getEvents().getEventsFromThisChannel(Event.Channel.AUTO_PLAY);
        for (Event event : backgroundEvents) {
            signatures.addAll(sampleSignatures(chart, event, absoluteTick(event, resolution)));
        }
        for (Event.Channel channel : Event.Channel.playableChannels()) {
            EventList events = chart.getEvents().getEventsFromThisChannel(channel);
            for (Event event : events) {
                if (event.getFlag() != Event.Flag.RELEASE) {
                    signatures.addAll(sampleSignatures(chart, event, absoluteTick(event, resolution)));
                }
            }
        }
        Collections.sort(signatures);
        return signatures;
    }

    private static List<NoteSignature> sampleSignatures(VOSChart chart, Event event, int offsetTick) throws Exception {
        SampleData sample = chart.getSamples().get((int) event.getValue());
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        sample.copyTo(output);
        return midiSignatures(output.toByteArray(), offsetTick);
    }

    private static List<NoteSignature> midiSignatures(byte[] midi, int offsetTick) throws Exception {
        Sequence sequence = MidiSystem.getSequence(new java.io.ByteArrayInputStream(midi));
        List<MidiRecord> records = new ArrayList<MidiRecord>();
        for (Track track : sequence.getTracks()) {
            for (int i = 0; i < track.size(); i++) {
                MidiEvent event = track.get(i);
                MidiMessage raw = event.getMessage();
                if (raw instanceof ShortMessage) {
                    ShortMessage message = (ShortMessage) raw;
                    int command = message.getCommand();
                    if (command == ShortMessage.PROGRAM_CHANGE || command == ShortMessage.NOTE_ON) {
                        records.add(new MidiRecord(event.getTick(), message));
                    }
                }
            }
        }
        Collections.sort(records);

        List<NoteSignature> signatures = new ArrayList<NoteSignature>();
        Map<Integer, Integer> programs = new HashMap<Integer, Integer>();
        for (MidiRecord record : records) {
            ShortMessage message = record.message;
            int channel = message.getChannel();
            if (message.getCommand() == ShortMessage.PROGRAM_CHANGE) {
                programs.put(channel, message.getData1());
            } else if (message.getCommand() == ShortMessage.NOTE_ON && message.getData2() > 0) {
                Integer program = programs.get(channel);
                signatures.add(new NoteSignature(
                        offsetTick + (int) record.tick,
                        channel,
                        message.getData1(),
                        message.getData2(),
                        program == null ? 0 : program));
            }
        }
        return signatures;
    }

    private static int absoluteTick(Event event, int resolution) {
        return (int) Math.round((event.getMeasure() + event.getPosition()) * resolution * 4.0);
    }

    private static ReferenceVos readReferenceVos(byte[] bytes) {
        int position = 4;
        int midAddress = -1;
        while (position + 20 <= bytes.length) {
            int address = readIntLE(bytes, position);
            String name = segmentName(bytes, position + 4);
            position += 20;
            if ("MID".equalsIgnoreCase(name)) {
                midAddress = address;
            }
            if ("EOF".equalsIgnoreCase(name)) {
                break;
            }
        }
        position = skipVosString(bytes, position);
        position = skipVosString(bytes, position);
        position = skipVosString(bytes, position);
        position = skipVosString(bytes, position);
        position += 1 + 1 + 4 + 1 + 1023;

        List<ReferenceChannel> channels = new ArrayList<ReferenceChannel>();
        while (position < midAddress) {
            int instrument = readIntLE(bytes, position);
            int noteCount = readIntLE(bytes, position + 4);
            position += 22;
            ReferenceChannel channel = new ReferenceChannel(instrument);
            for (int i = 0; i < noteCount; i++) {
                channel.notes.add(new ReferenceNote(
                        readIntLE(bytes, position),
                        readIntLE(bytes, position + 4),
                        bytes[position + 8] & 0xFF,
                        bytes[position + 9] & 0xFF,
                        bytes[position + 10] & 0xFF));
                position += 13;
            }
            channels.add(channel);
        }

        byte[] embeddedMidi = new byte[bytes.length - midAddress];
        System.arraycopy(bytes, midAddress, embeddedMidi, 0, embeddedMidi.length);
        return new ReferenceVos(midiResolution(embeddedMidi), embeddedMidi, channels);
    }

    private static int midiResolution(byte[] midi) {
        return ((midi[12] & 0xFF) << 8) | (midi[13] & 0xFF);
    }

    private static int skipVosString(byte[] bytes, int position) {
        return position + 1 + (bytes[position] & 0xFF);
    }

    private static String segmentName(byte[] bytes, int position) {
        int length = 0;
        while (length < 16 && bytes[position + length] != 0) {
            length++;
        }
        return new String(bytes, position, length, java.nio.charset.StandardCharsets.US_ASCII);
    }

    private static int readIntLE(byte[] bytes, int position) {
        return (bytes[position] & 0xFF)
                | ((bytes[position + 1] & 0xFF) << 8)
                | ((bytes[position + 2] & 0xFF) << 16)
                | ((bytes[position + 3] & 0xFF) << 24);
    }

    private static int ceilDiv(int numerator, int denominator) {
        return (numerator + denominator - 1) / denominator;
    }

    private static void assertSignatureEquals(List<NoteSignature> expected, List<NoteSignature> actual) {
        assertEquals(expected.size(), actual.size(), "signature size");
        for (int i = 0; i < expected.size(); i++) {
            assertEquals(expected.get(i), actual.get(i), "signature mismatch at " + i);
        }
    }

    private static final class ReferenceVos {
        final int resolution;
        final byte[] embeddedMidi;
        final List<ReferenceChannel> channels;

        ReferenceVos(int resolution, byte[] embeddedMidi, List<ReferenceChannel> channels) {
            this.resolution = resolution;
            this.embeddedMidi = embeddedMidi;
            this.channels = channels;
        }
    }

    private static final class ReferenceChannel {
        final int instrument;
        final List<ReferenceNote> notes = new ArrayList<ReferenceNote>();

        ReferenceChannel(int instrument) {
            this.instrument = instrument;
        }
    }

    private static final class ReferenceNote {
        final int sequencer;
        final int duration;
        final int channel;
        final int pitch;
        final int volume;

        ReferenceNote(int sequencer, int duration, int channel, int pitch, int volume) {
            this.sequencer = sequencer;
            this.duration = duration;
            this.channel = channel;
            this.pitch = pitch;
            this.volume = volume;
        }
    }

    private static final class MidiRecord implements Comparable<MidiRecord> {
        final long tick;
        final ShortMessage message;

        MidiRecord(long tick, ShortMessage message) {
            this.tick = tick;
            this.message = message;
        }

        public int compareTo(MidiRecord other) {
            if (tick != other.tick) {
                return tick < other.tick ? -1 : 1;
            }
            return priority(message) - priority(other.message);
        }

        private static int priority(ShortMessage message) {
            return message.getCommand() == ShortMessage.PROGRAM_CHANGE ? 0 : 1;
        }
    }

    private static final class NoteSignature implements Comparable<NoteSignature> {
        final int tick;
        final int channel;
        final int pitch;
        final int velocity;
        final int program;

        NoteSignature(int tick, int channel, int pitch, int velocity, int program) {
            this.tick = tick;
            this.channel = channel;
            this.pitch = pitch;
            this.velocity = velocity;
            this.program = program;
        }

        public int compareTo(NoteSignature other) {
            if (tick != other.tick) return tick - other.tick;
            if (channel != other.channel) return channel - other.channel;
            if (pitch != other.pitch) return pitch - other.pitch;
            if (velocity != other.velocity) return velocity - other.velocity;
            return program - other.program;
        }

        public boolean equals(Object other) {
            if (!(other instanceof NoteSignature)) return false;
            NoteSignature signature = (NoteSignature) other;
            return tick == signature.tick
                    && channel == signature.channel
                    && pitch == signature.pitch
                    && velocity == signature.velocity
                    && program == signature.program;
        }

        public int hashCode() {
            int result = tick;
            result = 31 * result + channel;
            result = 31 * result + pitch;
            result = 31 * result + velocity;
            result = 31 * result + program;
            return result;
        }

        public String toString() {
            return tick + ":" + channel + ":" + pitch + ":" + velocity + ":" + program;
        }
    }
}
