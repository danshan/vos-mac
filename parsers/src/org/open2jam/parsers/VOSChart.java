package org.open2jam.parsers;

import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.Map;
import org.open2jam.parsers.utils.SampleData;

public class VOSChart extends Chart {
    private static final int SAMPLE_RATE = 22050;
    private static final int DEFAULT_SAMPLE_MS = 180;
    private static final int MAX_SAMPLE_MS = 4000;
    private static final int DURATION_TICKS_PER_MEASURE = 0x2E4;

    private boolean levelKnown;
    private EventList events;
    private final Map<Integer, VOSSample> sample_specs = new LinkedHashMap<Integer, VOSSample>();
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

    int registerSample(int instrument, int pitch, int volume, int duration) {
        String key = instrument + ":" + pitch + ":" + volume + ":" + duration;
        Integer sample_id = sample_ids.get(key);
        if (sample_id == null) {
            sample_id = next_sample_id++;
            sample_ids.put(key, sample_id);
            sample_specs.put(sample_id, new VOSSample(instrument, pitch, volume, duration, bpm));
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
        return getNoImage();
    }

    public Map<Integer, SampleData> getSamples() {
        Map<Integer, SampleData> samples = new LinkedHashMap<Integer, SampleData>();
        for (Map.Entry<Integer, VOSSample> entry : sample_specs.entrySet()) {
            samples.put(entry.getKey(), entry.getValue().toSampleData());
        }
        return samples;
    }

    public EventList getEvents() {
        if (events == null) {
            events = new EventList();
        }
        return events;
    }

    private static final class VOSSample {
        private final int pitch;
        private final int instrument;
        private final int volume;
        private final int duration;
        private final double bpm;

        VOSSample(int instrument, int pitch, int volume, int duration, double bpm) {
            this.instrument = instrument;
            this.pitch = pitch;
            this.volume = volume;
            this.duration = duration;
            this.bpm = bpm;
        }

        SampleData toSampleData() {
            return new SampleData(new ByteArrayInputStream(toWav()), SampleData.Type.WAV,
                    "vos-" + pitch + ".wav");
        }

        private byte[] toWav() {
            int sample_count = Math.max(1, SAMPLE_RATE * durationMillis() / 1000);
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            try {
                writeAscii(out, "RIFF");
                writeInt(out, 36 + sample_count * 2);
                writeAscii(out, "WAVE");
                writeAscii(out, "fmt ");
                writeInt(out, 16);
                writeShort(out, 1);
                writeShort(out, 1);
                writeInt(out, SAMPLE_RATE);
                writeInt(out, SAMPLE_RATE * 2);
                writeShort(out, 2);
                writeShort(out, 16);
                writeAscii(out, "data");
                writeInt(out, sample_count * 2);
                writeSamples(out, sample_count);
            } catch (IOException e) {
                throw new IllegalStateException(e);
            }
            return out.toByteArray();
        }

        private int durationMillis() {
            if (duration <= 0) {
                return DEFAULT_SAMPLE_MS;
            }
            double beats_per_measure = 4.0;
            double milliseconds = duration / (double) DURATION_TICKS_PER_MEASURE
                    * beats_per_measure * 60000.0 / Math.max(1.0, bpm);
            return Math.max(DEFAULT_SAMPLE_MS, Math.min(MAX_SAMPLE_MS, (int) Math.round(milliseconds)));
        }

        private void writeSamples(ByteArrayOutputStream out, int sample_count) throws IOException {
            double frequency = 440.0 * Math.pow(2.0, (pitch - 69) / 12.0);
            double gain = Math.max(0.15, Math.min(1.0, volume / 127.0));
            double overtone = 0.15 + (Math.abs(instrument) % 8) * 0.025;
            int release_start = Math.max(0, sample_count - SAMPLE_RATE / 40);
            for (int i = 0; i < sample_count; i++) {
                double envelope = i < SAMPLE_RATE / 100 ? i / (SAMPLE_RATE / 100.0) : 1.0;
                if (i > release_start) {
                    envelope *= (sample_count - i) / (double) Math.max(1, sample_count - release_start);
                }
                double wave = Math.sin(2.0 * Math.PI * frequency * i / SAMPLE_RATE)
                        + overtone * Math.sin(2.0 * Math.PI * frequency * 2.0 * i / SAMPLE_RATE);
                short value = (short) (wave / (1.0 + overtone)
                        * Short.MAX_VALUE * 0.35 * gain * envelope);
                writeShort(out, value);
            }
        }

        private static void writeAscii(ByteArrayOutputStream out, String value) throws IOException {
            out.write(value.getBytes(StandardCharsets.US_ASCII));
        }

        private static void writeInt(ByteArrayOutputStream out, int value) throws IOException {
            out.write(value & 0xFF);
            out.write((value >>> 8) & 0xFF);
            out.write((value >>> 16) & 0xFF);
            out.write((value >>> 24) & 0xFF);
        }

        private static void writeShort(ByteArrayOutputStream out, int value) throws IOException {
            out.write(value & 0xFF);
            out.write((value >>> 8) & 0xFF);
        }
    }
}
