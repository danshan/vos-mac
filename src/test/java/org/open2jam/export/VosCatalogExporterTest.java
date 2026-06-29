package org.open2jam.export;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
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

        assertContains(json, JsonWriter.field("schemaVersion", 1));
        assertContains(json, JsonWriter.field("format", "VOS"));
        assertContains(json, JsonWriter.field("sourcePath", chartFile.getCanonicalPath()));
        assertContains(json, JsonWriter.field("title", "Canon in D"));
        assertContains(json, JsonWriter.field("artist", "Pachelbel"));
        assertContains(json, JsonWriter.field("level", 7));
        assertContains(json, JsonWriter.field("levelKnown", true));
        assertContains(json, JsonWriter.field("exportStatus", "ready"));
    }

    @Test
    void recursesDirectoryAndSkipsNonParsableFiles() throws Exception {
        File nested = new File(tempDir, "nested");
        Files.createDirectories(nested.toPath());
        VosFixtureFactory.writeFixture(tempDir, "first.vos", 3, true, true, false, "First Song");
        VosFixtureFactory.writeFixture(nested, "second.vos", 8, true, true, false, "Second Song");
        Files.write(new File(tempDir, "notes.txt").toPath(), "not a chart".getBytes(StandardCharsets.UTF_8));

        String json = new VosCatalogExporter().exportCatalog(tempDir);

        assertEquals(2, countOccurrences(json, JsonWriter.field("format", "VOS")));
        assertContains(json, JsonWriter.field("title", "First Song"));
        assertContains(json, JsonWriter.field("title", "Second Song"));
    }

    private static void assertContains(String json, String expectedField) {
        assertTrue(json.contains(expectedField), "Expected field " + expectedField + " in " + json);
    }

    private static int countOccurrences(String value, String needle) {
        int count = 0;
        int offset = 0;
        while (true) {
            int found = value.indexOf(needle, offset);
            if (found < 0) {
                return count;
            }
            count++;
            offset = found + needle.length();
        }
    }
}
