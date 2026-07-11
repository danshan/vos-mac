package org.open2jam.export;

import java.io.File;
import java.io.ByteArrayOutputStream;
import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.FileAlreadyExistsException;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.nio.file.attribute.BasicFileAttributes;
import java.nio.file.attribute.FileTime;
import java.nio.file.attribute.PosixFilePermission;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Stream;
import org.open2jam.parsers.OjnFixtureFactory;
import org.open2jam.parsers.OsuFixtureFactory;
import org.open2jam.parsers.VosFixtureFactory;

public final class MigrationGoldenCorpusGenerator {
    public static final String JAVA_SOURCE_COMMIT = "05257da";
    public static final String JAVA_DETERMINISM_OVERLAY_COMMIT =
            "62ece7083ea473f02ecc9a83ee7d3e151905bf0e";
    public static final String JAVA_DETERMINISM_OVERLAY_PURPOSE =
            "deterministic Liberation Sans font and provenance";
    public static final String JAVA_TOOL = "zulu-17.66.19.0";
    public static final String JAVA_ORACLE_TREE_SHA256 =
            "206614ef6d5df3ae2cd5f42ea0b1f0499cd7a3137cfbdf11c5a345fb8ff6978e";
    public static final String JAVA_ORACLE_FILES_SHA256 =
            "b1e093eaf4dd2a28ae918d29afcccff8d40b7ad60410d1caee5219fcec74feca";

    private static final String CANONICAL_WORK_ROOT = "/private/tmp/open2jam-java-golden-v1";
    private static final Path CORPUS_RELATIVE_PATH = Path.of("rewrite/golden/java-migration");
    private static final String FILE_TYPE_MANIFEST = "manifest.files";
    private static final String HASH_MANIFEST = "manifest.sha256";
    private static final List<String> JAVA_ORACLE_PATHS =
            List.of("src/org/open2jam", "parsers/src", "src/resources");
    private static final String MANIFEST = """
            {
              "schemaVersion": 3,
              "javaSourceCommit": "05257da",
              "javaDeterminismOverlayCommit": "62ece7083ea473f02ecc9a83ee7d3e151905bf0e",
              "javaDeterminismOverlayPurpose": "deterministic Liberation Sans font and provenance",
              "javaTool": "zulu-17.66.19.0",
              "javaOraclePaths": ["src/org/open2jam", "parsers/src", "src/resources"],
              "javaOracleTreeFile": "oracle-tree.txt",
              "javaOracleTreeSha256": "206614ef6d5df3ae2cd5f42ea0b1f0499cd7a3137cfbdf11c5a345fb8ff6978e",
              "javaOracleFilesystemManifestFile": "oracle-files.sha256",
              "javaOracleFilesystemManifestSha256": "b1e093eaf4dd2a28ae918d29afcccff8d40b7ad60410d1caee5219fcec74feca",
              "canonicalWorkRoot": "/private/tmp/open2jam-java-golden-v1",
              "cases": [
                {"id": "vos-canon", "format": "VOS", "source": "sources/vos/canon.vos", "expected": "expected/vos"},
                {"id": "ojn-o2jam", "format": "OJN", "source": "sources/ojn/o2jam.ojn", "expected": "expected/ojn"},
                {"id": "osu-seven-key", "format": "OSU", "source": "sources/osu/seven-key.osu", "expected": "expected/osu"},
                {"id": "osz-seven-key", "format": "OSU", "source": "sources/osu/seven-key.osz", "expected": "expected/osu/osz-catalog.json"},
                {"id": "vos-truncated", "format": "VOS", "source": "sources/malformed/truncated.vos", "expectedError": "CORRUPT_CHART"},
                {"id": "ojn-truncated", "format": "OJN", "source": "sources/malformed/truncated.ojn", "expectedError": "CORRUPT_CHART"},
                {"id": "osu-non-mania", "format": "OSU", "source": "sources/malformed/non-mania.osu", "expectedError": "UNSUPPORTED_FORMAT"}
              ]
            }
            """;

