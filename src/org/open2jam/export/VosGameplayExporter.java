package org.open2jam.export;

import java.io.File;
import java.util.ArrayList;
import java.util.List;
import org.open2jam.game.TimingData;
import org.open2jam.parsers.Chart;
import org.open2jam.parsers.ChartList;
import org.open2jam.parsers.ChartParser;
import org.open2jam.parsers.Event;
import org.open2jam.parsers.EventList;
import org.open2jam.parsers.VOSChart;
import org.open2jam.render.RenderTimingCompiler;

public final class VosGameplayExporter {
    public String exportGameplay(File input) throws Exception {
        VOSChart chart = firstVosChart(input);
        EventList timedEvents = RenderTimingCompiler.compile(chart.getEvents(), chart.type, chart.getBPM(), 0,
                new TimingData(), new TimingData());

        List<String> notes = new ArrayList<String>();
        List<String> autoPlayEvents = new ArrayList<String>();
        for (Event event : timedEvents) {
            int lane = laneFor(event.getChannel());
            if (lane >= 0) {
                String kind = kindFor(event.getFlag());
                if (kind != null) {
                    notes.add(note(event, lane, kind));
                }
            } else if (event.getChannel() == Event.Channel.AUTO_PLAY) {
                autoPlayEvents.add(autoPlayEvent(event));
            }
        }

        return JsonWriter.object(
                JsonWriter.field("schemaVersion", 1),
                JsonWriter.field("format", "VOS"),
                JsonWriter.field("sourcePath", input.getCanonicalPath()),
                JsonWriter.field("title", chart.getTitle()),
                JsonWriter.field("keys", chart.getKeys()),
                JsonWriter.field("bpm", chart.getBPM()),
                JsonWriter.field("durationMs", chart.getDuration() * 1000),
                JsonWriter.rawField("notes", JsonWriter.array(notes.toArray(new String[0]))),
                JsonWriter.rawField("autoPlayEvents", JsonWriter.array(autoPlayEvents.toArray(new String[0]))));
    }

    private static VOSChart firstVosChart(File input) {
        ChartList charts = ChartParser.parseFile(input);
        if (charts != null) {
            for (Chart chart : charts) {
                if (chart instanceof VOSChart) {
                    return (VOSChart) chart;
                }
            }
        }
        throw new IllegalArgumentException("No VOS chart found: " + input);
    }

    private static String note(Event event, int lane, String kind) {
        Event.SoundSample sample = event.getSample();
        return JsonWriter.object(
                JsonWriter.field("lane", lane),
                JsonWriter.field("kind", kind),
                JsonWriter.field("startMs", event.getTime()),
                JsonWriter.field("sampleId", sample.sample_id),
                JsonWriter.field("volume", sample.volume),
                JsonWriter.field("pan", sample.pan));
    }

    private static String autoPlayEvent(Event event) {
        Event.SoundSample sample = event.getSample();
        return JsonWriter.object(
                JsonWriter.field("startMs", event.getTime()),
                JsonWriter.field("sampleId", sample.sample_id),
                JsonWriter.field("volume", sample.volume),
                JsonWriter.field("pan", sample.pan));
    }

    private static int laneFor(Event.Channel channel) {
        switch (channel) {
            case NOTE_1:
                return 0;
            case NOTE_2:
                return 1;
            case NOTE_3:
                return 2;
            case NOTE_4:
                return 3;
            case NOTE_5:
                return 4;
            case NOTE_6:
                return 5;
            case NOTE_7:
                return 6;
            default:
                return -1;
        }
    }

    private static String kindFor(Event.Flag flag) {
        switch (flag) {
            case NONE:
                return "tap";
            case HOLD:
                return "holdStart";
            case RELEASE:
                return "holdEnd";
            default:
                return null;
        }
    }
}
