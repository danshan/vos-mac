package org.open2jam;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.PrintStream;
import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.Test;

class MainVosAudioCliTest {
    private static final File REFERENCE_VOS = new File(
            "/Users/honghao.shan/workspace/opensource/VosDroid/android/assets/Canon in D.vos");

    @Test
    void validatesVosAudioFromCliWithoutStartingGui() throws Exception {
        assumeTrue(REFERENCE_VOS.isFile(), "VosDroid reference chart is not available");
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        ByteArrayOutputStream error = new ByteArrayOutputStream();

        int status = Main.runCli(new String[] {"--validate-vos-audio", REFERENCE_VOS.getAbsolutePath()},
                new PrintStream(output, true, StandardCharsets.UTF_8),
                new PrintStream(error, true, StandardCharsets.UTF_8));

        assertEquals(0, status);
        String text = output.toString(StandardCharsets.UTF_8);
        assertTrue(text.contains("VOS audio validation OK"));
        assertTrue(text.contains("Playable notes: 885"));
        assertTrue(text.contains("MIDI samples: 134"));
        assertTrue(text.contains("Background MIDI notes: 3239"));
        assertTrue(text.contains("Live MIDI notes: 885"));
        assertTrue(text.contains("Combined MIDI notes: 4124"));
        assertTrue(text.contains("Performance signature: OK"));
        assertTrue(text.contains("Rendered MIDI samples: 2"));
        assertEquals("", error.toString(StandardCharsets.UTF_8));
    }

    @Test
    void ignoresUnknownCliArgumentsSoGuiStartupCanContinue() {
        int status = Main.runCli(new String[] {"--unknown"},
                new PrintStream(new ByteArrayOutputStream()),
                new PrintStream(new ByteArrayOutputStream()));

        assertEquals(-1, status);
    }
}
