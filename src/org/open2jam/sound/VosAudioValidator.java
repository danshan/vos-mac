package org.open2jam.sound;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import javax.sound.midi.InvalidMidiDataException;
import javax.sound.midi.MidiEvent;
import javax.sound.midi.MidiMessage;
import javax.sound.midi.MidiSystem;
import javax.sound.midi.Sequence;
import javax.sound.midi.ShortMessage;
import javax.sound.midi.Track;
import org.open2jam.parsers.ChartList;
import org.open2jam.parsers.ChartParser;
import org.open2jam.parsers.Event;
import org.open2jam.parsers.EventList;
import org.open2jam.parsers.VOSChart;
import org.open2jam.parsers.utils.SampleData;

public final class VosAudioValidator {
    private VosAudioValidator() {
    }

    public static Result validate(File file) throws SoundSystemException {
        if (file == null || !file.isFile()) {
            throw new SoundSystemException("VOS file does not exist: " + file);
        }

        byte[] fileBytes = readAll(file);
        ChartList charts = ChartParser.parseFile(file);
        if (charts == null || charts.isEmpty() || !(charts.get(0) instanceof VOSChart)) {
            throw new SoundSystemException("No VOS chart parsed from: " + file);
        }

        VOSChart chart = (VOSChart) charts.get(0);
        Map<Integer, SampleData> samples = chart.getSamples();
        Map<Integer, byte[]> sampleBytes = sampleBytes(samples);
        Event background = firstEvent(chart.getEvents().getEventsFromThisChannel(Event.Channel.AUTO_PLAY));
        Event live = firstPlayableEvent(chart.getEvents());
        if (background == null) {
            throw new SoundSystemException("VOS chart has no background MIDI sample: " + file);
        }
        if (live == null) {
            throw new SoundSystemException("VOS chart has no live note MIDI sample: " + file);
        }

        MidiSampleRenderer renderer = new MidiSampleRenderer();
        byte[] backgroundBytes = sampleBytes(sampleBytes, background);
        byte[] liveBytes = sampleBytes(sampleBytes, live);
        MidiSampleRenderer.RenderedAudio backgroundAudio = renderer.render(backgroundBytes);
        MidiSampleRenderer.RenderedAudio liveAudio = renderer.render(liveBytes);
        int backgroundMidiNotes = midiNoteCount(backgroundBytes);
        int liveMidiNotes = liveMidiNoteCount(chart.getEvents(), sampleBytes);
        RenderSummary summary = new RenderSummary(2, backgroundAudio.pcm().length + liveAudio.pcm().length);
        ReferenceVos reference = readReferenceVos(fileBytes);
        validatePerformanceSignature(referenceVosDroidSignatures(reference),
                open2jamSplitSignatures(chart, sampleBytes, reference.resolution));

        if (!sameFormat(backgroundAudio, liveAudio)) {
            throw new SoundSystemException("Background and live MIDI rendered to different PCM formats");
        }
        if (isSilent(backgroundAudio.pcm()) || isSilent(liveAudio.pcm())) {
            throw new SoundSystemException("Rendered VOS MIDI audio is silent");
        }

        return new Result(chart.getTitle(), chart.getNoteCount(), samples.size(),
                backgroundAudio.pcm().length, liveAudio.pcm().length,
                backgroundAudio.sampleRate(), backgroundAudio.channels(), backgroundAudio.bitsPerSample(),
                summary.renderedSamples, summary.totalPcmBytes, backgroundMidiNotes, liveMidiNotes, true);
    }

    private static Event firstPlayableEvent(EventList events) {
        for (Event.Channel channel : Event.Channel.values()) {
            if (!channel.toString().startsWith("NOTE_")) {
                continue;
            }
            Event event = firstEvent(events.getEventsFromThisChannel(channel));
            if (event != null) {
                return event;
            }
        }
        return null;
    }

    private static Event firstEvent(EventList events) {
        return events == null || events.isEmpty() ? null : events.get(0);
    }

    private static int liveMidiNoteCount(EventList events, Map<Integer, byte[]> samples) throws SoundSystemException {
        int notes = 0;
        for (Event.Channel channel : Event.Channel.playableChannels()) {
            EventList channelEvents = events.getEventsFromThisChannel(channel);
            for (Event event : channelEvents) {
                if (event.getFlag() != Event.Flag.RELEASE) {
                    notes += midiNoteCount(sampleBytes(samples, event));
                }
            }
        }
        return notes;
    }

