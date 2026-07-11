package org.open2jam.export;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class MigrationGoldenCorpusTest {
    private static final Path COMMITTED = Path.of("rewrite/golden/java-migration");
    private static final Path WORK = Path.of("/tmp/open2jam-java-golden-v1");

    @TempDir
    Path tempDir;

    @Test
    void committedHashesMatchManifest() throws Exception {
        String manifest = Files.readString(COMMITTED.resolve("manifest.json"), StandardCharsets.UTF_8);
        assertTrue(manifest.contains("\"javaSourceCommit\": \"05257da\""));
        assertTrue(manifest.contains("\"javaTool\": \"zulu-17.66.19.0\""));
        assertFalse(manifest.contains("generatedAt"));
        assertEquals(Files.readString(COMMITTED.resolve("manifest.sha256"), StandardCharsets.UTF_8),
                MigrationGoldenCorpusGenerator.hashManifest(COMMITTED));
    }

    @Test
    void pinnedJavaReproducesCommittedCorpus() throws Exception {
        Path regenerated = tempDir.resolve("regenerated");
        MigrationGoldenCorpusGenerator.generate(regenerated, WORK);
        assertEquals(MigrationGoldenCorpusGenerator.hashManifest(COMMITTED),
                MigrationGoldenCorpusGenerator.hashManifest(regenerated));
    }
}
