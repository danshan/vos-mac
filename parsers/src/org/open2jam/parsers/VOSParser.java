package org.open2jam.parsers;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileFilter;
import java.io.FileInputStream;
import java.io.IOException;
import java.nio.charset.Charset;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.logging.Level;
import org.open2jam.parsers.utils.Logger;

class VOSParser {
    private static final Charset VOS_CHARSET = Charset.forName("GB2312");
    private static final int HEADER_MAGIC = 3;
    private static final int INF_PADDING_LENGTH = 1023;
    private static final int PLAYABLE_CHANNEL_INDEX = 16;
    private static final int SEQUENCER_TICKS_PER_MEASURE = 0x300;
    private static final int DURATION_TICKS_PER_MEASURE = 0x2E4;

    private static final FileFilter vos_filter = new FileFilter() {
        public boolean accept(File f) {
            return !f.isDirectory() && f.getName().toLowerCase().endsWith(".vos");
        }
    };

    public static boolean canRead(File file) {
        if (file == null) {
            return false;
        }
        if (file.isDirectory()) {
            return false;
        }
        return file.getName().toLowerCase().endsWith(".vos") && isStructurallyReadable(file);
    }

    public static ChartList parseFile(File file) {
        if (file == null || file.isDirectory()) {
            return null;
        }

        ChartList list = new ChartList();
        list.source_file = file;

        for (File vos_file : listVOSFiles(file)) {
            try {
                VOSChart chart = parseVOS(vos_file);
                if (chart != null) {
                    list.add(chart);
                }
            } catch (IOException e) {
                Logger.global.log(Level.WARNING, "IO error reading VOS file {0}: {1}",
                        new Object[] {vos_file.getName(), e.getMessage()});
            } catch (IllegalArgumentException e) {
                Logger.global.log(Level.WARNING, "Invalid VOS file {0}: {1}",
                        new Object[] {vos_file.getName(), e.getMessage()});
            }
        }

        Collections.sort(list);
        return list.isEmpty() ? null : list;
    }

    public static EventList parseChart(VOSChart chart) {
        return chart.getEvents();
    }

    private static List<File> listVOSFiles(File file) {
        List<File> files = new ArrayList<File>();
        if (file.isDirectory()) {
            File[] vos_files = file.listFiles(vos_filter);
            if (vos_files != null) {
                Collections.addAll(files, vos_files);
            }
        } else {
            files.add(file);
        }
        return files;
    }

    private static boolean hasVOSHeader(File file) {
        try {
            byte[] bytes = readAll(file);
            return bytes.length >= 4 && readInt(bytes, 0) == HEADER_MAGIC;
        } catch (IOException e) {
            return false;
        }
    }

    private static boolean isStructurallyReadable(File file) {
        if (!hasVOSHeader(file)) {
            return false;
        }
        try {
            return parseVOS(file) != null;
        } catch (IOException e) {
            return false;
        } catch (IllegalArgumentException e) {
            return false;
        }
    }

    private static VOSChart parseVOS(File file) throws IOException {
        byte[] bytes = readAll(file);
        Reader reader = new Reader(bytes);
        int header = reader.readInt();
        if (header != HEADER_MAGIC) {
            throw new IllegalArgumentException("unexpected header");
        }

        List<Segment> segments = readSegments(reader);
        Segment inf = findSegment(segments, "INF");
        Segment mid = findSegment(segments, "MID");
        if (inf == null || mid == null) {
            throw new IllegalArgumentException("missing VOS segments");
        }
        if (inf.address < reader.position() || inf.address > bytes.length
                || mid.address < inf.address || mid.address > bytes.length) {
            throw new IllegalArgumentException("invalid VOS segment address");
        }

        VOSChart chart = new VOSChart();
        chart.setSource(file);
        chart.setBPM(130);

        reader.seek(inf.address);
        chart.setTitle(defaultString(reader.readString(), stripExtension(file.getName())));
        chart.setArtist(reader.readString());
        reader.readString();
        chart.setNoter(reader.readString());
        chart.setGenre(mapGenre(reader.readUnsignedByte()));
        reader.readUnsignedByte();
        chart.setDuration(reader.readInt() / 1000);

        if (reader.remainingBefore(mid.address) > INF_PADDING_LENGTH) {
            chart.setLevel(reader.readUnsignedByte());
        } else {
            chart.markLevelUnknown();
        }

        if (reader.remainingBefore(mid.address) < INF_PADDING_LENGTH) {
            throw new IllegalArgumentException("truncated INF padding");
        }
        reader.skip(INF_PADDING_LENGTH);

        List<VOSChannel> channels = readChannels(reader, mid.address);
        byte[] embedded_midi = Arrays.copyOfRange(bytes, mid.address, bytes.length);
        MidiModel midi = MidiModel.parse(embedded_midi);
        chart.setBPM(midi.initialBPM());

        EventList events = buildEvents(chart, channels, midi, embedded_midi);
        chart.setEvents(events);
        chart.setNoteCount(events.playableNotes);
        return chart;
    }

