package org.open2jam.render;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.lang.reflect.Field;
import java.util.EnumMap;

import org.junit.jupiter.api.Test;
import org.open2jam.game.TimingData;
import org.open2jam.parsers.Chart;
import org.open2jam.parsers.Event;
import org.open2jam.parsers.EventList;
import org.open2jam.render.entities.SampleEntity;

class RenderLastSoundBootstrapTest {
    @Test
    void constructVelocityTreeBootstrapsFirstSamplePerChannel() throws Exception {
        EnumMap<Event.Channel, SampleEntity> lastSound = new EnumMap<Event.Channel, SampleEntity>(Event.Channel.class);

        EventList events = new EventList();
        events.add(new Event(Event.Channel.NOTE_1, 20, 0.0, 11, Event.Flag.NONE));
        events.add(new Event(Event.Channel.NOTE_2, 40, 0.0, 12, Event.Flag.NONE));

        Render.constructVelocityTree(events, Chart.TYPE.OSU, 120.0, 0.0, new TimingData(), new TimingData(),
                lastSound, null);

        assertTrue(lastSound.containsKey(Event.Channel.NOTE_1));
        assertTrue(lastSound.containsKey(Event.Channel.NOTE_2));
        assertEquals(11, sampleId(lastSound.get(Event.Channel.NOTE_1)));
        assertEquals(12, sampleId(lastSound.get(Event.Channel.NOTE_2)));
    }

    private static int sampleId(SampleEntity sampleEntity) throws Exception {
        Field valueField = SampleEntity.class.getDeclaredField("value");
        valueField.setAccessible(true);
        Event.SoundSample sample = (Event.SoundSample) valueField.get(sampleEntity);
        return sample.sample_id;
    }
}
