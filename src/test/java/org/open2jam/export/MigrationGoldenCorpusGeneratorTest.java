package org.open2jam.export;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.nio.file.FileAlreadyExistsException;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.nio.file.StandardOpenOption;
import java.nio.file.attribute.BasicFileAttributes;
import java.nio.file.attribute.FileTime;
import java.util.Comparator;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.zip.ZipFile;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class MigrationGoldenCorpusGeneratorTest {
    @TempDir
    Path tempDir;

    @Test
    void generatesSourcesExpectedArtifactsAndProvenance() throws Exception {
        Path base = tempDir.toRealPath();
        Path output = base.resolve("java-migration");
        Path work = base.resolve("open2jam-java-golden-v1");

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
    void rejectsSameByteSymlinkReplacementDuringHashing() throws Exception {
        Path base = tempDir.toRealPath();
        Path root = base.resolve("racing-hash-corpus");
        Path target = root.resolve("z-target.txt");
        Path external = base.resolve("same-bytes.txt");
        Files.createDirectories(root);
        Files.writeString(target, "same bytes\n");
        Files.writeString(external, "same bytes\n");
        writeFileTypeManifest(root);

        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.hashManifest(
                        root,
                        new MigrationGoldenCorpusGenerator.TreeOperationObserver() {
                            @Override
                            public void beforeFileRead(String operation, Path relativePath)
                                    throws Exception {
                                if ("hash".equals(operation)
                                        && relativePath.equals(Path.of("z-target.txt"))) {
                                    Files.delete(target);
                                    Files.createSymbolicLink(target, external);
                                }
                            }
                        }));
        assertTrue(Files.isSymbolicLink(target));
        assertEquals("same bytes\n", Files.readString(external));
    }

    @Test
    void hashManifestRejectsEntryAddedAfterSnapshot() throws Exception {
        Path root = tempDir.toRealPath().resolve("hash-add-corpus");
        Files.createDirectories(root);
        Files.writeString(root.resolve("data.txt"), "data\n");
        writeFileTypeManifest(root);

        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.hashManifest(
                        root,
                        new MigrationGoldenCorpusGenerator.TreeOperationObserver() {
                            @Override
                            public void afterInitialSnapshot(String operation, Path snapshotRoot)
                                    throws Exception {
                                Files.writeString(snapshotRoot.resolve("z-added.txt"), "added\n");
                            }
                        }));
        assertEquals("added\n", Files.readString(root.resolve("z-added.txt")));
    }

    @Test
    void hashManifestRejectsEntryRemovedAfterHashing() throws Exception {
        Path root = tempDir.toRealPath().resolve("hash-remove-corpus");
        Path data = root.resolve("data.txt");
        Files.createDirectories(root);
        Files.writeString(data, "data\n");
        writeFileTypeManifest(root);

        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.hashManifest(
                        root,
                        new MigrationGoldenCorpusGenerator.TreeOperationObserver() {
                            @Override
                            public void beforeFinalSnapshot(String operation, Path snapshotRoot)
                                    throws Exception {
                                Files.delete(data);
                            }
                        }));
        assertFalse(Files.exists(data));
    }

    @Test
    void hashManifestRejectsSameLengthContentChangeWithRestoredMtimeAfterHashing()
            throws Exception {
        Path root = tempDir.toRealPath().resolve("hash-content-corpus");
        Path data = root.resolve("data.txt");
        Files.createDirectories(root);
        Files.writeString(data, "good\n");
        writeFileTypeManifest(root);
        Object originalFileKey = Files.readAttributes(
                data, BasicFileAttributes.class, LinkOption.NOFOLLOW_LINKS).fileKey();
        long originalSize = Files.size(data);
        FileTime originalMtime = Files.getLastModifiedTime(data, LinkOption.NOFOLLOW_LINKS);

        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.hashManifest(
                        root,
                        new MigrationGoldenCorpusGenerator.TreeOperationObserver() {
                            @Override
                            public void beforeFinalSnapshot(String operation, Path snapshotRoot)
                                    throws Exception {
                                if ("hash".equals(operation)) {
                                    Files.writeString(
                                            data,
                                            "evil\n",
                                            StandardOpenOption.WRITE,
                                            StandardOpenOption.TRUNCATE_EXISTING);
                                    Files.setLastModifiedTime(data, originalMtime);
                                }
                            }
                        }));
        assertEquals("evil\n", Files.readString(data));
        assertEquals(originalFileKey, Files.readAttributes(
                data, BasicFileAttributes.class, LinkOption.NOFOLLOW_LINKS).fileKey());
        assertEquals(originalSize, Files.size(data));
        assertEquals(originalMtime, Files.getLastModifiedTime(data, LinkOption.NOFOLLOW_LINKS));
    }

    @Test
    void fileTypeManifestRejectsEntryAddedAfterSnapshot() throws Exception {
        Path root = tempDir.toRealPath().resolve("type-add-corpus");
        Files.createDirectories(root);
        Files.writeString(root.resolve("data.txt"), "data\n");

        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.fileTypeManifest(
                        root,
                        new MigrationGoldenCorpusGenerator.TreeOperationObserver() {
                            @Override
                            public void beforeFinalSnapshot(String operation, Path snapshotRoot)
                                    throws Exception {
                                Files.writeString(snapshotRoot.resolve("z-added.txt"), "added\n");
                            }
                        }));
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
    void copyTreeNeverTruncatesExistingHardLinkedDestination() throws Exception {
        Path base = tempDir.toRealPath();
        Path source = base.resolve("copy-hard-link-source");
        Path target = base.resolve("copy-hard-link-target");
        Path externalSentinel = base.resolve("copy-hard-link-sentinel.txt");
        Files.createDirectories(source);
        Files.createDirectories(target);
        Files.writeString(source.resolve("data.txt"), "replacement\n");
        Files.writeString(externalSentinel, "keep outside\n");
        Files.createLink(target.resolve("data.txt"), externalSentinel);

        assertThrows(FileAlreadyExistsException.class,
                () -> MigrationGoldenCorpusGenerator.copyTree(source, target));
        assertEquals("keep outside\n", Files.readString(externalSentinel));
        assertEquals("keep outside\n", Files.readString(target.resolve("data.txt")));
    }

    @Test
    void generationCopyFailurePreservesExistingCorpusAndCleansPublicationDebris()
            throws Exception {
        Path base = tempDir.toRealPath();
        Path output = base.resolve("transaction-copy-output");
        Path work = base.resolve("transaction-copy-work");
        MigrationGoldenCorpusGenerator.copyTree(
                Path.of("rewrite/golden/java-migration"), output);
        String expectedHashes = Files.readString(output.resolve("manifest.sha256"));
        String expectedTypes = Files.readString(output.resolve("manifest.files"));
        AtomicInteger copiedFiles = new AtomicInteger();

        assertThrows(IOException.class,
                () -> MigrationGoldenCorpusGenerator.generate(
                        output,
                        work,
                        new MigrationGoldenCorpusGenerator.GenerationObserver() {
                            @Override
                            public void beforeFileRead(String operation, Path relativePath)
                                    throws Exception {
                                if ("publication-copy".equals(operation)
                                        && copiedFiles.incrementAndGet() == 2) {
                                    throw new IOException("deterministic publication copy failure");
                                }
                            }
                        }));

        assertCorpusUnchanged(output, expectedHashes, expectedTypes);
        assertNoPublicationDebris(output);
    }

    @Test
    void generationPublishFailureRestoresExistingCorpusAndCleansPublicationDebris()
            throws Exception {
        Path base = tempDir.toRealPath();
        Path output = base.resolve("transaction-publish-output");
        Path work = base.resolve("transaction-publish-work");
        MigrationGoldenCorpusGenerator.copyTree(
                Path.of("rewrite/golden/java-migration"), output);
        String expectedHashes = Files.readString(output.resolve("manifest.sha256"));
        String expectedTypes = Files.readString(output.resolve("manifest.files"));

        assertThrows(IOException.class,
                () -> MigrationGoldenCorpusGenerator.generate(
                        output,
                        work,
                        new MigrationGoldenCorpusGenerator.GenerationObserver() {
                            @Override
                            public void afterOutputBackedUp(Path backup, Path destination)
                                    throws Exception {
                                throw new IOException("deterministic publication failure");
                            }
                        }));

        assertCorpusUnchanged(output, expectedHashes, expectedTypes);
        assertNoPublicationDebris(output);
    }

    @Test
    void copyTreeRejectsSameByteSymlinkReplacementBeforeRead() throws Exception {
        Path base = tempDir.toRealPath();
        Path source = base.resolve("copy-race-replace-source");
        Path target = base.resolve("copy-race-replace-target");
        Path sourceFile = source.resolve("z-target.txt");
        Path external = base.resolve("copy-race-same-bytes.txt");
        Files.createDirectories(source);
        Files.writeString(sourceFile, "same bytes\n");
        Files.writeString(external, "same bytes\n");

        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.copyTree(
                        source,
                        target,
                        new MigrationGoldenCorpusGenerator.TreeOperationObserver() {
                            @Override
                            public void beforeFileRead(String operation, Path relativePath)
                                    throws Exception {
                                Files.delete(sourceFile);
                                Files.createSymbolicLink(sourceFile, external);
                            }
                        }));
        assertTrue(Files.isSymbolicLink(sourceFile));
        assertEquals("same bytes\n", Files.readString(external));
    }

    @Test
    void copyTreeRejectsSameInodeSourceContentReplacementBeforeRead() throws Exception {
        Path base = tempDir.toRealPath();
        Path source = base.resolve("copy-race-source-content-source");
        Path target = base.resolve("copy-race-source-content-target");
        Path sourceFile = source.resolve("data.txt");
        Files.createDirectories(source);
        Files.writeString(sourceFile, "good\n");

        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.copyTree(
                        source,
                        target,
                        new MigrationGoldenCorpusGenerator.TreeOperationObserver() {
                            @Override
                            public void beforeFileRead(String operation, Path relativePath)
                                    throws Exception {
                                FileTime originalMtime = Files.getLastModifiedTime(
                                        sourceFile, LinkOption.NOFOLLOW_LINKS);
                                Files.writeString(
                                        sourceFile,
                                        "evil\n",
                                        StandardOpenOption.WRITE,
                                        StandardOpenOption.TRUNCATE_EXISTING);
                                Files.setLastModifiedTime(sourceFile, originalMtime);
                            }
                        }));
        assertEquals("evil\n", Files.readString(sourceFile));
        assertEquals("evil\n", Files.readString(target.resolve("data.txt")));
    }

    @Test
    void copyTreeRejectsSourceEntryAddedAfterSnapshot() throws Exception {
        Path base = tempDir.toRealPath();
        Path source = base.resolve("copy-race-add-source");
        Path target = base.resolve("copy-race-add-target");
        Files.createDirectories(source);
        Files.writeString(source.resolve("data.txt"), "data\n");

        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.copyTree(
                        source,
                        target,
                        new MigrationGoldenCorpusGenerator.TreeOperationObserver() {
                            @Override
                            public void afterInitialSnapshot(String operation, Path snapshotRoot)
                                    throws Exception {
                                Files.writeString(snapshotRoot.resolve("z-added.txt"), "added\n");
                            }
                        }));
        assertEquals("added\n", Files.readString(source.resolve("z-added.txt")));
        assertFalse(Files.exists(target.resolve("z-added.txt")));
    }

    @Test
    void copyTreeRejectsSourceEntryRemovedBeforeFinalSnapshot() throws Exception {
        Path base = tempDir.toRealPath();
        Path source = base.resolve("copy-race-remove-source");
        Path target = base.resolve("copy-race-remove-target");
        Path sourceFile = source.resolve("data.txt");
        Files.createDirectories(source);
        Files.writeString(sourceFile, "data\n");

        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.copyTree(
                        source,
                        target,
                        new MigrationGoldenCorpusGenerator.TreeOperationObserver() {
                            @Override
                            public void beforeFinalSnapshot(String operation, Path snapshotRoot)
                                    throws Exception {
                                Files.delete(sourceFile);
                            }
                        }));
        assertFalse(Files.exists(sourceFile));
        assertEquals("data\n", Files.readString(target.resolve("data.txt")));
    }

    @Test
    void copyTreeRejectsTargetEntryAddedDuringCopy() throws Exception {
        Path base = tempDir.toRealPath();
        Path source = base.resolve("copy-race-target-add-source");
        Path target = base.resolve("copy-race-target-add-target");
        Files.createDirectories(source);
        Files.writeString(source.resolve("data.txt"), "data\n");

        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.copyTree(
                        source,
                        target,
                        new MigrationGoldenCorpusGenerator.TreeOperationObserver() {
                            @Override
                            public void beforeFinalSnapshot(String operation, Path snapshotRoot)
                                    throws Exception {
                                Files.writeString(target.resolve("z-unexpected.txt"), "unexpected\n");
                            }
                        }));
        assertEquals("unexpected\n", Files.readString(target.resolve("z-unexpected.txt")));
    }

    @Test
    void copyTreeRejectsSameLengthTargetContentReplacementBeforeFinalSnapshot()
            throws Exception {
        Path base = tempDir.toRealPath();
        Path source = base.resolve("copy-race-target-content-source");
        Path target = base.resolve("copy-race-target-content-target");
        Path targetFile = target.resolve("data.txt");
        Path sentinel = base.resolve("copy-race-target-content-sentinel.txt");
        Files.createDirectories(source);
        Files.writeString(source.resolve("data.txt"), "data\n");
        Files.writeString(sentinel, "keep\n");

        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.copyTree(
                        source,
                        target,
                        new MigrationGoldenCorpusGenerator.TreeOperationObserver() {
                            @Override
                            public void beforeFinalSnapshot(String operation, Path snapshotRoot)
                                    throws Exception {
                                FileTime originalMtime = Files.getLastModifiedTime(
                                        targetFile, LinkOption.NOFOLLOW_LINKS);
                                Files.writeString(
                                        targetFile,
                                        "evil\n",
                                        StandardOpenOption.WRITE,
                                        StandardOpenOption.TRUNCATE_EXISTING);
                                Files.setLastModifiedTime(targetFile, originalMtime);
                            }
                        }));
        assertEquals("evil\n", Files.readString(targetFile));
        assertEquals("keep\n", Files.readString(sentinel));
    }

    @Test
    void copyTreeRejectsSameByteTargetInodeReplacementBeforeFinalSnapshot()
            throws Exception {
        Path base = tempDir.toRealPath();
        Path source = base.resolve("copy-race-target-inode-source");
        Path target = base.resolve("copy-race-target-inode-target");
        Path targetFile = target.resolve("data.txt");
        Path replacement = base.resolve("copy-race-target-inode-replacement.txt");
        Path sentinel = base.resolve("copy-race-target-inode-sentinel.txt");
        Files.createDirectories(source);
        Files.writeString(source.resolve("data.txt"), "same bytes\n");
        Files.writeString(replacement, "same bytes\n");
        Files.writeString(sentinel, "keep\n");

        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.copyTree(
                        source,
                        target,
                        new MigrationGoldenCorpusGenerator.TreeOperationObserver() {
                            @Override
                            public void beforeFinalSnapshot(String operation, Path snapshotRoot)
                                    throws Exception {
                                Files.move(
                                        replacement,
                                        targetFile,
                                        StandardCopyOption.REPLACE_EXISTING);
                            }
                        }));
        assertEquals("same bytes\n", Files.readString(targetFile));
        assertFalse(Files.exists(replacement));
        assertEquals("keep\n", Files.readString(sentinel));
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
        Path output = tempDir.toRealPath().resolve("overlap");
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
        Path root = tempDir.toRealPath().resolve("equal");
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
        Path base = tempDir.toRealPath();
        Path realOutput = base.resolve("real-output");
        Path linkedOutput = base.resolve("linked-output");
        Path sentinel = realOutput.resolve("sentinel.txt");
        Files.createDirectories(realOutput);
        Files.writeString(sentinel, "keep\n");
        Files.createSymbolicLink(linkedOutput, realOutput);

        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.generate(
                        linkedOutput.resolve("java-migration"), base.resolve("work")));
        assertTrue(Files.isSymbolicLink(linkedOutput));
        assertEquals("keep\n", Files.readString(sentinel));
    }

    @Test
    void programmaticValidationRejectsRootProjectRelativeAndNonTempPaths() throws Exception {
        Path projectRoot = Path.of("").toRealPath();
        Path base = tempDir.toRealPath();
        Path safeOutput = base.resolve("safe-output");
        Path safeWork = base.resolve("safe-work");
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
    void programmaticGenerationRejectsTmpAliasedOutputBeforeMutation() throws Exception {
        Path lexicalRoot = Files.createTempDirectory(
                Path.of("/tmp"), "open2jam-programmatic-output-alias-");
        Path physicalRoot = lexicalRoot.toRealPath();
        Path physicalOutput = physicalRoot.resolve("output");
        Path physicalWork = physicalRoot.resolve("work");
        Path sentinel = physicalOutput.resolve("sentinel.txt");
        try {
            assertFalse(lexicalRoot.equals(physicalRoot),
                    "The macOS /tmp alias must resolve to a different physical path");
            Files.createDirectories(physicalOutput);
            Files.writeString(sentinel, "keep\n");

            assertThrows(IllegalArgumentException.class,
                    () -> MigrationGoldenCorpusGenerator.generate(
                            lexicalRoot.resolve("output"), physicalWork));
            assertEquals("keep\n", Files.readString(sentinel));
            assertFalse(Files.exists(physicalWork));
        } finally {
            deleteTestTree(physicalRoot);
        }
    }

    @Test
    void programmaticGenerationRejectsTmpAliasedWorkBeforeMutation() throws Exception {
        Path lexicalRoot = Files.createTempDirectory(
                Path.of("/tmp"), "open2jam-programmatic-work-alias-");
        Path physicalRoot = lexicalRoot.toRealPath();
        Path physicalOutput = physicalRoot.resolve("output");
        Path physicalWork = physicalRoot.resolve("work");
        Path sentinel = physicalWork.resolve("sentinel.txt");
        try {
            assertFalse(lexicalRoot.equals(physicalRoot),
                    "The macOS /tmp alias must resolve to a different physical path");
            Files.createDirectories(physicalWork);
            Files.writeString(sentinel, "keep\n");

            assertThrows(IllegalArgumentException.class,
                    () -> MigrationGoldenCorpusGenerator.generate(
                            physicalOutput, lexicalRoot.resolve("work")));
            assertEquals("keep\n", Files.readString(sentinel));
            assertFalse(Files.exists(physicalOutput));
        } finally {
            deleteTestTree(physicalRoot);
        }
    }

    @Test
    void ignoresForgedJavaIoTmpdirWhenItDivergesFromProcessEnvironment() throws Exception {
        String originalTmpdir = System.getProperty("java.io.tmpdir");
        Path forgedRoot = Path.of(System.getProperty("user.home")).toAbsolutePath().normalize();
        Path safeWork = tempDir.toRealPath().resolve("forged-property-safe-work");
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
        String tempWork = "/tmp/open2jam-java-golden-v1";
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
    void cliValidationAcceptsOnlyThePinnedWorkRootIncludingItsTmpAlias() throws Exception {
        Path projectRoot = Path.of("").toRealPath();
        String corpusOutput = "rewrite/golden/java-migration";

        MigrationGoldenCorpusGenerator.GenerationPaths paths =
                MigrationGoldenCorpusGenerator.validateCliPaths(
                        projectRoot, corpusOutput, "/tmp/open2jam-java-golden-v1");

        assertEquals(Path.of("/private/tmp/open2jam-java-golden-v1"), paths.workRoot());
        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.validateCliPaths(
                        projectRoot, corpusOutput, "/tmp/open2jam-other-work"));
        assertThrows(IllegalArgumentException.class,
                () -> MigrationGoldenCorpusGenerator.validateCliPaths(
                        projectRoot, corpusOutput, "/private/tmp/open2jam-other-work"));
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

    private static void writeFileTypeManifest(Path root) throws Exception {
        Files.writeString(root.resolve("manifest.files"), "");
        Files.writeString(root.resolve("manifest.files"),
                MigrationGoldenCorpusGenerator.fileTypeManifest(root));
    }

    private static void assertNoPublicationDebris(Path output) throws Exception {
        String stagingPrefix = "." + output.getFileName() + ".staging-";
        String backupPrefix = "." + output.getFileName() + ".backup-";
        try (var siblings = Files.list(output.getParent())) {
            assertFalse(siblings.anyMatch(path -> {
                String name = path.getFileName().toString();
                return name.startsWith(stagingPrefix) || name.startsWith(backupPrefix);
            }));
        }
    }

    private static void assertCorpusUnchanged(
            Path output, String expectedHashes, String expectedTypes) throws Exception {
        assertEquals(expectedHashes, Files.readString(output.resolve("manifest.sha256")));
        assertEquals(expectedTypes, Files.readString(output.resolve("manifest.files")));
        assertEquals(expectedHashes, MigrationGoldenCorpusGenerator.hashManifest(output));
        assertEquals(expectedTypes, MigrationGoldenCorpusGenerator.fileTypeManifest(output));
    }

    private static void deleteTestTree(Path root) throws Exception {
        if (!Files.exists(root)) {
            return;
        }
        try (var paths = Files.walk(root)) {
            for (Path path : paths.sorted(Comparator.reverseOrder()).toList()) {
                Files.delete(path);
            }
        }
    }
}