    private static List<Segment> readSegments(Reader reader) {
        List<Segment> segments = new ArrayList<Segment>();
        while (reader.remaining() >= 20) {
            int address = reader.readInt();
            String name = reader.readFixedString(16);
            if (name.length() == 0) {
                throw new IllegalArgumentException("empty VOS segment name");
            }
            segments.add(new Segment(address, name));
            if ("EOF".equalsIgnoreCase(name)) {
                return segments;
            }
            if (segments.size() > 64) {
                throw new IllegalArgumentException("too many VOS segments");
            }
        }
        throw new IllegalArgumentException("missing EOF segment");
    }

    private static Segment findSegment(List<Segment> segments, String name) {
        for (Segment segment : segments) {
            if (name.equalsIgnoreCase(segment.name)) {
                return segment;
            }
        }
        return null;
    }

    private static List<VOSChannel> readChannels(Reader reader, int end_address) {
        List<VOSChannel> channels = new ArrayList<VOSChannel>();
        while (reader.position() < end_address) {
            if (reader.remainingBefore(end_address) < 22) {
                throw new IllegalArgumentException("truncated VOS channel");
            }
            int instrument = reader.readInt();
            int note_count = reader.readInt();
            if (note_count < 0) {
                throw new IllegalArgumentException("negative VOS note count");
            }
            reader.skip(14);

            VOSChannel channel = new VOSChannel(instrument);
            for (int i = 0; i < note_count; i++) {
                if (reader.remainingBefore(end_address) < 13) {
                    throw new IllegalArgumentException("truncated VOS note");
                }
                channel.notes.add(readNote(reader));
            }
            channels.add(channel);
        }
        return channels;
    }

    private static EventList buildEvents(VOSChart chart, List<VOSChannel> channels, MidiModel midi,
            byte[] embedded_midi) {
        EventList events = new EventList();
        Set<Integer> playable_source_indexes = inferPlayableSourceIndexes(channels);
        byte[] background_midi = MidiBuilder.buildPlaybackMIDI(embedded_midi, midi, channels,
                playable_source_indexes, false);
        if (MidiModel.parseQuietly(background_midi).noteCount() > 0) {
            int sample_id = chart.registerMidiSample("background", background_midi);
            events.add(new Event(Event.Channel.AUTO_PLAY, 0, 0, sample_id, Event.Flag.NONE));
        }
        addTempoEvents(events, midi);

        VOSChannel playable_channel = playableChannel(channels);
        if (playable_channel != null) {
            for (int i = 0; i < playable_channel.notes.size(); i++) {
                VOSNote note = playable_channel.notes.get(i);
                List<LiveNote> live_notes = inferLiveNotes(channels, playable_source_indexes, note, midi);
                if (live_notes.isEmpty()) {
                    int duration_ms = fallbackDurationMilliseconds(note, midi);
                    int start_tick = toStartTick(note, midi.resolution);
                    live_notes.add(new LiveNote(0, note.channel & 0x0F, note.pitch, note.volume, duration_ms));
                }
                byte[] live_midi = MidiBuilder.buildLiveNotesMIDI(live_notes);
                int sample_id = chart.registerMidiSample(live_midi);
                events.playableNotes += addPlayableNoteEvents(events, midi, sample_id, note);
            }
        }
        Collections.sort(events);
        return events;
    }

    private static void addTempoEvents(EventList events, MidiModel midi) {
        for (TempoEvent tempo : midi.tempos) {
            Position position = toPosition(tempo.tick, midi.resolution);
            events.add(new Event(Event.Channel.BPM_CHANGE, position.measure, position.position,
                    60000000.0 / Math.max(1, tempo.mpqn), Event.Flag.NONE));
        }
    }

