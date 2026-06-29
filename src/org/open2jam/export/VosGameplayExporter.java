package org.open2jam.export;

import java.io.File;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.Collections;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import org.open2jam.game.TimingData;
import org.open2jam.parsers.Chart;
import org.open2jam.parsers.ChartList;
import org.open2jam.parsers.ChartParser;
import org.open2jam.parsers.Event;
import org.open2jam.parsers.EventList;
import org.open2jam.parsers.VOSChart;
import org.open2jam.render.RenderTimingCompiler;

public final class VosGameplayExporter {
    private static final double JAVA_RENDER_DELAY_MS = 1500.0;

    public String exportGameplay(File input) throws Exception {
        VOSChart chart = firstVosChart(input);
        return exportGameplay(chart, input, null);
    }

    public String exportGameplay(File input, File bgaAssetDir) throws Exception {
        VOSChart chart = firstVosChart(input);
        return exportGameplay(chart, input, bgaAssetDir);
    }

    String exportGameplay(VOSChart chart, File input) throws Exception {
        return exportGameplay(chart, input, null);
    }

    String exportGameplay(VOSChart chart, File input, File bgaAssetDir) throws Exception {
        TimingData visualTiming = new TimingData();
        EventList timedEvents = RenderTimingCompiler.compile(chart.getEvents(), chart.type, chart.getBPM(),
                JAVA_RENDER_DELAY_MS, new TimingData(), visualTiming);

        List<ExportNote> notes = new ArrayList<ExportNote>();
        EnumMap<Event.Channel, ExportNote> pendingLongNotes = new EnumMap<Event.Channel, ExportNote>(
                Event.Channel.class);
        List<String> measures = new ArrayList<String>();
        List<String> autoPlayEvents = new ArrayList<String>();
        List<String> bgaEvents = new ArrayList<String>();
        for (Event event : timedEvents) {
            int lane = laneFor(event.getChannel());
            if (lane >= 0) {
                switch (event.getFlag()) {
                    case NONE:
                        notes.add(new ExportNote(event, lane, "tap"));
                        break;
                    case HOLD:
                        ExportNote note = new ExportNote(event, lane, "holdStart");
                        notes.add(note);
                        pendingLongNotes.put(event.getChannel(), note);
                        break;
                    case RELEASE:
                        ExportNote pending = pendingLongNotes.remove(event.getChannel());
                        if (pending != null) {
                            pending.setEnd(event);
                        }
                        break;
                    default:
                        break;
                }
            } else if (event.getChannel() == Event.Channel.MEASURE) {
                measures.add(measureEvent(event));
            } else if (event.getChannel() == Event.Channel.AUTO_PLAY) {
                autoPlayEvents.add(autoPlayEvent(event));
            } else if (event.getChannel() == Event.Channel.BGA) {
                bgaEvents.add(bgaEvent(event));
            }
        }

        List<String> fields = new ArrayList<String>();
        fields.add(JsonWriter.field("schemaVersion", 1));
        fields.add(JsonWriter.field("format", "VOS"));
        fields.add(JsonWriter.field("sourcePath", input.getCanonicalPath()));
        fields.add(JsonWriter.field("title", chart.getTitle()));
        fields.add(JsonWriter.field("rank", 0));
        fields.add(JsonWriter.field("speedMultiplier", 1.0));
        fields.add(JsonWriter.field("speedType", "HiSpeed"));
        fields.add(JsonWriter.field("keys", chart.getKeys()));
        fields.add(JsonWriter.field("bpm", chart.getBPM()));
        fields.add(JsonWriter.field("durationMs", chart.getDuration() * 1000));
        fields.add(JsonWriter.rawField("notes", JsonWriter.array(noteJson(notes))));
        fields.add(JsonWriter.rawField("measures", JsonWriter.array(measures.toArray(new String[0]))));
        fields.add(JsonWriter.rawField("visualTiming", JsonWriter.array(visualTimingJson(visualTiming))));
        fields.add(JsonWriter.rawField("autoPlayEvents", JsonWriter.array(autoPlayEvents.toArray(new String[0]))));
        fields.add(JsonWriter.rawField("bgaEvents", JsonWriter.array(bgaEvents.toArray(new String[0]))));
        if (chart.hasVideo()) {
            fields.add(JsonWriter.field("bgaVideoPath", chart.getVideo().getCanonicalPath()));
        }
        fields.add(JsonWriter.rawField("bgaSprites", JsonWriter.array(bgaSprites(chart, bgaAssetDir))));
        return JsonWriter.object(fields.toArray(new String[fields.size()]));
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

    private static String[] noteJson(List<ExportNote> notes) {
        String[] json = new String[notes.size()];
        for (int i = 0; i < notes.size(); i++) {
            json[i] = notes.get(i).toJson();
        }
        return json;
    }

    private static String autoPlayEvent(Event event) {
        Event.SoundSample sample = event.getSample();
        return JsonWriter.object(
                JsonWriter.field("startMs", event.getTime()),
                JsonWriter.field("sampleId", sample.sample_id),
                JsonWriter.field("volume", sample.volume),
                JsonWriter.field("pan", sample.pan));
    }

    private static String measureEvent(Event event) {
        return JsonWriter.object(JsonWriter.field("startMs", event.getTime()));
    }

    private static String bgaEvent(Event event) {
        return JsonWriter.object(
                JsonWriter.field("startMs", event.getTime()),
                JsonWriter.field("spriteId", (int) event.getValue()));
    }

    private static String[] bgaSprites(VOSChart chart, File bgaAssetDir) throws Exception {
        Map<Integer, File> images = chart.getImages();
        if (images.isEmpty()) {
            return new String[0];
        }
        File outputDir = bgaAssetDir == null ? null : ExportPaths.ensureDirectory(bgaAssetDir);
        List<Integer> spriteIds = new ArrayList<Integer>(images.keySet());
        Collections.sort(spriteIds);
        List<String> json = new ArrayList<String>();
        for (Integer spriteId : spriteIds) {
            File source = images.get(spriteId);
            if (source == null) {
                continue;
            }
            File output = source;
            if (outputDir != null) {
                output = ExportPaths.child(outputDir, "bga-" + spriteId + extensionFor(source));
                Files.copy(source.toPath(), output.toPath(), StandardCopyOption.REPLACE_EXISTING);
            }
            json.add(JsonWriter.object(
                    JsonWriter.field("spriteId", spriteId.intValue()),
                    JsonWriter.field("texturePath", output.getCanonicalPath())));
        }
        return json.toArray(new String[json.size()]);
    }

    private static String extensionFor(File source) {
        String name = source.getName();
        int dot = name.lastIndexOf('.');
        if (dot < 0 || dot == name.length() - 1) {
            return ".png";
        }
        return name.substring(dot).toLowerCase();
    }

    private static String[] visualTimingJson(TimingData timing) {
        TimingData.VelocityChange[] changes = timing.getChanges();
        List<String> json = new ArrayList<String>();
        TimingData.VelocityChange previous = null;
        for (TimingData.VelocityChange change : changes) {
            if (previous != null && previous.getTime() == change.getTime() && previous.getBpm() == change.getBpm()) {
                continue;
            }
            json.add(JsonWriter.object(
                    JsonWriter.field("timeMs", change.getTime()),
                    JsonWriter.field("bpm", change.getBpm())));
            previous = change;
        }
        return json.toArray(new String[json.size()]);
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

    private static final class ExportNote {
        private final int lane;
        private final int measure;
        private final String kind;
        private final double startMs;
        private final int sampleId;
        private final float volume;
        private final float pan;
        private Double endMs;
        private Integer endMeasure;

        ExportNote(Event event, int lane, String kind) {
            Event.SoundSample sample = event.getSample();
            this.lane = lane;
            this.measure = event.getMeasure();
            this.kind = kind;
            this.startMs = event.getTime();
            this.sampleId = sample.sample_id;
            this.volume = sample.volume;
            this.pan = sample.pan;
        }

        void setEnd(Event event) {
            this.endMs = event.getTime();
            this.endMeasure = event.getMeasure();
        }

        String toJson() {
            if (endMs != null) {
                return JsonWriter.object(
                        JsonWriter.field("lane", lane),
                        JsonWriter.field("kind", kind),
                        JsonWriter.field("startMs", startMs),
                        JsonWriter.field("measure", measure),
                        JsonWriter.field("endMs", endMs),
                        JsonWriter.field("endMeasure", endMeasure.intValue()),
                        JsonWriter.field("sampleId", sampleId),
                        JsonWriter.field("volume", volume),
                        JsonWriter.field("pan", pan));
            }
            return JsonWriter.object(
                    JsonWriter.field("lane", lane),
                    JsonWriter.field("kind", kind),
                    JsonWriter.field("startMs", startMs),
                    JsonWriter.field("measure", measure),
                    JsonWriter.field("sampleId", sampleId),
                    JsonWriter.field("volume", volume),
                    JsonWriter.field("pan", pan));
        }
    }
}
