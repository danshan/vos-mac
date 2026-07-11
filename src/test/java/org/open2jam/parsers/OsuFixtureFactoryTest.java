package org.open2jam.parsers;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

import java.io.File;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class OsuFixtureFactoryTest {
    @TempDir
    File tempDir;

    @Test
    void writesPlayableDirectoryAndArchiveFixtures() throws Exception {
        File chart = OsuFixtureFactory.writeSevenKeyOsu(tempDir, "seven-key.osu");
        File archive = OsuFixtureFactory.writeSevenKeyOsz(tempDir, "seven-key.osz");

        ChartList chartResult = ChartParser.parseFile(chart);
        ChartList archiveResult = ChartParser.parseFile(archive);

        assertNotNull(chartResult);
        assertNotNull(archiveResult);
        assertEquals(1, chartResult.size());
        assertEquals(1, archiveResult.size());
        assertEquals(7, chartResult.get(0).getKeys());
        assertEquals("Seven Key Fixture", archiveResult.get(0).getTitle());
    }
}