    private static Set<Integer> inferPlayableSourceIndexes(List<VOSChannel> channels) {
        Set<Integer> indexes = new HashSet<Integer>();
        VOSChannel playable_channel = playableChannel(channels);
        if (playable_channel == null || playable_channel.notes.isEmpty()) {
            return indexes;
        }
        Map<NoteSignature, Integer> playable_signatures = countedSignatures(playable_channel.notes);
        int channel_limit = Math.min(PLAYABLE_CHANNEL_INDEX, channels.size());
        for (int i = 0; i < channel_limit; i++) {
            VOSChannel channel = channels.get(i);
            if (channel.notes.isEmpty()) {
                continue;
            }
            Map<NoteSignature, Integer> source_signatures = countedSignatures(channel.notes);
            int overlap_count = 0;
            for (Map.Entry<NoteSignature, Integer> entry : source_signatures.entrySet()) {
                Integer playable_count = playable_signatures.get(entry.getKey());
                if (playable_count != null) {
                    overlap_count += Math.min(entry.getValue(), playable_count);
                }
            }
            double overlap_ratio = overlap_count / (double) playable_channel.notes.size();
            if (overlap_ratio >= 0.85) {
                indexes.add(i);
            }
        }
        return indexes;
    }

    private static Map<NoteSignature, Integer> countedSignatures(List<VOSNote> notes) {
        Map<NoteSignature, Integer> counts = new HashMap<NoteSignature, Integer>();
        for (VOSNote note : notes) {
            NoteSignature signature = new NoteSignature(note);
            Integer count = counts.get(signature);
            counts.put(signature, count == null ? 1 : count + 1);
        }
        return counts;
    }

    private static List<LiveNote> inferLiveNotes(List<VOSChannel> channels, Set<Integer> playable_source_indexes,
            VOSNote playable_note, MidiModel midi) {
        List<LiveNote> live_notes = new ArrayList<LiveNote>();
        List<Integer> source_indexes = new ArrayList<Integer>(playable_source_indexes);
        Collections.sort(source_indexes);
        NoteSignature playable_signature = new NoteSignature(playable_note);
        for (Integer source_index : source_indexes) {
            if (source_index < 0 || source_index >= channels.size()) {
                continue;
            }
            VOSChannel source = channels.get(source_index);
            for (VOSNote note : source.notes) {
                if (new NoteSignature(note).equals(playable_signature)) {
                    int start_tick = toStartTick(note, midi.resolution);
                    int duration_ms = midi.durationMilliseconds(start_tick,
                            toDurationTicks(note, midi.resolution));
                    live_notes.add(new LiveNote(source.instrument, note.channel & 0x0F, note.pitch, note.volume,
                            duration_ms));
                }
            }
        }
        return live_notes;
    }

    private static VOSChannel playableChannel(List<VOSChannel> channels) {
        if (channels.isEmpty()) {
            return null;
        }
        if (channels.size() > PLAYABLE_CHANNEL_INDEX) {
            return channels.get(PLAYABLE_CHANNEL_INDEX);
        }
        return channels.get(channels.size() - 1);
    }

    private static VOSNote readNote(Reader reader) {
        int sequencer = reader.readInt();
        int duration = reader.readInt();
        int channel = reader.readUnsignedByte();
        int pitch = reader.readUnsignedByte();
        int volume = reader.readUnsignedByte();
        int keyboard = reader.readUnsignedByte();
        int type = reader.readUnsignedByte();
        return new VOSNote(sequencer, duration, channel, pitch, volume, keyboard, type);
    }

    private static int addPlayableNoteEvents(EventList events, MidiModel midi, int sample_id, VOSNote note) {
        Event.Channel channel = mapKeyboard(note.keyboard);
        if (channel == Event.Channel.NONE) {
            return 0;
        }

        int start_tick = toStartTick(note, midi.resolution);
        Position start = toPosition(start_tick, midi.resolution);
        if (isLongNote(note)) {
            events.add(new Event(channel, start.measure, start.position, sample_id, Event.Flag.HOLD));
            Position end = toPosition(start_tick + toDurationTicks(note, midi.resolution), midi.resolution);
            events.add(new Event(channel, end.measure, end.position, sample_id, Event.Flag.RELEASE));
        } else {
            events.add(new Event(channel, start.measure, start.position, sample_id, Event.Flag.NONE));
        }
        return 1;
    }

    private static boolean isLongNote(VOSNote note) {
        return (note.type & 0x80) == 0x80 && note.duration > 0;
    }

    private static Event.Channel mapKeyboard(int keyboard) {
        int key = ((keyboard >> 4) - 0x8) & 0x0F;
        switch (key) {
            case 0:
                return Event.Channel.NOTE_1;
            case 1:
                return Event.Channel.NOTE_2;
            case 2:
                return Event.Channel.NOTE_3;
            case 3:
                return Event.Channel.NOTE_4;
            case 4:
                return Event.Channel.NOTE_5;
            case 5:
                return Event.Channel.NOTE_6;
            case 6:
                return Event.Channel.NOTE_7;
            default:
                return Event.Channel.NONE;
        }
    }

