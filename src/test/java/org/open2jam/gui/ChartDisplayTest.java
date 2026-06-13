package org.open2jam.gui;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.awt.image.BufferedImage;
import java.io.File;
import java.util.ArrayList;
import org.junit.jupiter.api.Test;
import org.open2jam.parsers.Chart;
import org.open2jam.parsers.ChartList;
import org.open2jam.parsers.EventList;
import org.open2jam.parsers.VOSChart;

class ChartDisplayTest {
    @Test
    void displaysUnknownVosLevel() {
        VOSChart chart = new VOSChart();
        chart.markLevelUnknown();

        assertEquals("Unknown", ChartDisplay.level(chart));
    }

    @Test
    void displaysKnownVosLevel() {
        VOSChart chart = new VOSChart();
        chart.setLevel(7);

        assertEquals("7", ChartDisplay.level(chart));
    }

    @Test
    void displaysOjnFormatAsO2Jam() {
        assertEquals("O2Jam", ChartDisplay.format(new StubChart(Chart.TYPE.OJN)));
    }

    @Test
    void displaysVosFormatAsVos() {
        assertEquals("VOS", ChartDisplay.format(new VOSChart()));
    }

    @Test
    void displaysEmptyFormatForNullChart() {
        assertEquals("", ChartDisplay.format(null));
    }

    @Test
    void displaysEmptyFormatForNoneType() {
        assertEquals("", ChartDisplay.format(new StubChart(Chart.TYPE.NONE)));
    }

    @Test
    void levelComparatorSortsNumbersBeforeUnknown() {
        assertEquals(-1, Integer.signum(ChartDisplay.compareLevels("2", "10")));
        assertEquals(1, Integer.signum(ChartDisplay.compareLevels("10", "2")));
        assertEquals(-1, Integer.signum(ChartDisplay.compareLevels("10", "Unknown")));
        assertEquals(1, Integer.signum(ChartDisplay.compareLevels("Unknown", "2")));
        assertEquals(0, ChartDisplay.compareLevels("Unknown", "Unknown"));
    }

    @Test
    void levelComparatorUsesStableFallbackOrdering() {
        assertEquals(-1, Integer.signum(ChartDisplay.compareLevels("7", "abc")));
        assertEquals(-1, Integer.signum(ChartDisplay.compareLevels("7", null)));
        assertEquals(-1, Integer.signum(ChartDisplay.compareLevels("Unknown", "abc")));
        assertEquals(1, Integer.signum(ChartDisplay.compareLevels(null, "7")));
        assertEquals(0, ChartDisplay.compareLevels(null, null));
    }

    @Test
    void chartTableModelExposesFormatAtColumnOne() {
        ChartTableModel model = new ChartTableModel();
        model.addRow(new StubChart(Chart.TYPE.OJN, 4, 512, 7, "", "", ""));

        assertEquals("Level", model.getColumnName(0));
        assertEquals("Format", model.getColumnName(1));
        assertEquals("Notes", model.getColumnName(2));
        assertEquals("Keys", model.getColumnName(3));
        assertEquals(String.class, model.getColumnClass(0));
        assertEquals(String.class, model.getColumnClass(1));
        assertEquals(Integer.class, model.getColumnClass(2));
        assertEquals(Integer.class, model.getColumnClass(3));
        assertEquals("4", model.getValueAt(0, 0));
        assertEquals("O2Jam", model.getValueAt(0, 1));
        assertEquals(512, model.getValueAt(0, 2));
        assertEquals(7, model.getValueAt(0, 3));
    }

    @Test
    void chartTableModelDisplaysUnknownVosLevel() {
        ChartTableModel model = new ChartTableModel();
        VOSChart chart = new VOSChart();
        chart.markLevelUnknown();

        model.addRow(chart);

        assertEquals("Unknown", model.getValueAt(0, 0));
        assertEquals("VOS", model.getValueAt(0, 1));
    }

    @Test
    void chartListTableModelExposesFormatAtColumnTwo() {
        ChartList list = new ChartList();
        list.add(new StubChart(Chart.TYPE.VOS, 9, 640, 5, "Song", "Genre", ""));

        ChartListTableModel model = new ChartListTableModel();
        ArrayList<ChartList> rows = new ArrayList<ChartList>();
        rows.add(list);
        model.setRawList(rows);

        assertEquals("Name", model.getColumnName(0));
        assertEquals("Level", model.getColumnName(1));
        assertEquals("Format", model.getColumnName(2));
        assertEquals("Genre", model.getColumnName(3));
        assertEquals(String.class, model.getColumnClass(0));
        assertEquals(String.class, model.getColumnClass(1));
        assertEquals(String.class, model.getColumnClass(2));
        assertEquals(String.class, model.getColumnClass(3));
        assertEquals("Song", model.getValueAt(0, 0));
        assertEquals("9", model.getValueAt(0, 1));
        assertEquals("VOS", model.getValueAt(0, 2));
        assertEquals("Genre", model.getValueAt(0, 3));
    }

    private static final class StubChart extends Chart {
        private final int level;
        private final int keys;
        private final String title;
        private final String genre;
        private final int notes;

        private StubChart(TYPE type) {
            this(type, 0, 0, 0, "", "", "");
        }

        private StubChart(TYPE type, int level, int notes, int keys, String title, String genre, String noter) {
            this.type = type;
            this.level = level;
            this.notes = notes;
            this.keys = keys;
            this.title = title;
            this.genre = genre;
            this.noter = noter;
        }

        public File getSource() {
            return null;
        }

        public int getLevel() {
            return level;
        }

        public int getKeys() {
            return keys;
        }

        public int getPlayers() {
            return 0;
        }

        public String getTitle() {
            return title;
        }

        public String getArtist() {
            return "";
        }

        public String getGenre() {
            return genre;
        }

        public String getNoter() {
            return noter;
        }

        public double getBPM() {
            return 0;
        }

        public int getNoteCount() {
            return notes;
        }

        public int getDuration() {
            return 0;
        }

        public BufferedImage getCover() {
            return null;
        }

        public EventList getEvents() {
            return new EventList();
        }
    }
}
