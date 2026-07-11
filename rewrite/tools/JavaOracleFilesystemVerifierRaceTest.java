import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.util.Comparator;
import java.util.HexFormat;
import java.util.List;

public final class JavaOracleFilesystemVerifierRaceTest {
    private JavaOracleFilesystemVerifierRaceTest() {
    }

    public static void main(String[] args) throws Exception {
        rejectsAddedEntryAfterInitialSnapshot();
        rejectsRemovedEntryBeforeFinalSnapshot();
        rejectsSameByteSymlinkReplacementBeforeRead();
        System.out.println("Java oracle filesystem race contract passed: 3 cases.");
    }

    private static void rejectsAddedEntryAfterInitialSnapshot() throws Exception {
        Fixture fixture = Fixture.create("add");
        try {
            expectFailure(() -> JavaOracleFilesystemVerifier.verify(
                    fixture.root(),
                    fixture.manifest(),
                    List.of(Path.of("oracle")),
                    new JavaOracleFilesystemVerifier.VerificationObserver() {
                        @Override
                        public void afterInitialSnapshot() throws Exception {
                            Files.writeString(
                                    fixture.oracle().resolve("z-extra.txt"),
                                    "unexpected\n",
                                    StandardCharsets.UTF_8);
                        }
                    }), "added oracle entry");
        } finally {
            fixture.delete();
        }
    }

    private static void rejectsRemovedEntryBeforeFinalSnapshot() throws Exception {
        Fixture fixture = Fixture.create("remove");
        try {
            expectFailure(() -> JavaOracleFilesystemVerifier.verify(
                    fixture.root(),
                    fixture.manifest(),
                    List.of(Path.of("oracle")),
                    new JavaOracleFilesystemVerifier.VerificationObserver() {
                        @Override
                        public void beforeFinalSnapshot() throws Exception {
                            Files.delete(fixture.oracleFile());
                        }
                    }), "removed oracle entry");
        } finally {
            fixture.delete();
        }
    }

    private static void rejectsSameByteSymlinkReplacementBeforeRead() throws Exception {
        Fixture fixture = Fixture.create("replace");
        Path external = fixture.root().resolve("external.txt");
        Files.writeString(external, "pinned\n", StandardCharsets.UTF_8);
        try {
            expectFailure(() -> JavaOracleFilesystemVerifier.verify(
                    fixture.root(),
                    fixture.manifest(),
                    List.of(Path.of("oracle")),
                    new JavaOracleFilesystemVerifier.VerificationObserver() {
                        @Override
                        public void beforeFileRead(String relativePath) throws Exception {
                            Files.delete(fixture.oracleFile());
                            Files.createSymbolicLink(fixture.oracleFile(), external);
                        }
                    }), "same-byte oracle symlink replacement");
            if (!"pinned\n".equals(Files.readString(external))) {
                throw new AssertionError("External same-byte sentinel changed");
            }
        } finally {
            fixture.delete();
        }
    }

    private static void expectFailure(ThrowingOperation operation, String description)
            throws Exception {
        try {
            operation.run();
        } catch (IllegalStateException expected) {
            if (!expected.getMessage().startsWith("Java oracle filesystem verification failed:")) {
                throw new AssertionError(description + " failed for the wrong reason", expected);
            }
            return;
        }
        throw new AssertionError(description + " unexpectedly passed");
    }

    private static String sha256(String content) throws Exception {
        return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                .digest(content.getBytes(StandardCharsets.UTF_8)));
    }

    private record Fixture(Path root, Path oracle, Path oracleFile, Path manifest) {
        static Fixture create(String name) throws Exception {
            Path root = Files.createTempDirectory("open2jam-oracle-race-" + name + "-")
                    .toRealPath();
            Path oracle = Files.createDirectories(root.resolve("oracle"));
            Path oracleFile = oracle.resolve("a-pinned.txt");
            Files.writeString(oracleFile, "pinned\n", StandardCharsets.UTF_8);
            Path manifest = root.resolve("manifest.sha256");
            Files.writeString(
                    manifest,
                    "100644 " + sha256("pinned\n") + "  oracle/a-pinned.txt\n",
                    StandardCharsets.UTF_8);
            return new Fixture(root, oracle, oracleFile, manifest);
        }

        void delete() throws Exception {
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

    @FunctionalInterface
    private interface ThrowingOperation {
        void run() throws Exception;
    }
}
