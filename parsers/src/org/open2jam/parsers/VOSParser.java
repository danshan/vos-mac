package org.open2jam.parsers;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileFilter;
import java.io.FileInputStream;
import java.io.IOException;
import java.nio.charset.Charset;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.logging.Level;
import org.open2jam.parsers.utils.Logger;

class VOSParser {
    private static final Charset VOS_CHARSET = Charset.forName("GB2312");
    private static final int HEADER_MAGIC = 3;
    private static final int INF_PADDING_LENGTH = 1023;

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
            File[] vos_files = file.listFiles(vos_filter);
            if (vos_files == null) {
                return false;
            }
            for (File vos_file : vos_files) {
                if (isStructurallyReadable(vos_file)) {
                    return true;
                }
            }
            return false;
        }
        return file.getName().toLowerCase().endsWith(".vos") && isStructurallyReadable(file);
    }

    public static ChartList parseFile(File file) {
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

        EventList events = readChannels(reader, mid.address);
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

    private static EventList readChannels(Reader reader, int end_address) {
        EventList events = new EventList();
        while (reader.position() < end_address) {
            if (reader.remainingBefore(end_address) < 22) {
                throw new IllegalArgumentException("truncated VOS channel");
            }
            reader.readInt();
            int note_count = reader.readInt();
            if (note_count < 0) {
                throw new IllegalArgumentException("negative VOS note count");
            }
            reader.skip(14);

            for (int i = 0; i < note_count; i++) {
                if (reader.remainingBefore(end_address) < 13) {
                    throw new IllegalArgumentException("truncated VOS note");
                }
                events.playableNotes += addNoteEvents(events, readNote(reader));
            }
        }
        Collections.sort(events);
        return events;
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

    private static int addNoteEvents(EventList events, VOSNote note) {
        Event.Channel channel = mapKeyboard(note.keyboard);
        if (channel == Event.Channel.NONE) {
            return 0;
        }

        Position start = toPosition(note.sequencer);
        int value = Math.max(1, note.pitch);
        if (isLongNote(note)) {
            events.add(new Event(channel, start.measure, start.position, value, Event.Flag.HOLD));
            Position end = toPosition(note.sequencer + note.duration);
            events.add(new Event(channel, end.measure, end.position, value, Event.Flag.RELEASE));
        } else {
            events.add(new Event(channel, start.measure, start.position, value, Event.Flag.NONE));
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

    private static Position toPosition(int sequencer) {
        int measure = sequencer / 0x300;
        double position = (sequencer % 0x300) / (double) 0x300;
        return new Position(measure, position);
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
        return ((bytes[offset] & 0xFF) << 24)
                | ((bytes[offset + 1] & 0xFF) << 16)
                | ((bytes[offset + 2] & 0xFF) << 8)
                | (bytes[offset + 3] & 0xFF);
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
