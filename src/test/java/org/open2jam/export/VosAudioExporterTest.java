package org.open2jam.export;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.open2jam.parsers.OjnFixtureFactory;
import org.open2jam.parsers.VosFixtureFactory;

class VosAudioExporterTest {
    private static final int VOS_DROID_CHANNEL_COUNT = 17;
    private static final int VOS_DROID_PLAYABLE_CHANNEL_INDEX = 16;
    private static final boolean INCLUDE_DISTRACTOR_NOTE = true;

    @TempDir
    File tempDir;

    @Test
    void exportsVosMidiSamplesAsWavAssetsAndManifest() throws Exception {
        File chartFile = VosFixtureFactory.writeFixture(tempDir, "canon.vos", 7, VOS_DROID_CHANNEL_COUNT,
                VOS_DROID_PLAYABLE_CHANNEL_INDEX, INCLUDE_DISTRACTOR_NOTE);
        File assetDir = new File(tempDir, "audio");

        String json = new VosAudioExporter().exportAudio(chartFile, assetDir);

        assertTrue(assetDir.isDirectory());
        assertEquals(audioJson(chartFile, assetDir,
                asset(assetDir, 1),
                asset(assetDir, 2)), json);

        for (int sampleId = 1; sampleId <= 2; sampleId++) {
            assertWavFile(new File(assetDir, "sample-" + sampleId + ".wav"));
        }
    }

    @Test
    void exportsOsuManiaSevenKeyAudioSamplesAsWavAssetsAndManifest() throws Exception {
        File chartFile = writeOsuManiaSevenKeyFixture();
        writeSilentWav(new File(tempDir, "audio.wav"));
        File assetDir = new File(tempDir, "osu-audio");

        String json = new VosAudioExporter().exportAudio(chartFile, assetDir);

        assertTrue(assetDir.isDirectory());
        assertEquals(audioJsonWithFormat(chartFile, assetDir, "OSU", asset(assetDir, 1)), json);
        assertWavFile(new File(assetDir, "sample-1.wav"));
    }

    @Test
    void exportsOjnOjmSampleAsWavAssetAndManifest() throws Exception {
        OjnFixtureFactory.OjnFixture fixture = OjnFixtureFactory.writeFixture(tempDir, "audio-o2jam");
        File assetDir = new File(tempDir, "ojn-audio");

        String json = new VosAudioExporter().exportAudio(fixture.chart(), assetDir);

        assertTrue(json.contains("\"format\":\"OJN\""));
        assertTrue(json.contains("\"sampleId\":1"));
        assertWavFile(new File(assetDir, "sample-1.wav"));
    }

    private static String audioJson(File source, File assetDir, String... assets) throws Exception {
        return audioJsonWithFormat(source, assetDir, "VOS", assets);
    }

    private static String audioJsonWithFormat(File source, File assetDir, String format, String... assets)
            throws Exception {
        return JsonWriter.object(
                JsonWriter.field("schemaVersion", 1),
                JsonWriter.field("format", format),
                JsonWriter.field("sourcePath", source.getCanonicalPath()),
                JsonWriter.field("assetDir", assetDir.getCanonicalPath()),
                JsonWriter.rawField("assets", JsonWriter.array(assets)));
    }

    private static String asset(File assetDir, int sampleId) throws Exception {
        String fileName = "sample-" + sampleId + ".wav";
        return JsonWriter.object(
                JsonWriter.field("sampleId", sampleId),
                JsonWriter.field("fileName", fileName),
                JsonWriter.field("path", new File(assetDir, fileName).getCanonicalPath()),
                JsonWriter.field("type", "wav"),
                JsonWriter.field("role", "sample"),
                JsonWriter.field("preload", true));
    }

    private static void assertWavFile(File file) throws Exception {
        assertTrue(file.isFile());
        byte[] wav = Files.readAllBytes(file.toPath());
        assertTrue(wav.length >= 44);
        assertArrayEquals(ascii("RIFF"), slice(wav, 0, 4));
        assertEquals(wav.length - 8, readLittleEndianInt(wav, 4));
        assertArrayEquals(ascii("WAVE"), slice(wav, 8, 12));
        assertArrayEquals(ascii("fmt "), slice(wav, 12, 16));
        assertEquals(16, readLittleEndianInt(wav, 16));
        assertEquals(1, readLittleEndianShort(wav, 20));

        int channels = readLittleEndianShort(wav, 22);
        int sampleRate = readLittleEndianInt(wav, 24);
        int byteRate = readLittleEndianInt(wav, 28);
        int blockAlign = readLittleEndianShort(wav, 32);
        int bitsPerSample = readLittleEndianShort(wav, 34);
        assertTrue(channels > 0);
        assertTrue(sampleRate > 0);
        assertTrue(bitsPerSample > 0);
        assertEquals(0, bitsPerSample % 8);
        assertEquals(channels * bitsPerSample / 8, blockAlign);
        assertEquals(sampleRate * blockAlign, byteRate);

        assertArrayEquals(ascii("data"), slice(wav, 36, 40));
        assertEquals(wav.length - 44, readLittleEndianInt(wav, 40));
        assertFalse(startsWith(wav, "MThd"));
    }

