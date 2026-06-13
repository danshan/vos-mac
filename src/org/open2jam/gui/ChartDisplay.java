package org.open2jam.gui;

import org.open2jam.parsers.Chart;
import org.open2jam.parsers.VOSChart;

public final class ChartDisplay {
    private ChartDisplay() {
    }

    public static String level(Chart chart) {
        if (chart instanceof VOSChart) {
            VOSChart vosChart = (VOSChart) chart;
            if (!vosChart.hasKnownLevel()) {
                return "Unknown";
            }
        }
        return String.valueOf(chart.getLevel());
    }

    public static String format(Chart chart) {
        if (chart == null || chart.type == null) {
            return "";
        }

        switch (chart.type) {
            case OJN:
                return "O2Jam";
            case VOS:
                return "VOS";
            case BMS:
                return "BMS";
            case SM:
                return "SM";
            case XNT:
                return "XNT";
            case NONE:
            default:
                return "";
        }
    }
}
