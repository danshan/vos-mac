package org.open2jam.parsers;

import java.io.File;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;

public final class OjnFixtureFactory {
    private static final int OJM_SIGNATURE = 0x004D4A4F;

    private OjnFixtureFactory() {
    }

    public record OjnFixture(File chart, File samples) {
    }

    public static OjnFixture writeFixture(File directory, String baseName) throws Exception {
        File chart = new File(directory, baseName + ".ojn");
        File samples = new File(directory, baseName + ".ojm");
        writeOjn(chart, samples.getName());
        writePlainOjm(samples);
        return new OjnFixture(chart, samples);
    }

    private static void writePlainOjm(File file) throws Exception {
        byte[] pcm = new byte[] {0, 0, 0, 0};
        int oggStart = 20 + 56 + pcm.length;
        ByteBuffer buffer = ByteBuffer.allocate(oggStart).order(ByteOrder.LITTLE_ENDIAN);
        buffer.putInt(OJM_SIGNATURE);
        buffer.putShort((short) 0);
        buffer.putShort((short) 0);
        buffer.putInt(20);
        buffer.putInt(oggStart);
        buffer.putInt(oggStart);
        putFixedString(buffer, "fixture.wav", 32);
        buffer.putShort((short) 1);
        buffer.putShort((short) 1);
        buffer.putInt(8000);
        buffer.putInt(16000);
        buffer.putShort((short) 2);
        buffer.putShort((short) 16);
        buffer.putInt(0x61746164);
        buffer.putInt(pcm.length);
        buffer.put(pcm);
        Files.write(file.toPath(), buffer.array());
    }

    private static void writeOjn(File chart, String ojmName) throws Exception {
        ByteBuffer buffer = ByteBuffer.allocate(300).order(ByteOrder.LITTLE_ENDIAN);
        buffer.putInt(100);
        buffer.putInt(0x006E6A6F);
        buffer.putFloat(2.0f);
        buffer.putInt(2);
        buffer.putFloat(130.0f);
        buffer.putShort((short) 3);
        buffer.putShort((short) 5);
        buffer.putShort((short) 8);
        buffer.putShort((short) 0);
        buffer.putInt(0);
        buffer.putInt(0);
        buffer.putInt(0);
        buffer.putInt(10);
        buffer.putInt(20);
        buffer.putInt(30);
        buffer.putInt(0);
        buffer.putInt(0);
        buffer.putInt(0);
        buffer.putInt(0);
        buffer.putInt(0);
        buffer.putInt(0);
        buffer.putShort((short) 0);
        buffer.putShort((short) 0);
        putFixedString(buffer, "", 20);
        buffer.putInt(0);
        buffer.putInt(1);
        putFixedString(buffer, "O2Jam Fixture", 64);
        putFixedString(buffer, "O2 Artist", 32);
        putFixedString(buffer, "O2 Noter", 32);
        putFixedString(buffer, ojmName, 32);
        buffer.putInt(0);
        buffer.putInt(91);
        buffer.putInt(91);
        buffer.putInt(91);
        buffer.putInt(300);
        buffer.putInt(300);
        buffer.putInt(300);
        buffer.putInt(300);
        Files.write(chart.toPath(), buffer.array());
    }

    private static void putFixedString(ByteBuffer buffer, String value, int length) {
        byte[] bytes = value.getBytes(StandardCharsets.US_ASCII);
        int written = Math.min(bytes.length, length);
        buffer.put(bytes, 0, written);
        for (int i = written; i < length; i++) {
            buffer.put((byte) 0);
        }
    }
}
