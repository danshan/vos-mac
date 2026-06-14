package org.open2jam.parsers;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.Enumeration;
import java.util.List;
import java.util.logging.Level;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;
import org.open2jam.parsers.utils.Logger;

class OsuManiaParser {
    private static final int OSU_PLAYFIELD_WIDTH = 512;
    private static final int MANIA_MODE = 3;
    private static final int SUPPORTED_KEYS = 7;
    private static final int HOLD_TYPE = 128;
    private static final int NORMAL_TYPE = 1;

    public static boolean canRead(File file) {
        if (file == null || !file.isFile()) {
            return false;
        }
        String name = file.getName().toLowerCase();
        return name.endsWith(".osu") || name.endsWith(".osz");
    }

    public static ChartList parseFile(File file) {
        if (!canRead(file)) {
            return null;
        }

        try {
            if (file.getName().toLowerCase().endsWith(".osz")) {
                return parseArchive(file);
            }
            OsuManiaChart chart = parseChart(file);
            return chartList(file, chart);
        } catch (IOException ex) {
            Logger.global.log(Level.WARNING, "Unable to parse osu!mania chart {0}: {1}",
                    new Object[] {file.getName(), ex.getMessage()});
            return null;
        }
    }

    private static ChartList parseArchive(File file) throws IOException {
        ChartList list = new ChartList();
        list.source_file = file;

        ZipFile zip = new ZipFile(file);
        try {
            Enumeration<? extends ZipEntry> entries = zip.entries();
            while (entries.hasMoreElements()) {
                ZipEntry entry = entries.nextElement();
                if (entry.isDirectory() || !entry.getName().toLowerCase().endsWith(".osu")) {
                    continue;
                }
                InputStream input = zip.getInputStream(entry);
                try {
                    OsuManiaChart chart = parseChart(file, entry.getName(), input);
                    if (chart != null) {
                        list.add(chart);
                    }
                } finally {
                    input.close();
                }
            }
        } finally {
            zip.close();
        }

        if (list.isEmpty()) {
            return null;
        }
        Collections.sort(list);
        return list;
    }

    private static ChartList chartList(File file, OsuManiaChart chart) {
        if (chart == null) {
            return null;
        }
        ChartList list = new ChartList();
        list.source_file = file;
        list.add(chart);
        return list;
    }

    private static OsuManiaChart parseChart(File file) throws IOException {
        FileInputStream input = new FileInputStream(file);
        try {
            return parseChart(file, "", input);
        } finally {
            input.close();
        }
    }

    private static OsuManiaChart parseChart(File source, String archiveEntryName, InputStream input)
            throws IOException {
        RawOsuChart raw = readRawChart(input);
        if (raw.mode != MANIA_MODE || raw.circleSize != SUPPORTED_KEYS) {
            return null;
        }

        OsuManiaChart chart = new OsuManiaChart();
        chart.setSource(source);
        chart.setArchiveEntryName(archiveEntryName);
        chart.setTitle(defaultString(raw.title, defaultTitle(source, archiveEntryName)));
        chart.setArtist(defaultString(raw.artist, ""));
        chart.setNoter(defaultString(raw.creator, ""));
        chart.setGenre("osu!mania");
        chart.setAudioFilename(raw.audioFilename);
        chart.setLevel(raw.level);
        for (SampleDefinition sample : raw.samples) {
            chart.addSample(sample.id, sample.filename);
        }

        TimingMap timing = new TimingMap(raw.timingPoints);
        chart.setBPM(timing.initialBpm());

        EventList events = new EventList();
        int noteCount = 0;
        int maxTime = 0;

        if (!raw.audioFilename.isEmpty()) {
            events.add(new Event(Event.Channel.AUTO_PLAY, 0, 0, 1, Event.Flag.NONE));
        }

        for (TimingPoint point : timing.points) {
            Position position = timing.positionAt(point.time);
            events.add(new Event(Event.Channel.BPM_CHANGE, position.measure, position.position, point.bpm(),
                    Event.Flag.NONE));
            if (point.meter != 4) {
                events.add(new Event(Event.Channel.TIME_SIGNATURE, position.measure, position.position,
                        point.meter / 4.0, Event.Flag.NONE));
            }
        }

        for (ScrollSpeedPoint point : raw.scrollSpeedPoints) {
            Position position = timing.positionAt(point.time);
            events.add(new Event(Event.Channel.SCROLL_SPEED, position.measure, position.position, point.speed,
                    Event.Flag.NONE));
        }

        for (RawHitObject object : raw.hitObjects) {
            Event.Channel channel = channelForX(object.x);
            Position start = timing.positionAt(object.time);
            if (object.hold) {
                Position end = timing.positionAt(object.endTime);
                events.add(new Event(channel, start.measure, start.position, object.sampleId, Event.Flag.HOLD,
                        object.volume, 0));
                events.add(new Event(channel, end.measure, end.position, object.sampleId, Event.Flag.RELEASE,
                        object.volume, 0));
                maxTime = Math.max(maxTime, object.endTime);
            } else {
                events.add(new Event(channel, start.measure, start.position, object.sampleId, Event.Flag.NONE,
                        object.volume, 0));
                maxTime = Math.max(maxTime, object.time);
            }
            noteCount++;
        }

        Collections.sort(events);
        chart.setEvents(events);
        chart.setNoteCount(noteCount);
        chart.setDuration((int) Math.ceil(maxTime / 1000.0));
        return chart;
    }

