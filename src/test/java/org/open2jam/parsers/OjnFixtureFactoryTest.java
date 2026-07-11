package org.open2jam.parsers;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.File;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.open2jam.parsers.utils.SampleData;

class OjnFixtureFactoryTest {
    @TempDir
    File tempDir;

    @Test
    void writesThreeChartOjnWithOnePlainOjmWavSample() throws Exception {
        OjnFixtureFactory.OjnFixture fixture = OjnFixtureFactory.writeFixture(tempDir, "o2jam");

        ChartList charts = ChartParser.parseFile(fixture.chart());

        assertNotNull(charts);
        assertEquals(3, charts.size());
        assertEquals("O2Jam Fixture", charts.get(0).getTitle());
        assertEquals(3, charts.get(0).getLevel());
        assertEquals(5, charts.get(1).getLevel());
        assertEquals(8, charts.get(2).getLevel());
        assertTrue(fixture.samples().isFile());
        assertTrue(charts.get(0).getSamples().containsKey(0));
        assertEquals(SampleData.Type.WAV_NO_HEADER, charts.get(0).getSamples().get(0).getType());
    }
}
