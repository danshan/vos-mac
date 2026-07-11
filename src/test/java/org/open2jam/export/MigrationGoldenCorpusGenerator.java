package org.open2jam.export;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.FileAlreadyExistsException;
import java.nio.file.InvalidPathException;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
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
    public static final String CANONICAL_MANIFEST_SHA256 =
            "5791c29398844fd1add3db4961da3d7a412eab3072ba32a656b70c9cfb162f0a";

    private static final String CANONICAL_WORK_ROOT = "/private/tmp/open2jam-java-golden-v1";
    private static final String CONTEXT_PROCESS_TMPDIR_PREFIX = ".ctx-mode-";
    private static final String PROCESS_START_TMPDIR = System.getenv("TMPDIR");
    private static final String PROCESS_START_JVM_TMPDIR = System.getProperty("java.io.tmpdir");
    private static final Path CORPUS_RELATIVE_PATH = Path.of("rewrite/golden/java-migration");
    private static final String FILE_TYPE_MANIFEST = "manifest.files";
    private static final String HASH_MANIFEST = "manifest.sha256";
    private static final List<String> JAVA_ORACLE_PATHS =
            List.of("src/org/open2jam", "parsers/src", "src/resources");
    private static final List<LegacyAlias> LEGACY_ALIASES = List.of(
            new LegacyAlias("sources/malformed/truncated.vos", "vos-truncated"),
            new LegacyAlias("sources/malformed/truncated.ojn", "ojn-truncated"),
            new LegacyAlias("sources/malformed/non-mania.osu", "osu-non-mania"));
    private MigrationGoldenCorpusGenerator() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 4 || !"--output".equals(args[0]) || !"--work-root".equals(args[2])) {
            throw new IllegalArgumentException(
                    "Usage: MigrationGoldenCorpusGenerator --output <path> --work-root <path>");
        }
        GenerationPaths paths = validateCliPaths(Path.of("").toRealPath(), args[1], args[3]);
        generateValidated(paths, GenerationObserver.NONE);
    }

    public static void generate(Path outputRoot, Path workRoot) throws Exception {
        generateValidated(
                validateProgrammaticPaths(outputRoot, workRoot), GenerationObserver.NONE);
    }

    static void generate(Path outputRoot, Path workRoot, GenerationObserver observer)
            throws Exception {
        generateValidated(
                validateProgrammaticPaths(outputRoot, workRoot),
                Objects.requireNonNull(observer, "observer"));
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

    private static void generateValidated(GenerationPaths paths, GenerationObserver observer)
            throws Exception {
        revalidateGenerationPaths(paths);
        resetDirectory(paths.workRoot());
        Path stagedCorpus = paths.workRoot().resolve("corpus");
        Files.createDirectories(stagedCorpus);
        MigrationGoldenFixtureFactory.writeSources(paths.workRoot().resolve("sources"));
        generateVos(stagedCorpus, paths.workRoot());
        generateOjn(stagedCorpus, paths.workRoot());
        generateOsu(stagedCorpus, paths.workRoot());
        normalizeExpectedPaths(stagedCorpus, paths.workRoot());
        copyTree(paths.workRoot().resolve("sources"), stagedCorpus.resolve("sources"));
        writeInputOracle(stagedCorpus);
        writeReadme(stagedCorpus);
        writeProvenance(stagedCorpus);
        writeOracleTree(stagedCorpus);
        writeFileTypes(stagedCorpus);
        writeHashes(stagedCorpus);
        revalidateGenerationPaths(paths);
        publishCorpus(stagedCorpus, paths.outputRoot(), observer);
    }

    private static void generateVos(Path stagedCorpus, Path workRoot) throws Exception {
        File vos = workRoot.resolve("sources/vos/canon.vos").toFile();
        Path expected = stagedCorpus.resolve("expected/vos");
        Files.createDirectories(expected.resolve("audio"));
        writeUtf8(expected.resolve("catalog.json"), new VosCatalogExporter().exportCatalog(vos));
        writeUtf8(expected.resolve("gameplay.json"), new VosGameplayExporter().exportGameplay(vos));
        writeUtf8(expected.resolve("audio-manifest.json"),
                new VosAudioExporter().exportAudio(vos, expected.resolve("audio").toFile()));
        writeUtf8(expected.resolve("render-metadata.json"), stableRenderMetadata());
    }

    private static void generateOjn(Path stagedCorpus, Path workRoot) throws Exception {
        File ojn = workRoot.resolve("sources/ojn/o2jam.ojn").toFile();
        Path expected = stagedCorpus.resolve("expected/ojn");
        Files.createDirectories(expected.resolve("audio"));
        writeUtf8(expected.resolve("catalog.json"), new VosCatalogExporter().exportCatalog(ojn));
        writeUtf8(expected.resolve("gameplay.json"), new VosGameplayExporter().exportGameplay(ojn, 0));
        writeUtf8(expected.resolve("audio-manifest.json"),
                new VosAudioExporter().exportAudio(ojn, expected.resolve("audio").toFile(), 0));
    }

    private static void generateOsu(Path stagedCorpus, Path workRoot) throws Exception {
        File osu = workRoot.resolve("sources/osu/seven-key.osu").toFile();
        File osz = workRoot.resolve("sources/osu/seven-key.osz").toFile();
        Path expected = stagedCorpus.resolve("expected/osu");
        Files.createDirectories(expected.resolve("audio"));
        writeUtf8(expected.resolve("osu-catalog.json"), new VosCatalogExporter().exportCatalog(osu));
        writeUtf8(expected.resolve("osz-catalog.json"), new VosCatalogExporter().exportCatalog(osz));
        writeUtf8(expected.resolve("gameplay.json"), new VosGameplayExporter().exportGameplay(osu));
        writeUtf8(expected.resolve("audio-manifest.json"),
                new VosAudioExporter().exportAudio(osu, expected.resolve("audio").toFile()));
    }

    private static void writeInputOracle(Path stagedCorpus) throws Exception {
        writeUtf8(
                stagedCorpus.resolve("expected/parser-oracle.json"),
                MigrationGoldenInputOracle.render(
                        stagedCorpus, MigrationGoldenFixtureFactory.definitions()));
    }

    private static void writeReadme(Path stagedCorpus) throws Exception {
        String readme = """
                # Java Migration Golden Corpus

                This corpus preserves Java behavior from source commit `05257da` plus determinism overlay `62ece7083ea473f02ecc9a83ee7d3e151905bf0e`, which pins Liberation Sans font bytes and provenance. `oracle-tree.txt` pins Git modes, blob identities, and paths for `src/org/open2jam`, `parsers/src`, and `src/resources`; its SHA-256 is `206614ef6d5df3ae2cd5f42ea0b1f0499cd7a3137cfbdf11c5a345fb8ff6978e`. `oracle-files.sha256` independently pins raw file bytes and filesystem-executable modes; its SHA-256 is `b1e093eaf4dd2a28ae918d29afcccff8d40b7ad60410d1caee5219fcec74feca`.

                The 27 self-authored logical cases cover 7 VOS, 10 OJN/OJM, and 10 osu!mania/osz inputs. `expected/parser-oracle.json` is generated by executing the pinned Java parsers and records stable accept/reject categories and structural metrics without exception text.

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
        writeUtf8(stagedCorpus.resolve("manifest.json"), renderProvenance(stagedCorpus));
    }

    private static String renderProvenance(Path stagedCorpus) throws Exception {
        StringBuilder manifest = new StringBuilder();
        manifest.append("{\n")
                .append("  \"schemaVersion\": 4,\n")
                .append("  \"javaSourceCommit\": \"").append(JAVA_SOURCE_COMMIT).append("\",\n")
                .append("  \"javaDeterminismOverlayCommit\": \"")
                .append(JAVA_DETERMINISM_OVERLAY_COMMIT).append("\",\n")
                .append("  \"javaDeterminismOverlayPurpose\": \"")
                .append(JAVA_DETERMINISM_OVERLAY_PURPOSE).append("\",\n")
                .append("  \"javaTool\": \"").append(JAVA_TOOL).append("\",\n")
                .append("  \"javaOraclePaths\": [\"src/org/open2jam\", \"parsers/src\", \"src/resources\"],\n")
                .append("  \"javaOracleTreeFile\": \"oracle-tree.txt\",\n")
                .append("  \"javaOracleTreeSha256\": \"").append(JAVA_ORACLE_TREE_SHA256)
                .append("\",\n")
                .append("  \"javaOracleFilesystemManifestFile\": \"oracle-files.sha256\",\n")
                .append("  \"javaOracleFilesystemManifestSha256\": \"")
                .append(JAVA_ORACLE_FILES_SHA256).append("\",\n")
                .append("  \"canonicalWorkRoot\": \"").append(CANONICAL_WORK_ROOT)
                .append("\",\n")
                .append("  \"inputOracleFile\": \"expected/parser-oracle.json\",\n")
                .append("  \"machineErrorCodes\": [\"UNSUPPORTED_FORMAT\", \"CORRUPT_CHART\", ")
                .append("\"MISSING_COMPANION\", \"MISSING_ASSET\"],\n")
                .append("  \"legacyAliases\": ")
                .append(renderLegacyAliases(stagedCorpus)).append(",\n")
                .append("  \"cases\": [\n");

        List<MigrationGoldenFixtureFactory.CaseDefinition> definitions =
                MigrationGoldenFixtureFactory.definitions();
        for (int i = 0; i < definitions.size(); i++) {
            MigrationGoldenFixtureFactory.CaseDefinition definition = definitions.get(i);
            Path source = stagedCorpus.resolve(definition.source());
            manifest.append("    {\"id\": \"")
                    .append(MigrationGoldenInputOracle.jsonEscape(definition.id()))
                    .append("\", \"format\": \"").append(definition.format())
                    .append("\", \"source\": \"")
                    .append(MigrationGoldenInputOracle.jsonEscape(definition.source()))
                    .append("\", \"sourceSha256\": \"")
                    .append(stableSha256(source, definition.source())).append("\", ")
                    .append("\"relatedFiles\": ")
                    .append(renderRelatedFiles(stagedCorpus, definition.relatedFiles()))
                    .append(", \"coverage\": ").append(renderStringList(definition.coverage()))
                    .append(", \"expectedOutcome\": \"").append(definition.expectedOutcome())
                    .append("\", \"expectedError\": ")
                    .append(definition.expectedError() == null
                            ? "null"
                            : "\"" + definition.expectedError() + "\"")
                    .append(", \"minimumEvents\": ").append(definition.minimumEvents())
                    .append(", \"provenance\": \"")
                    .append(MigrationGoldenInputOracle.jsonEscape(definition.provenance()))
                    .append("\", \"license\": \"")
                    .append(MigrationGoldenInputOracle.jsonEscape(definition.license()))
                    .append("\"}")
                    .append(i + 1 == definitions.size() ? "\n" : ",\n");
        }
        return manifest.append("  ]\n}\n").toString();
    }

    private static String renderRelatedFiles(Path stagedCorpus, List<String> relatedFiles)
            throws Exception {
        List<String> rendered = new ArrayList<>();
        for (String relative : relatedFiles) {
            Path path = stagedCorpus.resolve(relative);
            String escaped = MigrationGoldenInputOracle.jsonEscape(relative);
            if (Files.isRegularFile(path, LinkOption.NOFOLLOW_LINKS)) {
                rendered.add("{\"path\": \"" + escaped + "\", \"sha256\": \""
                        + stableSha256(path, relative) + "\"}");
            } else {
                rendered.add("{\"path\": \"" + escaped + "\", \"missing\": true}");
            }
        }
        return rendered.stream().collect(java.util.stream.Collectors.joining(", ", "[", "]"));
    }

    private static String renderLegacyAliases(Path stagedCorpus) throws Exception {
        List<String> rendered = new ArrayList<>();
        for (LegacyAlias alias : LEGACY_ALIASES) {
            rendered.add("{\"path\": \""
                    + MigrationGoldenInputOracle.jsonEscape(alias.path())
                    + "\", \"sha256\": \""
                    + stableSha256(stagedCorpus.resolve(alias.path()), alias.path())
                    + "\", \"logicalCase\": \""
                    + MigrationGoldenInputOracle.jsonEscape(alias.logicalCase())
                    + "\"}");
        }
        return rendered.stream().collect(java.util.stream.Collectors.joining(", ", "[", "]"));
    }

    private static String renderStringList(List<String> values) {
        return values.stream()
                .map(value -> "\"" + MigrationGoldenInputOracle.jsonEscape(value) + "\"")
                .collect(java.util.stream.Collectors.joining(", ", "[", "]"));
    }

    private static String stableSha256(Path path, String label) throws Exception {
        EntryState state = captureEntry(path, label);
        if (state.kind() != EntryKind.REGULAR) {
            throw new IllegalArgumentException("Golden case source is not a regular file: " + label);
        }
        return hashStableFile(path, state, label);
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

    static void verifyCanonicalManifest(Path manifest) throws Exception {
        Path absolute = manifest.toAbsolutePath().normalize();
        validateNoSymlinkAncestry(absolute, "canonical provenance manifest");
        EntryState state = captureEntry(absolute, "canonical provenance manifest");
        if (state.kind() != EntryKind.REGULAR) {
            throw new IllegalArgumentException(
                    "Canonical provenance manifest is not a regular file: " + absolute);
        }
        String actual = hashStableFile(absolute, state, "canonical provenance manifest");
        if (!CANONICAL_MANIFEST_SHA256.equals(actual)) {
            throw new IllegalArgumentException(
                    "Canonical provenance manifest digest mismatch: expected "
                            + CANONICAL_MANIFEST_SHA256 + ", got " + actual);
        }
    }

    static String hashManifest(Path root, TreeOperationObserver observer) throws Exception {
        StableTreeSnapshot snapshot = captureStableTree(root, "golden corpus");
        observer.afterInitialSnapshot("hash", snapshot.tree().root());
        String fileTypesRelative = relativePath(
                snapshot.tree().root(), snapshot.tree().root().resolve(FILE_TYPE_MANIFEST));
        EntryState fileTypesState = snapshot.tree().entries().get(fileTypesRelative);
        if (fileTypesState == null || fileTypesState.kind() != EntryKind.REGULAR) {
            throw new IllegalArgumentException(
                    "Missing regular corpus file-type manifest: "
                            + snapshot.tree().root().resolve(FILE_TYPE_MANIFEST));
        }
        observer.beforeFileRead("hash", Path.of(fileTypesRelative));
        String expectedTypes = renderFileTypeManifest(snapshot.tree());
        String actualTypes = new String(
                readStableBytes(
                        snapshot.tree().root().resolve(fileTypesRelative),
                        fileTypesState,
                        fileTypesRelative),
                StandardCharsets.UTF_8);
        if (!actualTypes.equals(expectedTypes)) {
            throw new IllegalArgumentException("Corpus file-type manifest does not match the tree");
        }

        List<Map.Entry<String, EntryState>> files = snapshot.tree().entries().entrySet().stream()
                .filter(entry -> entry.getValue().kind() == EntryKind.REGULAR)
                .filter(entry -> !entry.getKey().equals(HASH_MANIFEST))
                .sorted(Map.Entry.comparingByKey())
                .toList();

        StringBuilder hashes = new StringBuilder();
        for (Map.Entry<String, EntryState> file : files) {
            observer.beforeFileRead("hash", Path.of(file.getKey()));
            String sha256 = snapshot.regularFileSha256().get(file.getKey());
            if (sha256 == null) {
                throw new IllegalArgumentException(
                        "Missing pinned corpus file hash: " + file.getKey());
            }
            hashes.append(sha256).append("  ").append(file.getKey()).append('\n');
        }
        observer.beforeFinalSnapshot("hash", snapshot.tree().root());
        StableTreeSnapshot finalSnapshot = captureStableTree(root, "golden corpus");
        if (!snapshot.equals(finalSnapshot)) {
            throw new IllegalArgumentException(
                    "golden corpus metadata or content changed during hashing");
        }
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
        Path temporary = Files.createTempFile(
                path.getParent(), "." + path.getFileName() + ".", ".tmp");
        boolean installed = false;
        try {
            EntryState identity = captureEntry(temporary, temporary.toString());
            try (FileChannel channel = FileChannel.open(
                    temporary, StandardOpenOption.WRITE, LinkOption.NOFOLLOW_LINKS)) {
                EntryState opened = captureEntry(temporary, temporary.toString());
                if (!identity.equals(opened) || opened.kind() != EntryKind.REGULAR) {
                    throw new IllegalArgumentException(
                            "Write target changed while opening: " + temporary);
                }
                ByteBuffer buffer = ByteBuffer.wrap(bytes);
                while (buffer.hasRemaining()) {
                    channel.write(buffer);
                }
                channel.force(true);
            }
            EntryState afterWrite = captureEntry(temporary, temporary.toString());
            if (!Objects.equals(identity.fileKey(), afterWrite.fileKey())
                    || afterWrite.kind() != EntryKind.REGULAR
                    || afterWrite.size() != bytes.length) {
                throw new IllegalArgumentException(
                        "Write target changed while writing: " + temporary);
            }
            Files.move(
                    temporary,
                    path,
                    StandardCopyOption.ATOMIC_MOVE,
                    StandardCopyOption.REPLACE_EXISTING);
            installed = true;
            EntryState installedState = captureEntry(path, path.toString());
            if (!Objects.equals(identity.fileKey(), installedState.fileKey())
                    || installedState.kind() != EntryKind.REGULAR
                    || installedState.size() != bytes.length) {
                throw new IllegalArgumentException("Write target changed while installing: " + path);
            }
        } finally {
            if (!installed && Files.exists(temporary, LinkOption.NOFOLLOW_LINKS)) {
                Files.delete(temporary);
            }
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

    private static void publishCorpus(
            Path source, Path output, GenerationObserver observer) throws Exception {
        Path destination = output.toAbsolutePath().normalize();
        Path parent = destination.getParent();
        if (parent == null) {
            throw new IllegalArgumentException("Publication output has no parent: " + destination);
        }
        ensureDirectoryNoFollow(parent, "publication parent");
        String stagingPrefix = "." + destination.getFileName() + ".staging-";
        String backupPrefix = "." + destination.getFileName() + ".backup-";
        Path staging = Files.createTempDirectory(parent, stagingPrefix);
        String token = staging.getFileName().toString().substring(stagingPrefix.length());
        Path backup = parent.resolve(backupPrefix + token);
        if (Files.exists(backup, LinkOption.NOFOLLOW_LINKS) || Files.isSymbolicLink(backup)) {
            deleteOwnedTree(staging);
            throw new FileAlreadyExistsException(backup.toString());
        }

        StableTreeSnapshot previous = null;
        boolean outputBackedUp = false;
        boolean stagingInstalled = false;
        boolean publicationCommitted = false;
        Exception failure = null;
        try {
            copyTree(source, staging, observer, "publication-copy");
            validateCopiedCorpus(source, staging);

            if (Files.exists(destination, LinkOption.NOFOLLOW_LINKS)
                    || Files.isSymbolicLink(destination)) {
                previous = captureStableTree(destination, "existing publication output");
                Files.move(destination, backup, StandardCopyOption.ATOMIC_MOVE);
                outputBackedUp = true;
                observer.afterOutputBackedUp(backup, destination);
            }

            Files.move(staging, destination, StandardCopyOption.ATOMIC_MOVE);
            stagingInstalled = true;
            validateCopiedCorpus(source, destination);
            publicationCommitted = true;
        } catch (Exception thrown) {
            failure = thrown;
            try {
                if (stagingInstalled
                        && Files.exists(destination, LinkOption.NOFOLLOW_LINKS)) {
                    Files.move(destination, staging, StandardCopyOption.ATOMIC_MOVE);
                    stagingInstalled = false;
                }
                if (outputBackedUp) {
                    if (Files.exists(destination, LinkOption.NOFOLLOW_LINKS)
                            || Files.isSymbolicLink(destination)) {
                        throw new IllegalStateException(
                                "Cannot restore publication backup over an unexpected output");
                    }
                    Files.move(backup, destination, StandardCopyOption.ATOMIC_MOVE);
                    outputBackedUp = false;
                    if (previous != null
                            && !previous.equals(captureStableTree(
                                    destination, "restored publication output"))) {
                        throw new IllegalStateException(
                                "Restored publication output does not match its stable snapshot");
                    }
                }
            } catch (Exception rollbackFailure) {
                failure.addSuppressed(rollbackFailure);
            }
            throw thrown;
        } finally {
            if (!publicationCommitted) {
                cleanupOwnedTree(staging, failure);
                if (!outputBackedUp) {
                    cleanupOwnedTree(backup, failure);
                }
            }
        }

        if (outputBackedUp) {
            try {
                deleteOwnedTree(backup);
            } catch (Exception cleanupFailure) {
                throw new PublicationCleanupException(destination, backup, cleanupFailure);
            }
        }
    }

    private static void validateCopiedCorpus(Path source, Path target) throws Exception {
        verifyCanonicalManifest(source.resolve("manifest.json"));
        verifyCanonicalManifest(target.resolve("manifest.json"));
        StableTreeSnapshot sourceSnapshot = captureStableTree(source, "publication source");
        StableTreeSnapshot targetSnapshot = captureStableTree(target, "publication target");
        if (!entryKinds(sourceSnapshot.tree()).equals(entryKinds(targetSnapshot.tree()))
                || !sourceSnapshot.regularFileSha256()
                        .equals(targetSnapshot.regularFileSha256())) {
            throw new IllegalArgumentException(
                    "Publication target types or hashes do not match the source corpus");
        }
        String sourceTypes = fileTypeManifest(source);
        String targetTypes = fileTypeManifest(target);
        String sourceHashes = hashManifest(source);
        String targetHashes = hashManifest(target);
        if (!sourceTypes.equals(targetTypes)
                || !sourceHashes.equals(targetHashes)
                || !sourceTypes.equals(Files.readString(
                        source.resolve(FILE_TYPE_MANIFEST), StandardCharsets.UTF_8))
                || !targetTypes.equals(Files.readString(
                        target.resolve(FILE_TYPE_MANIFEST), StandardCharsets.UTF_8))
                || !sourceHashes.equals(Files.readString(
                        source.resolve(HASH_MANIFEST), StandardCharsets.UTF_8))
                || !targetHashes.equals(Files.readString(
                        target.resolve(HASH_MANIFEST), StandardCharsets.UTF_8))) {
            throw new IllegalArgumentException(
                    "Publication corpus manifests do not authenticate exact target bytes");
        }
    }

    private static void cleanupOwnedTree(Path root, Exception failure) throws Exception {
        if (!Files.exists(root, LinkOption.NOFOLLOW_LINKS) && !Files.isSymbolicLink(root)) {
            return;
        }
        try {
            deleteOwnedTree(root);
        } catch (Exception cleanupFailure) {
            if (failure != null) {
                failure.addSuppressed(cleanupFailure);
            } else {
                throw cleanupFailure;
            }
        }
    }

    private static void deleteOwnedTree(Path root) throws Exception {
        validateNoSymlinkAncestry(root.toAbsolutePath().normalize(), "owned cleanup tree");
        List<Path> entries = validateTree(root, "owned cleanup tree");
        for (Path path : entries.stream().sorted(Comparator.reverseOrder()).toList()) {
            Files.delete(path);
        }
    }

    static void copyTree(Path source, Path target) throws Exception {
        copyTree(source, target, TreeOperationObserver.NONE);
    }

    static void copyTree(Path source, Path target, TreeOperationObserver observer) throws Exception {
        copyTree(source, target, observer, "copy");
    }

    private static void copyTree(
            Path source, Path target, TreeOperationObserver observer, String operation)
            throws Exception {
        validateNoSymlinkAncestry(source.toAbsolutePath().normalize(), "copy source tree");
        StableTreeSnapshot sourceSnapshot = captureStableTree(source, "copy source tree");
        TreeSnapshot targetSnapshot = captureOptionalTree(target, "copy target tree");
        observer.afterInitialSnapshot(operation, sourceSnapshot.tree().root());

        Map<String, EntryKind> expectedTargetTypes = targetSnapshot == null
                ? new LinkedHashMap<>()
                : entryKinds(targetSnapshot);
        for (Map.Entry<String, EntryState> entry : sourceSnapshot.tree().entries().entrySet()) {
            EntryKind previous = expectedTargetTypes.put(entry.getKey(), entry.getValue().kind());
            if (previous != null && previous != entry.getValue().kind()) {
                throw new IllegalArgumentException(
                        "Copy source and target entry types conflict: " + entry.getKey());
            }
        }

        ensureDirectoryNoFollow(target.toAbsolutePath().normalize(), "copy target root");
        Map<String, StableFileSnapshot> copiedTargetFiles = new LinkedHashMap<>();
        for (Map.Entry<String, EntryState> entry : sourceSnapshot.tree().entries().entrySet()) {
            Path sourcePath = sourceSnapshot.tree().root().resolve(entry.getKey());
            Path destination = target.toAbsolutePath().normalize().resolve(entry.getKey());
            if (entry.getValue().kind() == EntryKind.DIRECTORY) {
                assertEntryUnchanged(sourcePath, entry.getValue(), entry.getKey());
                ensureDirectoryNoFollow(destination, "copy target directory");
            } else if (entry.getValue().kind() == EntryKind.REGULAR) {
                observer.beforeFileRead(operation, Path.of(entry.getKey()));
                copiedTargetFiles.put(
                        entry.getKey(),
                        copyStableRegularFile(
                                sourcePath,
                                new StableFileSnapshot(
                                        entry.getValue(),
                                        sourceSnapshot.regularFileSha256().get(entry.getKey())),
                                entry.getKey(),
                                destination));
            } else {
                throw unsafeTreeEntry(sourcePath);
            }
        }
        StableTreeSnapshot postCopyTarget = captureStableTree(target, "copy target tree");
        if (!entryKinds(postCopyTarget.tree()).equals(expectedTargetTypes)) {
            throw new IllegalArgumentException("Copy target tree entry set or types changed");
        }
        assertCopiedTargetFilesMatch(copiedTargetFiles, postCopyTarget);
        observer.beforeFinalSnapshot(operation, sourceSnapshot.tree().root());
        StableTreeSnapshot finalSource = captureStableTree(source, "copy source tree");
        if (!sourceSnapshot.equals(finalSource)) {
            throw new IllegalArgumentException("Copy source tree changed after snapshotting");
        }
        StableTreeSnapshot finalTarget = captureStableTree(target, "copy target tree");
        if (!postCopyTarget.equals(finalTarget)) {
            throw new IllegalArgumentException("Copy target tree changed after copying");
        }
        assertCopiedTargetFilesMatch(copiedTargetFiles, finalTarget);
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

    private static StableFileSnapshot copyStableRegularFile(
            Path source,
            StableFileSnapshot expected,
            String label,
            Path destination) throws Exception {
        EntryState before = captureEntry(source, label);
        if (!expected.state().equals(before) || before.kind() != EntryKind.REGULAR) {
            throw new IllegalArgumentException("Copy source changed before reading: " + label);
        }
        ensureDirectoryNoFollow(destination.getParent(), "copy target parent");
        MessageDigest sourceDigest = MessageDigest.getInstance("SHA-256");
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
                sourceDigest.update(buffer.asReadOnlyBuffer());
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
        String sourceSha256 = HexFormat.of().formatHex(sourceDigest.digest());
        if (!expected.sha256().equals(sourceSha256)) {
            throw new IllegalArgumentException("Copy source content changed before reading: " + label);
        }
        EntryState destinationAfter = captureEntry(destination, destination.toString());
        if (!Objects.equals(destinationIdentity.fileKey(), destinationAfter.fileKey())
                || destinationAfter.kind() != EntryKind.REGULAR
                || destinationAfter.size() != bytesRead) {
            throw new IllegalArgumentException("Copy target changed while writing: " + destination);
        }
        String destinationSha256 = hashStableFile(
                destination, destinationAfter, destination.toString());
        if (!sourceSha256.equals(destinationSha256)) {
            throw new IllegalArgumentException(
                    "Copy target content does not match source: " + destination);
        }
        return new StableFileSnapshot(destinationAfter, destinationSha256);
    }

    private static StableTreeSnapshot captureStableTree(Path root, String role) throws Exception {
        TreeSnapshot tree = captureTree(root, role);
        Map<String, String> hashes = new LinkedHashMap<>();
        for (Map.Entry<String, EntryState> entry : tree.entries().entrySet().stream()
                .filter(item -> item.getValue().kind() == EntryKind.REGULAR)
                .sorted(Map.Entry.comparingByKey())
                .toList()) {
            hashes.put(
                    entry.getKey(),
                    hashStableFile(
                            tree.root().resolve(entry.getKey()),
                            entry.getValue(),
                            entry.getKey()));
        }
        assertTreeUnchanged(tree, role);
        return new StableTreeSnapshot(tree, Map.copyOf(hashes));
    }

    private static void assertCopiedTargetFilesMatch(
            Map<String, StableFileSnapshot> copiedTargetFiles,
            StableTreeSnapshot target) {
        for (Map.Entry<String, StableFileSnapshot> copied : copiedTargetFiles.entrySet()) {
            EntryState state = target.tree().entries().get(copied.getKey());
            String sha256 = target.regularFileSha256().get(copied.getKey());
            if (!copied.getValue().equals(new StableFileSnapshot(state, sha256))) {
                throw new IllegalArgumentException(
                        "Copied target file changed after copying: " + copied.getKey());
            }
        }
    }

    private static FileChannel openDestinationNoFollow(Path destination) throws Exception {
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
        Set<TempRoot> roots = new LinkedHashSet<>();
        for (String fixedRoot : List.of("/private/tmp", "/tmp")) {
            Path lexical = Path.of(fixedRoot).toAbsolutePath().normalize();
            Path canonical = canonicalExistingTempDirectory(fixedRoot);
            if (canonical != null) {
                roots.add(new TempRoot(lexical, canonical));
                roots.add(new TempRoot(canonical, canonical));
            }
        }

        Path processTmpdir = canonicalExistingTempDirectory(PROCESS_START_TMPDIR);
        if (processTmpdir != null) {
            roots.add(new TempRoot(processTmpdir, processTmpdir));
        }
        Path relatedJvmTempRoot = canonicalRelatedJvmTempRoot(
                PROCESS_START_TMPDIR, PROCESS_START_JVM_TMPDIR);
        if (relatedJvmTempRoot != null) {
            roots.add(new TempRoot(relatedJvmTempRoot, relatedJvmTempRoot));
        }
        return new ArrayList<>(roots);
    }

    static Path canonicalRelatedJvmTempRoot(String processTmpdir, String javaTmpdir)
            throws Exception {
        Path canonicalProcessTmpdir = canonicalExistingTempDirectory(processTmpdir);
        Path canonicalJvmTempRoot = canonicalExistingTempDirectory(javaTmpdir);
        Path processTmpdirName = canonicalProcessTmpdir == null
                ? null
                : canonicalProcessTmpdir.getFileName();
        boolean approvedDirectChild = processTmpdirName != null
                && canonicalJvmTempRoot != null
                && canonicalJvmTempRoot.equals(canonicalProcessTmpdir.getParent())
                && processTmpdirName.toString().startsWith(CONTEXT_PROCESS_TMPDIR_PREFIX)
                && processTmpdirName.toString().length() > CONTEXT_PROCESS_TMPDIR_PREFIX.length();
        if (canonicalProcessTmpdir == null || canonicalJvmTempRoot == null
                || (!canonicalProcessTmpdir.equals(canonicalJvmTempRoot)
                        && !approvedDirectChild)) {
            return null;
        }
        return canonicalJvmTempRoot;
    }

    private static Path canonicalExistingTempDirectory(String candidate) throws Exception {
        if (candidate == null || candidate.isEmpty()) {
            return null;
        }
        final Path lexical;
        try {
            lexical = Path.of(candidate);
        } catch (InvalidPathException invalidPath) {
            return null;
        }
        if (!lexical.isAbsolute()) {
            return null;
        }
        Path normalized = lexical.normalize();
        if (!Files.isDirectory(normalized)) {
            return null;
        }
        Path canonical = normalized.toRealPath();
        return canonical.getParent() == null ? null : canonical;
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

    interface GenerationObserver extends TreeOperationObserver {
        GenerationObserver NONE = new GenerationObserver() {
        };

        default void afterOutputBackedUp(Path backup, Path destination) throws Exception {
        }
    }

    static final class PublicationCleanupException extends IOException {
        private final Path backupPath;

        PublicationCleanupException(Path destination, Path backupPath, Exception cause) {
            super("Published corpus remains installed at " + destination
                    + "; old backup cleanup failed at " + backupPath, cause);
            this.backupPath = backupPath;
        }

        Path backupPath() {
            return backupPath;
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

    private record StableFileSnapshot(EntryState state, String sha256) {
    }

    private record StableTreeSnapshot(
            TreeSnapshot tree, Map<String, String> regularFileSha256) {
    }

    record GenerationPaths(
            Path outputRoot, Path workRoot, Path projectRoot, boolean cli) {
    }

    private record TempRoot(Path lexicalRoot, Path canonicalRoot) {
    }

    private record LegacyAlias(String path, String logicalCase) {
    }
}
