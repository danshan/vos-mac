package org.open2jam.gui;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.awt.image.BufferedImage;
import java.io.File;
import org.junit.jupiter.api.Test;
import org.open2jam.parsers.Chart;
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

    private static final class StubChart extends Chart {
        private StubChart(TYPE type) {
            this.type = type;
        }

        public File getSource() {
            return null;
        }

        public int getLevel() {
            return 0;
        }

        public int getKeys() {
            return 0;
        }

        public int getPlayers() {
            return 0;
        }

        public String getTitle() {
            return "";
        }

        public String getArtist() {
            return "";
        }

        public String getGenre() {
            return "";
        }

        public String getNoter() {
            return "";
        }

        public double getBPM() {
            return 0;
        }

        public int getNoteCount() {
            return 0;
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
