package org.open2jam.export;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class MigrationGoldenCorpusTest {
    private static final Path COMMITTED = Path.of("rewrite/golden/java-migration");
    @TempDir
    Path tempDir;

    @Test
    void committedHashesMatchManifest() throws Exception {
        MigrationGoldenCorpusGenerator.verifyCanonicalManifest(
                COMMITTED.resolve("manifest.json"));
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
    void canonicalManifestRejectsMissingChangedDuplicateAndFragmentPreservingBytes()
            throws Exception {
        Path source = COMMITTED.resolve("manifest.json");
        Path missing = tempDir.resolve("missing-manifest.json");
        Path changed = tempDir.resolve("changed-manifest.json");
        Path duplicate = tempDir.resolve("duplicate-manifest.json");
        Path fragmentPreserving = tempDir.resolve("fragment-preserving-manifest.json");
        String canonical = Files.readString(source, StandardCharsets.UTF_8);
        Files.writeString(
                changed,
                canonical.replace("\"schemaVersion\": 4", "\"schemaVersion\": 3"),
                StandardCharsets.UTF_8);
        Files.writeString(
                duplicate,
                canonical.replaceFirst(
                        "\\{", "{\\n  \\\"schemaVersion\\\": 4,"),
                StandardCharsets.UTF_8);
        Files.writeString(fragmentPreserving, canonical + "\n", StandardCharsets.UTF_8);

        assertThrows(Exception.class,
                () -> MigrationGoldenCorpusGenerator.verifyCanonicalManifest(missing));
        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.verifyCanonicalManifest(changed));
        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.verifyCanonicalManifest(duplicate));
        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.verifyCanonicalManifest(fragmentPreserving));
    }

    @Test
    void pinnedJavaReproducesCommittedCorpus() throws Exception {
        Path base = tempDir.toRealPath();
        Path regenerated = base.resolve("regenerated");
        MigrationGoldenCorpusGenerator.generate(regenerated, base.resolve("work"));
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
        Path base = tempDir.toRealPath();
        Path regenerated = base.resolve("regenerated-directory-symlink");
        Path external = base.resolve("external-directory");
        MigrationGoldenCorpusGenerator.generate(regenerated, base.resolve("directory-work"));
        Files.createDirectories(external);
        Files.writeString(external.resolve("same.json"), "{}\n", StandardCharsets.UTF_8);
        Files.createSymbolicLink(regenerated.resolve("linked-directory"), external);

        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.hashManifest(regenerated.toRealPath()));
    }

    @Test
    void regeneratedCorpusHashRejectsSpecialFile() throws Exception {
        Path base = tempDir.toRealPath();
        Path regenerated = base.resolve("regenerated-special-file");
        Path fifo = regenerated.resolve("fifo");
        MigrationGoldenCorpusGenerator.generate(regenerated, base.resolve("special-work"));
        Process process = new ProcessBuilder("mkfifo", fifo.toString()).start();
        assertEquals(0, process.waitFor());

        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.hashManifest(regenerated.toRealPath()));
    }
}
