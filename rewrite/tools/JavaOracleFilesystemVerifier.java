import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.nio.file.attribute.BasicFileAttributes;
import java.nio.file.attribute.FileTime;
import java.nio.file.attribute.PosixFilePermission;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Stream;

public final class JavaOracleFilesystemVerifier {
    private static final Pattern MANIFEST_LINE =
            Pattern.compile("^(100644|100755) ([0-9a-f]{64})  (.+)$");
    private static final Set<PosixFilePermission> EXECUTE_PERMISSIONS = Set.of(
            PosixFilePermission.OWNER_EXECUTE,
            PosixFilePermission.GROUP_EXECUTE,
            PosixFilePermission.OTHERS_EXECUTE);

    private JavaOracleFilesystemVerifier() {
    }

    public static void main(String[] args) throws Exception {
        verify(args, VerificationObserver.NONE);
    }

    static void verify(String[] args, VerificationObserver observer) throws Exception {
        if (args.length < 2) {
            throw failure("usage: JavaOracleFilesystemVerifier <manifest> <root>...");
        }

        Path projectRoot = Path.of("").toAbsolutePath().normalize();
        List<Path> oracleRoots = new ArrayList<>();
        for (int index = 1; index < args.length; index++) {
            oracleRoots.add(parseRelativePath(args[index]));
        }
        verify(projectRoot, Path.of(args[0]).toAbsolutePath().normalize(), oracleRoots, observer);
    }

    static void verify(
            Path projectRoot,
            Path manifestPath,
            List<Path> oracleRoots,
            VerificationObserver observer) throws Exception {
        Objects.requireNonNull(observer, "observer");
        Path project = projectRoot.toAbsolutePath().normalize();
        Path manifest = manifestPath.toAbsolutePath().normalize();
        validateNoSymlinkAncestry(project);
        validateNoSymlinkAncestry(manifest);

        EntryState manifestState = captureEntry(manifest, "manifest");
        if (manifestState.kind() != EntryKind.REGULAR) {
            throw failure("manifest is not a regular file: " + manifest);
        }
        byte[] manifestBytes = readStableBytes(manifest, manifestState, "manifest");
        StableFileSnapshot manifestSnapshot = new StableFileSnapshot(
                manifestState, sha256(manifestBytes));
        String manifestContent = new String(manifestBytes, StandardCharsets.UTF_8);
        Map<String, ExpectedFile> expectedFiles =
                readManifest(manifestContent, oracleRoots);
        Set<String> expectedDirectories = expectedDirectories(expectedFiles, oracleRoots);

        StableTreeSnapshot initialTree = captureStableTree(project, oracleRoots);
        observer.afterInitialSnapshot();
        Map<String, ActualFile> actualFiles = new HashMap<>();
        Set<String> actualDirectories = new HashSet<>();

        for (Map.Entry<String, EntryState> entry : initialTree.tree().entries().entrySet()) {
            String relative = entry.getKey();
            EntryState state = entry.getValue();
            if (state.kind() == EntryKind.DIRECTORY) {
                actualDirectories.add(relative);
                continue;
            }
            ExpectedFile expected = expectedFiles.get(relative);
            if (expected == null) {
                throw failure("unexpected oracle file: " + relative);
            }
            observer.beforeFileRead(relative);
            String sha256 = hashStableFile(project.resolve(relative), state, relative);
            ActualFile previous = actualFiles.put(
                    relative, new ActualFile(gitMode(state.permissions()), sha256));
            if (previous != null) {
                throw failure("duplicate oracle file: " + relative);
            }
        }

        if (!actualDirectories.equals(expectedDirectories)) {
            Set<String> missing = new HashSet<>(expectedDirectories);
            missing.removeAll(actualDirectories);
            Set<String> extra = new HashSet<>(actualDirectories);
            extra.removeAll(expectedDirectories);
            throw failure("directory set mismatch; missing=" + missing + ", extra=" + extra);
        }
        if (!actualFiles.keySet().equals(expectedFiles.keySet())) {
            Set<String> missing = new HashSet<>(expectedFiles.keySet());
            missing.removeAll(actualFiles.keySet());
            Set<String> extra = new HashSet<>(actualFiles.keySet());
            extra.removeAll(expectedFiles.keySet());
            throw failure("file set mismatch; missing=" + missing + ", extra=" + extra);
        }
        for (Map.Entry<String, ExpectedFile> entry : expectedFiles.entrySet()) {
            ActualFile actual = actualFiles.get(entry.getKey());
            ExpectedFile expected = entry.getValue();
            if (!expected.mode().equals(actual.mode())) {
                throw failure("mode mismatch for " + entry.getKey()
                        + ": expected " + expected.mode() + ", got " + actual.mode());
            }
            if (!expected.sha256().equals(actual.sha256())) {
                throw failure("raw SHA-256 mismatch for " + entry.getKey()
                        + ": expected " + expected.sha256() + ", got " + actual.sha256());
            }
        }

        observer.beforeFinalSnapshot();
        StableTreeSnapshot finalTree = captureStableTree(project, oracleRoots);
        if (!initialTree.equals(finalTree)) {
            throw failure(treeDifference(initialTree, finalTree));
        }
        EntryState finalManifestState = captureEntry(manifest, "manifest");
        StableFileSnapshot finalManifestSnapshot = new StableFileSnapshot(
                finalManifestState,
                hashStableFile(manifest, finalManifestState, "manifest"));
        if (!manifestSnapshot.equals(finalManifestSnapshot)) {
            throw failure("manifest changed during verification");
        }

        System.out.printf(
                "Java oracle filesystem gate passed: %d files, %d directories.%n",
                actualFiles.size(), actualDirectories.size());
    }