    private static int toStartTick(VOSNote note, int resolution) {
        return ceilDiv(note.sequencer * resolution, SEQUENCER_TICKS_PER_MEASURE);
    }

    private static int toDurationTicks(VOSNote note, int resolution) {
        return Math.max(1, ceilDiv(note.duration * resolution, DURATION_TICKS_PER_MEASURE));
    }

    private static int fallbackDurationMilliseconds(VOSNote note, MidiModel midi) {
        int start_tick = toStartTick(note, midi.resolution);
        int end_tick = ceilDiv((note.sequencer + note.duration) * midi.resolution, SEQUENCER_TICKS_PER_MEASURE);
        return Math.max(1, midi.millisecondsAtTick(end_tick) - midi.millisecondsAtTick(start_tick));
    }

    private static Position toPosition(int tick, int resolution) {
        int ticks_per_measure = Math.max(1, resolution * 4);
        int measure = tick / ticks_per_measure;
        double position = (tick % ticks_per_measure) / (double) ticks_per_measure;
        return new Position(measure, position);
    }

    private static int ceilDiv(int numerator, int denominator) {
        if (denominator <= 0) {
            return 0;
        }
        return (numerator + denominator - 1) / denominator;
    }

    private static String mapGenre(int music_type) {
        switch (music_type) {
            case 1:
                return "Pop";
            case 2:
                return "New Age";
            case 3:
                return "Techno";
            case 4:
                return "Rock";
            case 5:
                return "SoundTrack";
            case 6:
                return "Game&Anime";
            case 7:
                return "Jazz";
            case 8:
                return "CenturyEnd";
            case 9:
                return "Classical";
            default:
                return "Other";
        }
    }

    private static String defaultString(String value, String fallback) {
        if (value == null || value.trim().isEmpty()) {
            return fallback;
        }
        return value.trim();
    }

    private static String stripExtension(String name) {
        int dot = name.lastIndexOf('.');
        return dot > 0 ? name.substring(0, dot) : name;
    }

    private static byte[] readAll(File file) throws IOException {
        FileInputStream input = new FileInputStream(file);
        try {
            ByteArrayOutputStream output = new ByteArrayOutputStream();
            byte[] buffer = new byte[8192];
            int read;
            while ((read = input.read(buffer)) != -1) {
                output.write(buffer, 0, read);
            }
            return output.toByteArray();
        } finally {
            input.close();
        }
    }

    private static int readInt(byte[] bytes, int offset) {
        return (bytes[offset] & 0xFF)
                | ((bytes[offset + 1] & 0xFF) << 8)
                | ((bytes[offset + 2] & 0xFF) << 16)
                | ((bytes[offset + 3] & 0xFF) << 24);
    }

    private static final class Segment {
        final int address;
        final String name;

        Segment(int address, String name) {
            this.address = address;
            this.name = name;
        }
    }

    private static final class VOSNote {
        final int sequencer;
        final int duration;
        final int channel;
        final int pitch;
        final int volume;
        final int keyboard;
        final int type;

        VOSNote(int sequencer, int duration, int channel, int pitch, int volume, int keyboard, int type) {
            this.sequencer = sequencer;
            this.duration = duration;
            this.channel = channel;
            this.pitch = pitch;
            this.volume = volume;
            this.keyboard = keyboard;
            this.type = type;
        }
    }

    private static final class VOSChannel {
        final int instrument;
        final List<VOSNote> notes = new ArrayList<VOSNote>();

        VOSChannel(int instrument) {
            this.instrument = instrument;
        }
    }

    private static final class LiveNote {
        final int instrument;
        final int channel;
        final int pitch;
        final int volume;
        final int duration_ms;

        LiveNote(int instrument, int channel, int pitch, int volume, int duration_ms) {
            this.instrument = instrument;
            this.channel = channel;
            this.pitch = pitch;
            this.volume = volume;
            this.duration_ms = duration_ms;
        }
    }

    private static final class NoteSignature {
        final int sequencer;
        final int duration;
        final int channel;
        final int pitch;
        final int volume;

        NoteSignature(VOSNote note) {
            this.sequencer = note.sequencer;
            this.duration = note.duration;
            this.channel = note.channel;
            this.pitch = note.pitch;
            this.volume = note.volume;
        }

