package org.open2jam.parsers;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.File;
import org.junit.jupiter.api.Test;

class VOSChartTest {
    @Test
    void storesKnownLevelMetadata() {
        VOSChart chart = new VOSChart();
        chart.setSource(new File("known.vos"));
        chart.setTitle("Canon in D");
        chart.setArtist("Pachelbel");
        chart.setGenre("Classical");
        chart.setNoter("ReVanTis");
        chart.setDuration(123);
        chart.setLevel(7);
        chart.setNoteCount(11);

        assertEquals(Chart.TYPE.VOS, chart.type);
        assertEquals("Canon in D", chart.getTitle());
        assertEquals("Pachelbel", chart.getArtist());
        assertEquals("Classical", chart.getGenre());
        assertEquals("ReVanTis", chart.getNoter());
        assertEquals(123, chart.getDuration());
        assertTrue(chart.hasKnownLevel());
        assertEquals(7, chart.getLevel());
        assertEquals(11, chart.getNoteCount());
        assertFalse(chart.hasCover());
    }

    @Test
    void storesMissingLevelAsUnknownLevel() {
        VOSChart chart = new VOSChart();
        chart.markLevelUnknown();

        assertFalse(chart.hasKnownLevel());
        assertEquals(0, chart.getLevel());
    }

    @Test
    void cachesEmptyEventList() {
        VOSChart chart = new VOSChart();

        EventList firstEvents = chart.getEvents();

        assertSame(firstEvents, chart.getEvents());
    }
}