    private static Map<String, ExpectedFile> readManifest(
            String content, List<Path> oracleRoots) {
        List<String> lines = content.lines().toList();
        if (lines.isEmpty()) {
            throw failure("manifest is empty");
        }
        Map<String, ExpectedFile> files = new LinkedHashMap<>();
        String previous = null;
        for (String line : lines) {
            Matcher matcher = MANIFEST_LINE.matcher(line);
            if (!matcher.matches()) {
                throw failure("invalid manifest line: " + line);
            }
            Path relativePath = parseRelativePath(matcher.group(3));
            if (oracleRoots.stream().noneMatch(relativePath::startsWith)) {
                throw failure("manifest path is outside oracle roots: " + relativePath);
            }
            String portablePath = portable(relativePath);
            if (previous != null && previous.compareTo(portablePath) >= 0) {
                throw failure("manifest paths are not strictly sorted: " + portablePath);
            }
            previous = portablePath;
            ExpectedFile prior = files.put(
                    portablePath, new ExpectedFile(matcher.group(1), matcher.group(2)));
            if (prior != null) {
                throw failure("duplicate manifest path: " + portablePath);
            }
        }
        return files;
    }

    private static Set<String> expectedDirectories(
            Map<String, ExpectedFile> expectedFiles, List<Path> oracleRoots) {
        Set<String> directories = new HashSet<>();
        for (Path root : oracleRoots) {
            directories.add(portable(root));
        }
        for (String file : expectedFiles.keySet()) {
            Path parent = Path.of(file).getParent();
            while (parent != null) {
                Path current = parent;
                if (oracleRoots.stream().noneMatch(current::startsWith)) {
                    break;
                }
                directories.add(portable(current));
                parent = parent.getParent();
            }
        }
        return directories;
    }

    private static String gitMode(Set<PosixFilePermission> permissions) {
        boolean executable = permissions.stream().anyMatch(EXECUTE_PERMISSIONS::contains);
        return executable ? "100755" : "100644";
    }

    private static TreeSnapshot captureTree(Path projectRoot, List<Path> oracleRoots)
            throws Exception {
        Map<String, EntryState> entries = new LinkedHashMap<>();
        for (Path relativeRoot : oracleRoots) {
            Path absoluteRoot = projectRoot.resolve(relativeRoot).normalize();
            validateNoSymlinkAncestry(absoluteRoot);
            EntryState rootState = captureEntry(absoluteRoot, portable(relativeRoot));
            if (rootState.kind() != EntryKind.DIRECTORY) {
                throw failure("oracle root is not a directory: " + relativeRoot);
            }
            List<Path> rootEntries;
            try (Stream<Path> paths = Files.walk(absoluteRoot)) {
                rootEntries = paths.sorted(Comparator.comparing(Path::toString)).toList();
            }
            for (Path path : rootEntries) {
                String relative = portable(projectRoot.relativize(path));
                EntryState previous = entries.put(relative, captureEntry(path, relative));
                if (previous != null) {
                    throw failure("overlapping oracle roots contain: " + relative);
                }
            }
        }
        return new TreeSnapshot(Map.copyOf(entries));
    }

    private static StableTreeSnapshot captureStableTree(
            Path projectRoot, List<Path> oracleRoots) throws Exception {
        TreeSnapshot tree = captureTree(projectRoot, oracleRoots);
        Map<String, String> hashes = new LinkedHashMap<>();
        for (Map.Entry<String, EntryState> entry : tree.entries().entrySet()) {
            if (entry.getValue().kind() == EntryKind.REGULAR) {
                hashes.put(
                        entry.getKey(),
                        hashStableFile(
                                projectRoot.resolve(entry.getKey()),
                                entry.getValue(),
                                entry.getKey()));
            }
        }
        TreeSnapshot finalMetadata = captureTree(projectRoot, oracleRoots);
        if (!tree.equals(finalMetadata)) {
            throw failure("oracle tree changed while snapshotting stable content");
        }
        return new StableTreeSnapshot(tree, Map.copyOf(hashes));
    }

