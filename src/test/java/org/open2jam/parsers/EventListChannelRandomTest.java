package org.open2jam.parsers;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;

import org.junit.jupiter.api.Test;

class EventListChannelRandomTest {

    @Test
    void channelRandomKeepsLongTargetOccupiedUntilReleaseEvent() {
        EventList events = new EventList();
        Event hold = new Event(Event.Channel.NOTE_1, 0, 0.25, 1, Event.Flag.HOLD);
        Event collidingTap = new Event(Event.Channel.NOTE_1, 0, 0.50, 2, Event.Flag.NONE);
        Event release = new Event(Event.Channel.NOTE_1, 0, 0.50, 1, Event.Flag.RELEASE);
        events.add(hold);
        events.add(collidingTap);
        events.add(release);

        events.channelRandom();

        assertNotEquals(Event.Channel.NONE, hold.getChannel());
        assertEquals(Event.Channel.NONE, collidingTap.getChannel());
        assertEquals(hold.getChannel(), release.getChannel());
    }

    @Test
    void channelRandomKeepsPreviousMapAfterPastReleaseInSameMeasure() {
        EventList events = new EventList();
        Event hold = new Event(Event.Channel.NOTE_1, 0, 0.25, 1, Event.Flag.HOLD);
        Event release = new Event(Event.Channel.NOTE_1, 1, 0.10, 1, Event.Flag.RELEASE);
        Event tapAfterRelease = new Event(Event.Channel.NOTE_1, 1, 0.20, 2, Event.Flag.NONE);
        events.add(hold);
        events.add(release);
        events.add(tapAfterRelease);

        events.channelRandom();

        assertNotEquals(Event.Channel.NONE, hold.getChannel());
        assertEquals(hold.getChannel(), release.getChannel());
        assertEquals(hold.getChannel(), tapAfterRelease.getChannel());
    }
}
