package org.open2jam;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.PrintStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.open2jam.parsers.VosFixtureFactory;

class MainVosExportCliTest {
    private static final int VOS_DROID_CHANNEL_COUNT = 17;
    private static final int VOS_DROID_PLAYABLE_CHANNEL_INDEX = 16;
    private static final boolean INCLUDE_DISTRACTOR_NOTE = true;

    @TempDir
    File tempDir;

    @Test
    void exportsVosCatalogFromCliWithoutStartingGui() throws Exception {
        File chartFile = VosFixtureFactory.writeFixture(tempDir, "canon.vos", 7, true, true, false);
        File outputFile = new File(tempDir, "exports/catalog.json");
        CliResult result = runCli("--export-vos-catalog", "--output", outputFile.getPath(), chartFile.getPath());

        assertEquals(0, result.status);
        assertEquals("", result.stdout);
        assertEquals("", result.stderr);
        String json = Files.readString(outputFile.toPath(), StandardCharsets.UTF_8);
        assertTrue(json.contains("\"schemaVersion\":1"));
        assertTrue(json.contains("\"title\":\"Canon in D\""));
    }

    @Test
    void ignoresUnknownCliArgumentsSoGuiStartupCanContinue() throws Exception {
        CliResult result = runCli("--unknown");

        assertEquals(-1, result.status);
        assertEquals("", result.stdout);
        assertEquals("", result.stderr);
    }

    @Test
    void reportsUsageErrorsForVosExportCommands() throws Exception {
        CliResult result = runCli("--export-vos-catalog", "--output");

        assertEquals(2, result.status);
        assertEquals("", result.stdout);
        assertTrue(result.stderr.contains(
                "Usage: open2jam --export-vos-catalog --output <file> <file-or-directory>"));
    }

    @Test
    void exportsSelectedVosBundleFromCliWithoutStartingGui() throws Exception {
        File chartFile = VosFixtureFactory.writeFixture(tempDir, "selected.vos", 7, VOS_DROID_CHANNEL_COUNT,
                VOS_DROID_PLAYABLE_CHANNEL_INDEX, INCLUDE_DISTRACTOR_NOTE);
        File outDir = new File(tempDir, "selected-export");
        CliResult result = runCli("--export-vos-selected", "--out-dir", outDir.getPath(), chartFile.getPath());

        assertEquals(0, result.status);
        assertEquals("", result.stdout);
        assertEquals("", result.stderr);
        assertTrue(new File(outDir, "catalog.json").isFile());
        assertTrue(new File(outDir, "gameplay.json").isFile());
        assertTrue(new File(outDir, "audio-manifest.json").isFile());
        File assetDir = new File(outDir, "audio");
        assertTrue(assetDir.isDirectory());
        assertTrue(new File(assetDir, "sample-1.wav").isFile());
        assertTrue(new File(assetDir, "sample-2.wav").isFile());
    }

    private static CliResult runCli(String... args) throws Exception {
        ByteArrayOutputStream stdout = new ByteArrayOutputStream();
        ByteArrayOutputStream stderr = new ByteArrayOutputStream();
        int status = Main.runCli(args,
                new PrintStream(stdout, true, StandardCharsets.UTF_8),
                new PrintStream(stderr, true, StandardCharsets.UTF_8));
        return new CliResult(status,
                stdout.toString(StandardCharsets.UTF_8),
                stderr.toString(StandardCharsets.UTF_8));
    }

    private static final class CliResult {
        final int status;
        final String stdout;
        final String stderr;

        CliResult(int status, String stdout, String stderr) {
            this.status = status;
            this.stdout = stdout;
            this.stderr = stderr;
        }
    }
}
