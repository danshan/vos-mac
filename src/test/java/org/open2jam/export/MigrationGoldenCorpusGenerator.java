package org.open2jam.export;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.nio.file.attribute.BasicFileAttributes;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HexFormat;
import java.util.LinkedHashSet;
import java.util.List;
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
        Path output = canonicalTempDescendant(outputRoot, "output root");
        Path work = canonicalTempDescendant(workRoot, "work root");
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
            String content = Files.readString(path, StandardCharsets.UTF_8);
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
        List<Path> entries = validateTree(root, "golden corpus");
        Path fileTypes = root.resolve(FILE_TYPE_MANIFEST);
        if (!isRegularFileNoFollow(fileTypes)) {
            throw new IllegalArgumentException("Missing regular corpus file-type manifest: " + fileTypes);
        }
        String expectedTypes = fileTypeManifest(root);
        String actualTypes = Files.readString(fileTypes, StandardCharsets.UTF_8);
        if (!actualTypes.equals(expectedTypes)) {
            throw new IllegalArgumentException("Corpus file-type manifest does not match the tree");
        }

        List<Path> files = entries.stream()
                .filter(MigrationGoldenCorpusGenerator::isRegularFileNoFollow)
                .filter(path -> !path.equals(root.resolve(HASH_MANIFEST)))
                .sorted(Comparator.comparing(path -> relativePath(root, path)))
                .toList();

        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        StringBuilder hashes = new StringBuilder();
        for (Path file : files) {
            String sha256 = HexFormat.of().formatHex(digest.digest(Files.readAllBytes(file)));
            hashes.append(sha256).append("  ").append(relativePath(root, file)).append('\n');
        }
        return hashes.toString();
    }

    public static String fileTypeManifest(Path root) throws Exception {
        List<Path> entries = validateTree(root, "golden corpus");
        StringBuilder types = new StringBuilder();
        for (Path path : entries.stream()
                .filter(entry -> !entry.equals(root))
                .filter(entry -> !entry.equals(root.resolve(HASH_MANIFEST)))
                .sorted(Comparator.comparing(entry -> relativePath(root, entry)))
                .toList()) {
            BasicFileAttributes attributes = readAttributesNoFollow(path);
            if (attributes.isDirectory()) {
                types.append("directory  ").append(relativePath(root, path)).append("/\n");
            } else if (attributes.isRegularFile()) {
                types.append("regular  ").append(relativePath(root, path)).append('\n');
            } else {
                throw unsafeTreeEntry(path);
            }
        }
        return types.toString();
    }

    private static String relativePath(Path root, Path path) {
        return root.relativize(path).toString().replace(File.separatorChar, '/');
    }

    private static void writeUtf8(Path path, String content) throws Exception {
        Files.createDirectories(path.getParent());
        Files.writeString(path, content, StandardCharsets.UTF_8);
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
        validateNoSymlinkAncestry(source.toAbsolutePath().normalize(), "copy source tree");
        List<Path> entries = validateTree(source, "copy source tree");
        validateExistingTargetTree(target);
        for (Path path : entries) {
            Path destination = target.resolve(source.relativize(path));
            BasicFileAttributes attributes = readAttributesNoFollow(path);
            if (attributes.isDirectory()) {
                Files.createDirectories(destination);
            } else if (attributes.isRegularFile()) {
                Files.createDirectories(destination.getParent());
                Files.copy(path, destination, StandardCopyOption.REPLACE_EXISTING,
                        LinkOption.NOFOLLOW_LINKS);
            } else {
                throw unsafeTreeEntry(path);
            }
        }
    }

    private static void validateExistingTargetTree(Path target) throws Exception {
        Path absolute = target.toAbsolutePath().normalize();
        validateNoSymlinkAncestry(absolute, "copy target tree");
        if (Files.exists(absolute, LinkOption.NOFOLLOW_LINKS)) {
            validateTree(absolute, "copy target tree");
        }
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
        validateNoSymlinkAncestry(root.toAbsolutePath().normalize(), role);
        if (Files.isSymbolicLink(root)) {
            throw new IllegalArgumentException(role + " contains a symbolic link: " + root);
        }
        BasicFileAttributes rootAttributes = readAttributesNoFollow(root);
        if (!rootAttributes.isDirectory()) {
            throw new IllegalArgumentException(role + " root is not a directory: " + root);
        }
        List<Path> entries;
        try (Stream<Path> paths = Files.walk(root)) {
            entries = paths.sorted(Comparator.comparing(path -> relativePath(root, path))).toList();
        }
        for (Path path : entries) {
            BasicFileAttributes attributes = readAttributesNoFollow(path);
            if (Files.isSymbolicLink(path)
                    || (!attributes.isDirectory() && !attributes.isRegularFile())) {
                throw unsafeTreeEntry(path);
            }
        }
        return entries;
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

    record GenerationPaths(
            Path outputRoot, Path workRoot, Path projectRoot, boolean cli) {
    }

    private record TempRoot(Path lexicalRoot, Path canonicalRoot) {
    }
}