    private static List<NoteSignature> referenceVosDroidSignatures(ReferenceVos reference)
            throws SoundSystemException {
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

    private static List<NoteSignature> open2jamSplitSignatures(VOSChart chart, Map<Integer, byte[]> samples,
            int resolution) throws SoundSystemException {
        List<NoteSignature> signatures = new ArrayList<NoteSignature>();
        EventList backgroundEvents = chart.getEvents().getEventsFromThisChannel(Event.Channel.AUTO_PLAY);
        for (Event event : backgroundEvents) {
            signatures.addAll(sampleSignatures(samples, event, absoluteTick(event, resolution)));
        }
        for (Event.Channel channel : Event.Channel.playableChannels()) {
            EventList events = chart.getEvents().getEventsFromThisChannel(channel);
            for (Event event : events) {
                if (event.getFlag() != Event.Flag.RELEASE) {
                    signatures.addAll(sampleSignatures(samples, event, absoluteTick(event, resolution)));
                }
            }
        }
        Collections.sort(signatures);
        return signatures;
    }

    private static List<NoteSignature> sampleSignatures(Map<Integer, byte[]> samples, Event event, int offsetTick)
            throws SoundSystemException {
        return midiSignatures(sampleBytes(samples, event), offsetTick);
    }

    private static List<NoteSignature> midiSignatures(byte[] midi, int offsetTick) throws SoundSystemException {
        try {
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
        } catch (InvalidMidiDataException e) {
            throw new SoundSystemException(e);
        } catch (IOException e) {
            throw new SoundSystemException(e);
        }
    }

    private static int absoluteTick(Event event, int resolution) {
        return (int) Math.round((event.getMeasure() + event.getPosition()) * resolution * 4.0);
    }

    private static void validatePerformanceSignature(List<NoteSignature> expected, List<NoteSignature> actual)
            throws SoundSystemException {
        if (expected.size() != actual.size()) {
            throw new SoundSystemException("VOS performance signature size mismatch: expected "
                    + expected.size() + ", actual " + actual.size());
        }
        for (int i = 0; i < expected.size(); i++) {
            if (!expected.get(i).equals(actual.get(i))) {
                throw new SoundSystemException("VOS performance signature mismatch at " + i
                        + ": expected " + expected.get(i) + ", actual " + actual.get(i));
            }
        }
    }

    private static Map<Integer, byte[]> sampleBytes(Map<Integer, SampleData> samples) throws SoundSystemException {
        Map<Integer, byte[]> bytes = new LinkedHashMap<Integer, byte[]>();
        for (Map.Entry<Integer, SampleData> entry : samples.entrySet()) {
            bytes.put(entry.getKey(), sampleBytes(entry.getValue()));
        }
        return bytes;
    }

    private static byte[] sampleBytes(Map<Integer, byte[]> samples, Event event) throws SoundSystemException {
        byte[] sample = samples.get((int) event.getValue());
        if (sample == null) {
            throw new SoundSystemException("Missing VOS MIDI sample: " + event.getValue());
        }
        return sample;
    }

    private static byte[] sampleBytes(SampleData sample) throws SoundSystemException {
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        try {
            sample.copyTo(output);
        } catch (IOException e) {
            throw new SoundSystemException(e);
        }
        return output.toByteArray();
    }

    private static byte[] readAll(File file) throws SoundSystemException {
        try {
            return Files.readAllBytes(file.toPath());
        } catch (IOException e) {
            throw new SoundSystemException(e);
        }
    }

    private static boolean sameFormat(MidiSampleRenderer.RenderedAudio left, MidiSampleRenderer.RenderedAudio right) {
        return left.sampleRate() == right.sampleRate()
                && left.channels() == right.channels()
                && left.bitsPerSample() == right.bitsPerSample();
    }

    private static boolean isSilent(byte[] pcm) {
        for (byte value : pcm) {
            if (value != 0) {
                return false;
            }
        }
        return true;
    }

    private static int midiNoteCount(byte[] midi) throws SoundSystemException {
        try {
            Sequence sequence = MidiSystem.getSequence(new java.io.ByteArrayInputStream(midi));
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
        } catch (InvalidMidiDataException e) {
            throw new SoundSystemException(e);
        } catch (IOException e) {
            throw new SoundSystemException(e);
        }
    }

    private static ReferenceVos readReferenceVos(byte[] bytes) throws SoundSystemException {
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
        if (midAddress < 0 || midAddress >= bytes.length) {
            throw new SoundSystemException("VOS MID segment not found");
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
        return new String(bytes, position, length, StandardCharsets.US_ASCII);
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

    private static final class RenderSummary {
        final int renderedSamples;
        final long totalPcmBytes;

        RenderSummary(int renderedSamples, long totalPcmBytes) {
            this.renderedSamples = renderedSamples;
            this.totalPcmBytes = totalPcmBytes;
        }
    }

    public static final class Result {
        public final String title;
        public final int playableNotes;
        public final int samples;
        public final int backgroundPcmBytes;
        public final int livePcmBytes;
        public final int sampleRate;
        public final int channels;
        public final int bitsPerSample;
        public final int renderedSamples;
        public final long totalPcmBytes;
        public final int backgroundMidiNotes;
        public final int liveMidiNotes;
        public final boolean performanceSignatureMatches;

        private Result(String title, int playableNotes, int samples, int backgroundPcmBytes, int livePcmBytes,
                int sampleRate, int channels, int bitsPerSample, int renderedSamples, long totalPcmBytes,
                int backgroundMidiNotes, int liveMidiNotes, boolean performanceSignatureMatches) {
            this.title = title;
            this.playableNotes = playableNotes;
            this.samples = samples;
            this.backgroundPcmBytes = backgroundPcmBytes;
            this.livePcmBytes = livePcmBytes;
            this.sampleRate = sampleRate;
            this.channels = channels;
            this.bitsPerSample = bitsPerSample;
            this.renderedSamples = renderedSamples;
            this.totalPcmBytes = totalPcmBytes;
            this.backgroundMidiNotes = backgroundMidiNotes;
            this.liveMidiNotes = liveMidiNotes;
            this.performanceSignatureMatches = performanceSignatureMatches;
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
