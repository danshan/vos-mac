package org.open2jam.render;

import java.util.Collections;
import org.open2jam.game.TimingData;
import org.open2jam.parsers.Chart;
import org.open2jam.parsers.Event;
import org.open2jam.parsers.EventList;
import org.open2jam.util.Logger;

final class RenderTimingCompiler {
    static final int BEATS_PER_MSEC = 4 * 60 * 1000;

    private RenderTimingCompiler() {
    }

    static EventList compile(EventList list, Chart.TYPE chartType, double initialBpm, double startTime,
            TimingData judgmentTiming, TimingData visualTiming) {
        Collections.sort(list);

        int measure = 0;
        double timer = startTime;
        double bpm = initialBpm;
        double scrollSpeed = 1;
        double fracMeasure = 1;
        double measurePointer = 0;
        double eventPosition;

        EventList newList = new EventList();

        judgmentTiming.add(timer, bpm);
        visualTiming.add(timer, bpm);

        Event measureEvent = new Event(Event.Channel.MEASURE, measure, 0, 0, Event.Flag.NONE);
        measureEvent.setTime(timer);
        newList.add(measureEvent);

        for (Event event : list) {
            while (event.getMeasure() > measure) {
                timer += (BEATS_PER_MSEC * (fracMeasure - measurePointer)) / bpm;
                measureEvent = new Event(Event.Channel.MEASURE, measure, 0, 0, Event.Flag.NONE);
                measureEvent.setTime(timer);
                newList.add(measureEvent);
                measure++;
                fracMeasure = 1;
                measurePointer = 0;
            }

            if (chartType == Chart.TYPE.OJN) {
                eventPosition = event.getPosition();
            } else {
                eventPosition = event.getPosition() * fracMeasure;
            }
            timer += (BEATS_PER_MSEC * (eventPosition - measurePointer)) / bpm;
            measurePointer = eventPosition;

            switch (event.getChannel()) {
                case STOP:
                    judgmentTiming.add(timer, 0);
                    visualTiming.add(timer, 0);
                    double stopTime = event.getValue();
                    if (chartType == Chart.TYPE.BMS) {
                        stopTime = (event.getValue() / 192) * BEATS_PER_MSEC / bpm;
                    }
                    judgmentTiming.add(timer + stopTime, bpm);
                    visualTiming.add(timer + stopTime, bpm * scrollSpeed);
                    timer += stopTime;
                    break;
                case BPM_CHANGE:
                    bpm = event.getValue();
                    judgmentTiming.add(timer, bpm);
                    visualTiming.add(timer, bpm * scrollSpeed);
                    break;
                case SCROLL_SPEED:
                    scrollSpeed = event.getValue();
                    visualTiming.add(timer, bpm * scrollSpeed);
                    break;
                case TIME_SIGNATURE:
                    fracMeasure = event.getValue();
                    break;
                case NOTE_1:
                case NOTE_2:
                case NOTE_3:
                case NOTE_4:
                case NOTE_5:
                case NOTE_6:
                case NOTE_7:
                case NOTE_SC:
                case NOTE_8:
                case NOTE_9:
                case NOTE_10:
                case NOTE_11:
                case NOTE_12:
                case NOTE_13:
                case NOTE_14:
                case NOTE_SC2:
                case AUTO_PLAY:
                case BGA:
                    event.setTime(timer + event.getOffset());
                    if (event.getOffset() != 0) {
                        System.out.println("offset: " + event.getOffset() + " timer: " + (timer + event.getOffset()));
                    }
                    break;
                case MEASURE:
                    Logger.global.log(java.util.logging.Level.WARNING, "Unexpected measure event in chart events");
                    break;
                default:
                    break;
            }

            newList.add(event);
        }

        judgmentTiming.finish();
        visualTiming.finish();
        return newList;
    }
}
