package org.open2jam.sound;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

import java.io.ByteArrayOutputStream;
import java.io.File;
import org.junit.jupiter.api.Test;
import org.open2jam.parsers.Chart;
import org.open2jam.parsers.ChartParser;
import org.open2jam.parsers.utils.SampleData;

class JavaSoundPcmDecoderTest {
    private static final File REFERENCE_OSZ = new File(
            "/Users/honghao.shan/Downloads/L33 - Project Loved_ Best of 2025 (osu!mania)/1187083 Jay Chou - Nocturne.osz");

    @Test
    void decodesReferenceOsuManiaMp3ToPcm() throws Exception {
        assumeTrue(REFERENCE_OSZ.isFile(), "Nocturne reference beatmapset is not available");

        Chart chart = ChartParser.parseFile(REFERENCE_OSZ).get(0);
        SampleData sample = chart.getSamples().get(1);
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        sample.copyTo(output);
        sample.dispose();

        JavaSoundPcmDecoder.DecodedPcm pcm = JavaSoundPcmDecoder.decode(output.toByteArray());

        assertEquals(2, pcm.channels);
        assertEquals(16, pcm.bitsPerSample);
        assertTrue(pcm.sampleRate > 0);
        assertTrue(pcm.pcm.length > pcm.sampleRate);
        assertTrue(containsNonSilentSample(pcm.pcm));
    }

    private static boolean containsNonSilentSample(byte[] pcm) {
        for (byte value : pcm) {
            if (value != 0) {
                return true;
            }
        }
        return false;
    }
}
