package org.open2jam.export;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.security.MessageDigest;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.open2jam.parsers.OjnFixtureFactory;
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

    @Test
    void exportsOsuManiaSevenKeyCatalogEntryFromDirectory() throws Exception {
        File chartFile = writeOsuManiaSevenKeyFixture("seven-key.osu");

        String json = new VosCatalogExporter().exportCatalog(tempDir);

        assertEquals(catalogJson(expectedOsuEntry(chartFile)), json);
    }

    @Test
    void exportsOjnCatalogEntriesForEachDifficulty() throws Exception {
        File chartFile = OjnFixtureFactory.writeFixture(tempDir, "o2jam").chart();

        String json = new VosCatalogExporter().exportCatalog(tempDir);

        assertEquals(catalogJson(
                expectedOjnEntry(chartFile, 0, 3, 10),
                expectedOjnEntry(chartFile, 1, 5, 20),
                expectedOjnEntry(chartFile, 2, 8, 30)), json);
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

    private static String expectedOsuEntry(File source) throws Exception {
        String sourcePath = source.getCanonicalPath();
        return JsonWriter.object(
                JsonWriter.field("id", idFor("osu", sourcePath)),
                JsonWriter.field("format", "OSU"),
                JsonWriter.field("sourcePath", sourcePath),
                JsonWriter.field("title", "Seven Key Fixture"),
                JsonWriter.field("artist", "Fixture Artist"),
                JsonWriter.field("noter", "Fixture Creator"),
                JsonWriter.field("genre", "osu!mania"),
                JsonWriter.field("keys", 7),
                JsonWriter.field("level", 8),
                JsonWriter.field("levelKnown", true),
                JsonWriter.field("bpm", 120.0),
                JsonWriter.field("durationMs", 2000),
                JsonWriter.field("noteCount", 2),
                JsonWriter.field("coverAsset", ""),
                JsonWriter.field("exportStatus", "ready"));
    }

    private static String expectedOjnEntry(File source, int chartIndex, int level, int noteCount) throws Exception {
        String sourcePath = source.getCanonicalPath();
        return JsonWriter.object(
                JsonWriter.field("id", idFor("ojn", sourcePath + "#chart=" + chartIndex)),
                JsonWriter.field("format", "OJN"),
                JsonWriter.field("sourcePath", sourcePath),
                JsonWriter.field("chartIndex", chartIndex),
                JsonWriter.field("title", "O2Jam Fixture"),
                JsonWriter.field("artist", "O2 Artist"),
                JsonWriter.field("noter", "O2 Noter"),
                JsonWriter.field("genre", "Dance"),
                JsonWriter.field("keys", 7),
                JsonWriter.field("level", level),
                JsonWriter.field("levelKnown", true),
                JsonWriter.field("bpm", 130.0),
                JsonWriter.field("durationMs", 91000),
                JsonWriter.field("noteCount", noteCount),
                JsonWriter.field("coverAsset", ""),
                JsonWriter.field("exportStatus", "ready"));
    }

    private static String idFor(String sourcePath) throws Exception {
        return idFor("vos", sourcePath);
    }

    private static String idFor(String prefix, String sourcePath) throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        byte[] hash = digest.digest(sourcePath.getBytes(StandardCharsets.UTF_8));
        StringBuilder id = new StringBuilder(prefix + ":sha256:");
        for (int i = 0; i < 8; i++) {
            id.append(String.format("%02x", hash[i] & 0xFF));
        }
        return id.toString();
    }

    private File writeOsuManiaSevenKeyFixture(String name) throws Exception {
        File chartFile = new File(tempDir, name);
        String content = ""
                + "osu file format v14\n"
                + "\n"
                + "[General]\n"
                + "AudioFilename: audio.ogg\n"
                + "Mode: 3\n"
                + "\n"
                + "[Metadata]\n"
                + "Title:Seven Key Fixture\n"
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
                + "36,192,0,1,0,0:0:0:75:kick.wav\n"
                + "256,192,1000,128,0,2000:0:0:0:65:hold.wav\n";
        Files.write(chartFile.toPath(), content.getBytes(StandardCharsets.UTF_8));
        return chartFile;
    }

}
