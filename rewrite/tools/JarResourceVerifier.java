import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.util.HashMap;
import java.util.HexFormat;
import java.util.Map;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;

public final class JarResourceVerifier {
    private static final Map<String, ExpectedResource> EXPECTED = Map.of(
            "resources/fonts/LiberationSans-Bold.ttf",
            new ExpectedResource(
                    137052L,
                    "361c61b82d575c5c35fd9157fda8b0194bcfcd0d88ea8521a4fb5dd53d33dddc",
                    null),
            "resources/fonts/LICENSE_LIBERATION",
            new ExpectedResource(
                    4407L,
                    "3b169ed27ce05b624bc8bf173906286150fc729bad72bda86c98aee7a4631f2f",
                    "SIL OPEN FONT LICENSE Version 1.1 - 26 February 2007"));

    private JarResourceVerifier() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 1) {
            throw new IllegalArgumentException("Usage: JarResourceVerifier <shaded-jar>");
        }
        Path jarPath = Path.of(args[0]);
        if (Files.isSymbolicLink(jarPath)
                || !Files.isRegularFile(jarPath, LinkOption.NOFOLLOW_LINKS)) {
            throw new IllegalArgumentException("Packaged JAR is not a regular file: " + jarPath);
        }

        Map<String, Integer> counts = new HashMap<>();
        try (JarFile jar = new JarFile(jarPath.toFile(), true)) {
            var entries = jar.entries();
            while (entries.hasMoreElements()) {
                JarEntry entry = entries.nextElement();
                ExpectedResource expected = EXPECTED.get(entry.getName());
                if (expected == null) {
                    continue;
                }
                counts.merge(entry.getName(), 1, Integer::sum);
                if (entry.isDirectory()) {
                    throw new IllegalStateException("JAR resource is a directory: " + entry.getName());
                }
                long declaredSize = entry.getSize();
                if (declaredSize != expected.size()) {
                    throw new IllegalStateException(
                            "JAR resource size mismatch for " + entry.getName()
                                    + ": expected " + expected.size() + ", got " + declaredSize);
                }
                MessageDigest messageDigest = MessageDigest.getInstance("SHA-256");
                byte[] requiredTextBytes = expected.requiredText() == null
                        ? null
                        : new byte[Math.toIntExact(expected.size())];
                long bytesRead = 0L;
                try (InputStream input = jar.getInputStream(entry)) {
                    byte[] buffer = new byte[8192];
                    int read;
                    while ((read = input.read(buffer)) != -1) {
                        if (read == 0) {
                            continue;
                        }
                        if (bytesRead > expected.size() - read) {
                            throw new IllegalStateException(
                                    "JAR resource exceeds pinned byte ceiling for "
                                            + entry.getName());
                        }
                        messageDigest.update(buffer, 0, read);
                        if (requiredTextBytes != null) {
                            System.arraycopy(
                                    buffer, 0, requiredTextBytes, Math.toIntExact(bytesRead), read);
                        }
                        bytesRead += read;
                    }
                }
                if (bytesRead != expected.size()) {
                    throw new IllegalStateException(
                            "JAR resource short read for " + entry.getName()
                                    + ": expected " + expected.size() + ", got " + bytesRead);
                }
                String digest = HexFormat.of().formatHex(messageDigest.digest());
                if (!expected.sha256().equals(digest)) {
                    throw new IllegalStateException(
                            "JAR resource digest mismatch for " + entry.getName()
                                    + ": expected " + expected.sha256() + ", got " + digest);
                }
                if (expected.requiredText() != null
                        && !new String(requiredTextBytes, StandardCharsets.UTF_8)
                                .contains(expected.requiredText())) {
                    throw new IllegalStateException(
                            "JAR license identity mismatch for " + entry.getName());
                }
            }
        }

        for (String resource : EXPECTED.keySet()) {
            int count = counts.getOrDefault(resource, 0);
            if (count == 0) {
                throw new IllegalStateException("Missing JAR resource: " + resource);
            }
            if (count != 1) {
                throw new IllegalStateException(
                        "Duplicate JAR resource: " + resource + " (count=" + count + ")");
            }
        }

        System.out.printf("Packaged font and license verified in %s.%n", jarPath);
    }

    private record ExpectedResource(long size, String sha256, String requiredText) {
    }
}
