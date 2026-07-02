package org.open2jam.export;

import java.io.File;
import java.util.ArrayList;
import java.util.List;
import org.open2jam.parsers.Chart;
import org.open2jam.parsers.ChartList;
import org.open2jam.parsers.ChartParser;
import org.open2jam.parsers.VOSChart;

final class PlayableChartSelector {
    private PlayableChartSelector() {
    }

    static List<Chart> playableCharts(File input) {
        ChartList charts = ChartParser.parseFile(input);
        List<Chart> playable = new ArrayList<Chart>();
        if (charts == null) {
            return playable;
        }
        for (Chart chart : charts) {
            if (isPlayableChart(chart)) {
                playable.add(chart);
            }
        }
        return playable;
    }

    static Chart select(File input, int chartIndex) {
        List<Chart> playable = playableCharts(input);
        if (playable.isEmpty()) {
            throw new IllegalArgumentException("No supported gameplay chart found: " + input);
        }
        if (chartIndex < 0 || chartIndex >= playable.size()) {
            throw new IllegalArgumentException(
                    "Playable chart index out of range: " + chartIndex + " for " + input);
        }
        return playable.get(chartIndex);
    }

    static boolean isPlayableChart(Chart chart) {
        if (chart == null) {
            return false;
        }
        if (chart instanceof VOSChart) {
            return true;
        }
        if (chart.type == Chart.TYPE.OJN) {
            return chart.getKeys() == 7;
        }
        return chart.type == Chart.TYPE.OSU && chart.getKeys() == 7;
    }
}
