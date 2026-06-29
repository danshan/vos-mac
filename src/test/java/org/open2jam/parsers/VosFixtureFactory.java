package org.open2jam.parsers;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;

public final class VosFixtureFactory {
    private static final Charset VOS_CHARSET = Charset.forName("GB2312");

    private VosFixtureFactory() {
    }

    public static File writeFixture(File directory, String fileName, int level, boolean includeLevel,
            boolean includeChannelData, boolean includeLongNote) throws IOException {
        return writeFixture(directory, fileName, level, includeLevel, includeChannelData, includeLongNote,
                "Canon in D");
    }

    public static File writeFixture(File directory, String fileName, int level, boolean includeLevel,
            boolean includeChannelData, boolean includeLongNote, String title) throws IOException {
        byte[] bytes = buildFixture(level, includeLevel, includeChannelData, includeLongNote, title);
        File file = new File(directory, fileName);
        Files.write(file.toPath(), bytes);
        return file;
    }

    public static byte[] buildFixture(int level, boolean includeLevel, boolean includeChannelData,
            boolean includeLongNote, String title) throws IOException {
        return buildFixture(level, includeLevel, includeChannelData, includeLongNote, title, null);
    }

    static File writeLongNoteFixture(File directory, String fileName, int level) throws IOException {
        byte[] bytes = buildFixture(level, true, true, false, "Canon in D", null, true);
        File file = new File(directory, fileName);
        Files.write(file.toPath(), bytes);
        return file;
    }

    static File writeTapNoteFixture(File directory, String fileName, int level, int keyboard) throws IOException {
        byte[] bytes = buildFixture(level, true, true, false, "Canon in D", null, false, keyboard);
        File file = new File(directory, fileName);
        Files.write(file.toPath(), bytes);
        return file;
    }

    static File writePlayableChannelFixture(File directory, String fileName, int level) throws IOException {
        return writePlayableChannelFixture(directory, fileName, level, minimalMidi());
    }

    static File writePlayableChannelFixture(File directory, String fileName, int level, byte[] embeddedMidi)
            throws IOException {
        byte[] bytes = buildFixture(level, true, true, false, "Canon in D", null, false, 0x80,
                17, 16, true, embeddedMidi);
        File file = new File(directory, fileName);
        Files.write(file.toPath(), bytes);
        return file;
    }

    static File writePlayableOnlyFixture(File directory, String fileName, int level, byte[] embeddedMidi)
            throws IOException {
        byte[] bytes = buildFixture(level, true, true, false, "Canon in D", null, false, 0x80,
                17, 16, false, embeddedMidi);
        File file = new File(directory, fileName);
        Files.write(file.toPath(), bytes);
        return file;
    }

    static File writeSourceOverlapFixture(File directory, String fileName, int level, byte[] embeddedMidi)
            throws IOException {
        return writeSourceOverlapFixture(directory, fileName, level, embeddedMidi, 0x000, 0x000);
    }

    static File writeSourceOverlapFixture(File directory, String fileName, int level, byte[] embeddedMidi,
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
        File file = new File(directory, fileName);
        Files.write(file.toPath(), patchSegmentAddresses(out.toByteArray(), channelEnd));
        return file;
    }

    static File writeRepeatedLiveSampleFixture(File directory, String fileName, int level, byte[] embeddedMidi)
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
        File file = new File(directory, fileName);
        Files.write(file.toPath(), patchSegmentAddresses(out.toByteArray(), channelEnd));
        return file;
    }

    static File writeFixtureWithNoteCount(File directory, String fileName, int noteCount) throws IOException {
        byte[] bytes = buildFixture(4, true, true, false, "Canon in D", noteCount);
        File file = new File(directory, fileName);
        Files.write(file.toPath(), bytes);
        return file;
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

    static byte[] minimalMidi() throws IOException {
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

    static byte[] midiWithChannelState(int channel, int program, int controller, int controllerValue)
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
