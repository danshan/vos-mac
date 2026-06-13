package org.open2jam.gui.parts;

import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertNull;

import java.util.ArrayList;
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
}
