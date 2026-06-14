package org.open2jam.gui.parts;

import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import javax.swing.SwingWorker;
import org.junit.jupiter.api.Test;
import org.open2jam.gui.ChartListTableModel;
import org.open2jam.parsers.Chart;
import org.open2jam.parsers.ChartList;
import org.open2jam.parsers.VOSChart;

class MusicSelectionSelectionTest {
    @Test
    void keepsCurrentSelectionWhenRequestedRowDoesNotExistDuringReload() {
        ChartList current = new ChartList();
        ChartListTableModel model = new ChartListTableModel();
        model.setRawList(new ArrayList<ChartList>());

        ChartList resolved = MusicSelection.resolveSelectedChart(model, 0, current);

        assertSame(current, resolved);
    }

    @Test
    void resolvesSelectedHeaderToFirstChartWhenPreviousRankIsOutOfRange() {
        VOSChart onlyVosChart = new VOSChart();
        ChartList vosCharts = new ChartList();
        vosCharts.add(onlyVosChart);

        Chart resolved = MusicSelection.resolveSelectedHeader(vosCharts, 2);

        assertSame(onlyVosChart, resolved);
    }

    @Test
    void ignoresChartSelectionIndexOutsideCurrentChartList() {
        ChartList vosCharts = new ChartList();
        vosCharts.add(new VOSChart());

        assertNull(MusicSelection.resolveChartSelection(vosCharts, 2));
    }

    @Test
    void explicitDirectorySelectionBypassesCachedChartList() {
        ArrayList<ChartList> cachedCharts = new ArrayList<ChartList>();
        cachedCharts.add(new ChartList());

        assertFalse(MusicSelection.shouldUseCachedChartList(cachedCharts, true));
    }

    @Test
    void automaticDirectoryLoadCanUseCachedChartList() {
        ArrayList<ChartList> cachedCharts = new ArrayList<ChartList>();
        cachedCharts.add(new ChartList());

        assertTrue(MusicSelection.shouldUseCachedChartList(cachedCharts, false));
    }

    @Test
    void loaderCompletionCanBeDetectedFromProgressOrWorkerDoneState() {
        assertTrue(MusicSelection.isLoadCompleteEvent("progress", 100));
        assertTrue(MusicSelection.isLoadCompleteEvent("state", SwingWorker.StateValue.DONE));
        assertFalse(MusicSelection.isLoadCompleteEvent("progress", 50));
    }
}
