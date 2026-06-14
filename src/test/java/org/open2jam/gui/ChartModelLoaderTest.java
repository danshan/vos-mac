package org.open2jam.gui;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

import java.io.File;
import java.util.ArrayList;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.open2jam.parsers.Chart;
import org.open2jam.parsers.ChartList;

class ChartModelLoaderTest {
    private static final File REFERENCE_OSU_MANIA_DIR = new File(
            "/Users/honghao.shan/Downloads/L33 - Project Loved_ Best of 2025 (osu!mania)");

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
        assumeTrue(REFERENCE_OSU_MANIA_DIR.isDirectory(), "osu!mania reference directory is not available");

        ArrayList<ChartList> charts = ChartModelLoader.loadChartLists(REFERENCE_OSU_MANIA_DIR);

        assertEquals(1, charts.size());
        Chart chart = charts.get(0).get(0);
        assertEquals(Chart.TYPE.OSU, chart.type);
        assertEquals(7, chart.getKeys());
        assertEquals("\u591c\u66f2", chart.getTitle());
        assertEquals("osu!mania", chart.getGenre());

        ChartListTableModel model = new ChartListTableModel();
        model.setRawList(charts);
        assertEquals("osu!mania", model.getValueAt(0, 2));
        assertEquals("osu!mania", model.getValueAt(0, 3));
    }
}
