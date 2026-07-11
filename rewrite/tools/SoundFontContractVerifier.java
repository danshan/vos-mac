import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.URI;
import java.net.URISyntaxException;
import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.FileAlreadyExistsException;
import java.nio.file.FileVisitOption;
import java.nio.file.FileVisitResult;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.nio.file.SimpleFileVisitor;
import java.nio.file.StandardOpenOption;
import java.nio.file.StandardCopyOption;
import java.nio.file.attribute.BasicFileAttributes;
import java.nio.file.attribute.FileTime;
import java.security.MessageDigest;
import java.util.EnumSet;
import java.util.HashMap;
import java.util.HashSet;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.regex.Pattern;

public final class SoundFontContractVerifier {
    private static final long MANIFEST_SIZE_CAP = 64L * 1024L;
    private static final long ASSET_SIZE_CAP = 512L * 1024L * 1024L;
    private static final long LICENSE_SIZE_CAP = 1024L * 1024L;
    private static final long APPROVAL_SIZE_CAP = 256L * 1024L;
    private static final int SNAPSHOT_CLEANUP_ENTRY_CAP = 4096;
    private static final int SNAPSHOT_CLEANUP_DEPTH_CAP = 512;
    private static final Pattern SHA256 = Pattern.compile("[0-9a-f]{64}");
    private static final Pattern COMMIT = Pattern.compile("[0-9a-f]{40}");
    private static final Pattern PORTABLE_PATH =
            Pattern.compile("[A-Za-z0-9][A-Za-z0-9._/-]{0,511}");
    private static final Pattern ASSET_NAME =
            Pattern.compile("[A-Za-z0-9][A-Za-z0-9 ._+()'-]{0,127}");
    private static final Pattern VERSION =
            Pattern.compile("[A-Za-z0-9][A-Za-z0-9._+-]{0,63}");
    private static final List<String> MANIFEST_KEYS = List.of(
            "asset.path",
            "asset.name",
            "asset.version",
            "asset.size",
            "asset.sha256",
            "source.url",
            "source.commit",
            "license.path",
            "license.size",
            "license.sha256",
            "license.url",
            "approval.path",
            "approval.size",
            "approval.sha256",
            "approval.id");

