import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.nio.file.attribute.BasicFileAttributes;
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
        if (args.length < 2) {
            throw failure("usage: JavaOracleFilesystemVerifier <manifest> <root>...");
        }

        Path projectRoot = Path.of("").toAbsolutePath().normalize();
        validateNoSymlinkAncestry(projectRoot);
        List<Path> oracleRoots = new ArrayList<>();
        for (int index = 1; index < args.length; index++) {
            Path relativeRoot = parseRelativePath(args[index]);
            Path absoluteRoot = projectRoot.resolve(relativeRoot);
            validateNoSymlinkAncestry(absoluteRoot);
            BasicFileAttributes attributes = readAttributes(absoluteRoot);
            if (!attributes.isDirectory()) {
                throw failure("oracle root is not a directory: " + relativeRoot);
            }
            oracleRoots.add(relativeRoot);
        }

        Path manifestPath = Path.of(args[0]);
        validateNoSymlinkAncestry(manifestPath.toAbsolutePath().normalize());
        if (!Files.isRegularFile(manifestPath, LinkOption.NOFOLLOW_LINKS)) {
            throw failure("manifest is not a regular file: " + manifestPath);
        }

        Map<String, ExpectedFile> expectedFiles = readManifest(manifestPath, oracleRoots);
        Set<String> expectedDirectories = expectedDirectories(expectedFiles, oracleRoots);
        Map<String, ActualFile> actualFiles = new HashMap<>();
        Set<String> actualDirectories = new HashSet<>();

        for (Path relativeRoot : oracleRoots) {
            Path absoluteRoot = projectRoot.resolve(relativeRoot);
            List<Path> entries;
            try (Stream<Path> paths = Files.walk(absoluteRoot)) {
                entries = paths.sorted(Comparator.comparing(Path::toString)).toList();
            }
            for (Path entry : entries) {
                BasicFileAttributes attributes = readAttributes(entry);
                String relative = portable(projectRoot.relativize(entry));
                if (Files.isSymbolicLink(entry)) {
                    throw failure("symbolic link is not allowed: " + relative);
                }
                if (attributes.isDirectory()) {
                    actualDirectories.add(relative);
                    continue;
                }
                if (!attributes.isRegularFile()) {
                    throw failure("special file is not allowed: " + relative);
                }
                ExpectedFile expected = expectedFiles.get(relative);
                if (expected == null) {
                    throw failure("unexpected oracle file: " + relative);
                }
                String mode = filesystemMode(entry);
                byte[] bytes = Files.readAllBytes(entry);
                BasicFileAttributes afterRead = readAttributes(entry);
                if (!afterRead.isRegularFile()
                        || !Objects.equals(attributes.fileKey(), afterRead.fileKey())
                        || attributes.size() != afterRead.size()
                        || !attributes.lastModifiedTime().equals(afterRead.lastModifiedTime())) {
                    throw failure("oracle file changed while reading: " + relative);
                }
                String sha256 = HexFormat.of().formatHex(
                        MessageDigest.getInstance("SHA-256").digest(bytes));
                ActualFile previous = actualFiles.put(relative, new ActualFile(mode, sha256));
                if (previous != null) {
                    throw failure("duplicate oracle file: " + relative);
                }
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

        System.out.printf(
                "Java oracle filesystem gate passed: %d files, %d directories.%n",
                actualFiles.size(), actualDirectories.size());
    }

    private static Map<String, ExpectedFile> readManifest(
            Path manifestPath, List<Path> oracleRoots) throws Exception {
        List<String> lines = Files.readAllLines(manifestPath, StandardCharsets.UTF_8);
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

    private static String filesystemMode(Path path) throws IOException {
        Set<PosixFilePermission> permissions =
                Files.getPosixFilePermissions(path, LinkOption.NOFOLLOW_LINKS);
        boolean executable = permissions.stream().anyMatch(EXECUTE_PERMISSIONS::contains);
        return executable ? "100755" : "100644";
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
}
