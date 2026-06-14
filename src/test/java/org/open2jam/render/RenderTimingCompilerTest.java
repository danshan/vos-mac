package org.open2jam.render;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.File;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.open2jam.game.TimingData;
import org.open2jam.parsers.Chart;
import org.open2jam.parsers.ChartList;
import org.open2jam.parsers.ChartParser;
import org.open2jam.parsers.Event;
import org.open2jam.parsers.EventList;
import org.open2jam.parsers.utils.SampleData;

class RenderTimingCompilerTest {
    private static final File REFERENCE_OSU_MANIA_OSZ = new File(
            "/Users/honghao.shan/Downloads/L33 - Project Loved_ Best of 2025 (osu!mania)/"
                    + "1187083 Jay Chou - Nocturne.osz");

    @Test
    void scrollSpeedChangesVisualTimingWithoutChangingJudgmentTiming() {
        EventList events = new EventList();
        events.add(new Event(Event.Channel.BPM_CHANGE, 0, 0, 120, Event.Flag.NONE));
        events.add(new Event(Event.Channel.SCROLL_SPEED, 0, 0.5, 2.0, Event.Flag.NONE));
        events.add(new Event(Event.Channel.NOTE_1, 1, 0, 0, Event.Flag.NONE));

        TimingData judgmentTiming = new TimingData();
        TimingData visualTiming = new TimingData();
        EventList timedEvents = RenderTimingCompiler.compile(events, Chart.TYPE.OSU, 120, 0,
                judgmentTiming, visualTiming);

        Event note = timedEvents.getEventsFromThisChannel(Event.Channel.NOTE_1).get(0);

        assertEquals(2000.0, note.getTime(), 0.0001);
        assertEquals(4.0, judgmentTiming.getBeat(note.getTime()), 0.0001);
        assertEquals(6.0, visualTiming.getBeat(note.getTime()), 0.0001);
    }

    @Test
    void compilesReferenceOsuManiaSevenKeyChartIntoPlayableTimeline() throws Exception {
        assertTrue(REFERENCE_OSU_MANIA_OSZ.isFile(), "reference osu!mania archive is required");

        ChartList charts = ChartParser.parseFile(REFERENCE_OSU_MANIA_OSZ);
        Chart chart = charts.get(0);

        TimingData judgmentTiming = new TimingData();
        TimingData visualTiming = new TimingData();
        EventList timedEvents = RenderTimingCompiler.compile(chart.getEvents(), Chart.TYPE.OSU, chart.getBPM(), 0,
                judgmentTiming, visualTiming);

        int playableEvents = 0;
        for (Event.Channel channel : Event.Channel.playableChannels()) {
            EventList lane = timedEvents.getEventsFromThisChannel(channel);
            double previousTime = -1;
            for (Event event : lane) {
                assertTrue(event.getTime() >= previousTime);
                assertTrue(judgmentTiming.getBeat(event.getTime()) >= 0);
                assertTrue(visualTiming.getBeat(event.getTime()) >= 0);
                previousTime = event.getTime();
                if (event.getFlag() != Event.Flag.RELEASE) {
                    playableEvents++;
                }
            }
        }

        Map<Integer, SampleData> samples = chart.getSamples();
        try {
            assertEquals(1487, playableEvents);
            assertEquals(SampleData.Type.MP3, samples.get(1).getType());
        } finally {
            for (SampleData sample : samples.values()) {
                sample.dispose();
            }
        }
    }
}