    private SoundFontContractVerifier() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 3) {
            throw failure(
                    "usage: SoundFontContractVerifier <manifest> <payload-root> <snapshot-root>");
        }
        Path snapshot = verify(
                Path.of(args[0]).toAbsolutePath().normalize(),
                Path.of(args[1]).toAbsolutePath().normalize(),
                Path.of(args[2]).toAbsolutePath().normalize(),
                VerificationObserver.NONE);
        System.out.printf("SoundFont snapshot verified: %s.%n", snapshot);
    }

    static Path verify(
            Path manifestPath,
            Path payloadRoot,
            Path snapshotRoot,
            VerificationObserver observer)
            throws Exception {
        return verify(
                manifestPath,
                payloadRoot,
                snapshotRoot,
                observer,
                SnapshotPublisher.ATOMIC);
    }

    static Path verify(
            Path manifestPath,
            Path payloadRoot,
            Path snapshotRoot,
            VerificationObserver observer,
            SnapshotPublisher publisher)
            throws Exception {
        Objects.requireNonNull(manifestPath, "manifestPath");
        Objects.requireNonNull(payloadRoot, "payloadRoot");
        Objects.requireNonNull(snapshotRoot, "snapshotRoot");
        Objects.requireNonNull(observer, "observer");
        Objects.requireNonNull(publisher, "publisher");

        Path manifest = canonicalInput(manifestPath, "manifest");
        Path root = canonicalInput(payloadRoot, "payload root");
        Path snapshot = canonicalInput(snapshotRoot, "snapshot root");
        EntryState snapshotParentGuard = validateSnapshotPaths(manifest, root, snapshot);

        EntryState manifestState = captureEntry(manifest, "manifest");
        if (manifestState.kind() != EntryKind.REGULAR) {
            throw failure("manifest is not a regular file: " + manifest);
        }
        StableRead manifestRead = readStableBytes(
                manifest, manifestState, MANIFEST_SIZE_CAP, "manifest");
        Contract contract = parseManifest(decodeUtf8(manifestRead.bytes()));
        observer.afterManifestRead();
        StableTreeSnapshot initial = captureStableTree(root, contract);
        validateExpectedFiles(initial, contract);
        observer.afterInitialSnapshot();
        return buildAndPublishSnapshot(
                manifestRead,
                root,
                snapshot,
                snapshotParentGuard,
                contract,
                observer,
                publisher);
    }

    private static Path canonicalInput(Path input, String label) {
        Path absolute = input.toAbsolutePath();
        Path normalized = absolute.normalize();
        if (!absolute.equals(normalized)) {
            throw failure("[SNAPSHOT_PATH] " + label + " must be canonical: " + input);
        }
        return normalized;
    }

    private static EntryState validateSnapshotPaths(
            Path manifest, Path payloadRoot, Path snapshotRoot) {
        validateNoSymlinkAncestry(manifest);
        validateNoSymlinkAncestry(payloadRoot);
        try {
            validateNoSymlinkAncestry(snapshotRoot);
        } catch (IllegalStateException exception) {
            throw failure("[SNAPSHOT_PATH] snapshot path ancestry is unsafe", exception);
        }
        if (overlaps(manifest, payloadRoot)
                || overlaps(manifest, snapshotRoot)
                || overlaps(payloadRoot, snapshotRoot)) {
            throw failure("[SNAPSHOT_PATH] manifest, payload, and snapshot paths must not overlap");
        }
        if (Files.exists(snapshotRoot, LinkOption.NOFOLLOW_LINKS)
                || Files.isSymbolicLink(snapshotRoot)) {
            throw failure("[SNAPSHOT_PATH] requested snapshot must not exist: " + snapshotRoot);
        }
        Path parent = snapshotRoot.getParent();
        if (parent == null) {
            throw failure("[SNAPSHOT_PATH] snapshot root must have a parent");
        }
        EntryState parentState;
        try {
            parentState = captureEntry(parent, "snapshot parent");
        } catch (IllegalStateException exception) {
            throw failure("[SNAPSHOT_PATH] snapshot parent must exist and be inspectable", exception);
        }
        if (parentState.kind() != EntryKind.DIRECTORY) {
            throw failure("[SNAPSHOT_PATH] snapshot parent is not a directory: " + parent);
        }
        try {
            if (!parent.toRealPath(LinkOption.NOFOLLOW_LINKS).equals(parent)) {
                throw failure("[SNAPSHOT_PATH] snapshot parent must be canonical: " + parent);
            }
        } catch (IOException exception) {
            throw failure("[SNAPSHOT_PATH] unable to resolve snapshot parent", exception);
        }
        return parentState;
    }

    private static boolean overlaps(Path left, Path right) {
        return left.startsWith(right) || right.startsWith(left);
    }

    private static Path buildAndPublishSnapshot(
            StableRead manifestRead,
            Path payloadRoot,
            Path snapshotRoot,
            EntryState snapshotParentGuard,
            Contract contract,
            VerificationObserver observer,
            SnapshotPublisher publisher)
            throws Exception {
        Path staging = createOwnedStaging(snapshotRoot, snapshotParentGuard);
        EntryState guard = captureEntry(staging, "snapshot staging root");
        SnapshotShape shape = snapshotShape(contract, manifestRead);
        boolean published = false;
        Exception primaryFailure = null;
        try {
            try {
                requireSnapshotParentGuard(snapshotRoot, snapshotParentGuard);
                validateNoSymlinkAncestry(staging);
                buildSnapshot(
                        manifestRead, payloadRoot, staging, contract, observer);
            } catch (Exception exception) {
                throw phaseFailure("SNAPSHOT_BUILD", "unable to build verified snapshot", exception);
            }

            SnapshotState first;
            try {
                observer.beforeSnapshotVerification(staging);
                int maxDepth = observer.snapshotMaxDepth(shape.maxDepth());
                int maxEntries = observer.snapshotMaxEntries(shape.maxEntries());
                if (maxDepth < 1
                        || maxDepth > shape.maxDepth()
                        || maxEntries < 1
                        || maxEntries > shape.maxEntries()) {
                    throw failure("snapshot traversal limits may only tighten fixed ceilings");
                }
                first = verifySnapshot(staging, shape, maxDepth, maxEntries);
                SnapshotState second = verifySnapshot(
                        staging, shape, maxDepth, maxEntries);
                if (!first.equals(second)) {
                    throw failure("completed snapshot changed during final verification");
                }
            } catch (Exception exception) {
                throw phaseFailure("SNAPSHOT_VERIFY", "completed snapshot verification failed", exception);
            }

            try {
                requireSnapshotParentGuard(snapshotRoot, snapshotParentGuard);
                if (Files.exists(snapshotRoot, LinkOption.NOFOLLOW_LINKS)
                        || Files.isSymbolicLink(snapshotRoot)) {
                    throw failure("requested snapshot appeared before publication");
                }
                publisher.publish(staging, snapshotRoot);
                published = true;
            } catch (Exception exception) {
                throw phaseFailure("SNAPSHOT_PUBLISH", "atomic snapshot publication failed", exception);
            }
            return snapshotRoot.toRealPath(LinkOption.NOFOLLOW_LINKS);
        } catch (Exception exception) {
            primaryFailure = exception;
            throw exception;
        } finally {
            if (!published) {
                try {
                    deleteOwnedStaging(staging, guard, shape);
                } catch (Exception cleanupFailure) {
                    IllegalStateException residueFailure = failure(
                            "[SNAPSHOT_CLEANUP] owned staging residue retained: " + staging,
                            cleanupFailure);
                    if (primaryFailure != null) {
                        primaryFailure.addSuppressed(residueFailure);
                    } else {
                        throw residueFailure;
                    }
                }
            }
        }
    }

    private static Path createOwnedStaging(
            Path snapshotRoot, EntryState snapshotParentGuard) {
        Path parent = snapshotRoot.getParent();
        requireSnapshotParentGuard(snapshotRoot, snapshotParentGuard);
        String prefix = "." + snapshotRoot.getFileName() + ".staging-";
        for (int attempt = 0; attempt < 16; attempt++) {
            Path candidate = parent.resolve(prefix + UUID.randomUUID());
            try {
                return Files.createDirectory(candidate);
            } catch (FileAlreadyExistsException ignored) {
                // Retry with a fresh unguessable sibling name.
            } catch (IOException exception) {
                throw failure("[SNAPSHOT_BUILD] unable to create snapshot staging directory", exception);
            }
        }
        throw failure("[SNAPSHOT_BUILD] unable to allocate unique snapshot staging directory");
    }

    private static void requireSnapshotParentGuard(
            Path snapshotRoot, EntryState expected) {
        Path parent = snapshotRoot.getParent();
        try {
            validateNoSymlinkAncestry(parent);
            EntryState actual = captureEntry(parent, "snapshot parent");
            if (expected.kind() != EntryKind.DIRECTORY
                    || actual.kind() != EntryKind.DIRECTORY
                    || !expected.fileKey().equals(actual.fileKey())) {
                throw failure("snapshot parent identity changed");
            }
        } catch (IllegalStateException exception) {
            throw failure("[SNAPSHOT_PATH] snapshot parent changed", exception);
        }
    }

    private static void buildSnapshot(
            StableRead manifestRead,
            Path payloadRoot,
            Path staging,
            Contract contract,
            VerificationObserver observer)
            throws Exception {
        Files.createDirectory(staging.resolve("payload"));
        expectedPayloadDirectories(contract).stream()
                .filter(path -> !path.isEmpty())
                .sorted((left, right) -> Integer.compare(
                        Path.of(left).getNameCount(), Path.of(right).getNameCount()))
                .forEach(relative -> createSnapshotDirectory(
                        staging.resolve("payload").resolve(relative)));

        writeCreateNew(
                staging.resolve("contract.manifest"),
                manifestRead.bytes(),
                MANIFEST_SIZE_CAP,
                "manifest snapshot");
        String manifestSnapshotSha = hashStableFile(
                staging.resolve("contract.manifest"),
                captureEntry(staging.resolve("contract.manifest"), "manifest snapshot"),
                MANIFEST_SIZE_CAP,
                "manifest snapshot");
        if (!manifestRead.sha256().equals(manifestSnapshotSha)) {
            throw failure("manifest snapshot SHA-256 mismatch");
        }

        for (ExpectedFile expected : contract.files()) {
            copyVerifiedSource(
                    payloadRoot.resolve(expected.relativePath()),
                    staging.resolve("payload").resolve(expected.relativePath()),
                    expected,
                    observer);
        }
        observer.beforeMarkerWrite();
        byte[] marker = markerBytes(manifestRead.sha256());
        writeCreateNew(
                staging.resolve("snapshot.marker"), marker, marker.length, "snapshot marker");
    }

    private static Set<String> expectedPayloadDirectories(Contract contract) {
        Set<String> directories = new HashSet<>();
        for (ExpectedFile file : contract.files()) {
            Path parent = Path.of(file.relativePath()).getParent();
            while (parent != null) {
                directories.add(portable(parent));
                parent = parent.getParent();
            }
        }
        return directories;
    }

    private static void createSnapshotDirectory(Path directory) {
        try {
            Files.createDirectory(directory);
        } catch (IOException exception) {
            throw failure("unable to create snapshot directory: " + directory, exception);
        }
    }

    private static void writeCreateNew(
            Path destination, byte[] bytes, long cap, String label) throws Exception {
        if (bytes.length > cap) {
            throw failure(label + " exceeds hard cap of " + cap + " bytes");
        }
        try (FileChannel output = FileChannel.open(
                destination, StandardOpenOption.CREATE_NEW, StandardOpenOption.WRITE)) {
            ByteBuffer buffer = ByteBuffer.wrap(bytes);
            while (buffer.hasRemaining()) {
                output.write(buffer);
            }
        }
    }

    private static void copyVerifiedSource(
            Path source,
            Path destination,
            ExpectedFile expected,
            VerificationObserver observer)
            throws Exception {
        EntryState before = captureEntry(source, expected.relativePath());
        if (before.kind() != EntryKind.REGULAR || before.size() != expected.size()) {
            throw failure("[SOURCE_CONTENT] source metadata mismatch for "
                    + expected.relativePath());
        }
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        long copied = 0L;
        try (FileChannel input = FileChannel.open(
                        source, StandardOpenOption.READ, LinkOption.NOFOLLOW_LINKS);
                FileChannel output = FileChannel.open(
                        destination,
                        StandardOpenOption.CREATE_NEW,
                        StandardOpenOption.WRITE)) {
            EntryState afterOpen = captureEntry(source, expected.relativePath());
            if (!before.equals(afterOpen)) {
                throw failure("[SOURCE_CONTENT] source changed while opening: "
                        + expected.relativePath());
            }
            observer.afterSourceOpen(expected.relativePath());
            ByteBuffer buffer = ByteBuffer.allocateDirect(64 * 1024);
            int count;
            while ((count = input.read(buffer)) != -1) {
                if (count == 0) {
                    continue;
                }
                if (copied > expected.sizeCap() - count) {
                    throw failure("[SOURCE_CONTENT] source exceeds hard cap: "
                            + expected.relativePath());
                }
                copied += count;
                buffer.flip();
                digest.update(buffer.asReadOnlyBuffer());
                while (buffer.hasRemaining()) {
                    output.write(buffer);
                }
                buffer.clear();
            }
        } catch (IllegalStateException exception) {
            throw exception;
        } catch (Exception exception) {
            throw failure("[SOURCE_CONTENT] unable to copy source: "
                    + expected.relativePath(), exception);
        }
        String actualSha = HexFormat.of().formatHex(digest.digest());
        if (copied != expected.size() || !actualSha.equals(expected.sha256())) {
            throw failure("[SOURCE_CONTENT] source bytes do not match manifest: "
                    + expected.relativePath());
        }
    }

    private static byte[] markerBytes(String manifestSha256) {
        return ("soundfont-snapshot-v1\nmanifest.sha256=" + manifestSha256 + "\n")
                .getBytes(StandardCharsets.UTF_8);
    }

    private static SnapshotShape snapshotShape(
            Contract contract, StableRead manifestRead) {
        Map<String, SnapshotExpectedFile> files = new LinkedHashMap<>();
        files.put(
                "contract.manifest",
                new SnapshotExpectedFile(
                        manifestRead.bytes().length,
                        manifestRead.sha256(),
                        MANIFEST_SIZE_CAP));
        for (ExpectedFile expected : contract.files()) {
            files.put(
                    "payload/" + expected.relativePath(),
                    new SnapshotExpectedFile(
                            expected.size(), expected.sha256(), expected.sizeCap()));
        }
        byte[] marker = markerBytes(manifestRead.sha256());
        files.put(
                "snapshot.marker",
                new SnapshotExpectedFile(
                        marker.length, sha256(marker), marker.length));

        Set<String> directories = new HashSet<>();
        directories.add("");
        for (String relative : files.keySet()) {
            Path parent = Path.of(relative).getParent();
            while (parent != null) {
                directories.add(portable(parent));
                parent = parent.getParent();
            }
        }
        int maxDepth = files.keySet().stream()
                .mapToInt(relative -> Path.of(relative).getNameCount())
                .max()
                .orElse(1);
        return new SnapshotShape(
                Map.copyOf(files),
                Set.copyOf(directories),
                maxDepth,
                files.size() + directories.size());
    }

    private static String sha256(byte[] bytes) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(bytes));
        } catch (Exception exception) {
            throw failure("unable to compute SHA-256", exception);
        }
    }

    private static SnapshotState verifySnapshot(
            Path root, SnapshotShape shape, int maxDepth, int maxEntries)
            throws Exception {
        TreeSnapshot initial = captureSnapshotTree(root, shape, maxDepth, maxEntries);
        Map<String, String> hashes = new LinkedHashMap<>();
        for (Map.Entry<String, SnapshotExpectedFile> entry : shape.files().entrySet()) {
            EntryState state = initial.entries().get(entry.getKey());
            SnapshotExpectedFile expected = entry.getValue();
            if (state == null
                    || state.kind() != EntryKind.REGULAR
                    || state.size() != expected.size()) {
                throw failure("snapshot metadata mismatch for: " + entry.getKey());
            }
            String actual = hashStableFile(
                    root.resolve(entry.getKey()), state, expected.sizeCap(), entry.getKey());
            if (!actual.equals(expected.sha256())) {
                throw failure("snapshot SHA-256 mismatch for: " + entry.getKey());
            }
            hashes.put(entry.getKey(), actual);
        }
        TreeSnapshot afterHashes = captureSnapshotTree(root, shape, maxDepth, maxEntries);
        if (!initial.equals(afterHashes)) {
            throw failure("snapshot tree changed while verifying");
        }
        return new SnapshotState(initial, Map.copyOf(hashes));
    }

    private static TreeSnapshot captureSnapshotTree(
            Path root, SnapshotShape shape, int maxDepth, int maxEntries)
            throws Exception {
        Map<String, EntryState> entries = new LinkedHashMap<>();
        int[] count = {0};
        try {
            Files.walkFileTree(
                    root,
                    EnumSet.noneOf(FileVisitOption.class),
                    maxDepth,
                    new SimpleFileVisitor<>() {
                        @Override
                        public FileVisitResult preVisitDirectory(
                                Path directory, BasicFileAttributes attributes) {
                            String relative = portable(root.relativize(directory));
                            countSnapshotTreeEntry(count, maxEntries, relative);
                            if (!shape.directories().contains(relative)) {
                                throw failure("unexpected snapshot directory: " + relative);
                            }
                            addTreeEntry(entries, relative, captureEntry(directory, relative));
                            return FileVisitResult.CONTINUE;
                        }

                        @Override
                        public FileVisitResult visitFile(
                                Path file, BasicFileAttributes attributes) {
                            String relative = portable(root.relativize(file));
                            countSnapshotTreeEntry(count, maxEntries, relative);
                            if (attributes.isDirectory()) {
                                throw failure(
                                        "snapshot tree exceeds fixed depth ceiling at: "
                                                + relative);
                            }
                            if (!shape.files().containsKey(relative)) {
                                throw failure("unexpected snapshot file: " + relative);
                            }
                            EntryState state = captureEntry(file, relative);
                            if (state.kind() != EntryKind.REGULAR) {
                                throw failure("snapshot file is not regular: " + relative);
                            }
                            addTreeEntry(entries, relative, state);
                            return FileVisitResult.CONTINUE;
                        }

                        @Override
                        public FileVisitResult visitFileFailed(
                                Path file, IOException exception) {
                            throw failure("unable to inspect snapshot entry: " + file, exception);
                        }
                    });
        } catch (IOException exception) {
            throw failure("unable to enumerate snapshot tree", exception);
        }
        if (!entries.keySet().equals(union(shape.directories(), shape.files().keySet()))) {
            throw failure("snapshot tree does not match exact layout");
        }
        return new TreeSnapshot(Map.copyOf(entries));
    }

    private static void countSnapshotTreeEntry(
            int[] count, int maximum, String relative) {
        count[0]++;
        if (count[0] > maximum) {
            throw failure("snapshot tree exceeds fixed entry ceiling at: " + relative);
        }
    }

    private static Set<String> union(Set<String> left, Set<String> right) {
        Set<String> result = new HashSet<>(left);
        result.addAll(right);
        return result;
    }

    private static void deleteOwnedStaging(
            Path staging, EntryState guard, SnapshotShape shape) throws Exception {
        if (!Files.exists(staging, LinkOption.NOFOLLOW_LINKS)
                && !Files.isSymbolicLink(staging)) {
            return;
        }
        EntryState current = captureEntry(staging, "snapshot staging cleanup root");
        if (guard.kind() != EntryKind.DIRECTORY
                || current.kind() != EntryKind.DIRECTORY
                || !guard.fileKey().equals(current.fileKey())) {
            throw failure("staging guard mismatch; residue retained: " + staging);
        }
        int[] count = {0};
        Files.walkFileTree(
                staging,
                EnumSet.noneOf(FileVisitOption.class),
                Math.max(shape.maxDepth() + 2, SNAPSHOT_CLEANUP_DEPTH_CAP),
                new SimpleFileVisitor<>() {
                    @Override
                    public FileVisitResult preVisitDirectory(
                            Path directory, BasicFileAttributes attributes) {
                        count[0]++;
                        if (count[0] > SNAPSHOT_CLEANUP_ENTRY_CAP) {
                            throw failure("staging cleanup exceeded bounded entry ceiling; "
                                    + "residue retained: " + staging);
                        }
                        return FileVisitResult.CONTINUE;
                    }

                    @Override
                    public FileVisitResult visitFile(
                            Path file, BasicFileAttributes attributes) throws IOException {
                        count[0]++;
                        if (count[0] > SNAPSHOT_CLEANUP_ENTRY_CAP) {
                            throw failure("staging cleanup exceeded bounded entry ceiling; "
                                    + "residue retained: " + staging);
                        }
                        Files.delete(file);
                        return FileVisitResult.CONTINUE;
                    }

                    @Override
                    public FileVisitResult postVisitDirectory(
                            Path directory, IOException exception) throws IOException {
                        if (exception != null) {
                            throw exception;
                        }
                        Files.delete(directory);
                        return FileVisitResult.CONTINUE;
                    }
                });
    }

    private static IllegalStateException phaseFailure(
            String phase, String message, Exception cause) {
        if (cause instanceof IllegalStateException illegal
                && illegal.getMessage() != null
                && illegal.getMessage().matches(".*\\[[A-Z_]+].*")) {
            return illegal;
        }
        return failure(
                "[" + phase + "] " + message + ": " + cause.getMessage(), cause);
    }

    private static Contract parseManifest(String content) {
        if (content.indexOf('\r') >= 0) {
            throw failure("manifest must use LF line endings");
        }
        if (!content.endsWith("\n")) {
            throw failure("manifest must end with exactly one LF");
        }
        String[] lines = content.split("\n", -1);
        int expectedLineCount = MANIFEST_KEYS.size() + 2;
        if (lines.length != expectedLineCount || !lines[lines.length - 1].isEmpty()) {
            throw failure("manifest must contain the exact canonical line set");
        }
        if (!"soundfont-contract-v1".equals(lines[0])) {
            throw failure("unsupported or non-canonical manifest header");
        }

        Map<String, String> values = new LinkedHashMap<>();
        for (int index = 0; index < MANIFEST_KEYS.size(); index++) {
            String key = MANIFEST_KEYS.get(index);
            String prefix = key + "=";
            String line = lines[index + 1];
            if (!line.startsWith(prefix)) {
                throw failure("missing, unknown, duplicate, or out-of-order key: " + key);
            }
            String value = line.substring(prefix.length());
            if (value.isEmpty() || value.indexOf('=') >= 0) {
                throw failure("empty or non-canonical value for: " + key);
            }
            values.put(key, value);
        }

        String assetName = requirePattern(
                "asset.name", values.get("asset.name"), ASSET_NAME);
        String assetVersion = requirePattern(
                "asset.version", values.get("asset.version"), VERSION);
        String commit = requirePattern(
                "source.commit", values.get("source.commit"), COMMIT);
        validateSourceUrl(values.get("source.url"), commit);
        validateHttpsUrl(values.get("license.url"), "license.url");
        ExpectedFile asset = expectedFile(
                "asset",
                values.get("asset.path"),
                values.get("asset.size"),
                values.get("asset.sha256"),
                ASSET_SIZE_CAP);
        ExpectedFile license = expectedFile(
                "license",
                values.get("license.path"),
                values.get("license.size"),
                values.get("license.sha256"),
                LICENSE_SIZE_CAP);
        ExpectedFile approval = expectedFile(
                "approval",
                values.get("approval.path"),
                values.get("approval.size"),
                values.get("approval.sha256"),
                APPROVAL_SIZE_CAP);
        validateApprovalId(values.get("approval.id"), approval.sha256());
        List<ExpectedFile> files = List.of(asset, license, approval);
        validateDistinctPaths(files);
        return new Contract(assetName, assetVersion, asset, files);
    }

    private static ExpectedFile expectedFile(
            String kind,
            String pathValue,
            String sizeValue,
            String sha256,
            long sizeCap) {
        String relativePath = parseRelativePath(pathValue);
        long size = parseSize(kind + ".size", sizeValue, sizeCap);
        requirePattern(kind + ".sha256", sha256, SHA256);
        return new ExpectedFile(kind, relativePath, size, sha256, sizeCap);
    }

    private static String parseRelativePath(String value) {
        if (!PORTABLE_PATH.matcher(value).matches()
                || value.startsWith("/")
                || value.endsWith("/")
                || value.contains("\\")
                || value.contains("//")) {
            throw failure("path must be canonical relative POSIX: " + value);
        }
        String[] components = value.split("/", -1);
        for (String component : components) {
            if (component.isEmpty() || component.equals(".") || component.equals("..")) {
                throw failure("path must be canonical relative POSIX: " + value);
            }
        }
        Path path;
        try {
            path = Path.of(value);
        } catch (RuntimeException exception) {
            throw failure("invalid payload path: " + value, exception);
        }
        if (path.isAbsolute()
                || !path.equals(path.normalize())
                || !portable(path).equals(value)) {
            throw failure("path must be canonical relative POSIX: " + value);
        }
        return value;
    }

    private static void validateDistinctPaths(List<ExpectedFile> files) {
        Set<String> exact = new HashSet<>();
        Map<String, String> caseFoldedPrefixes = new HashMap<>();
        for (ExpectedFile file : files) {
            if (!exact.add(file.relativePath())) {
                throw failure("declared payload paths must be distinct: "
                        + file.relativePath());
            }
            StringBuilder exactPrefix = new StringBuilder();
            StringBuilder foldedPrefix = new StringBuilder();
            for (String component : file.relativePath().split("/")) {
                if (!exactPrefix.isEmpty()) {
                    exactPrefix.append('/');
                    foldedPrefix.append('/');
                }
                exactPrefix.append(component);
                foldedPrefix.append(component.toLowerCase(Locale.ROOT));
                String previous = caseFoldedPrefixes.putIfAbsent(
                        foldedPrefix.toString(), exactPrefix.toString());
                if (previous != null && !previous.equals(exactPrefix.toString())) {
                    throw failure("path components must not collide by case: "
                            + previous + " and " + exactPrefix);
                }
            }
        }
    }

    private static long parseSize(String key, String value, long cap) {
        if (value == null || !value.matches("[1-9][0-9]*")) {
            throw failure("non-canonical positive decimal for: " + key);
        }
        long size;
        try {
            size = Long.parseLong(value);
        } catch (NumberFormatException exception) {
            throw failure("size overflows signed 64-bit range for: " + key, exception);
        }
        if (size > cap) {
            throw failure(key + " exceeds hard cap of " + cap + " bytes");
        }
        return size;
    }

    private static String requirePattern(String key, String value, Pattern pattern) {
        if (value == null || !pattern.matcher(value).matches()) {
            throw failure("non-canonical value for: " + key);
        }
        return value;
    }

    private static void validateApprovalId(String value, String approvalSha256) {
        String expected = "owner-risk-acceptance:sha256:" + approvalSha256;
        if (!expected.equals(value)) {
            throw failure("approval.id must bind exact approval SHA-256");
        }
    }

    private static void validateSourceUrl(String value, String commit) {
        URI uri = validateHttpsUrl(value, "source.url");
        int commitSegments = 0;
        for (String segment : uri.getRawPath().split("/", -1)) {
            if (segment.equals(commit)) {
                commitSegments++;
            }
        }
        if (commitSegments != 1) {
            throw failure("source.url must contain source.commit as one exact path segment");
        }
    }

    private static URI validateHttpsUrl(String value, String key) {
        if (value == null || !StandardCharsets.US_ASCII.newEncoder().canEncode(value)) {
            throw failure(key + " must be canonical ASCII HTTPS");
        }
        URI uri;
        try {
            uri = new URI(value);
        } catch (URISyntaxException exception) {
            throw failure("invalid URI for: " + key, exception);
        }
        String rawPath = uri.getRawPath();
        if (!uri.isAbsolute()
                || !"https".equals(uri.getScheme())
                || uri.getHost() == null
                || uri.getHost().isEmpty()
                || !uri.getHost().equals(uri.getHost().toLowerCase(Locale.ROOT))
                || uri.getRawUserInfo() != null
                || uri.getRawQuery() != null
                || uri.getRawFragment() != null
                || rawPath == null
                || rawPath.isEmpty()
                || rawPath.indexOf('%') >= 0
                || !uri.normalize().equals(uri)
                || !uri.toASCIIString().equals(value)) {
            throw failure(key
                    + " must be canonical HTTPS without userinfo, query, fragment, or dot segments");
        }
        if (uri.getPort() != -1 || !uri.getRawAuthority().equals(uri.getHost())) {
            throw failure(key + " must not contain an explicit or empty port");
        }
        String[] segments = rawPath.split("/", -1);
        for (int index = 1; index < segments.length; index++) {
            if (segments[index].isEmpty()) {
                throw failure(key + " contains an empty path segment");
            }
        }
        return uri;
    }

    private static void validateExactTree(TreeSnapshot tree, Contract contract) {
        Set<String> expectedFiles = new HashSet<>();
        Set<String> expectedDirectories = new HashSet<>();
        expectedDirectories.add("");
        for (ExpectedFile file : contract.files()) {
            expectedFiles.add(file.relativePath());
            Path parent = Path.of(file.relativePath()).getParent();
            while (parent != null) {
                expectedDirectories.add(portable(parent));
                parent = parent.getParent();
            }
        }

        Set<String> actualFiles = new HashSet<>();
        Set<String> actualDirectories = new HashSet<>();
        for (Map.Entry<String, EntryState> entry : tree.entries().entrySet()) {
            if (entry.getValue().kind() == EntryKind.REGULAR) {
                actualFiles.add(entry.getKey());
            } else {
                actualDirectories.add(entry.getKey());
            }
        }
        if (!actualFiles.equals(expectedFiles) || !actualDirectories.equals(expectedDirectories)) {
            throw failure("payload tree does not match the exact declared file set; files="
                    + setDifference(expectedFiles, actualFiles)
                    + ", extraFiles=" + setDifference(actualFiles, expectedFiles)
                    + ", directories=" + setDifference(expectedDirectories, actualDirectories)
                    + ", extraDirectories="
                    + setDifference(actualDirectories, expectedDirectories));
        }
    }

    private static Set<String> setDifference(Set<String> left, Set<String> right) {
        Set<String> difference = new HashSet<>(left);
        difference.removeAll(right);
        return difference;
    }

    private static void validateExpectedFiles(
            StableTreeSnapshot snapshot, Contract contract) {
        for (ExpectedFile expected : contract.files()) {
            EntryState state = snapshot.tree().entries().get(expected.relativePath());
            if (state == null || state.kind() != EntryKind.REGULAR) {
                throw failure("missing regular payload file: " + expected.relativePath());
            }
            if (state.size() != expected.size()) {
                throw failure("size mismatch for " + expected.relativePath()
                        + ": expected " + expected.size() + ", got " + state.size());
            }
            String actualSha = snapshot.regularFileSha256().get(expected.relativePath());
            if (!expected.sha256().equals(actualSha)) {
                throw failure("SHA-256 mismatch for " + expected.relativePath());
            }
        }
    }

    private static StableTreeSnapshot captureStableTree(Path root, Contract contract)
            throws Exception {
        validateNoSymlinkAncestry(root);
        TreeSnapshot initial = captureTree(root, contract);
        validateExactTree(initial, contract);
        Map<String, String> hashes = new LinkedHashMap<>();
        for (ExpectedFile expected : contract.files()) {
            hashes.put(
                    expected.relativePath(),
                    hashStableFile(
                            root.resolve(expected.relativePath()),
                            initial.entries().get(expected.relativePath()),
                            expected.sizeCap(),
                            expected.relativePath()));
        }
        TreeSnapshot afterHashes = captureTree(root, contract);
        if (!initial.equals(afterHashes)) {
            throw failure("payload tree changed while taking a stable snapshot");
        }
        return new StableTreeSnapshot(initial, Map.copyOf(hashes));
    }

    private static TreeSnapshot captureTree(Path root, Contract contract) throws Exception {
        EntryState rootState = captureEntry(root, "payload root");
        if (rootState.kind() != EntryKind.DIRECTORY) {
            throw failure("payload root is not a directory: " + root);
        }
        ExpectedTree expected = expectedTree(contract);
        Map<String, EntryState> entries = new LinkedHashMap<>();
        int[] entryCount = {0};
        try {
            Files.walkFileTree(
                    root,
                    EnumSet.noneOf(FileVisitOption.class),
                    expected.maxDepth(),
                    new SimpleFileVisitor<>() {
                        @Override
                        public FileVisitResult preVisitDirectory(
                                Path directory, BasicFileAttributes attributes) {
                            String relative = portable(root.relativize(directory));
                            countTreeEntry(entryCount, expected.maxEntries(), relative);
                            if (!expected.directories().contains(relative)) {
                                throw failure("unexpected payload directory: " + relative);
                            }
                            addTreeEntry(
                                    entries,
                                    relative,
                                    captureEntry(directory, relative));
                            return FileVisitResult.CONTINUE;
                        }

                        @Override
                        public FileVisitResult visitFile(
                                Path file, BasicFileAttributes attributes) {
                            String relative = portable(root.relativize(file));
                            countTreeEntry(entryCount, expected.maxEntries(), relative);
                            if (!expected.files().contains(relative)) {
                                throw failure("unexpected payload file: " + relative);
                            }
                            EntryState state = captureEntry(file, relative);
                            if (state.kind() != EntryKind.REGULAR) {
                                throw failure("payload file is not regular: " + relative);
                            }
                            addTreeEntry(entries, relative, state);
                            return FileVisitResult.CONTINUE;
                        }

                        @Override
                        public FileVisitResult visitFileFailed(
                                Path file, IOException exception) {
                            throw failure("unable to inspect payload entry: " + file, exception);
                        }

                        @Override
                        public FileVisitResult postVisitDirectory(
                                Path directory, IOException exception) {
                            if (exception != null) {
                                throw failure(
                                        "unable to finish payload directory: " + directory,
                                        exception);
                            }
                            return FileVisitResult.CONTINUE;
                        }
                    });
        } catch (IOException exception) {
            throw failure("unable to enumerate payload root", exception);
        }
        TreeSnapshot snapshot = new TreeSnapshot(Map.copyOf(entries));
        validateExactTree(snapshot, contract);
        return snapshot;
    }

    private static ExpectedTree expectedTree(Contract contract) {
        Set<String> files = new HashSet<>();
        Set<String> directories = new HashSet<>();
        directories.add("");
        int maxDepth = 0;
        for (ExpectedFile file : contract.files()) {
            files.add(file.relativePath());
            Path path = Path.of(file.relativePath());
            maxDepth = Math.max(maxDepth, path.getNameCount());
            Path parent = path.getParent();
            while (parent != null) {
                directories.add(portable(parent));
                parent = parent.getParent();
            }
        }
        return new ExpectedTree(
                Set.copyOf(files),
                Set.copyOf(directories),
                maxDepth,
                files.size() + directories.size());
    }

    private static void countTreeEntry(int[] count, int maximum, String relative) {
        count[0]++;
        if (count[0] > maximum) {
            throw failure("payload tree exceeds fixed entry ceiling at: " + relative);
        }
    }

    private static void addTreeEntry(
            Map<String, EntryState> entries, String relative, EntryState state) {
        EntryState previous = entries.put(relative, state);
        if (previous != null) {
            throw failure("duplicate payload entry: " + relative);
        }
    }

    private static EntryState captureEntry(Path path, String label) {
        try {
            BasicFileAttributes before = readAttributes(path);
            EntryKind kind = entryKind(before, label);
            BasicFileAttributes after = readAttributes(path);
            EntryState first = entryState(kind, before, label);
            EntryState second = entryState(entryKind(after, label), after, label);
            if (!first.equals(second)) {
                throw failure("filesystem entry changed while snapshotting: " + label);
            }
            return second;
        } catch (IOException exception) {
            throw failure("unable to snapshot filesystem entry: " + label, exception);
        }
    }

    private static BasicFileAttributes readAttributes(Path path) throws IOException {
        return Files.readAttributes(
                path, BasicFileAttributes.class, LinkOption.NOFOLLOW_LINKS);
    }

    private static EntryKind entryKind(BasicFileAttributes attributes, String label) {
        if (attributes.isDirectory()) {
            return EntryKind.DIRECTORY;
        }
        if (attributes.isRegularFile()) {
            return EntryKind.REGULAR;
        }
        if (attributes.isSymbolicLink()) {
            throw failure("symbolic link is not allowed: " + label);
        }
        throw failure("special file is not allowed: " + label);
    }

    private static EntryState entryState(
            EntryKind kind, BasicFileAttributes attributes, String label) {
        Object fileKey = attributes.fileKey();
        if (fileKey == null) {
            throw failure("filesystem identity is unavailable for: " + label);
        }
        return new EntryState(
                kind, fileKey, attributes.size(), attributes.lastModifiedTime());
    }

    private static StableRead readStableBytes(
            Path path, EntryState expected, long sizeCap, String label) throws Exception {
        if (expected.size() > sizeCap) {
            throw failure(label + " exceeds hard cap of " + sizeCap + " bytes");
        }
        EntryState before = captureEntry(path, label);
        if (!expected.equals(before) || before.kind() != EntryKind.REGULAR) {
            throw failure(label + " changed before reading");
        }
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        ByteArrayOutputStream output = new ByteArrayOutputStream(
                Math.toIntExact(Math.min(before.size(), 16L * 1024L)));
        long bytesRead = 0L;
        try (FileChannel channel = FileChannel.open(
                path, StandardOpenOption.READ, LinkOption.NOFOLLOW_LINKS)) {
            EntryState afterOpen = captureEntry(path, label);
            if (!before.equals(afterOpen)) {
                throw failure(label + " changed while opening");
            }
            ByteBuffer buffer = ByteBuffer.allocate(16 * 1024);
            while (channel.read(buffer) != -1) {
                int count = buffer.position();
                if (count == 0) {
                    continue;
                }
                if (bytesRead > sizeCap - count) {
                    throw failure(label + " exceeds hard cap while reading");
                }
                digest.update(buffer.array(), 0, count);
                output.write(buffer.array(), 0, count);
                bytesRead += count;
                buffer.clear();
            }
        }
        EntryState after = captureEntry(path, label);
        if (!before.equals(after) || bytesRead != before.size()) {
            throw failure(label + " changed while reading");
        }
        return new StableRead(
                output.toByteArray(), HexFormat.of().formatHex(digest.digest()));
    }

    private static String hashStableFile(
            Path path, EntryState expected, long sizeCap, String label) throws Exception {
        if (expected == null || expected.kind() != EntryKind.REGULAR) {
            throw failure("missing regular file before hashing: " + label);
        }
        if (expected.size() > sizeCap) {
            throw failure(label + " exceeds hard cap of " + sizeCap + " bytes");
        }
        EntryState before = captureEntry(path, label);
        if (!expected.equals(before)) {
            throw failure("file changed before hashing: " + label);
        }
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        long bytesRead = 0L;
        try (FileChannel channel = FileChannel.open(
                path, StandardOpenOption.READ, LinkOption.NOFOLLOW_LINKS)) {
            EntryState afterOpen = captureEntry(path, label);
            if (!before.equals(afterOpen)) {
                throw failure("file changed while opening: " + label);
            }
            ByteBuffer buffer = ByteBuffer.allocateDirect(64 * 1024);
            int count;
            while ((count = channel.read(buffer)) != -1) {
                if (count == 0) {
                    continue;
                }
                if (bytesRead > sizeCap - count) {
                    throw failure(label + " exceeds hard cap while hashing");
                }
                bytesRead += count;
                buffer.flip();
                digest.update(buffer);
                buffer.clear();
            }
        }
        EntryState after = captureEntry(path, label);
        if (!before.equals(after) || bytesRead != before.size()) {
            throw failure("file changed while hashing: " + label);
        }
        return HexFormat.of().formatHex(digest.digest());
    }

    private static String decodeUtf8(byte[] bytes) {
        try {
            return StandardCharsets.UTF_8.newDecoder()
                    .onMalformedInput(CodingErrorAction.REPORT)
                    .onUnmappableCharacter(CodingErrorAction.REPORT)
                    .decode(ByteBuffer.wrap(bytes))
                    .toString();
        } catch (CharacterCodingException exception) {
            throw failure("manifest is not canonical UTF-8", exception);
        }
    }

    private static void validateNoSymlinkAncestry(Path absolutePath) {
        Path current = absolutePath.getRoot();
        if (current == null) {
            throw failure("path must be absolute: " + absolutePath);
        }
        try {
            for (Path component : absolutePath) {
                current = current.resolve(component);
                if (Files.isSymbolicLink(current)) {
                    throw failure("path contains a symbolic-link component: " + current);
                }
                if (Files.exists(current, LinkOption.NOFOLLOW_LINKS)
                        && !current.equals(absolutePath)
                        && !Files.isDirectory(current, LinkOption.NOFOLLOW_LINKS)) {
                    throw failure("path contains a non-directory component: " + current);
                }
            }
        } catch (SecurityException exception) {
            throw failure("unable to validate path ancestry: " + absolutePath, exception);
        }
    }

    private static String portable(Path path) {
        return path.toString().replace(path.getFileSystem().getSeparator(), "/");
    }

    private static IllegalStateException failure(String message) {
        return new IllegalStateException(
                "SoundFont contract verification failed: " + message);
    }

    private static IllegalStateException failure(String message, Throwable cause) {
        return new IllegalStateException(
                "SoundFont contract verification failed: " + message, cause);
    }

    interface VerificationObserver {
        VerificationObserver NONE = new VerificationObserver() {
        };

        default void afterManifestRead() throws Exception {
        }

        default void afterInitialSnapshot() throws Exception {
        }

        default void afterSourceOpen(String relativePath) throws Exception {
        }

        default void beforeMarkerWrite() throws Exception {
        }

        default void beforeSnapshotVerification(Path staging) throws Exception {
        }

        default int snapshotMaxDepth(int fixedMaximum) {
            return fixedMaximum;
        }

        default int snapshotMaxEntries(int fixedMaximum) {
            return fixedMaximum;
        }
    }

    @FunctionalInterface
    interface SnapshotPublisher {
        SnapshotPublisher ATOMIC = (staging, requested) -> Files.move(
                staging, requested, StandardCopyOption.ATOMIC_MOVE);

        void publish(Path staging, Path requested) throws Exception;
    }

    private enum EntryKind {
        DIRECTORY,
        REGULAR
    }

    private record EntryState(
            EntryKind kind, Object fileKey, long size, FileTime lastModifiedTime) {
    }

    private record ExpectedFile(
            String kind, String relativePath, long size, String sha256, long sizeCap) {
    }

    private record Contract(
            String assetName,
            String assetVersion,
            ExpectedFile asset,
            List<ExpectedFile> files) {
    }

    private record TreeSnapshot(Map<String, EntryState> entries) {
    }

    private record ExpectedTree(
            Set<String> files,
            Set<String> directories,
            int maxDepth,
            int maxEntries) {
    }

    private record StableTreeSnapshot(
            TreeSnapshot tree, Map<String, String> regularFileSha256) {
    }

    private record StableRead(byte[] bytes, String sha256) {
    }

    private record SnapshotExpectedFile(long size, String sha256, long sizeCap) {
    }

    private record SnapshotShape(
            Map<String, SnapshotExpectedFile> files,
            Set<String> directories,
            int maxDepth,
            int maxEntries) {
    }

    private record SnapshotState(TreeSnapshot tree, Map<String, String> hashes) {
    }
}