    private static RawOsuChart readRawChart(InputStream input) throws IOException {
        RawOsuChart chart = new RawOsuChart();
        String section = "";

        BufferedReader reader = new BufferedReader(new InputStreamReader(input, StandardCharsets.UTF_8));
        try {
            String line;
            while ((line = reader.readLine()) != null) {
                line = stripBom(line).trim();
                if (line.length() == 0 || line.startsWith("//")) {
                    continue;
                }
                if (line.startsWith("[") && line.endsWith("]")) {
                    section = line.substring(1, line.length() - 1);
                    continue;
                }

                if ("General".equals(section)) {
                    parseGeneral(chart, line);
                } else if ("Metadata".equals(section)) {
                    parseMetadata(chart, line);
                } else if ("Difficulty".equals(section)) {
                    parseDifficulty(chart, line);
                } else if ("TimingPoints".equals(section)) {
                    parseTimingPoint(chart, line);
                } else if ("HitObjects".equals(section)) {
                    parseHitObject(chart, line);
                }
            }
        } finally {
            reader.close();
        }

        return chart;
    }

    private static void parseGeneral(RawOsuChart chart, String line) {
        KeyValue property = splitProperty(line);
        if (property == null) {
            return;
        }
        if ("AudioFilename".equals(property.key)) {
            chart.audioFilename = property.value;
        } else if ("Mode".equals(property.key)) {
            chart.mode = parseInt(property.value, 0);
        }
    }

    private static void parseMetadata(RawOsuChart chart, String line) {
        KeyValue property = splitProperty(line);
        if (property == null) {
            return;
        }
        if ("Title".equals(property.key)) {
            chart.title = property.value;
        } else if ("TitleUnicode".equals(property.key) && property.value.length() > 0) {
            chart.title = property.value;
        } else if ("Artist".equals(property.key)) {
            chart.artist = property.value;
        } else if ("ArtistUnicode".equals(property.key) && property.value.length() > 0) {
            chart.artist = property.value;
        } else if ("Creator".equals(property.key)) {
            chart.creator = property.value;
        }
    }

    private static void parseDifficulty(RawOsuChart chart, String line) {
        KeyValue property = splitProperty(line);
        if (property == null) {
            return;
        }
        if ("CircleSize".equals(property.key)) {
            chart.circleSize = (int) Math.round(parseDouble(property.value, 0));
        } else if ("OverallDifficulty".equals(property.key)) {
            chart.level = (int) Math.round(parseDouble(property.value, 0));
        }
    }

    private static void parseTimingPoint(RawOsuChart chart, String line) {
        String[] fields = line.split(",", -1);
        if (fields.length < 2) {
            return;
        }
        double beatLength = parseDouble(fields[1].trim(), 0);
        int meter = fields.length >= 3 ? parseInt(fields[2].trim(), 4) : 4;
        if (meter < 1) {
            meter = 4;
        }
        boolean uninherited = fields.length < 7 || parseInt(fields[6].trim(), 1) == 1;
        if (uninherited) {
            if (beatLength <= 0) {
                return;
            }
            int time = (int) Math.round(parseDouble(fields[0].trim(), 0));
            chart.timingPoints.add(new TimingPoint(time, beatLength, meter));
            return;
        }
        if (beatLength >= 0) {
            return;
        }
        int time = (int) Math.round(parseDouble(fields[0].trim(), 0));
        chart.scrollSpeedPoints.add(new ScrollSpeedPoint(time, -100.0 / beatLength));
    }

