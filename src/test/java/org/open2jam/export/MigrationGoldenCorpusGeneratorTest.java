package org.open2jam.export;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
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
        assertTrue(output.resolve("manifest.files").toFile().isFile());
        assertTrue(output.resolve("manifest.sha256").toFile().isFile());
        assertEquals(Files.readString(output.resolve("manifest.files")),
                MigrationGoldenCorpusGenerator.fileTypeManifest(output.toRealPath()));

        String firstHashes = Files.readString(output.resolve("manifest.sha256"));
        String firstTypes = Files.readString(output.resolve("manifest.files"));
        MigrationGoldenCorpusGenerator.generate(output, work);
        assertEquals(firstHashes, Files.readString(output.resolve("manifest.sha256")));
        assertEquals(firstTypes, Files.readString(output.resolve("manifest.files")));
    }

    @Test
    void rejectsSameByteFileSymlinkFromHashManifest() throws Exception {
        Path base = tempDir.toRealPath();
        Path root = base.resolve("symlink-corpus");
        Path target = base.resolve("target.json");
        Files.createDirectories(root);
        Files.writeString(target, "same bytes\n");
        Files.createSymbolicLink(root.resolve("data.json"), target);

        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.hashManifest(root));
    }

    @Test
    void rejectsDirectorySymlinkFromFileTypeManifest() throws Exception {
        Path base = tempDir.toRealPath();
        Path root = base.resolve("directory-symlink-corpus");
        Path target = base.resolve("linked-directory");
        Files.createDirectories(root);
        Files.createDirectories(target);
        Files.writeString(target.resolve("data.json"), "same bytes\n");
        Files.createSymbolicLink(root.resolve("expected"), target);

        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.fileTypeManifest(root));
    }

    @Test
    void hashAndFileTypeRejectSymlinkedRootAncestor() throws Exception {
        Path base = tempDir.toRealPath();
        Path realRoot = base.resolve("real-corpus-root");
        Path corpus = realRoot.resolve("corpus");
        Path alias = base.resolve("corpus-alias");
        Files.createDirectories(corpus);
        Files.writeString(corpus.resolve("data.txt"), "data\n");
        Files.writeString(corpus.resolve("manifest.files"), "");
        Files.writeString(corpus.resolve("manifest.files"),
                MigrationGoldenCorpusGenerator.fileTypeManifest(corpus));
        Files.createSymbolicLink(alias, realRoot);
        Path aliasedCorpus = alias.resolve("corpus");

        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.fileTypeManifest(aliasedCorpus));
        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.hashManifest(aliasedCorpus));
    }

    @Test
    void rejectsSpecialFileFromFileTypeManifest() throws Exception {
        Path root = tempDir.toRealPath().resolve("special-file-corpus");
        Path fifo = root.resolve("fifo");
        Files.createDirectories(root);

        Process process = new ProcessBuilder("mkfifo", fifo.toString()).start();
        assertEquals(0, process.waitFor());
        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.fileTypeManifest(root));
    }

    @Test
    void copyTreeRejectsFileAndDirectorySymlinksBeforeWriting() throws Exception {
        Path base = tempDir.toRealPath();
        Path source = base.resolve("copy-source");
        Path target = base.resolve("copy-target");
        Path external = base.resolve("external");
        Files.createDirectories(source.resolve("real-directory"));
        Files.createDirectories(external);
        Files.writeString(source.resolve("regular.txt"), "regular\n");
        Files.writeString(external.resolve("same.txt"), "same bytes\n");
        Files.createSymbolicLink(source.resolve("linked-file.txt"), external.resolve("same.txt"));
        Files.createSymbolicLink(source.resolve("linked-directory"), external);

        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.copyTree(source, target));
        assertFalse(Files.exists(target));
    }

    @Test
    void copyTreeRejectsSymlinkInExistingTargetAncestry() throws Exception {
        Path base = tempDir.toRealPath();
        Path source = base.resolve("target-link-source");
        Path realTarget = base.resolve("real-target");
        Path linkedTarget = base.resolve("linked-target");
        Path sentinel = realTarget.resolve("child/sentinel.txt");
        Files.createDirectories(source);
        Files.writeString(source.resolve("copied.txt"), "copy\n");
        Files.createDirectories(sentinel.getParent());
        Files.writeString(sentinel, "keep\n");
        Files.createSymbolicLink(linkedTarget, realTarget);

        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.copyTree(source, linkedTarget.resolve("child")));
        assertEquals("keep\n", Files.readString(sentinel));
        assertFalse(Files.exists(realTarget.resolve("child/copied.txt")));
    }

    @Test
    void copyTreeRejectsSymlinkInSourceAncestry() throws Exception {
        Path base = tempDir.toRealPath();
        Path realSource = base.resolve("real-source");
        Path linkedSource = base.resolve("linked-source");
        Path target = base.resolve("source-link-target");
        Files.createDirectories(realSource.resolve("child"));
        Files.writeString(realSource.resolve("child/data.txt"), "data\n");
        Files.createSymbolicLink(linkedSource, realSource);

        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.copyTree(
                        linkedSource.resolve("child"), target));
        assertFalse(Files.exists(target));
    }

    @Test
    void rejectsOverlappingRootsBeforeDeletingSentinels() throws Exception {
        Path output = tempDir.resolve("overlap");
        Path work = output.resolve("work");
        Path sentinel = output.resolve("sentinel.txt");
        Files.createDirectories(work);
        Files.writeString(sentinel, "keep\n");

        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.generate(output, work));
        assertEquals("keep\n", Files.readString(sentinel));
    }

    @Test
    void rejectsEqualRootsBeforeDeletingSentinels() throws Exception {
        Path root = tempDir.resolve("equal");
        Path sentinel = root.resolve("sentinel.txt");
        Files.createDirectories(root);
        Files.writeString(sentinel, "keep\n");

        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.generate(root, root));
        assertEquals("keep\n", Files.readString(sentinel));
    }

    @Test
    void resetDirectoryRejectsSymlinkedAncestorBeforeDeletingSentinel() throws Exception {
        Path base = tempDir.toRealPath();
        Path realRoot = base.resolve("real-reset-root");
        Path resetRoot = realRoot.resolve("reset");
        Path alias = base.resolve("reset-alias");
        Path sentinel = resetRoot.resolve("sentinel.txt");
        Files.createDirectories(resetRoot);
        Files.writeString(sentinel, "keep\n");
        Files.createSymbolicLink(alias, realRoot);

        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.resetDirectory(alias.resolve("reset")));
        assertEquals("keep\n", Files.readString(sentinel));
    }

    @Test
    void rejectsExistingSymlinkComponentBeforeMutation() throws Exception {
        Path realOutput = tempDir.resolve("real-output");
        Path linkedOutput = tempDir.resolve("linked-output");
        Path sentinel = realOutput.resolve("sentinel.txt");
        Files.createDirectories(realOutput);
        Files.writeString(sentinel, "keep\n");
        Files.createSymbolicLink(linkedOutput, realOutput);

        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.generate(
                        linkedOutput.resolve("java-migration"), tempDir.resolve("work")));
        assertTrue(Files.isSymbolicLink(linkedOutput));
        assertEquals("keep\n", Files.readString(sentinel));
    }

    @Test
    void programmaticValidationRejectsRootProjectRelativeAndNonTempPaths() throws Exception {
        Path projectRoot = Path.of("").toRealPath();
        Path safeOutput = tempDir.resolve("safe-output");
        Path safeWork = tempDir.resolve("safe-work");
        Path sentinel = tempDir.resolve("programmatic-sentinel.txt");
        Files.writeString(sentinel, "keep\n");

        MigrationGoldenCorpusGenerator.validateProgrammaticPaths(safeOutput, safeWork);
        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.validateProgrammaticPaths(Path.of("/"), safeWork));
        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.validateProgrammaticPaths(projectRoot, safeWork));
        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.validateProgrammaticPaths(
                        Path.of("relative-output"), safeWork));
        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.validateProgrammaticPaths(
                        Path.of(System.getProperty("user.home"), "open2jam-unsafe-output"), safeWork));
        assertEquals("keep\n", Files.readString(sentinel));
    }

    @Test
    void ignoresForgedJavaIoTmpdirWhenItDivergesFromProcessEnvironment() throws Exception {
        String originalTmpdir = System.getProperty("java.io.tmpdir");
        Path forgedRoot = Path.of(System.getProperty("user.home")).toAbsolutePath().normalize();
        Path safeWork = tempDir.resolve("forged-property-safe-work");
        Path sentinel = tempDir.resolve("forged-property-sentinel.txt");
        Files.writeString(sentinel, "keep\n");

        try {
            System.setProperty("java.io.tmpdir", forgedRoot.toString());
            assertThrows(IllegalArgumentException.class,
                    () -> MigrationGoldenCorpusGenerator.validateProgrammaticPaths(
                            forgedRoot.resolve("open2jam-forged-output"), safeWork));
            assertEquals("keep\n", Files.readString(sentinel));
        } finally {
            if (originalTmpdir == null) {
                System.clearProperty("java.io.tmpdir");
            } else {
                System.setProperty("java.io.tmpdir", originalTmpdir);
            }
        }
    }

    @Test
    void cliValidationAcceptsOnlyExactCorpusOutputAndControlledTempWork() throws Exception {
        Path projectRoot = Path.of("").toRealPath();
        String corpusOutput = "rewrite/golden/java-migration";
        String tempWork = tempDir.resolve("cli-work").toString();
        Path sentinel = tempDir.resolve("cli-sentinel.txt");
        Files.writeString(sentinel, "keep\n");

        MigrationGoldenCorpusGenerator.validateCliPaths(
                projectRoot, corpusOutput, tempWork);
        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.validateCliPaths(
                        projectRoot, "", tempWork));
        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.validateCliPaths(
                        projectRoot, "/", tempWork));
        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.validateCliPaths(
                        projectRoot, ".", tempWork));
        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.validateCliPaths(
                        projectRoot, tempWork, corpusOutput));
        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.validateCliPaths(
                        projectRoot, corpusOutput, "relative-work"));
        assertEquals("keep\n", Files.readString(sentinel));
    }

    @Test
    void fileTypeManifestPinsOnlyRegularFilesAndDirectoriesInStableOrder() throws Exception {
        Path root = tempDir.toRealPath().resolve("typed-corpus");
        Files.createDirectories(root.resolve("b"));
        Files.createDirectories(root.resolve("a"));
        Files.writeString(root.resolve("b/two.txt"), "two\n");
        Files.writeString(root.resolve("a/one.txt"), "one\n");
        Files.writeString(root.resolve("manifest.files"), "");

        String manifest = MigrationGoldenCorpusGenerator.fileTypeManifest(root);

        assertEquals("directory  a/\n"
                + "regular  a/one.txt\n"
                + "directory  b/\n"
                + "regular  b/two.txt\n"
                + "regular  manifest.files\n", manifest);
    }
}