    private MigrationGoldenCorpusGenerator() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 4 || !"--output".equals(args[0]) || !"--work-root".equals(args[2])) {
            throw new IllegalArgumentException(
                    "Usage: MigrationGoldenCorpusGenerator --output <path> --work-root <path>");
        }
        GenerationPaths paths = validateCliPaths(Path.of("").toRealPath(), args[1], args[3]);
        generateValidated(paths);
    }

    public static void generate(Path outputRoot, Path workRoot) throws Exception {
        generateValidated(validateProgrammaticPaths(outputRoot, workRoot));
    }

    static GenerationPaths validateProgrammaticPaths(Path outputRoot, Path workRoot) throws Exception {
        Path projectRoot = Path.of("").toRealPath();
        Path output = canonicalProgrammaticTempDescendant(outputRoot, "output root");
        Path work = canonicalProgrammaticTempDescendant(workRoot, "work root");
        rejectProjectTree(output, projectRoot, "output root");
        rejectProjectTree(work, projectRoot, "work root");
        rejectOverlappingRoots(output, work);
        return new GenerationPaths(output, work, projectRoot, false);
    }

    static GenerationPaths validateCliPaths(
            Path projectRoot, String outputArgument, String workArgument) throws Exception {
        Path project = requireCanonicalProjectRoot(projectRoot);
        if (outputArgument == null || outputArgument.isEmpty()
                || workArgument == null || workArgument.isEmpty()) {
            throw new IllegalArgumentException("Generator paths must not be empty");
        }

        Path rawOutput = Path.of(outputArgument);
        Path output = rawOutput.isAbsolute()
                ? rawOutput.normalize()
                : project.resolve(rawOutput).normalize();
        Path expectedOutput = project.resolve(CORPUS_RELATIVE_PATH).normalize();
        if (!output.equals(expectedOutput)) {
            throw new IllegalArgumentException(
                    "CLI output must be the repository migration corpus: " + expectedOutput);
        }
        validateNoSymlinkComponents(project, output, "output root");

        Path rawWork = Path.of(workArgument);
        Path work = canonicalTempDescendant(rawWork, "work root");
        Path expectedWork = Path.of(CANONICAL_WORK_ROOT);
        if (!work.equals(expectedWork)) {
            throw new IllegalArgumentException(
                    "CLI work root must be the pinned migration temp root: " + expectedWork);
        }
        rejectProjectTree(work, project, "work root");
        rejectOverlappingRoots(output, work);
        return new GenerationPaths(output, work, project, true);
    }

    private static void generateValidated(GenerationPaths paths) throws Exception {
        revalidateGenerationPaths(paths);
        resetDirectory(paths.workRoot());
        Path stagedCorpus = paths.workRoot().resolve("corpus");
        Files.createDirectories(stagedCorpus);
        generateVos(stagedCorpus, paths.workRoot());
        generateOjn(stagedCorpus, paths.workRoot());
        generateOsu(stagedCorpus, paths.workRoot());
        normalizeExpectedPaths(stagedCorpus, paths.workRoot());
        copyTree(paths.workRoot().resolve("sources"), stagedCorpus.resolve("sources"));
        generateMalformedCases(stagedCorpus);
        writeReadme(stagedCorpus);
        writeProvenance(stagedCorpus);
        writeOracleTree(stagedCorpus);
        writeFileTypes(stagedCorpus);
        writeHashes(stagedCorpus);
        revalidateGenerationPaths(paths);
        resetDirectory(paths.outputRoot());
        copyTree(stagedCorpus, paths.outputRoot());
    }

    private static void generateVos(Path stagedCorpus, Path workRoot) throws Exception {
        Path sourceDir = workRoot.resolve("sources/vos");
        Files.createDirectories(sourceDir);
        File vos = VosFixtureFactory.writeFixture(sourceDir.toFile(), "canon.vos", 7, true, true, true);
        Path expected = stagedCorpus.resolve("expected/vos");
        Files.createDirectories(expected.resolve("audio"));
        writeUtf8(expected.resolve("catalog.json"), new VosCatalogExporter().exportCatalog(vos));
        writeUtf8(expected.resolve("gameplay.json"), new VosGameplayExporter().exportGameplay(vos));
        writeUtf8(expected.resolve("audio-manifest.json"),
                new VosAudioExporter().exportAudio(vos, expected.resolve("audio").toFile()));
        writeUtf8(expected.resolve("render-metadata.json"), stableRenderMetadata());
    }

    private static void generateOjn(Path stagedCorpus, Path workRoot) throws Exception {
        Path sourceDir = workRoot.resolve("sources/ojn");
        Files.createDirectories(sourceDir);
        OjnFixtureFactory.OjnFixture ojn = OjnFixtureFactory.writeFixture(sourceDir.toFile(), "o2jam");
        Path expected = stagedCorpus.resolve("expected/ojn");
        Files.createDirectories(expected.resolve("audio"));
        writeUtf8(expected.resolve("catalog.json"), new VosCatalogExporter().exportCatalog(ojn.chart()));
        writeUtf8(expected.resolve("gameplay.json"), new VosGameplayExporter().exportGameplay(ojn.chart(), 0));
        writeUtf8(expected.resolve("audio-manifest.json"),
                new VosAudioExporter().exportAudio(ojn.chart(), expected.resolve("audio").toFile(), 0));
    }

    private static void generateOsu(Path stagedCorpus, Path workRoot) throws Exception {
        Path sourceDir = workRoot.resolve("sources/osu");
        Files.createDirectories(sourceDir);
        File osu = OsuFixtureFactory.writeSevenKeyOsu(sourceDir.toFile(), "seven-key.osu");
        File osz = OsuFixtureFactory.writeSevenKeyOsz(sourceDir.toFile(), "seven-key.osz");
        Path expected = stagedCorpus.resolve("expected/osu");
        Files.createDirectories(expected.resolve("audio"));
        writeUtf8(expected.resolve("osu-catalog.json"), new VosCatalogExporter().exportCatalog(osu));
        writeUtf8(expected.resolve("osz-catalog.json"), new VosCatalogExporter().exportCatalog(osz));
        writeUtf8(expected.resolve("gameplay.json"), new VosGameplayExporter().exportGameplay(osu));
        writeUtf8(expected.resolve("audio-manifest.json"),
                new VosAudioExporter().exportAudio(osu, expected.resolve("audio").toFile()));
    }

    private static void generateMalformedCases(Path stagedCorpus) throws Exception {
        Path malformed = stagedCorpus.resolve("sources/malformed");
        Files.createDirectories(malformed);
        Files.write(malformed.resolve("truncated.vos"), new byte[] {3, 0, 0, 0});
        Files.write(malformed.resolve("truncated.ojn"), new byte[] {1, 2, 3});
        Files.writeString(
                malformed.resolve("non-mania.osu"),
                OsuFixtureFactory.sevenKeyContent("audio.wav").replace("Mode: 3", "Mode: 0"),
                StandardCharsets.UTF_8);
    }

    private static void writeReadme(Path stagedCorpus) throws Exception {
        String readme = """
                # Java Migration Golden Corpus

                This corpus preserves Java behavior from source commit `05257da` plus determinism overlay `62ece7083ea473f02ecc9a83ee7d3e151905bf0e`, which pins Liberation Sans font bytes and provenance. `oracle-tree.txt` pins Git modes, blob identities, and paths for `src/org/open2jam`, `parsers/src`, and `src/resources`; its SHA-256 is `206614ef6d5df3ae2cd5f42ea0b1f0499cd7a3137cfbdf11c5a345fb8ff6978e`. `oracle-files.sha256` independently pins raw file bytes and filesystem-executable modes; its SHA-256 is `b1e093eaf4dd2a28ae918d29afcccff8d40b7ad60410d1caee5219fcec74feca`.

                Normal tests treat this directory as read-only. Regenerate it only from the pinned Java source and toolchain with:

                ```bash
                mise exec -- bash -lc 'mvn -s "$MAVEN_SETTINGS" test-compile org.codehaus.mojo:exec-maven-plugin:3.5.0:exec -Dexec.args="--add-exports java.desktop/com.sun.media.sound=ALL-UNNAMED -classpath target/test-classes:lib/*:%classpath org.open2jam.export.MigrationGoldenCorpusGenerator --output rewrite/golden/java-migration --work-root /tmp/open2jam-java-golden-v1"'
                ```

                On macOS, the CLI spelling `/tmp/open2jam-java-golden-v1` resolves canonically to `/private/tmp/open2jam-java-golden-v1`; the manifest and normalized expected JSON pin the canonical spelling.

                Do not regenerate this corpus after the Java implementation is deleted. It is immutable migration provenance.
                """;
        writeUtf8(stagedCorpus.resolve("README.md"), readme);
    }

    private static String stableRenderMetadata() throws Exception {
        String projectRoot = Path.of("").toRealPath().toString().replace(File.separatorChar, '/');
        return new VosRenderMetadataExporter()
                .exportDefaultMetadata()
                .replace(projectRoot + "/", "$PROJECT_ROOT/");
    }

    private static void writeProvenance(Path stagedCorpus) throws Exception {
        writeUtf8(stagedCorpus.resolve("manifest.json"), MANIFEST);
    }

    private static void writeOracleTree(Path stagedCorpus) throws Exception {
        List<String> command = new ArrayList<>();
        command.add("git");
        command.add("ls-tree");
        command.add("-r");
        command.add("--full-tree");
        command.add(JAVA_DETERMINISM_OVERLAY_COMMIT);
        command.add("--");
        command.addAll(JAVA_ORACLE_PATHS);
        byte[] output = runCommand(command);
        if (output.length == 0) {
            throw new IllegalStateException("Pinned Java oracle tree is empty");
        }
        String tree = new String(output, StandardCharsets.UTF_8);
        String sha256 = HexFormat.of().formatHex(
                MessageDigest.getInstance("SHA-256").digest(tree.getBytes(StandardCharsets.UTF_8)));
        if (!JAVA_ORACLE_TREE_SHA256.equals(sha256)) {
            throw new IllegalStateException(
                    "Pinned Java oracle tree digest mismatch: " + sha256);
        }
        writeUtf8(stagedCorpus.resolve("oracle-tree.txt"), tree);

        StringBuilder fileManifest = new StringBuilder();
        for (String line : tree.split("\n")) {
            int tab = line.indexOf('\t');
            if (tab <= 0 || tab == line.length() - 1) {
                throw new IllegalStateException("Invalid pinned Java oracle tree line: " + line);
            }
            String[] metadata = line.substring(0, tab).split(" ");
            String relativePath = line.substring(tab + 1);
            if (metadata.length != 3 || !"blob".equals(metadata[1])
                    || (!("100644".equals(metadata[0])) && !("100755".equals(metadata[0])))) {
                throw new IllegalStateException("Unsupported pinned Java oracle entry: " + line);
            }
            byte[] blob = runCommand(List.of("git", "cat-file", "blob", metadata[2]));
            String blobSha256 = HexFormat.of().formatHex(
                    MessageDigest.getInstance("SHA-256").digest(blob));
            fileManifest.append(metadata[0]).append(' ').append(blobSha256)
                    .append("  ").append(relativePath).append('\n');
        }
        String rawManifest = fileManifest.toString();
        String rawManifestSha256 = HexFormat.of().formatHex(
                MessageDigest.getInstance("SHA-256")
                        .digest(rawManifest.getBytes(StandardCharsets.UTF_8)));
        if (!JAVA_ORACLE_FILES_SHA256.equals(rawManifestSha256)) {
            throw new IllegalStateException(
                    "Pinned Java oracle filesystem manifest digest mismatch: "
                            + rawManifestSha256);
        }
        writeUtf8(stagedCorpus.resolve("oracle-files.sha256"), rawManifest);
    }

    private static byte[] runCommand(List<String> command) throws Exception {
        ProcessBuilder builder = new ProcessBuilder(command);
        builder.environment().put("LC_ALL", "C");
        builder.redirectErrorStream(true);
        Process process = builder.start();
        byte[] output = process.getInputStream().readAllBytes();
        int exitCode = process.waitFor();
        if (exitCode != 0) {
            throw new IllegalStateException(
                    "Command failed: " + command + ": "
                            + new String(output, StandardCharsets.UTF_8));
        }
        return output;
    }

    private static void writeHashes(Path stagedCorpus) throws Exception {
        writeUtf8(stagedCorpus.resolve(HASH_MANIFEST), hashManifest(stagedCorpus));
    }

    private static void writeFileTypes(Path stagedCorpus) throws Exception {
        writeUtf8(stagedCorpus.resolve(FILE_TYPE_MANIFEST), "");
        writeUtf8(stagedCorpus.resolve(FILE_TYPE_MANIFEST), fileTypeManifest(stagedCorpus));
    }

    private static void normalizeExpectedPaths(Path stagedCorpus, Path workRoot) throws Exception {
        String actualWorkRoot = workRoot.toFile().getCanonicalPath().replace(File.separatorChar, '/');
        Path expectedRoot = stagedCorpus.resolve("expected");
        List<Path> expectedEntries = validateTree(expectedRoot, "expected artifact tree");
        for (Path path : expectedEntries.stream()
                .filter(file -> isRegularFileNoFollow(file))
                .filter(file -> file.getFileName().toString().endsWith(".json"))
                .toList()) {
            EntryState state = captureEntry(path, relativePath(expectedRoot, path));
            String content = new String(
                    readStableBytes(path, state, relativePath(expectedRoot, path)),
                    StandardCharsets.UTF_8);
            String normalized = normalizeCatalogIds(content, actualWorkRoot)
                    .replace(actualWorkRoot, CANONICAL_WORK_ROOT);
            writeUtf8(path, normalized);
        }
    }

    private static String normalizeCatalogIds(String content, String actualWorkRoot) throws Exception {
        String normalized = replaceCatalogId(
                content, "vos", actualWorkRoot + "/sources/vos/canon.vos",
                CANONICAL_WORK_ROOT + "/sources/vos/canon.vos", -1);
        for (int chartIndex = 0; chartIndex < 3; chartIndex++) {
            normalized = replaceCatalogId(
                    normalized, "ojn", actualWorkRoot + "/sources/ojn/o2jam.ojn",
                    CANONICAL_WORK_ROOT + "/sources/ojn/o2jam.ojn", chartIndex);
        }
        normalized = replaceCatalogId(
                normalized, "osu", actualWorkRoot + "/sources/osu/seven-key.osu",
                CANONICAL_WORK_ROOT + "/sources/osu/seven-key.osu", -1);
        return replaceCatalogId(
                normalized, "osu", actualWorkRoot + "/sources/osu/seven-key.osz",
                CANONICAL_WORK_ROOT + "/sources/osu/seven-key.osz", -1);
    }

    private static String replaceCatalogId(
            String content, String prefix, String actualSource, String canonicalSource, int chartIndex)
            throws Exception {
        String actualIdentity = chartIndex < 0 ? actualSource : actualSource + "#chart=" + chartIndex;
        String canonicalIdentity = chartIndex < 0 ? canonicalSource : canonicalSource + "#chart=" + chartIndex;
        return content.replace(catalogId(prefix, actualIdentity), catalogId(prefix, canonicalIdentity));
    }

    private static String catalogId(String prefix, String identity) throws Exception {
        byte[] hash = MessageDigest.getInstance("SHA-256").digest(identity.getBytes(StandardCharsets.UTF_8));
        return prefix + ":sha256:" + HexFormat.of().formatHex(hash, 0, 8);
    }

    public static String hashManifest(Path root) throws Exception {
        return hashManifest(root, TreeOperationObserver.NONE);
    }

    static String hashManifest(Path root, TreeOperationObserver observer) throws Exception {
        TreeSnapshot snapshot = captureTree(root, "golden corpus");
        observer.afterInitialSnapshot("hash", snapshot.root());
        String fileTypesRelative = relativePath(snapshot.root(), snapshot.root().resolve(FILE_TYPE_MANIFEST));
        EntryState fileTypesState = snapshot.entries().get(fileTypesRelative);
        if (fileTypesState == null || fileTypesState.kind() != EntryKind.REGULAR) {
            throw new IllegalArgumentException(
                    "Missing regular corpus file-type manifest: "
                            + snapshot.root().resolve(FILE_TYPE_MANIFEST));
        }
        observer.beforeFileRead("hash", Path.of(fileTypesRelative));
        String expectedTypes = renderFileTypeManifest(snapshot);
        String actualTypes = new String(
                readStableBytes(
                        snapshot.root().resolve(fileTypesRelative),
                        fileTypesState,
                        fileTypesRelative),
                StandardCharsets.UTF_8);
        if (!actualTypes.equals(expectedTypes)) {
            throw new IllegalArgumentException("Corpus file-type manifest does not match the tree");
        }

        List<Map.Entry<String, EntryState>> files = snapshot.entries().entrySet().stream()
                .filter(entry -> entry.getValue().kind() == EntryKind.REGULAR)
                .filter(entry -> !entry.getKey().equals(HASH_MANIFEST))
                .sorted(Map.Entry.comparingByKey())
                .toList();

        StringBuilder hashes = new StringBuilder();
        for (Map.Entry<String, EntryState> file : files) {
            observer.beforeFileRead("hash", Path.of(file.getKey()));
            String sha256 = hashStableFile(
                    snapshot.root().resolve(file.getKey()), file.getValue(), file.getKey());
            hashes.append(sha256).append("  ").append(file.getKey()).append('\n');
        }
        observer.beforeFinalSnapshot("hash", snapshot.root());
        assertTreeUnchanged(snapshot, "golden corpus");
        return hashes.toString();
    }

    public static String fileTypeManifest(Path root) throws Exception {
        return fileTypeManifest(root, TreeOperationObserver.NONE);
    }

    static String fileTypeManifest(Path root, TreeOperationObserver observer) throws Exception {
        TreeSnapshot snapshot = captureTree(root, "golden corpus");
        observer.afterInitialSnapshot("file-types", snapshot.root());
        String manifest = renderFileTypeManifest(snapshot);
        observer.beforeFinalSnapshot("file-types", snapshot.root());
        assertTreeUnchanged(snapshot, "golden corpus");
        return manifest;
    }

    private static String renderFileTypeManifest(TreeSnapshot snapshot) {
        StringBuilder types = new StringBuilder();
        for (Map.Entry<String, EntryState> entry : snapshot.entries().entrySet().stream()
                .filter(item -> !item.getKey().isEmpty())
                .filter(item -> !item.getKey().equals(HASH_MANIFEST))
                .sorted(Map.Entry.comparingByKey())
                .toList()) {
            if (entry.getValue().kind() == EntryKind.DIRECTORY) {
                types.append("directory  ").append(entry.getKey()).append("/\n");
            } else if (entry.getValue().kind() == EntryKind.REGULAR) {
                types.append("regular  ").append(entry.getKey()).append('\n');
            } else {
                throw new IllegalStateException("Unsupported captured tree entry: " + entry.getKey());
            }
        }
        return types.toString();
    }

    private static String relativePath(Path root, Path path) {
        return root.relativize(path).toString().replace(File.separatorChar, '/');
    }

    private static void writeUtf8(Path path, String content) throws Exception {
        ensureDirectoryNoFollow(path.getParent(), "write target parent");
        byte[] bytes = content.getBytes(StandardCharsets.UTF_8);
        EntryState identity;
        try (FileChannel channel = openDestinationNoFollow(path)) {
            identity = captureEntry(path, path.toString());
            ByteBuffer buffer = ByteBuffer.wrap(bytes);
            while (buffer.hasRemaining()) {
                channel.write(buffer);
            }
            channel.force(true);
        }
        EntryState after = captureEntry(path, path.toString());
        if (!Objects.equals(identity.fileKey(), after.fileKey())
                || after.kind() != EntryKind.REGULAR
                || after.size() != bytes.length) {
            throw new IllegalArgumentException("Write target changed while writing: " + path);
        }
    }

    static void resetDirectory(Path root) throws Exception {
        validateNoSymlinkAncestry(root.toAbsolutePath().normalize(), "reset directory");
        if (Files.exists(root, LinkOption.NOFOLLOW_LINKS) || Files.isSymbolicLink(root)) {
            List<Path> entries = validateTree(root, "reset directory");
            for (Path path : entries.stream().sorted(Comparator.reverseOrder()).toList()) {
                Files.delete(path);
            }
        }
        Files.createDirectories(root);
    }

    static void copyTree(Path source, Path target) throws Exception {
        copyTree(source, target, TreeOperationObserver.NONE);
    }

    static void copyTree(Path source, Path target, TreeOperationObserver observer) throws Exception {
        validateNoSymlinkAncestry(source.toAbsolutePath().normalize(), "copy source tree");
        TreeSnapshot sourceSnapshot = captureTree(source, "copy source tree");
        TreeSnapshot targetSnapshot = captureOptionalTree(target, "copy target tree");
        observer.afterInitialSnapshot("copy", sourceSnapshot.root());

        Map<String, EntryKind> expectedTargetTypes = targetSnapshot == null
                ? new LinkedHashMap<>()
                : entryKinds(targetSnapshot);
        for (Map.Entry<String, EntryState> entry : sourceSnapshot.entries().entrySet()) {
            EntryKind previous = expectedTargetTypes.put(entry.getKey(), entry.getValue().kind());
            if (previous != null && previous != entry.getValue().kind()) {
                throw new IllegalArgumentException(
                        "Copy source and target entry types conflict: " + entry.getKey());
            }
        }

        ensureDirectoryNoFollow(target.toAbsolutePath().normalize(), "copy target root");
        for (Map.Entry<String, EntryState> entry : sourceSnapshot.entries().entrySet()) {
            Path sourcePath = sourceSnapshot.root().resolve(entry.getKey());
            Path destination = target.toAbsolutePath().normalize().resolve(entry.getKey());
            if (entry.getValue().kind() == EntryKind.DIRECTORY) {
                assertEntryUnchanged(sourcePath, entry.getValue(), entry.getKey());
                ensureDirectoryNoFollow(destination, "copy target directory");
            } else if (entry.getValue().kind() == EntryKind.REGULAR) {
                observer.beforeFileRead("copy", Path.of(entry.getKey()));
                copyStableRegularFile(sourcePath, entry.getValue(), entry.getKey(), destination);
            } else {
                throw unsafeTreeEntry(sourcePath);
            }
        }
        observer.beforeFinalSnapshot("copy", sourceSnapshot.root());
        assertTreeUnchanged(sourceSnapshot, "copy source tree");
        TreeSnapshot finalTarget = captureTree(target, "copy target tree");
        if (!entryKinds(finalTarget).equals(expectedTargetTypes)) {
            throw new IllegalArgumentException("Copy target tree entry set or types changed");
        }
    }

    private static TreeSnapshot captureOptionalTree(Path target, String role) throws Exception {
        Path absolute = target.toAbsolutePath().normalize();
        validateNoSymlinkAncestry(absolute, role);
        if (Files.exists(absolute, LinkOption.NOFOLLOW_LINKS)) {
            return captureTree(absolute, role);
        }
        return null;
    }

    private static void validateNoSymlinkAncestry(Path absolute, String role) {
        Path current = absolute.getRoot();
        if (current == null) {
            throw new IllegalArgumentException(role + " must be absolute: " + absolute);
        }
        for (Path component : absolute) {
            current = current.resolve(component);
            if (Files.isSymbolicLink(current)) {
                throw unsafeTreeEntry(current);
            }
            if (Files.exists(current, LinkOption.NOFOLLOW_LINKS)
                    && !Files.isDirectory(current, LinkOption.NOFOLLOW_LINKS)
                    && !current.equals(absolute)) {
                throw unsafeTreeEntry(current);
            }
        }
    }

    private static List<Path> validateTree(Path root, String role) throws Exception {
        TreeSnapshot snapshot = captureTree(root, role);
        return snapshot.entries().keySet().stream()
                .map(snapshot.root()::resolve)
                .toList();
    }

    private static TreeSnapshot captureTree(Path root, String role) throws Exception {
        Path absolute = root.toAbsolutePath().normalize();
        validateNoSymlinkAncestry(absolute, role);
        EntryState rootState = captureEntry(absolute, role + " root");
        if (rootState.kind() != EntryKind.DIRECTORY) {
            throw new IllegalArgumentException(role + " root is not a directory: " + absolute);
        }
        List<Path> paths;
        try (Stream<Path> stream = Files.walk(absolute)) {
            paths = stream.sorted(Comparator.comparing(path -> relativePath(absolute, path))).toList();
        }
        Map<String, EntryState> entries = new LinkedHashMap<>();
        for (Path path : paths) {
            String relative = relativePath(absolute, path);
            EntryState previous = entries.put(relative, captureEntry(path, relative));
            if (previous != null) {
                throw new IllegalArgumentException(role + " contains duplicate entry: " + relative);
            }
        }
        return new TreeSnapshot(absolute, Map.copyOf(entries));
    }

    private static EntryState captureEntry(Path path, String label) throws Exception {
        BasicFileAttributes before = readAttributesNoFollow(path);
        EntryKind beforeKind = entryKind(before, path);
        Object beforeKey = before.fileKey();
        if (beforeKey == null) {
            throw new IllegalArgumentException(
                    "Filesystem identity is unavailable for tree entry: " + label);
        }
        Set<PosixFilePermission> permissions = Set.copyOf(
                Files.getPosixFilePermissions(path, LinkOption.NOFOLLOW_LINKS));
        BasicFileAttributes after = readAttributesNoFollow(path);
        EntryState first = entryState(beforeKind, before, permissions);
        EntryState second = entryState(entryKind(after, path), after, permissions);
        if (!first.equals(second)) {
            throw new IllegalArgumentException(
                    "Tree entry changed while snapshotting: " + label);
        }
        return second;
    }

    private static EntryKind entryKind(BasicFileAttributes attributes, Path path) {
        if (attributes.isDirectory()) {
            return EntryKind.DIRECTORY;
        }
        if (attributes.isRegularFile()) {
            return EntryKind.REGULAR;
        }
        throw unsafeTreeEntry(path);
    }

    private static EntryState entryState(
            EntryKind kind,
            BasicFileAttributes attributes,
            Set<PosixFilePermission> permissions) {
        if (attributes.fileKey() == null) {
            throw new IllegalArgumentException("Filesystem identity became unavailable");
        }
        return new EntryState(
                kind,
                attributes.fileKey(),
                attributes.size(),
                attributes.lastModifiedTime(),
                permissions);
    }

    private static byte[] readStableBytes(Path path, EntryState expected, String label)
            throws Exception {
        EntryState before = captureEntry(path, label);
        if (!expected.equals(before) || before.kind() != EntryKind.REGULAR) {
            throw new IllegalArgumentException("Tree entry changed before reading: " + label);
        }
        if (before.size() > Integer.MAX_VALUE) {
            throw new IllegalArgumentException("Tree entry is too large to read: " + label);
        }
        ByteArrayOutputStream output = new ByteArrayOutputStream((int) before.size());
        long bytesRead = 0L;
        try (FileChannel channel = FileChannel.open(
                path, StandardOpenOption.READ, LinkOption.NOFOLLOW_LINKS)) {
            EntryState afterOpen = captureEntry(path, label);
            if (!before.equals(afterOpen)) {
                throw new IllegalArgumentException("Tree entry changed while opening: " + label);
            }
            ByteBuffer buffer = ByteBuffer.allocate(64 * 1024);
            while (channel.read(buffer) != -1) {
                if (buffer.position() == 0) {
                    continue;
                }
                bytesRead += buffer.position();
                output.write(buffer.array(), 0, buffer.position());
                buffer.clear();
            }
        }
        EntryState after = captureEntry(path, label);
        if (!before.equals(after) || bytesRead != before.size()) {
            throw new IllegalArgumentException("Tree entry changed while reading: " + label);
        }
        return output.toByteArray();
    }

    private static String hashStableFile(Path path, EntryState expected, String label)
            throws Exception {
        EntryState before = captureEntry(path, label);
        if (!expected.equals(before) || before.kind() != EntryKind.REGULAR) {
            throw new IllegalArgumentException("Tree entry changed before hashing: " + label);
        }
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        long bytesRead = 0L;
        try (FileChannel channel = FileChannel.open(
                path, StandardOpenOption.READ, LinkOption.NOFOLLOW_LINKS)) {
            EntryState afterOpen = captureEntry(path, label);
            if (!before.equals(afterOpen)) {
                throw new IllegalArgumentException("Tree entry changed while opening: " + label);
            }
            ByteBuffer buffer = ByteBuffer.allocateDirect(64 * 1024);
            int read;
            while ((read = channel.read(buffer)) != -1) {
                if (read == 0) {
                    continue;
                }
                bytesRead += read;
                buffer.flip();
                digest.update(buffer);
                buffer.clear();
            }
        }
        EntryState after = captureEntry(path, label);
        if (!before.equals(after) || bytesRead != before.size()) {
            throw new IllegalArgumentException("Tree entry changed while hashing: " + label);
        }
        return HexFormat.of().formatHex(digest.digest());
    }

    private static void copyStableRegularFile(
            Path source,
            EntryState expected,
            String label,
            Path destination) throws Exception {
        EntryState before = captureEntry(source, label);
        if (!expected.equals(before) || before.kind() != EntryKind.REGULAR) {
            throw new IllegalArgumentException("Copy source changed before reading: " + label);
        }
        ensureDirectoryNoFollow(destination.getParent(), "copy target parent");
        long bytesRead = 0L;
        EntryState destinationIdentity;
        try (FileChannel input = FileChannel.open(
                        source, StandardOpenOption.READ, LinkOption.NOFOLLOW_LINKS);
                FileChannel output = openDestinationNoFollow(destination)) {
            EntryState afterOpen = captureEntry(source, label);
            if (!before.equals(afterOpen)) {
                throw new IllegalArgumentException("Copy source changed while opening: " + label);
            }
            destinationIdentity = captureEntry(destination, relativePath(destination.getParent(), destination));
            if (destinationIdentity.kind() != EntryKind.REGULAR) {
                throw unsafeTreeEntry(destination);
            }
            ByteBuffer buffer = ByteBuffer.allocateDirect(64 * 1024);
            int read;
            while ((read = input.read(buffer)) != -1) {
                if (read == 0) {
                    continue;
                }
                bytesRead += read;
                buffer.flip();
                while (buffer.hasRemaining()) {
                    output.write(buffer);
                }
                buffer.clear();
            }
            output.force(true);
        }
        EntryState after = captureEntry(source, label);
        if (!before.equals(after) || bytesRead != before.size()) {
            throw new IllegalArgumentException("Copy source changed while reading: " + label);
        }
        EntryState destinationAfter = captureEntry(destination, destination.toString());
        if (!Objects.equals(destinationIdentity.fileKey(), destinationAfter.fileKey())
                || destinationAfter.kind() != EntryKind.REGULAR
                || destinationAfter.size() != bytesRead) {
            throw new IllegalArgumentException("Copy target changed while writing: " + destination);
        }
    }

    private static FileChannel openDestinationNoFollow(Path destination) throws Exception {
        if (Files.exists(destination, LinkOption.NOFOLLOW_LINKS)) {
            EntryState existing = captureEntry(destination, destination.toString());
            if (existing.kind() != EntryKind.REGULAR) {
                throw unsafeTreeEntry(destination);
            }
            FileChannel channel = FileChannel.open(
                    destination,
                    StandardOpenOption.WRITE,
                    StandardOpenOption.TRUNCATE_EXISTING,
                    LinkOption.NOFOLLOW_LINKS);
            EntryState opened = captureEntry(destination, destination.toString());
            if (!Objects.equals(existing.fileKey(), opened.fileKey())
                    || opened.kind() != EntryKind.REGULAR) {
                channel.close();
                throw new IllegalArgumentException(
                        "Copy target changed while opening: " + destination);
            }
            return channel;
        }
        FileChannel channel = FileChannel.open(
                destination,
                StandardOpenOption.WRITE,
                StandardOpenOption.CREATE_NEW,
                LinkOption.NOFOLLOW_LINKS);
        EntryState created = captureEntry(destination, destination.toString());
        if (created.kind() != EntryKind.REGULAR) {
            channel.close();
            throw unsafeTreeEntry(destination);
        }
        return channel;
    }

    private static void ensureDirectoryNoFollow(Path directory, String role) throws Exception {
        Path absolute = directory.toAbsolutePath().normalize();
        List<Path> missing = new ArrayList<>();
        Path current = absolute;
        while (!Files.exists(current, LinkOption.NOFOLLOW_LINKS)) {
            missing.add(current);
            current = current.getParent();
            if (current == null) {
                throw new IllegalArgumentException(role + " has no existing ancestor: " + directory);
            }
        }
        validateNoSymlinkAncestry(current, role);
        if (captureEntry(current, role).kind() != EntryKind.DIRECTORY) {
            throw unsafeTreeEntry(current);
        }
        for (Path path : missing.stream().sorted(Comparator.comparingInt(Path::getNameCount)).toList()) {
            try {
                Files.createDirectory(path);
            } catch (FileAlreadyExistsException ignored) {
                // A concurrent creator is accepted only if the final entry is the expected directory.
            }
            if (captureEntry(path, role).kind() != EntryKind.DIRECTORY) {
                throw unsafeTreeEntry(path);
            }
        }
        validateNoSymlinkAncestry(absolute, role);
    }

    private static void assertEntryUnchanged(Path path, EntryState expected, String label)
            throws Exception {
        if (!expected.equals(captureEntry(path, label))) {
            throw new IllegalArgumentException("Tree entry changed: " + label);
        }
    }

    private static void assertTreeUnchanged(TreeSnapshot expected, String role) throws Exception {
        TreeSnapshot actual = captureTree(expected.root(), role);
        if (!expected.equals(actual)) {
            Set<String> missing = new LinkedHashSet<>(expected.entries().keySet());
            missing.removeAll(actual.entries().keySet());
            Set<String> extra = new LinkedHashSet<>(actual.entries().keySet());
            extra.removeAll(expected.entries().keySet());
            List<String> changed = expected.entries().entrySet().stream()
                    .filter(entry -> actual.entries().containsKey(entry.getKey()))
                    .filter(entry -> !entry.getValue().equals(actual.entries().get(entry.getKey())))
                    .map(Map.Entry::getKey)
                    .sorted()
                    .toList();
            throw new IllegalArgumentException(
                    role + " changed during operation; missing=" + missing
                            + ", extra=" + extra + ", changed=" + changed);
        }
    }

    private static Map<String, EntryKind> entryKinds(TreeSnapshot snapshot) {
        Map<String, EntryKind> kinds = new LinkedHashMap<>();
        snapshot.entries().entrySet().stream()
                .sorted(Map.Entry.comparingByKey())
                .forEach(entry -> kinds.put(entry.getKey(), entry.getValue().kind()));
        return kinds;
    }

    private static IllegalArgumentException unsafeTreeEntry(Path path) {
        return new IllegalArgumentException("Tree entry must be a regular file or directory: " + path);
    }

    private static BasicFileAttributes readAttributesNoFollow(Path path) throws Exception {
        return Files.readAttributes(path, BasicFileAttributes.class, LinkOption.NOFOLLOW_LINKS);
    }

    private static boolean isRegularFileNoFollow(Path path) {
        return Files.isRegularFile(path, LinkOption.NOFOLLOW_LINKS) && !Files.isSymbolicLink(path);
    }

    private static Path requireCanonicalProjectRoot(Path projectRoot) throws Exception {
        if (projectRoot == null || !projectRoot.isAbsolute()) {
            throw new IllegalArgumentException("Project root must be absolute");
        }
        Path normalized = projectRoot.normalize();
        Path canonical = normalized.toRealPath();
        if (!canonical.equals(normalized) || canonical.getParent() == null) {
            throw new IllegalArgumentException("Project root must be canonical and non-root: " + projectRoot);
        }
        return canonical;
    }

    private static Path canonicalTempDescendant(Path rawPath, String role) throws Exception {
        if (rawPath == null || !rawPath.isAbsolute() || !rawPath.equals(rawPath.normalize())) {
            throw new IllegalArgumentException(role + " must be an absolute normalized path: " + rawPath);
        }
        Path normalized = rawPath.normalize();
        for (TempRoot tempRoot : controlledTempRoots()) {
            if (!normalized.startsWith(tempRoot.lexicalRoot())
                    || normalized.equals(tempRoot.lexicalRoot())) {
                continue;
            }
            Path suffix = tempRoot.lexicalRoot().relativize(normalized);
            Path canonical = tempRoot.canonicalRoot().resolve(suffix).normalize();
            if (canonical.equals(tempRoot.canonicalRoot())
                    || !canonical.startsWith(tempRoot.canonicalRoot())) {
                throw new IllegalArgumentException(role + " escapes the controlled temp root");
            }
            validateNoSymlinkComponents(tempRoot.canonicalRoot(), canonical, role);
            return canonical;
        }
        throw new IllegalArgumentException(role + " must be below a controlled temp root: " + rawPath);
    }

    private static Path canonicalProgrammaticTempDescendant(Path rawPath, String role)
            throws Exception {
        if (rawPath == null || !rawPath.isAbsolute() || !rawPath.equals(rawPath.normalize())) {
            throw new IllegalArgumentException(
                    role + " must be an absolute normalized path: " + rawPath);
        }
        Path normalized = rawPath.normalize();
        validateNoSymlinkAncestry(normalized, role);
        Path canonical = canonicalTempDescendant(normalized, role);
        if (!canonical.equals(normalized)) {
            throw new IllegalArgumentException(
                    role + " must use its physical canonical path: " + rawPath);
        }
        return canonical;
    }

    private static List<TempRoot> controlledTempRoots() throws Exception {
        Set<String> candidates = new LinkedHashSet<>();
        candidates.add(System.getenv("TMPDIR"));
        candidates.add("/private/tmp");
        candidates.add("/tmp");
        List<TempRoot> roots = new ArrayList<>();
        for (String candidate : candidates) {
            if (candidate == null || candidate.isEmpty()) {
                continue;
            }
            Path lexical = Path.of(candidate).toAbsolutePath().normalize();
            if (!Files.isDirectory(lexical) || lexical.getParent() == null) {
                continue;
            }
            Path canonical = lexical.toRealPath();
            if (canonical.getParent() != null) {
                roots.add(new TempRoot(lexical, canonical));
                if (!canonical.equals(lexical)) {
                    roots.add(new TempRoot(canonical, canonical));
                }
            }
        }
        return roots;
    }

    private static void validateNoSymlinkComponents(
            Path existingRoot, Path candidate, String role) throws Exception {
        if (!candidate.startsWith(existingRoot) || candidate.equals(existingRoot)) {
            throw new IllegalArgumentException(role + " is not a strict descendant: " + candidate);
        }
        Path current = existingRoot;
        for (Path component : existingRoot.relativize(candidate)) {
            current = current.resolve(component);
            if (Files.isSymbolicLink(current)) {
                throw new IllegalArgumentException(role + " contains a symbolic link: " + current);
            }
            if (Files.exists(current, LinkOption.NOFOLLOW_LINKS)
                    && !Files.isDirectory(current, LinkOption.NOFOLLOW_LINKS)
                    && !current.equals(candidate)) {
                throw new IllegalArgumentException(role + " has a non-directory component: " + current);
            }
        }
    }

    private static void rejectProjectTree(Path candidate, Path projectRoot, String role) {
        if (candidate.equals(projectRoot) || candidate.startsWith(projectRoot)) {
            throw new IllegalArgumentException(role + " must not be inside the project tree: " + candidate);
        }
    }

    private static void rejectOverlappingRoots(Path output, Path work) {
        if (output.equals(work) || output.startsWith(work) || work.startsWith(output)) {
            throw new IllegalArgumentException("Output and work roots must not overlap");
        }
    }

    private static void revalidateGenerationPaths(GenerationPaths paths) throws Exception {
        if (paths.cli()) {
            validateCliPaths(paths.projectRoot(), paths.outputRoot().toString(), paths.workRoot().toString());
        } else {
            GenerationPaths validated = validateProgrammaticPaths(paths.outputRoot(), paths.workRoot());
            if (!validated.outputRoot().equals(paths.outputRoot())
                    || !validated.workRoot().equals(paths.workRoot())) {
                throw new IllegalArgumentException("Generator roots changed after validation");
            }
        }
    }

    interface TreeOperationObserver {
        TreeOperationObserver NONE = new TreeOperationObserver() {
        };

        default void afterInitialSnapshot(String operation, Path root) throws Exception {
        }

        default void beforeFileRead(String operation, Path relativePath) throws Exception {
        }

        default void beforeFinalSnapshot(String operation, Path root) throws Exception {
        }
    }

    private enum EntryKind {
        DIRECTORY,
        REGULAR
    }

    private record EntryState(
            EntryKind kind,
            Object fileKey,
            long size,
            FileTime lastModifiedTime,
            Set<PosixFilePermission> permissions) {
    }

    private record TreeSnapshot(Path root, Map<String, EntryState> entries) {
    }

    record GenerationPaths(
            Path outputRoot, Path workRoot, Path projectRoot, boolean cli) {
    }

    private record TempRoot(Path lexicalRoot, Path canonicalRoot) {
    }
}
