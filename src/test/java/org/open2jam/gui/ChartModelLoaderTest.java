package org.open2jam.gui;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.io.File;
import java.util.ArrayList;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.open2jam.parsers.Chart;
import org.open2jam.parsers.ChartList;
import org.open2jam.parsers.OsuFixtureFactory;

class ChartModelLoaderTest {
    @TempDir
    File tempDir;

    @Test
    void listFilesSafelyReturnsEmptyArrayWhenFileCannotBeListed() throws Exception {
        File notDirectory = new File(tempDir, "song.vos");
        assertEquals(true, notDirectory.createNewFile());

        assertEquals(0, ChartModelLoader.listFilesSafely(notDirectory).length);
    }

    @Test
    void loadsSevenKeyOsuManiaOszFromDirectoryIntoTableModel() throws Exception {
        OsuFixtureFactory.writeSevenKeyOsz(tempDir, "seven-key.osz");

        ArrayList<ChartList> charts = ChartModelLoader.loadChartLists(tempDir);

        assertEquals(1, charts.size());
        Chart chart = charts.get(0).get(0);
        assertEquals(Chart.TYPE.OSU, chart.type);
        assertEquals(7, chart.getKeys());
        assertEquals("Seven Key Fixture", chart.getTitle());
        assertEquals("osu!mania", chart.getGenre());

        ChartListTableModel model = new ChartListTableModel();
        model.setRawList(charts);
        assertEquals("osu!mania", model.getValueAt(0, 2));
        assertEquals("osu!mania", model.getValueAt(0, 3));
    }
}
