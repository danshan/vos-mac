package org.open2jam;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.PrintStream;
import java.awt.image.BufferedImage;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import javax.imageio.ImageIO;
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
    void exportsVosGameplayFromCliWithoutStartingGui() throws Exception {
        File chartFile = VosFixtureFactory.writeFixture(tempDir, "gameplay.vos", 7, true, true, false);
        File outputFile = new File(tempDir, "exports/gameplay/gameplay.json");
        CliResult result = runCli("--export-vos-gameplay", "--output", outputFile.getPath(), chartFile.getPath());

        assertEquals(0, result.status);
        assertEquals("", result.stdout);
        assertEquals("", result.stderr);
        assertTrue(outputFile.getParentFile().isDirectory());
        String json = Files.readString(outputFile.toPath(), StandardCharsets.UTF_8);
        assertTrue(json.contains("\"format\":\"VOS\""));
        assertTrue(json.contains("\"title\":\"Canon in D\""));
        assertTrue(json.contains("\"notes\""));
    }

    @Test
    void exportsVosAudioFromCliWithoutStartingGui() throws Exception {
        File chartFile = VosFixtureFactory.writeFixture(tempDir, "audio.vos", 7, VOS_DROID_CHANNEL_COUNT,
                VOS_DROID_PLAYABLE_CHANNEL_INDEX, INCLUDE_DISTRACTOR_NOTE);
        File manifestFile = new File(tempDir, "exports/audio/audio-manifest.json");
        File assetDir = new File(tempDir, "exports/audio-assets");
        CliResult result = runCli("--export-vos-audio", "--output", manifestFile.getPath(),
                "--asset-dir", assetDir.getPath(), chartFile.getPath());

        assertEquals(0, result.status);
        assertEquals("", result.stdout);
        assertEquals("", result.stderr);
        assertTrue(manifestFile.getParentFile().isDirectory());
        assertTrue(manifestFile.isFile());
        assertTrue(assetDir.isDirectory());
        assertTrue(new File(assetDir, "sample-1.wav").isFile());
        assertTrue(new File(assetDir, "sample-2.wav").isFile());
        String json = Files.readString(manifestFile.toPath(), StandardCharsets.UTF_8);
        assertTrue(json.contains("\"assets\""));
        assertTrue(json.contains("\"fileName\":\"sample-1.wav\""));
        assertTrue(json.contains("\"fileName\":\"sample-2.wav\""));
    }

    @Test
    void exportsVosRenderMetadataFromCliWithoutStartingGui() throws Exception {
        File outputFile = new File(tempDir, "exports/render/render-metadata.json");
        CliResult result = runCli("--export-vos-render-metadata", "--output", outputFile.getPath());

        assertEquals(0, result.status);
        assertEquals("", result.stdout);
        assertEquals("", result.stderr);
        assertTrue(outputFile.getParentFile().isDirectory());
        String json = Files.readString(outputFile.toPath(), StandardCharsets.UTF_8);
        assertTrue(json.contains("\"format\":\"VOS_RENDER_METADATA\""));
        assertTrue(json.contains("\"id\":\"NOTE_1\""));
        assertTrue(json.contains("\"id\":\"JAM_BAR\""));
    }

    @Test
    void comparesGameplayScreenshotsWithDiffComponentsArtifact() throws Exception {
        File javaImage = new File(tempDir, "compare/java.png");
        File godotImage = new File(tempDir, "compare/godot.png");
        File outDir = new File(tempDir, "compare/out");
        writeComparisonFixture(javaImage, godotImage);

        CliResult result = runCli("--compare-vos-gameplay-screenshots",
                "--java", javaImage.getPath(),
                "--godot", godotImage.getPath(),
                "--out-dir", outDir.getPath());

        assertEquals(0, result.status);
        assertEquals("", result.stdout);
        assertEquals("", result.stderr);
        assertTrue(new File(outDir, "side-by-side.png").isFile());
        assertTrue(new File(outDir, "diff.png").isFile());
        File componentsFile = new File(outDir, "diff-components.json");
        assertTrue(componentsFile.isFile());
        String summaryJson = Files.readString(new File(outDir, "summary.json").toPath(), StandardCharsets.UTF_8);
        assertTrue(summaryJson.contains("\"diffComponents\":\"" + componentsFile.getCanonicalPath() + "\""));
        String componentsJson = Files.readString(componentsFile.toPath(), StandardCharsets.UTF_8);
        assertTrue(componentsJson.contains("\"componentCount\":2"));
        assertTrue(componentsJson.contains("\"x\":1,\"y\":1,\"width\":2,\"height\":1,\"pixels\":2"));
        assertTrue(componentsJson.contains("\"x\":0,\"y\":3,\"width\":1,\"height\":1,\"pixels\":1"));
    }

    @Test
    void comparesGameplayScreenshotsWithPixelToleranceForRendererRounding() throws Exception {
        File javaImage = new File(tempDir, "compare-tolerance/java.png");
        File godotImage = new File(tempDir, "compare-tolerance/godot.png");
        File outDir = new File(tempDir, "compare-tolerance/out");
        writeComparisonToleranceFixture(javaImage, godotImage);

        CliResult result = runCli("--compare-vos-gameplay-screenshots",
                "--java", javaImage.getPath(),
                "--godot", godotImage.getPath(),
                "--out-dir", outDir.getPath(),
                "--pixel-tolerance", "4");

        assertEquals(0, result.status);
        assertEquals("", result.stdout);
        assertEquals("", result.stderr);
        String summaryJson = Files.readString(new File(outDir, "summary.json").toPath(), StandardCharsets.UTF_8);
        assertTrue(summaryJson.contains("\"differingPixels\":2"));
        assertTrue(summaryJson.contains("\"significantDifferingPixels\":1"));
        assertTrue(summaryJson.contains("\"pixelTolerance\":4"));
        assertTrue(summaryJson.contains("\"significantMeanAbsDelta\":0.625"));
        String componentsJson = Files.readString(new File(outDir, "diff-components.json").toPath(),
                StandardCharsets.UTF_8);
        assertTrue(componentsJson.contains("\"componentCount\":1"));
        assertTrue(componentsJson.contains("\"x\":2,\"y\":2,\"width\":1,\"height\":1,\"pixels\":1"));
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
        assertUsageError(
                new String[] {"--export-vos-catalog", "--output"},
                "Usage: open2jam --export-vos-catalog --output <file> <file-or-directory>");
        assertUsageError(
                new String[] {"--export-vos-gameplay", "--output"},
                "Usage: open2jam --export-vos-gameplay --output <file> <file.vos>");
        assertUsageError(
                new String[] {"--export-vos-audio", "--output", "manifest.json", "--asset-dir"},
                "Usage: open2jam --export-vos-audio --output <manifest> --asset-dir <directory> <file.vos>");
        assertUsageError(
                new String[] {"--export-vos-render-metadata", "--output"},
                "Usage: open2jam --export-vos-render-metadata --output <file>");
        assertUsageError(
                new String[] {"--export-vos-selected", "--out-dir"},
                "Usage: open2jam --export-vos-selected --out-dir <directory> <file.vos>");
        assertUsageError(
                new String[] {"--capture-vos-gameplay-screenshot", "--output"},
                "Usage: open2jam --capture-vos-gameplay-screenshot --output <png>");
        assertUsageError(
                new String[] {"--compare-vos-gameplay-screenshots", "--java", "java.png"},
                "Usage: open2jam --compare-vos-gameplay-screenshots --java <png>");
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
        assertTrue(new File(outDir, "render-metadata.json").isFile());
        File assetDir = new File(outDir, "audio");
        assertTrue(assetDir.isDirectory());
        assertTrue(new File(assetDir, "sample-1.wav").isFile());
        assertTrue(new File(assetDir, "sample-2.wav").isFile());
    }

    @Test
    void exportsSelectedOjnBundleFromCliWithoutStartingGui() throws Exception {
        File chartFile = new File("/Users/honghao.shan/Music/demo/o2ma101.ojn");
        File sampleFile = new File("/Users/honghao.shan/Music/demo/o2ma101.ojm");
        assumeTrue(chartFile.isFile(), "OJN demo fixture is not available");
        assumeTrue(sampleFile.isFile(), "OJM demo fixture is not available");
        File outDir = new File(tempDir, "selected-ojn-export");
        CliResult result = runCli("--export-vos-selected", "--out-dir", outDir.getPath(), chartFile.getPath());

        assertEquals(0, result.status);
        assertEquals("", result.stdout);
        assertEquals("", result.stderr);
        assertTrue(new File(outDir, "catalog.json").isFile());
        File gameplayFile = new File(outDir, "gameplay.json");
        File audioManifestFile = new File(outDir, "audio-manifest.json");
        assertTrue(gameplayFile.isFile());
        assertTrue(audioManifestFile.isFile());
        assertTrue(new File(outDir, "render-metadata.json").isFile());
        File assetDir = new File(outDir, "audio");
        assertTrue(assetDir.isDirectory());
        assertTrue(new File(assetDir, "sample-1.wav").isFile());
        assertTrue(new File(assetDir, "sample-1001.wav").isFile());
        String gameplayJson = Files.readString(gameplayFile.toPath(), StandardCharsets.UTF_8);
        String audioJson = Files.readString(audioManifestFile.toPath(), StandardCharsets.UTF_8);
        assertTrue(gameplayJson.contains("\"format\":\"OJN\""));
        assertTrue(gameplayJson.contains("\"sampleId\":1"));
        assertTrue(audioJson.contains("\"format\":\"OJN\""));
        assertTrue(audioJson.contains("\"sampleId\":1"));
        assertTrue(audioJson.contains("\"sampleId\":1001"));
    }

    @Test
    void exportsSelectedOjnBundleForRequestedChartIndex() throws Exception {
        File chartFile = new File("/Users/honghao.shan/Music/demo/o2ma101.ojn");
        File sampleFile = new File("/Users/honghao.shan/Music/demo/o2ma101.ojm");
        assumeTrue(chartFile.isFile(), "OJN demo fixture is not available");
        assumeTrue(sampleFile.isFile(), "OJM demo fixture is not available");
        File outDir = new File(tempDir, "selected-hard-ojn-export");
        CliResult result = runCli("--export-vos-selected", "--out-dir", outDir.getPath(),
                "--chart-index", "2", chartFile.getPath());

        assertEquals(0, result.status);
        assertEquals("", result.stdout);
        assertEquals("", result.stderr);
        File gameplayFile = new File(outDir, "gameplay.json");
        assertTrue(gameplayFile.isFile());
        String gameplayJson = Files.readString(gameplayFile.toPath(), StandardCharsets.UTF_8);
        assertTrue(gameplayJson.contains("\"format\":\"OJN\""));
        assertTrue(countOccurrences(gameplayJson, "\"eventOrder\":") > 900);
    }

    private static void assertUsageError(String[] args, String expectedUsage) throws Exception {
        CliResult result = runCli(args);

        assertEquals(2, result.status);
        assertEquals("", result.stdout);
        assertTrue(result.stderr.contains(expectedUsage));
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

    private static int countOccurrences(String text, String needle) {
        int count = 0;
        int index = text.indexOf(needle);
        while (index >= 0) {
            count++;
            index = text.indexOf(needle, index + needle.length());
        }
        return count;
    }

    private static void writeComparisonFixture(File javaImageFile, File godotImageFile) throws Exception {
        javaImageFile.getParentFile().mkdirs();
        BufferedImage javaImage = new BufferedImage(4, 4, BufferedImage.TYPE_INT_RGB);
        BufferedImage godotImage = new BufferedImage(4, 4, BufferedImage.TYPE_INT_RGB);
        godotImage.setRGB(1, 1, 0xff0000);
        godotImage.setRGB(2, 1, 0xff0000);
        godotImage.setRGB(0, 3, 0x0000ff);
        ImageIO.write(javaImage, "png", javaImageFile);
        ImageIO.write(godotImage, "png", godotImageFile);
    }

    private static void writeComparisonToleranceFixture(File javaImageFile, File godotImageFile) throws Exception {
        javaImageFile.getParentFile().mkdirs();
        BufferedImage javaImage = new BufferedImage(4, 4, BufferedImage.TYPE_INT_RGB);
        BufferedImage godotImage = new BufferedImage(4, 4, BufferedImage.TYPE_INT_RGB);
        javaImage.setRGB(1, 1, 0x101010);
        godotImage.setRGB(1, 1, 0x131313);
        javaImage.setRGB(2, 2, 0x101010);
        godotImage.setRGB(2, 2, 0x1a1a1a);
        ImageIO.write(javaImage, "png", javaImageFile);
        ImageIO.write(godotImage, "png", godotImageFile);
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