        public boolean equals(Object other) {
            if (!(other instanceof NoteSignature)) {
                return false;
            }
            NoteSignature signature = (NoteSignature) other;
            return sequencer == signature.sequencer
                    && duration == signature.duration
                    && channel == signature.channel
                    && pitch == signature.pitch
                    && volume == signature.volume;
        }

        public int hashCode() {
            int result = sequencer;
            result = 31 * result + duration;
            result = 31 * result + channel;
            result = 31 * result + pitch;
            result = 31 * result + volume;
            return result;
        }
    }

    private static final class MidiModel {
        final int resolution;
        final List<TempoEvent> tempos;
        final int note_count;

        MidiModel(int resolution, List<TempoEvent> tempos, int note_count) {
            this.resolution = resolution;
            this.tempos = tempos;
            this.note_count = note_count;
        }

        double initialBPM() {
            int mpqn = tempos.isEmpty() ? 500000 : tempos.get(0).mpqn;
            return 60000000.0 / Math.max(1, mpqn);
        }

        int noteCount() {
            return note_count;
        }

        int durationMilliseconds(int start_tick, int duration_ticks) {
            return Math.max(1, millisecondsAtTick(start_tick + duration_ticks) - millisecondsAtTick(start_tick));
        }

        int millisecondsAtTick(int target_tick) {
            List<TempoEvent> sorted_tempos = new ArrayList<TempoEvent>(tempos);
            Collections.sort(sorted_tempos);
            int current_tick = 0;
            int current_tempo = 500000;
            double elapsed = 0.0;
            for (TempoEvent tempo : sorted_tempos) {
                if (tempo.tick > target_tick) {
                    break;
                }
                int delta = Math.max(0, tempo.tick - current_tick);
                elapsed += delta * current_tempo / (resolution * 1000.0);
                current_tick = tempo.tick;
                current_tempo = tempo.mpqn;
            }
            int remaining = Math.max(0, target_tick - current_tick);
            elapsed += remaining * current_tempo / (resolution * 1000.0);
            return (int) Math.round(elapsed);
        }

        static MidiModel parseQuietly(byte[] data) {
            try {
                return parse(data);
            } catch (IllegalArgumentException e) {
                return new MidiModel(480, new ArrayList<TempoEvent>(), 0);
            }
        }

        static MidiModel parse(byte[] data) {
            Reader reader = new Reader(data);
            if (!"MThd".equals(reader.readAscii(4))) {
                throw new IllegalArgumentException("missing MIDI header");
            }
            int header_length = reader.readIntBE();
            if (header_length < 6) {
                throw new IllegalArgumentException("invalid MIDI header length");
            }
            int format = reader.readUnsignedShortBE();
            int track_count = reader.readUnsignedShortBE();
            int division = reader.readUnsignedShortBE();
            if ((division & 0x8000) != 0 || format > 1) {
                throw new IllegalArgumentException("unsupported MIDI file");
            }
            if (header_length > 6) {
                reader.skip(header_length - 6);
            }

            List<TempoEvent> tempos = new ArrayList<TempoEvent>();
            int note_count = 0;
            for (int i = 0; i < track_count; i++) {
                if (!"MTrk".equals(reader.readAscii(4))) {
                    throw new IllegalArgumentException("missing MIDI track");
                }
                int length = reader.readIntBE();
                byte[] track = reader.readBytes(length);
                ParsedTrack parsed = parseTrack(track);
                tempos.addAll(parsed.tempos);
                note_count += parsed.note_count;
            }
            Collections.sort(tempos);
            return new MidiModel(division, tempos, note_count);
        }

