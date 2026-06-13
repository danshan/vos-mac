package org.open2jam.render;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;
import org.open2jam.parsers.BMSChart;
import org.open2jam.parsers.Event;
import org.open2jam.parsers.VOSChart;

class RenderVosKeysoundTest {
    @Test
    void vosRejectedKeysoundOnlyTriggersWithinVosDroidTolerance() {
        VOSChart chart = new VOSChart();

        assertTrue(Render.shouldTriggerRejectedKeysound(chart, -280));
        assertTrue(Render.shouldTriggerRejectedKeysound(chart, 280));
        assertFalse(Render.shouldTriggerRejectedKeysound(chart, -281));
        assertFalse(Render.shouldTriggerRejectedKeysound(chart, 281));
    }

    @Test
    void nonVosRejectedKeysoundKeepsLegacyReplayBehavior() {
        BMSChart chart = new BMSChart();

        assertTrue(Render.shouldTriggerRejectedKeysound(chart, 10_000));
    }

    @Test
    void vosPreparesEveryNonReleaseSampleBeforeGameplay() {
        VOSChart chart = new VOSChart();

        assertTrue(Render.shouldPrepareVOSSample(chart,
                new Event(Event.Channel.AUTO_PLAY, 0, 0, 1, Event.Flag.NONE)));
        assertTrue(Render.shouldPrepareVOSSample(chart,
                new Event(Event.Channel.NOTE_1, 20, 0, 2, Event.Flag.NONE)));
        assertTrue(Render.shouldPrepareVOSSample(chart,
                new Event(Event.Channel.NOTE_1, 20, 0, 2, Event.Flag.HOLD)));
        assertFalse(Render.shouldPrepareVOSSample(chart,
                new Event(Event.Channel.NOTE_1, 20, 0, 2, Event.Flag.RELEASE)));
        assertFalse(Render.shouldPrepareVOSSample(new BMSChart(),
                new Event(Event.Channel.NOTE_1, 20, 0, 2, Event.Flag.NONE)));
    }

    @Test
    void vosOnlyAwaitsBackgroundAndInitiallyBufferedSamplesBeforeGameplay() {
        VOSChart chart = new VOSChart();
        Event background = timedEvent(Event.Channel.AUTO_PLAY, Event.Flag.NONE, 0.0);
        Event initial = timedEvent(Event.Channel.NOTE_1, Event.Flag.NONE, 0.5);
        Event later = timedEvent(Event.Channel.NOTE_1, Event.Flag.NONE, 20.0);
        Event release = timedEvent(Event.Channel.NOTE_1, Event.Flag.RELEASE, 0.0);

        assertTrue(Render.shouldAwaitVOSSample(chart, background, 0));
        assertTrue(Render.shouldAwaitVOSSample(chart, initial, 1.0));
        assertFalse(Render.shouldAwaitVOSSample(chart, later, 1.0));
        assertFalse(Render.shouldAwaitVOSSample(chart, release, 1.0));
    }

    private static Event timedEvent(Event.Channel channel, Event.Flag flag, double time) {
        Event event = new Event(channel, 0, 0, 2, flag);
        event.setTime(time);
        return event;
    }
}