    private static void parseHitObject(RawOsuChart chart, String line) {
        String[] fields = line.split(",", -1);
        if (fields.length < 5) {
            return;
        }

        int type = parseInt(fields[3].trim(), 0);
        boolean hold = (type & HOLD_TYPE) != 0;
        boolean normal = (type & NORMAL_TYPE) != 0;
        if (!hold && !normal) {
            return;
        }

        int x = parseInt(fields[0].trim(), 0);
        int time = (int) Math.round(parseDouble(fields[2].trim(), 0));
        int endTime = time;
        SampleReference sample = parseSampleReference(chart, fields.length >= 6 ? fields[5] : "", hold);
        if (hold) {
            if (fields.length < 6) {
                return;
            }
            String endTimeText = fields[5];
            int colon = endTimeText.indexOf(':');
            if (colon >= 0) {
                endTimeText = endTimeText.substring(0, colon);
            }
            endTime = (int) Math.round(parseDouble(endTimeText.trim(), time));
            if (endTime <= time) {
                return;
            }
        }

        chart.hitObjects.add(new RawHitObject(x, time, hold, endTime, sample.sampleId, sample.volume));
    }

    private static SampleReference parseSampleReference(RawOsuChart chart, String hitSample, boolean hold) {
        if (hitSample == null || hitSample.length() == 0) {
            return new SampleReference(0, 1.0f);
        }

        String[] parts = hitSample.split(":", -1);
        String filename = "";
        int volume = 100;
        int volumeIndex = hold ? 4 : 3;
        int filenameIndex = hold ? 5 : 4;
        if (parts.length > volumeIndex) {
            volume = parseInt(parts[volumeIndex], 100);
        }
        if (parts.length > filenameIndex) {
            filename = parts[filenameIndex].trim();
        }
        if (filename.length() == 0) {
            return new SampleReference(0, clampVolume(volume));
        }

        Integer id = chart.sampleIdsByFilename.get(filename);
        if (id == null) {
            id = chart.nextSampleId++;
            chart.sampleIdsByFilename.put(filename, id);
            chart.samples.add(new SampleDefinition(id, filename));
        }
        return new SampleReference(id, clampVolume(volume));
    }

    private static float clampVolume(int volume) {
        if (volume < 0) {
            volume = 0;
        } else if (volume > 100) {
            volume = 100;
        }
        return volume / 100.0f;
    }

    private static KeyValue splitProperty(String line) {
        int colon = line.indexOf(':');
        if (colon < 0) {
            return null;
        }
        return new KeyValue(line.substring(0, colon).trim(), line.substring(colon + 1).trim());
    }

    private static Event.Channel channelForX(int x) {
        int lane = (int) Math.floor(x * SUPPORTED_KEYS / (double) OSU_PLAYFIELD_WIDTH);
        if (lane < 0) {
            lane = 0;
        } else if (lane >= SUPPORTED_KEYS) {
            lane = SUPPORTED_KEYS - 1;
        }
        return Event.Channel.playableChannels()[lane];
    }

    private static int parseInt(String value, int fallback) {
        try {
            return Integer.parseInt(value.trim());
        } catch (RuntimeException ex) {
            return fallback;
        }
    }

    private static double parseDouble(String value, double fallback) {
        try {
            return Double.parseDouble(value.trim());
        } catch (RuntimeException ex) {
            return fallback;
        }
    }

    private static String defaultString(String value, String fallback) {
        if (value == null || value.length() == 0) {
            return fallback;
        }
        return value;
    }

    private static String stripExtension(String name) {
        int dot = name.lastIndexOf('.');
        return dot > 0 ? name.substring(0, dot) : name;
    }

    private static String defaultTitle(File source, String archiveEntryName) {
        String name = archiveEntryName == null || archiveEntryName.length() == 0
                ? source.getName()
                : new File(archiveEntryName).getName();
        return stripExtension(name);
    }

    private static String stripBom(String line) {
        if (line.length() > 0 && line.charAt(0) == '\uFEFF') {
            return line.substring(1);
        }
        return line;
    }