        private static ParsedTrack parseTrack(byte[] data) {
            Reader reader = new Reader(data);
            List<TempoEvent> tempos = new ArrayList<TempoEvent>();
            Map<String, Integer> active_notes = new HashMap<String, Integer>();
            int tick = 0;
            int running_status = -1;
            int note_count = 0;

            while (reader.remaining() > 0) {
                tick += reader.readVariableLengthQuantity();
                int status = reader.readUnsignedByte();
                if (status < 0x80) {
                    if (running_status < 0) {
                        throw new IllegalArgumentException("invalid MIDI running status");
                    }
                    reader.seek(reader.position() - 1);
                    status = running_status;
                } else if (status < 0xF0) {
                    running_status = status;
                }

                if (status >= 0x80 && status <= 0x8F) {
                    int pitch = reader.readUnsignedByte();
                    reader.readUnsignedByte();
                    if (active_notes.remove((status & 0x0F) + ":" + pitch) != null) {
                        note_count++;
                    }
                } else if (status >= 0x90 && status <= 0x9F) {
                    int pitch = reader.readUnsignedByte();
                    int velocity = reader.readUnsignedByte();
                    String key = (status & 0x0F) + ":" + pitch;
                    if (velocity == 0) {
                        if (active_notes.remove(key) != null) {
                            note_count++;
                        }
                    } else {
                        active_notes.put(key, tick);
                    }
                } else if (status >= 0xB0 && status <= 0xBF) {
                    reader.skip(2);
                } else if ((status >= 0xA0 && status <= 0xAF) || (status >= 0xE0 && status <= 0xEF)) {
                    reader.skip(2);
                } else if (status >= 0xC0 && status <= 0xCF) {
                    reader.skip(1);
                } else if (status >= 0xD0 && status <= 0xDF) {
                    reader.skip(1);
                } else if (status == 0xFF) {
                    running_status = -1;
                    int type = reader.readUnsignedByte();
                    int length = reader.readVariableLengthQuantity();
                    byte[] payload = reader.readBytes(length);
                    if (type == 0x51 && payload.length == 3) {
                        int mpqn = ((payload[0] & 0xFF) << 16)
                                | ((payload[1] & 0xFF) << 8)
                                | (payload[2] & 0xFF);
                        tempos.add(new TempoEvent(tick, mpqn));
                    } else if (type == 0x2F) {
                        break;
                    }
                } else if (status == 0xF0 || status == 0xF7) {
                    running_status = -1;
                    reader.skip(reader.readVariableLengthQuantity());
                } else {
                    throw new IllegalArgumentException("unsupported MIDI event");
                }
            }
            return new ParsedTrack(tempos, note_count);
        }
    }

    private static final class MidiBuilder {
        static byte[] buildPlaybackMIDI(byte[] embedded_midi, MidiModel midi, List<VOSChannel> channels,
                Set<Integer> excluding_channel_indexes, boolean include_playable_fallback) {
            List<MidiNote> notes = playbackNotes(channels, excluding_channel_indexes, include_playable_fallback);
            return appendNotesToMIDI(embedded_midi, midi.resolution, notes);
        }

        static byte[] buildLiveNotesMIDI(List<LiveNote> live_notes) {
            List<MidiNote> notes = new ArrayList<MidiNote>();
            for (LiveNote note : live_notes) {
                VOSNote raw_note = new VOSNote(0, Math.max(1, note.duration_ms * DURATION_TICKS_PER_MEASURE / 500),
                        note.channel, note.pitch, note.volume, 0, note.duration_ms > 500 ? 0x80 : 0);
                notes.add(new MidiNote(note.instrument, raw_note));
            }
            List<TempoEvent> tempos = new ArrayList<TempoEvent>();
            tempos.add(new TempoEvent(0, 500000));
            return buildMIDI(480, tempos, notes);
        }

        private static List<MidiNote> playbackNotes(List<VOSChannel> channels,
                Set<Integer> excluding_channel_indexes, boolean include_playable_fallback) {
            List<MidiNote> notes = new ArrayList<MidiNote>();
            int channel_limit = Math.min(PLAYABLE_CHANNEL_INDEX, channels.size());
            for (int i = 0; i < channel_limit; i++) {
                if (excluding_channel_indexes.contains(i)) {
                    continue;
                }
                VOSChannel channel = channels.get(i);
                for (VOSNote note : channel.notes) {
                    notes.add(new MidiNote(channel.instrument, note));
                }
            }
            if (!notes.isEmpty() || !include_playable_fallback || !excluding_channel_indexes.isEmpty()
                    || channels.size() <= PLAYABLE_CHANNEL_INDEX) {
                return notes;
            }
            VOSChannel playable = channels.get(PLAYABLE_CHANNEL_INDEX);
            for (VOSNote note : playable.notes) {
                notes.add(new MidiNote(0, note));
            }
            return notes;
        }

        private static byte[] buildMIDI(int resolution, List<TempoEvent> tempos, List<MidiNote> notes) {
            ByteArrayOutputStream output = new ByteArrayOutputStream();
            writeAscii(output, "MThd");
            writeIntBE(output, 6);
            writeShortBE(output, 1);
            writeShortBE(output, 2);
            writeShortBE(output, Math.max(1, resolution));

            byte[] tempo_track = buildTempoTrack(tempos);
            writeAscii(output, "MTrk");
            writeIntBE(output, tempo_track.length);
            output.write(tempo_track, 0, tempo_track.length);

            byte[] note_track = buildNoteTrack(notes, resolution);
            writeAscii(output, "MTrk");
            writeIntBE(output, note_track.length);
            output.write(note_track, 0, note_track.length);
            return output.toByteArray();
        }

