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
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.nio.file.attribute.BasicFileAttributes;
import java.nio.file.attribute.FileTime;
import java.security.MessageDigest;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.regex.Pattern;
import java.util.stream.Stream;

public final class SoundFontContractVerifier {
    private static final long MANIFEST_SIZE_CAP = 64L * 1024L;
    private static final long ASSET_SIZE_CAP = 512L * 1024L * 1024L;
    private static final long LICENSE_SIZE_CAP = 1024L * 1024L;
    private static final long APPROVAL_SIZE_CAP = 256L * 1024L;
    private static final Pattern SHA256 = Pattern.compile("[0-9a-f]{64}");
    private static final Pattern COMMIT = Pattern.compile("[0-9a-f]{40}");
    private static final Pattern PORTABLE_PATH =
            Pattern.compile("[A-Za-z0-9][A-Za-z0-9._/-]{0,511}");
    private static final Pattern ASSET_NAME =
            Pattern.compile("[A-Za-z0-9][A-Za-z0-9 ._+()'-]{0,127}");
    private static final Pattern VERSION =
            Pattern.compile("[A-Za-z0-9][A-Za-z0-9._+-]{0,63}");
    private static final Pattern APPROVAL_ID =
            Pattern.compile("[A-Z0-9][A-Z0-9._-]{7,127}");
    private static final List<String> PLACEHOLDER_APPROVAL_TOKENS = List.of(
            "TBD",
            "TODO",
            "PENDING",
            "PLACEHOLDER",
            "UNKNOWN",
            "NONE",
            "UNAPPROVED",
            "TEST",
            "DUMMY",
            "EXAMPLE");
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
        if (args.length != 2) {
            throw failure(
                    "usage: SoundFontContractVerifier <manifest> <payload-root>");
        }
        verify(
                Path.of(args[0]).toAbsolutePath().normalize(),
                Path.of(args[1]).toAbsolutePath().normalize(),
                VerificationObserver.NONE);
    }

    static void verify(Path manifestPath, Path payloadRoot, VerificationObserver observer)
            throws Exception {
        Objects.requireNonNull(manifestPath, "manifestPath");
        Objects.requireNonNull(payloadRoot, "payloadRoot");
        Objects.requireNonNull(observer, "observer");

        Path manifest = manifestPath.toAbsolutePath().normalize();
        Path root = payloadRoot.toAbsolutePath().normalize();
        if (manifest.equals(root) || manifest.startsWith(root)) {
            throw failure("manifest must be outside the dedicated payload root");
        }
        validateNoSymlinkAncestry(manifest);
        validateNoSymlinkAncestry(root);

        EntryState manifestState = captureEntry(manifest, "manifest");
        if (manifestState.kind() != EntryKind.REGULAR) {
            throw failure("manifest is not a regular file: " + manifest);
        }
        StableRead manifestRead = readStableBytes(
                manifest, manifestState, MANIFEST_SIZE_CAP, "manifest");
        Contract contract = parseManifest(decodeUtf8(manifestRead.bytes()));
        observer.afterManifestRead();

        StableTreeSnapshot initialTree = captureStableTree(root, contract);
        validateExpectedFiles(initialTree, contract);
        observer.afterInitialSnapshot();

        observer.beforeFinalSnapshot();
        StableTreeSnapshot finalTree = captureStableTree(root, contract);
        if (!initialTree.equals(finalTree)) {
            throw failure(treeDifference(initialTree, finalTree));
        }
        validateNoSymlinkAncestry(manifest);
        validateNoSymlinkAncestry(root);
        EntryState finalManifestState = captureEntry(manifest, "manifest");
        String finalManifestSha = hashStableFile(
                manifest, finalManifestState, MANIFEST_SIZE_CAP, "manifest");
        if (!manifestState.equals(finalManifestState)
                || !manifestRead.sha256().equals(finalManifestSha)) {
            throw failure("manifest changed during verification");
        }

        System.out.printf(
                "SoundFont contract verified: %s %s (%d bytes).%n",
                contract.assetName(), contract.assetVersion(), contract.asset().size());
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
        validateApprovalId(values.get("approval.id"));

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

    private static void validateApprovalId(String value) {
        requirePattern("approval.id", value, APPROVAL_ID);
        Set<String> tokens = new HashSet<>();
        for (String token : value.toUpperCase(Locale.ROOT).split("[._-]+")) {
            if (!tokens.add(token)) {
                throw failure("approval.id contains a duplicate token: " + token);
            }
        }
        for (String token : tokens) {
            String normalized = token.replaceAll("[0-9]", "");
            for (String placeholder : PLACEHOLDER_APPROVAL_TOKENS) {
                if (normalized.startsWith(placeholder)) {
                    throw failure("approval.id contains a placeholder token: "
                            + placeholder);
                }
            }
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
        TreeSnapshot initial = captureTree(root);
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
        TreeSnapshot afterHashes = captureTree(root);
        if (!initial.equals(afterHashes)) {
            throw failure("payload tree changed while taking a stable snapshot");
        }
        return new StableTreeSnapshot(initial, Map.copyOf(hashes));
    }

    private static TreeSnapshot captureTree(Path root) throws Exception {
        EntryState rootState = captureEntry(root, "payload root");
        if (rootState.kind() != EntryKind.DIRECTORY) {
            throw failure("payload root is not a directory: " + root);
        }
        List<Path> paths;
        try (Stream<Path> stream = Files.walk(root)) {
            paths = stream.sorted(Comparator.comparing(Path::toString)).toList();
        } catch (IOException exception) {
            throw failure("unable to enumerate payload root", exception);
        }
        Map<String, EntryState> entries = new LinkedHashMap<>();
        for (Path path : paths) {
            String relative = portable(root.relativize(path));
            EntryState previous = entries.put(relative, captureEntry(path, relative));
            if (previous != null) {
                throw failure("duplicate payload entry: " + relative);
            }
        }
        return new TreeSnapshot(Map.copyOf(entries));
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

    private static String treeDifference(
            StableTreeSnapshot expected, StableTreeSnapshot actual) {
        Set<String> expectedPaths = expected.tree().entries().keySet();
        Set<String> actualPaths = actual.tree().entries().keySet();
        Set<String> missing = setDifference(expectedPaths, actualPaths);
        Set<String> extra = setDifference(actualPaths, expectedPaths);
        if (!missing.isEmpty() || !extra.isEmpty()) {
            return "payload tree changed during verification; missing=" + missing
                    + ", extra=" + extra;
        }
        List<String> changed = expectedPaths.stream()
                .filter(path -> !expected.tree().entries().get(path)
                                .equals(actual.tree().entries().get(path))
                        || !Objects.equals(
                                expected.regularFileSha256().get(path),
                                actual.regularFileSha256().get(path)))
                .sorted()
                .toList();
        return "payload tree entries changed during verification: " + changed;
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

        default void beforeFinalSnapshot() throws Exception {
        }
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

    private record StableTreeSnapshot(
            TreeSnapshot tree, Map<String, String> regularFileSha256) {
    }

    private record StableRead(byte[] bytes, String sha256) {
    }
}
