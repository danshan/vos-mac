package org.open2jam.export;

import java.io.File;
import java.io.IOException;

final class ExportPaths {
    private ExportPaths() {
    }

    static File ensureDirectory(File directory) throws IOException {
        if (directory == null) {
            throw new IllegalArgumentException("Export directory is required");
        }
        if (!directory.exists() && !directory.mkdirs()) {
            throw new IOException("Unable to create export directory: " + directory);
        }
        if (!directory.isDirectory()) {
            throw new IOException("Export path is not a directory: " + directory);
        }
        return directory;
    }

    static File child(File directory, String fileName) {
        return new File(directory, fileName);
    }
}