    private static boolean startsWith(byte[] bytes, String prefix) {
        byte[] needle = ascii(prefix);
        if (bytes.length < needle.length) {
            return false;
        }
        for (int i = 0; i < needle.length; i++) {
            if (bytes[i] != needle[i]) {
                return false;
            }
        }
        return true;
    }

    private static byte[] slice(byte[] bytes, int start, int end) {
        byte[] out = new byte[end - start];
        System.arraycopy(bytes, start, out, 0, out.length);
        return out;
    }

    private static int readLittleEndianInt(byte[] bytes, int offset) {
        return (bytes[offset] & 0xFF)
                | ((bytes[offset + 1] & 0xFF) << 8)
                | ((bytes[offset + 2] & 0xFF) << 16)
                | ((bytes[offset + 3] & 0xFF) << 24);
    }

    private static int readLittleEndianShort(byte[] bytes, int offset) {
        return (bytes[offset] & 0xFF) | ((bytes[offset + 1] & 0xFF) << 8);
    }

    private static byte[] ascii(String value) {
        return value.getBytes(StandardCharsets.US_ASCII);
    }

    private File writeOsuManiaSevenKeyFixture() throws Exception {
        File chartFile = new File(tempDir, "seven-key.osu");
        String content = ""
                + "osu file format v14\n"
                + "\n"
                + "[General]\n"
                + "AudioFilename: audio.wav\n"
                + "Mode: 3\n"
                + "\n"
                + "[Metadata]\n"
                + "Title:Audio Fixture\n"
                + "Artist:Fixture Artist\n"
                + "Creator:Fixture Creator\n"
                + "Version:Test 7K\n"
                + "\n"
                + "[Difficulty]\n"
                + "CircleSize:7\n"
                + "OverallDifficulty:8\n"
                + "\n"
                + "[TimingPoints]\n"
                + "0,500,4,2,1,60,1,0\n"
                + "\n"
                + "[HitObjects]\n"
                + "36,192,0,1,0,0:0:0:0:\n";
        Files.write(chartFile.toPath(), content.getBytes(StandardCharsets.UTF_8));
        return chartFile;
    }

    private static void writeSilentWav(File file) throws Exception {
        byte[] pcm = new byte[800];
        int channels = 1;
        int sampleRate = 8000;
        int bitsPerSample = 16;
        int blockAlign = channels * bitsPerSample / 8;
        ByteArrayBuilder wav = new ByteArrayBuilder();
        wav.writeAscii("RIFF");
        wav.writeLittleEndianInt(36 + pcm.length);
        wav.writeAscii("WAVE");
        wav.writeAscii("fmt ");
        wav.writeLittleEndianInt(16);
        wav.writeLittleEndianShort(1);
        wav.writeLittleEndianShort(channels);
        wav.writeLittleEndianInt(sampleRate);
        wav.writeLittleEndianInt(sampleRate * blockAlign);
        wav.writeLittleEndianShort(blockAlign);
        wav.writeLittleEndianShort(bitsPerSample);
        wav.writeAscii("data");
        wav.writeLittleEndianInt(pcm.length);
        wav.writeBytes(pcm);
        Files.write(file.toPath(), wav.toByteArray());
    }

    private static final class ByteArrayBuilder {
        private final java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream();

        void writeAscii(String value) {
            writeBytes(ascii(value));
        }

        void writeLittleEndianInt(int value) {
            out.write(value & 0xFF);
            out.write((value >>> 8) & 0xFF);
            out.write((value >>> 16) & 0xFF);
            out.write((value >>> 24) & 0xFF);
        }

        void writeLittleEndianShort(int value) {
            out.write(value & 0xFF);
            out.write((value >>> 8) & 0xFF);
        }

        void writeBytes(byte[] bytes) {
            out.write(bytes, 0, bytes.length);
        }

        byte[] toByteArray() {
            return out.toByteArray();
        }
    }
}
