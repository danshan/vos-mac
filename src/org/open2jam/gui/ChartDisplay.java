package org.open2jam.gui;

import java.util.Comparator;
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
            case OSU:
                return "osu!mania";
            case NONE:
            default:
                return "";
        }
    }

    public static Comparator<String> levelComparator() {
        return new Comparator<String>() {
            public int compare(String left, String right) {
                return compareLevels(left, right);
            }
        };
    }

    public static int compareLevels(String left, String right) {
        Integer leftLevel = parseLevel(left);
        Integer rightLevel = parseLevel(right);

        if (leftLevel != null && rightLevel != null) {
            return leftLevel.compareTo(rightLevel);
        }
        if (leftLevel != null) {
            return -1;
        }
        if (rightLevel != null) {
            return 1;
        }
        if (left == null && right == null) {
            return 0;
        }
        if (left == null) {
            return 1;
        }
        if (right == null) {
            return -1;
        }
        return left.compareTo(right);
    }

    private static Integer parseLevel(String level) {
        if (level == null) {
            return null;
        }
        try {
            return Integer.valueOf(level);
        } catch (NumberFormatException ignored) {
            return null;
        }
    }
}
