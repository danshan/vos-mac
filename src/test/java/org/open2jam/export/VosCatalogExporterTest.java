package org.open2jam.export;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.security.MessageDigest;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.open2jam.parsers.VosFixtureFactory;

class VosCatalogExporterTest {
    @TempDir
    File tempDir;

    @Test
    void exportsSingleVosFileMetadata() throws Exception {
        File chartFile = VosFixtureFactory.writeFixture(tempDir, "canon.vos", 7, true, true, false);

        String json = new VosCatalogExporter().exportCatalog(chartFile);

        assertEquals(catalogJson(expectedEntry(chartFile, "Canon in D", 7)), json);
    }

    @Test
    void recursesDirectoryWithStableOrderAndDeterministicIds() throws Exception {
        File nested = new File(tempDir, "nested");
        Files.createDirectories(nested.toPath());
        File first = VosFixtureFactory.writeFixture(tempDir, "first.vos", 3, true, true, false, "First Song");
        File second = VosFixtureFactory.writeFixture(nested, "second.VOS", 8, true, true, false, "Second Song");
        VosFixtureFactory.writeFixture(tempDir, "ignored.dat", 5, true, true, false, "Ignored Song");
        Files.write(new File(nested, "broken.vos").toPath(), new byte[] {3, 0, 0, 0});
        Files.write(new File(tempDir, "notes.txt").toPath(), "not a chart".getBytes(StandardCharsets.UTF_8));
        Files.write(new File(tempDir, "broken.ojn").toPath(), new byte[] {1, 2, 3});

        String json = new VosCatalogExporter().exportCatalog(tempDir);

        assertEquals(catalogJson(
                expectedEntry(first, "First Song", 3),
                expectedEntry(second, "Second Song", 8)), json);
    }

    private static String catalogJson(String... entries) {
        return JsonWriter.object(
                JsonWriter.field("schemaVersion", 1),
                JsonWriter.rawField("entries", JsonWriter.array(entries)));
    }

    private static String expectedEntry(File source, String title, int level) throws Exception {
        String sourcePath = source.getCanonicalPath();
        return JsonWriter.object(
                JsonWriter.field("id", idFor(sourcePath)),
                JsonWriter.field("format", "VOS"),
                JsonWriter.field("sourcePath", sourcePath),
                JsonWriter.field("title", title),
                JsonWriter.field("artist", "Pachelbel"),
                JsonWriter.field("noter", "ReVanTis"),
                JsonWriter.field("genre", "Classical"),
                JsonWriter.field("keys", 7),
                JsonWriter.field("level", level),
                JsonWriter.field("levelKnown", true),
                JsonWriter.field("bpm", 120.0),
                JsonWriter.field("durationMs", 123000),
                JsonWriter.field("noteCount", 1),
                JsonWriter.field("coverAsset", ""),
                JsonWriter.field("exportStatus", "ready"));
    }

    private static String idFor(String sourcePath) throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        byte[] hash = digest.digest(sourcePath.getBytes(StandardCharsets.UTF_8));
        StringBuilder id = new StringBuilder("vos:sha256:");
        for (int i = 0; i < 8; i++) {
            id.append(String.format("%02x", hash[i] & 0xFF));
        }
        return id.toString();
    }
}
