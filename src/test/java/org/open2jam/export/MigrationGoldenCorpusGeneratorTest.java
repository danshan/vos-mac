package org.open2jam.export;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.zip.ZipFile;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class MigrationGoldenCorpusGeneratorTest {
    @TempDir
    Path tempDir;

    @Test
    void generatesSourcesExpectedArtifactsAndProvenance() throws Exception {
        Path output = tempDir.resolve("java-migration");
        Path work = tempDir.resolve("open2jam-java-golden-v1");

        MigrationGoldenCorpusGenerator.generate(output, work);

        assertTrue(output.resolve("sources/vos/canon.vos").toFile().isFile());
        assertTrue(output.resolve("sources/ojn/o2jam.ojn").toFile().isFile());
        assertTrue(output.resolve("sources/ojn/o2jam.ojm").toFile().isFile());
        assertTrue(output.resolve("sources/osu/seven-key.osu").toFile().isFile());
        assertTrue(output.resolve("sources/osu/seven-key.osz").toFile().isFile());
        try (ZipFile archive = new ZipFile(output.resolve("sources/osu/seven-key.osz").toFile())) {
            archive.stream().forEach(entry -> assertEquals(0L, entry.getTime()));
        }
        assertTrue(output.resolve("expected/vos/catalog.json").toFile().isFile());
        assertTrue(output.resolve("expected/vos/gameplay.json").toFile().isFile());
        assertTrue(output.resolve("expected/vos/audio-manifest.json").toFile().isFile());
        assertTrue(output.resolve("expected/ojn/catalog.json").toFile().isFile());
        assertTrue(output.resolve("expected/osu/osu-catalog.json").toFile().isFile());
        String renderMetadata = Files.readString(output.resolve("expected/vos/render-metadata.json"));
        assertTrue(renderMetadata.contains("$PROJECT_ROOT/src/resources/"));
        assertFalse(renderMetadata.contains(Path.of("").toRealPath().toString()));
        assertTrue(output.resolve("manifest.json").toFile().isFile());
        assertTrue(output.resolve("manifest.sha256").toFile().isFile());

        String firstHashes = Files.readString(output.resolve("manifest.sha256"));
        MigrationGoldenCorpusGenerator.generate(output, work);
        assertEquals(firstHashes, Files.readString(output.resolve("manifest.sha256")));
    }
}
