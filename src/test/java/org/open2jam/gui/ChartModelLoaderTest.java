package org.open2jam.gui;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.io.File;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class ChartModelLoaderTest {
    @TempDir
    File tempDir;

    @Test
    void listFilesSafelyReturnsEmptyArrayWhenFileCannotBeListed() throws Exception {
        File notDirectory = new File(tempDir, "song.vos");
        assertEquals(true, notDirectory.createNewFile());

        assertEquals(0, ChartModelLoader.listFilesSafely(notDirectory).length);
    }
}