        private static byte[] appendNotesToMIDI(byte[] embedded_midi, int resolution, List<MidiNote> notes) {
            if (notes.isEmpty()) {
                return embedded_midi;
            }

            Reader reader = new Reader(embedded_midi);
            if (!"MThd".equals(reader.readAscii(4))) {
                throw new IllegalArgumentException("missing MIDI header");
            }
            int header_length = reader.readIntBE();
            if (header_length < 6) {
                throw new IllegalArgumentException("invalid MIDI header length");
            }
            reader.readUnsignedShortBE();
            int track_count = reader.readUnsignedShortBE();
            int division = reader.readUnsignedShortBE();
            if (header_length > 6) {
                reader.skip(header_length - 6);
            }

            ByteArrayOutputStream output = new ByteArrayOutputStream();
            writeAscii(output, "MThd");
            writeIntBE(output, 6);
            writeShortBE(output, 1);
            writeShortBE(output, track_count + 1);
            writeShortBE(output, division);
            output.write(embedded_midi, reader.position(), embedded_midi.length - reader.position());

            byte[] note_track = buildNoteTrack(notes, resolution);
            writeAscii(output, "MTrk");
            writeIntBE(output, note_track.length);
            output.write(note_track, 0, note_track.length);
            return output.toByteArray();
        }

        private static byte[] buildTempoTrack(List<TempoEvent> tempos) {
            ByteArrayOutputStream track = new ByteArrayOutputStream();
            List<TempoEvent> sorted = new ArrayList<TempoEvent>(tempos);
            if (sorted.isEmpty()) {
                sorted.add(new TempoEvent(0, 500000));
            }
            Collections.sort(sorted);
            int last_tick = 0;
            for (TempoEvent tempo : sorted) {
                writeVariableLengthQuantity(track, Math.max(0, tempo.tick - last_tick));
                track.write(0xFF);
                track.write(0x51);
                track.write(0x03);
                track.write((tempo.mpqn >>> 16) & 0xFF);
                track.write((tempo.mpqn >>> 8) & 0xFF);
                track.write(tempo.mpqn & 0xFF);
                last_tick = tempo.tick;
            }
            writeVariableLengthQuantity(track, 0);
            track.write(0xFF);
            track.write(0x2F);
            track.write(0x00);
            return track.toByteArray();
        }

        private static byte[] buildNoteTrack(List<MidiNote> notes, int resolution) {
            List<MidiBuildEvent> events = new ArrayList<MidiBuildEvent>();
            Set<Integer> configured_channels = new HashSet<Integer>();
            for (MidiNote midi_note : notes) {
                VOSNote note = midi_note.note;
                int channel = note.channel & 0x0F;
                if (!configured_channels.contains(channel)) {
                    configured_channels.add(channel);
                    events.add(new MidiBuildEvent(0, 0,
                            new int[] {0xC0 | channel, clampMidi(midi_note.instrument)}));
                }
                int start_tick = toStartTick(note, resolution);
                int duration_ticks = toDurationTicks(note, resolution);
                int pitch = clampMidi(note.pitch);
                int velocity = Math.max(1, clampMidi(note.volume));
                events.add(new MidiBuildEvent(start_tick, 2, new int[] {0x90 | channel, pitch, velocity}));
                events.add(new MidiBuildEvent(start_tick + duration_ticks, 1, new int[] {0x80 | channel, pitch, 0}));
            }
            Collections.sort(events);

            ByteArrayOutputStream track = new ByteArrayOutputStream();
            int last_tick = 0;
            for (MidiBuildEvent event : events) {
                writeVariableLengthQuantity(track, Math.max(0, event.tick - last_tick));
                for (int value : event.bytes) {
                    track.write(value & 0xFF);
                }
                last_tick = event.tick;
            }
            writeVariableLengthQuantity(track, 0);
            track.write(0xFF);
            track.write(0x2F);
            track.write(0x00);
            return track.toByteArray();
        }

        private static int clampMidi(int value) {
            return Math.max(0, Math.min(127, value));
        }

        private static void writeAscii(ByteArrayOutputStream output, String value) {
            byte[] bytes = value.getBytes(VOS_CHARSET);
            output.write(bytes, 0, bytes.length);
        }

        private static void writeIntBE(ByteArrayOutputStream output, int value) {
            output.write((value >>> 24) & 0xFF);
            output.write((value >>> 16) & 0xFF);
            output.write((value >>> 8) & 0xFF);
            output.write(value & 0xFF);
        }

