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

        File sample = new File(assetDir, "sample-1.wav");
        assertTrue(sample.isFile());
        byte[] wav = Files.readAllBytes(sample.toPath());
        assertArrayEquals(ascii("RIFF"), slice(wav, 0, 4));
        assertArrayEquals(ascii("WAVE"), slice(wav, 8, 12));
        assertTrue(containsChunk(wav, "fmt "));
        assertTrue(containsChunk(wav, "data"));
        assertFalse(startsWith(wav, "MThd"));
    }

    private static String audioJson(File source, File assetDir, String... assets) throws Exception {
        return JsonWriter.object(
                JsonWriter.field("schemaVersion", 1),
                JsonWriter.field("format", "VOS"),
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
                JsonWriter.field("role", "sample"));
    }

    private static boolean containsChunk(byte[] bytes, String chunk) {
        byte[] needle = ascii(chunk);
        for (int i = 0; i <= bytes.length - needle.length; i++) {
            boolean matched = true;
            for (int j = 0; j < needle.length; j++) {
                if (bytes[i + j] != needle[j]) {
                    matched = false;
                    break;
                }
            }
            if (matched) {
                return true;
            }
        }
        return false;
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

    private static byte[] ascii(String value) {
        return value.getBytes(StandardCharsets.US_ASCII);
    }
}
