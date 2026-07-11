package org.open2jam.export;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.security.MessageDigest;
import java.util.Comparator;
import java.util.HexFormat;
import java.util.List;
import java.util.stream.Stream;
import org.open2jam.parsers.OjnFixtureFactory;
import org.open2jam.parsers.OsuFixtureFactory;
import org.open2jam.parsers.VosFixtureFactory;

public final class MigrationGoldenCorpusGenerator {
    public static final String JAVA_SOURCE_COMMIT = "05257da";
    public static final String JAVA_TOOL = "zulu-17.66.19.0";

    private static final String CANONICAL_WORK_ROOT = "/private/tmp/open2jam-java-golden-v1";
    private static final String MANIFEST = """
            {
              "schemaVersion": 1,
              "javaSourceCommit": "05257da",
              "javaTool": "zulu-17.66.19.0",
              "canonicalWorkRoot": "/tmp/open2jam-java-golden-v1",
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
        generate(Path.of(args[1]), Path.of(args[3]));
    }

    public static void generate(Path outputRoot, Path workRoot) throws Exception {
        resetDirectory(workRoot);
        Path stagedCorpus = workRoot.resolve("corpus");
        Files.createDirectories(stagedCorpus);
        generateVos(stagedCorpus, workRoot);
        generateOjn(stagedCorpus, workRoot);
        generateOsu(stagedCorpus, workRoot);
        normalizeExpectedPaths(stagedCorpus, workRoot);
        copyTree(workRoot.resolve("sources"), stagedCorpus.resolve("sources"));
        generateMalformedCases(stagedCorpus);
        writeReadme(stagedCorpus);
        writeProvenance(stagedCorpus);
        writeHashes(stagedCorpus);
        resetDirectory(outputRoot);
        copyTree(stagedCorpus, outputRoot);
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

                Normal tests treat this directory as read-only. Regenerate it only from the pinned Java source and toolchain with:

                ```bash
                mise exec -- bash -lc 'mvn -s "$MAVEN_SETTINGS" test-compile org.codehaus.mojo:exec-maven-plugin:3.5.0:exec -Dexec.args="--add-exports java.desktop/com.sun.media.sound=ALL-UNNAMED -classpath target/test-classes:lib/*:%classpath org.open2jam.export.MigrationGoldenCorpusGenerator --output rewrite/golden/java-migration --work-root /tmp/open2jam-java-golden-v1"'
                ```

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

    private static void writeHashes(Path stagedCorpus) throws Exception {
        writeUtf8(stagedCorpus.resolve("manifest.sha256"), hashManifest(stagedCorpus));
    }

    private static void normalizeExpectedPaths(Path stagedCorpus, Path workRoot) throws Exception {
        String actualWorkRoot = workRoot.toFile().getCanonicalPath().replace(File.separatorChar, '/');
        try (Stream<Path> paths = Files.walk(stagedCorpus.resolve("expected"))) {
            for (Path path : paths.filter(Files::isRegularFile)
                    .filter(file -> file.getFileName().toString().endsWith(".json"))
                    .toList()) {
                String content = Files.readString(path, StandardCharsets.UTF_8);
                String normalized = normalizeCatalogIds(content, actualWorkRoot)
                        .replace(actualWorkRoot, CANONICAL_WORK_ROOT);
                writeUtf8(path, normalized);
            }
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
        List<Path> files;
        try (Stream<Path> paths = Files.walk(root)) {
            files = paths.filter(Files::isRegularFile)
                    .filter(path -> !path.equals(root.resolve("manifest.sha256")))
                    .sorted(Comparator.comparing(path -> relativePath(root, path)))
                    .toList();
        }

        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        StringBuilder hashes = new StringBuilder();
        for (Path file : files) {
            String sha256 = HexFormat.of().formatHex(digest.digest(Files.readAllBytes(file)));
            hashes.append(sha256).append("  ").append(relativePath(root, file)).append('\n');
        }
        return hashes.toString();
    }

    private static String relativePath(Path root, Path path) {
        return root.relativize(path).toString().replace(File.separatorChar, '/');
    }

    private static void writeUtf8(Path path, String content) throws Exception {
        Files.createDirectories(path.getParent());
        Files.writeString(path, content, StandardCharsets.UTF_8);
    }

    private static void resetDirectory(Path root) throws Exception {
        if (Files.exists(root)) {
            try (Stream<Path> paths = Files.walk(root)) {
                for (Path path : paths.sorted(Comparator.reverseOrder()).toList()) {
                    Files.delete(path);
                }
            }
        }
        Files.createDirectories(root);
    }

    private static void copyTree(Path source, Path target) throws Exception {
        try (Stream<Path> paths = Files.walk(source)) {
            for (Path path : paths.toList()) {
                Path destination = target.resolve(source.relativize(path));
                if (Files.isDirectory(path)) {
                    Files.createDirectories(destination);
                } else {
                    Files.createDirectories(destination.getParent());
                    Files.copy(path, destination, StandardCopyOption.REPLACE_EXISTING);
                }
            }
        }
    }
}