        private static void writeShortBE(ByteArrayOutputStream output, int value) {
            output.write((value >>> 8) & 0xFF);
            output.write(value & 0xFF);
        }

        private static void writeVariableLengthQuantity(ByteArrayOutputStream output, int value) {
            int buffer = value & 0x7F;
            while ((value >>= 7) > 0) {
                buffer <<= 8;
                buffer |= ((value & 0x7F) | 0x80);
            }
            while (true) {
                output.write(buffer & 0xFF);
                if ((buffer & 0x80) != 0) {
                    buffer >>= 8;
                } else {
                    break;
                }
            }
        }
    }

    private static final class MidiNote {
        final int instrument;
        final VOSNote note;

        MidiNote(int instrument, VOSNote note) {
            this.instrument = instrument;
            this.note = note;
        }
    }

    private static final class TempoEvent implements Comparable<TempoEvent> {
        final int tick;
        final int mpqn;

        TempoEvent(int tick, int mpqn) {
            this.tick = tick;
            this.mpqn = mpqn;
        }

        public int compareTo(TempoEvent other) {
            return tick - other.tick;
        }
    }

    private static final class ParsedTrack {
        final List<TempoEvent> tempos;
        final int note_count;

        ParsedTrack(List<TempoEvent> tempos, int note_count) {
            this.tempos = tempos;
            this.note_count = note_count;
        }
    }

    private static final class MidiBuildEvent implements Comparable<MidiBuildEvent> {
        final int tick;
        final int priority;
        final int[] bytes;

        MidiBuildEvent(int tick, int priority, int[] bytes) {
            this.tick = tick;
            this.priority = priority;
            this.bytes = bytes;
        }

        public int compareTo(MidiBuildEvent other) {
            if (tick == other.tick) {
                return priority - other.priority;
            }
            return tick - other.tick;
        }
    }

    private static final class Position {
        final int measure;
        final double position;

        Position(int measure, double position) {
            this.measure = measure;
            this.position = position;
        }
    }

    private static final class Reader {
        private final byte[] bytes;
        private int position;

        Reader(byte[] bytes) {
            this.bytes = bytes;
        }

        int position() {
            return position;
        }

        int remaining() {
            return bytes.length - position;
        }

        int remainingBefore(int end_address) {
            return Math.max(0, Math.min(end_address, bytes.length) - position);
        }

        void seek(int position) {
            if (position < 0 || position > bytes.length) {
                throw new IllegalArgumentException("invalid VOS seek address");
            }
            this.position = position;
        }

        int readUnsignedByte() {
            require(1);
            return bytes[position++] & 0xFF;
        }

        int readInt() {
            require(4);
            int value = VOSParser.readInt(bytes, position);
            position += 4;
            return value;
        }

        int readIntBE() {
            require(4);
            int value = ((bytes[position] & 0xFF) << 24)
                    | ((bytes[position + 1] & 0xFF) << 16)
                    | ((bytes[position + 2] & 0xFF) << 8)
                    | (bytes[position + 3] & 0xFF);
            position += 4;
            return value;
        }

        int readUnsignedShortBE() {
            require(2);
            int value = ((bytes[position] & 0xFF) << 8) | (bytes[position + 1] & 0xFF);
            position += 2;
            return value;
        }

        int readVariableLengthQuantity() {
            int value = 0;
            int current;
            do {
                current = readUnsignedByte();
                value = (value << 7) | (current & 0x7F);
            } while ((current & 0x80) != 0);
            return value;
        }

        byte[] readBytes(int length) {
            require(length);
            byte[] value = Arrays.copyOfRange(bytes, position, position + length);
            position += length;
            return value;
        }

        String readAscii(int length) {
            require(length);
            String value = new String(bytes, position, length, Charset.forName("US-ASCII"));
            position += length;
            return value;
        }

        String readString() {
            int length = readUnsignedByte();
            require(length);
            String value = new String(bytes, position, length, VOS_CHARSET).trim();
            position += length;
            return value;
        }

        String readFixedString(int length) {
            require(length);
            int end = position;
            while (end < position + length && bytes[end] != 0) {
                end++;
            }
            String value = new String(bytes, position, end - position, VOS_CHARSET).trim();
            position += length;
            return value;
        }

        void skip(int count) {
            require(count);
            position += count;
        }

        private void require(int count) {
            if (position + count > bytes.length) {
                throw new IllegalArgumentException("unexpected end of VOS file");
            }
        }
    }
}
