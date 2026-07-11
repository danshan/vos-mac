package org.open2jam.export;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class MigrationGoldenCorpusTest {
    private static final Path COMMITTED = Path.of("rewrite/golden/java-migration");
    private static final String ORACLE_TREE_SHA256 =
            "206614ef6d5df3ae2cd5f42ea0b1f0499cd7a3137cfbdf11c5a345fb8ff6978e";
    private static final String ORACLE_FILES_SHA256 =
            "b1e093eaf4dd2a28ae918d29afcccff8d40b7ad60410d1caee5219fcec74feca";

    @TempDir
    Path tempDir;

    @Test
    void committedHashesMatchManifest() throws Exception {
        String manifest = Files.readString(COMMITTED.resolve("manifest.json"), StandardCharsets.UTF_8);
        assertTrue(manifest.contains("\"javaSourceCommit\": \"05257da\""));
        assertTrue(manifest.contains(
                "\"javaDeterminismOverlayCommit\": \"62ece7083ea473f02ecc9a83ee7d3e151905bf0e\""));
        assertTrue(manifest.contains(
                "\"javaDeterminismOverlayPurpose\": \"deterministic Liberation Sans font and provenance\""));
        assertTrue(manifest.contains("\"javaTool\": \"zulu-17.66.19.0\""));
        assertTrue(manifest.contains(
                "\"javaOraclePaths\": [\"src/org/open2jam\", \"parsers/src\", \"src/resources\"]"));
        assertTrue(manifest.contains("\"javaOracleTreeFile\": \"oracle-tree.txt\""));
        assertTrue(manifest.contains("\"javaOracleTreeSha256\": \"" + ORACLE_TREE_SHA256 + "\""));
        assertTrue(manifest.contains(
                "\"javaOracleFilesystemManifestFile\": \"oracle-files.sha256\""));
        assertTrue(manifest.contains(
                "\"javaOracleFilesystemManifestSha256\": \"" + ORACLE_FILES_SHA256 + "\""));
        assertTrue(manifest.contains("\"canonicalWorkRoot\": \"/private/tmp/open2jam-java-golden-v1\""));
        assertFalse(manifest.contains("generatedAt"));
        assertTrue(Files.readString(COMMITTED.resolve("oracle-tree.txt"), StandardCharsets.UTF_8)
                .contains("src/org/open2jam/export/VosRenderMetadataExporter.java"));
        assertTrue(Files.readString(COMMITTED.resolve("oracle-files.sha256"), StandardCharsets.UTF_8)
                .contains("src/org/open2jam/export/VosRenderMetadataExporter.java"));
        assertEquals(Files.readString(COMMITTED.resolve("manifest.files"), StandardCharsets.UTF_8),
                MigrationGoldenCorpusGenerator.fileTypeManifest(COMMITTED));
        assertEquals(Files.readString(COMMITTED.resolve("manifest.sha256"), StandardCharsets.UTF_8),
                MigrationGoldenCorpusGenerator.hashManifest(COMMITTED));
    }

    @Test
    void pinnedJavaReproducesCommittedCorpus() throws Exception {
        Path regenerated = tempDir.resolve("regenerated");
        MigrationGoldenCorpusGenerator.generate(regenerated, tempDir.resolve("work"));
        assertEquals(MigrationGoldenCorpusGenerator.hashManifest(COMMITTED),
                MigrationGoldenCorpusGenerator.hashManifest(regenerated.toRealPath()));
    }

    @Test
    void committedCorpusHashRejectsSameByteSymlinkReplacement() throws Exception {
        Path base = tempDir.toRealPath();
        Path candidate = base.resolve("committed-symlink");
        Path sameBytes = base.resolve("same-readme.md");
        MigrationGoldenCorpusGenerator.copyTree(COMMITTED, candidate);
        Files.copy(candidate.resolve("README.md"), sameBytes);
        Files.delete(candidate.resolve("README.md"));
        Files.createSymbolicLink(candidate.resolve("README.md"), sameBytes);

        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.hashManifest(candidate));
    }

    @Test
    void regeneratedCorpusHashRejectsDirectorySymlink() throws Exception {
        Path regenerated = tempDir.resolve("regenerated-directory-symlink");
        Path external = tempDir.resolve("external-directory");
        MigrationGoldenCorpusGenerator.generate(regenerated, tempDir.resolve("directory-work"));
        Files.createDirectories(external);
        Files.writeString(external.resolve("same.json"), "{}\n", StandardCharsets.UTF_8);
        Files.createSymbolicLink(regenerated.resolve("linked-directory"), external);

        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.hashManifest(regenerated.toRealPath()));
    }

    @Test
    void regeneratedCorpusHashRejectsSpecialFile() throws Exception {
        Path regenerated = tempDir.resolve("regenerated-special-file");
        Path fifo = regenerated.resolve("fifo");
        MigrationGoldenCorpusGenerator.generate(regenerated, tempDir.resolve("special-work"));
        Process process = new ProcessBuilder("mkfifo", fifo.toString()).start();
        assertEquals(0, process.waitFor());

        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.hashManifest(regenerated.toRealPath()));
    }
}
