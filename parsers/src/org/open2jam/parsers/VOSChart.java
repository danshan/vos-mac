package org.open2jam.parsers;

import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.File;
import java.util.LinkedHashMap;
import java.util.Map;
import org.open2jam.parsers.utils.SampleData;

public class VOSChart extends Chart {
    private boolean levelKnown;
    private transient EventList events;
    private final Map<Integer, byte[]> midi_samples = new LinkedHashMap<Integer, byte[]>();
    private final Map<String, Integer> sample_ids = new LinkedHashMap<String, Integer>();
    private int next_sample_id = 1;

    public VOSChart() {
        type = TYPE.VOS;
    }

    public void setSource(File source) {
        this.source = source;
    }

    public void setLevel(int level) {
        this.level = level;
        this.levelKnown = true;
    }

    public void markLevelUnknown() {
        this.level = 0;
        this.levelKnown = false;
    }

    public boolean hasKnownLevel() {
        return levelKnown;
    }

    public void setTitle(String title) {
        this.title = title == null ? "" : title;
    }

    public void setArtist(String artist) {
        this.artist = artist == null ? "" : artist;
    }

    public void setGenre(String genre) {
        this.genre = genre == null ? "" : genre;
    }

    public void setNoter(String noter) {
        this.noter = noter == null ? "" : noter;
    }

    public void setBPM(double bpm) {
        this.bpm = bpm;
    }

    public void setNoteCount(int notes) {
        this.notes = notes;
    }

    public void setDuration(int duration) {
        this.duration = duration;
    }

    public void setEvents(EventList events) {
        this.events = events;
    }

    int registerMidiSample(String key, byte[] data) {
        Integer sample_id = sample_ids.get(key);
        if (sample_id == null) {
            sample_id = next_sample_id++;
            sample_ids.put(key, sample_id);
            midi_samples.put(sample_id, data);
        }
        return sample_id;
    }

    public File getSource() {
        return source;
    }

    public int getLevel() {
        return level;
    }

    public int getKeys() {
        return keys;
    }

    public int getPlayers() {
        return players;
    }

    public String getTitle() {
        return title;
    }

    public String getArtist() {
        return artist;
    }

    public String getGenre() {
        return genre;
    }

    public String getNoter() {
        return noter;
    }

    public double getBPM() {
        return bpm;
    }

    public int getNoteCount() {
        return notes;
    }

    public int getDuration() {
        return duration;
    }

    public boolean hasCover() {
        return false;
    }

    public BufferedImage getCover() {
        BufferedImage image = getResourceImage("/resources/vos_default_cover.png");
        return image == null ? getNoImage() : image;
    }

    public Map<Integer, SampleData> getSamples() {
        Map<Integer, SampleData> samples = new LinkedHashMap<Integer, SampleData>();
        for (Map.Entry<Integer, byte[]> entry : midi_samples.entrySet()) {
            samples.put(entry.getKey(), new SampleData(new ByteArrayInputStream(entry.getValue()),
                    SampleData.Type.MIDI, "vos-" + entry.getKey() + ".mid"));
        }
        return samples;
    }

    public EventList getEvents() {
        if (events == null) {
            events = reloadEvents();
        }
        return events;
    }

    private EventList reloadEvents() {
        if (source != null && source.exists()) {
            ChartList charts = VOSParser.parseFile(source);
            if (charts != null && !charts.isEmpty() && charts.get(0) instanceof VOSChart) {
                return ((VOSChart) charts.get(0)).getEvents();
            }
        }
        return new EventList();
    }
}