    private static EntryState captureEntry(Path path, String label) throws IOException {
        BasicFileAttributes before = readAttributes(path);
        EntryKind kind = entryKind(before, label);
        Object fileKey = before.fileKey();
        if (fileKey == null) {
            throw failure("filesystem identity is unavailable for: " + label);
        }
        Set<PosixFilePermission> permissions = Set.copyOf(
                Files.getPosixFilePermissions(path, LinkOption.NOFOLLOW_LINKS));
        BasicFileAttributes after = readAttributes(path);
        EntryState first = entryState(kind, before, permissions);
        EntryState second = entryState(entryKind(after, label), after, permissions);
        if (!first.equals(second)) {
            throw failure("filesystem entry changed while snapshotting: " + label);
        }
        return second;
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
            EntryKind kind,
            BasicFileAttributes attributes,
            Set<PosixFilePermission> permissions) {
        Object fileKey = attributes.fileKey();
        if (fileKey == null) {
            throw failure("filesystem identity became unavailable");
        }
        return new EntryState(
                kind,
                fileKey,
                attributes.size(),
                attributes.lastModifiedTime(),
                permissions);
    }

    private static String hashStableFile(Path path, EntryState expected, String label)
            throws Exception {
        EntryState before = captureEntry(path, label);
        if (!expected.equals(before) || before.kind() != EntryKind.REGULAR) {
            throw failure("oracle file changed before reading: " + label);
        }
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        long bytesRead = 0L;
        try (FileChannel channel = FileChannel.open(
                path, StandardOpenOption.READ, LinkOption.NOFOLLOW_LINKS)) {
            EntryState afterOpen = captureEntry(path, label);
            if (!before.equals(afterOpen)) {
                throw failure("oracle file changed while opening: " + label);
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
            throw failure("oracle file changed while reading: " + label);
        }
        return HexFormat.of().formatHex(digest.digest());
    }

    private static byte[] readStableBytes(Path path, EntryState expected, String label)
            throws Exception {
        EntryState before = captureEntry(path, label);
        if (!expected.equals(before) || before.kind() != EntryKind.REGULAR) {
            throw failure(label + " changed before reading");
        }
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        long bytesRead = 0L;
        try (FileChannel channel = FileChannel.open(
                path, StandardOpenOption.READ, LinkOption.NOFOLLOW_LINKS)) {
            EntryState afterOpen = captureEntry(path, label);
            if (!before.equals(afterOpen)) {
                throw failure(label + " changed while opening");
            }
            ByteBuffer buffer = ByteBuffer.allocate(16 * 1024);
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
            throw failure(label + " changed while reading");
        }
        return output.toByteArray();
    }

    private static String treeDifference(
            StableTreeSnapshot expected, StableTreeSnapshot actual) {
        Set<String> missing = new HashSet<>(expected.tree().entries().keySet());
        missing.removeAll(actual.tree().entries().keySet());
        Set<String> extra = new HashSet<>(actual.tree().entries().keySet());
        extra.removeAll(expected.tree().entries().keySet());
        if (!missing.isEmpty() || !extra.isEmpty()) {
            return "oracle tree changed during verification; missing=" + missing + ", extra=" + extra;
        }
        List<String> changed = expected.tree().entries().entrySet().stream()
                .filter(entry -> !entry.getValue().equals(
                                actual.tree().entries().get(entry.getKey()))
                        || !Objects.equals(
                                expected.regularFileSha256().get(entry.getKey()),
                                actual.regularFileSha256().get(entry.getKey())))
                .map(Map.Entry::getKey)
                .sorted()
                .toList();
        return "oracle tree entries changed during verification: " + changed;
    }

    private static String sha256(byte[] bytes) throws Exception {
        return HexFormat.of().formatHex(
                MessageDigest.getInstance("SHA-256").digest(bytes));
    }

    private static Path parseRelativePath(String value) {
        Path path = Path.of(value);
        if (path.isAbsolute() || !path.equals(path.normalize())
                || value.isEmpty() || value.indexOf('\\') >= 0) {
            throw failure("path must be normalized and relative: " + value);
        }
        return path;
    }

    private static void validateNoSymlinkAncestry(Path absolutePath) throws IOException {
        Path current = absolutePath.getRoot();
        if (current == null) {
            throw failure("path must be absolute: " + absolutePath);
        }
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
    }

    private static BasicFileAttributes readAttributes(Path path) throws IOException {
        return Files.readAttributes(
                path, BasicFileAttributes.class, LinkOption.NOFOLLOW_LINKS);
    }

    private static String portable(Path path) {
        return path.toString().replace(path.getFileSystem().getSeparator(), "/");
    }

    private static IllegalStateException failure(String message) {
        return new IllegalStateException("Java oracle filesystem verification failed: " + message);
    }

    private record ExpectedFile(String mode, String sha256) {
    }

    private record ActualFile(String mode, String sha256) {
    }

    interface VerificationObserver {
        VerificationObserver NONE = new VerificationObserver() {
        };

        default void afterInitialSnapshot() throws Exception {
        }

        default void beforeFileRead(String relativePath) throws Exception {
        }

        default void beforeFinalSnapshot() throws Exception {
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

    private record TreeSnapshot(Map<String, EntryState> entries) {
    }

    private record StableFileSnapshot(EntryState state, String sha256) {
    }

    private record StableTreeSnapshot(
            TreeSnapshot tree, Map<String, String> regularFileSha256) {
    }
}