    private static final class RawOsuChart {
        int mode = 0;
        int circleSize = 0;
        int level = 0;
        String audioFilename = "";
        String title = "";
        String artist = "";
        String creator = "";
        List<TimingPoint> timingPoints = new ArrayList<TimingPoint>();
        List<ScrollSpeedPoint> scrollSpeedPoints = new ArrayList<ScrollSpeedPoint>();
        List<RawHitObject> hitObjects = new ArrayList<RawHitObject>();
        List<SampleDefinition> samples = new ArrayList<SampleDefinition>();
        java.util.Map<String, Integer> sampleIdsByFilename = new java.util.HashMap<String, Integer>();
        int nextSampleId = 2;
    }

    private static final class RawHitObject {
        final int x;
        final int time;
        final boolean hold;
        final int endTime;
        final int sampleId;
        final float volume;

        RawHitObject(int x, int time, boolean hold, int endTime, int sampleId, float volume) {
            this.x = x;
            this.time = time;
            this.hold = hold;
            this.endTime = endTime;
            this.sampleId = sampleId;
            this.volume = volume;
        }
    }

    private static final class SampleDefinition {
        final int id;
        final String filename;

        SampleDefinition(int id, String filename) {
            this.id = id;
            this.filename = filename;
        }
    }

    private static final class SampleReference {
        final int sampleId;
        final float volume;

        SampleReference(int sampleId, float volume) {
            this.sampleId = sampleId;
            this.volume = volume;
        }
    }

    private static final class TimingPoint {
        final int time;
        final double beatLength;
        final int meter;

        TimingPoint(int time, double beatLength, int meter) {
            this.time = time;
            this.beatLength = beatLength;
            this.meter = meter;
        }

        double bpm() {
            return 60000.0 / beatLength;
        }
    }

    private static final class ScrollSpeedPoint {
        final int time;
        final double speed;

        ScrollSpeedPoint(int time, double speed) {
            this.time = time;
            this.speed = speed;
        }
    }

    private static final class TimingMap {
        final List<TimingPoint> points;
        final List<Double> beats;
        final List<Double> measures;
        final double originBeat;
        final double originMeasure;

        TimingMap(List<TimingPoint> source) {
            points = new ArrayList<TimingPoint>(source);
            if (points.isEmpty()) {
                points.add(new TimingPoint(0, 500.0, 4));
            }
            Collections.sort(points, new Comparator<TimingPoint>() {
                public int compare(TimingPoint a, TimingPoint b) {
                    return a.time - b.time;
                }
            });
            beats = new ArrayList<Double>();
            measures = new ArrayList<Double>();
            beats.add(0.0);
            measures.add(0.0);
            for (int i = 1; i < points.size(); i++) {
                TimingPoint previous = points.get(i - 1);
                TimingPoint current = points.get(i);
                double previousBeat = beats.get(i - 1);
                double beatDelta = (current.time - previous.time) / previous.beatLength;
                beats.add(previousBeat + beatDelta);
                measures.add(measures.get(i - 1) + beatDelta / previous.meter);
            }
            originBeat = rawBeatAt(0);
            originMeasure = rawMeasureAt(0);
        }

        double initialBpm() {
            return points.get(0).bpm();
        }

        Position positionAt(int time) {
            double beat = rawBeatAt(time) - originBeat;
            double measureValue = rawMeasureAt(time) - originMeasure;
            if (beat < 0 || measureValue < 0) {
                return new Position(0, 0);
            }
            int measure = (int) Math.floor(measureValue);
            double position = measureValue - measure;
            return new Position(measure, position);
        }

        private double rawBeatAt(int time) {
            int index = timingPointIndexAt(time);
            TimingPoint point = points.get(index);
            return beats.get(index) + (time - point.time) / point.beatLength;
        }

        private double rawMeasureAt(int time) {
            int index = timingPointIndexAt(time);
            TimingPoint point = points.get(index);
            double beatDelta = (time - point.time) / point.beatLength;
            return measures.get(index) + beatDelta / point.meter;
        }

        private int timingPointIndexAt(int time) {
            int index = 0;
            for (int i = 1; i < points.size(); i++) {
                if (points.get(i).time <= time) {
                    index = i;
                } else {
                    break;
                }
            }
            return index;
        }
    }

    private static final class Position {
        final int measure;
        final double position;

        Position(int measure, double position) {
            this.measure = measure;
            this.position = position;
        }
    }

    private static final class KeyValue {
        final String key;
        final String value;

        KeyValue(String key, String value) {
            this.key = key;
            this.value = value;
        }
    }
}
