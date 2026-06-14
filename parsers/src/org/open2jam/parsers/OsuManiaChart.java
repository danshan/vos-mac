package org.open2jam.parsers;

import java.awt.image.BufferedImage;
import java.io.File;
import java.io.FilterInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.HashMap;
import java.util.Map;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;
import org.open2jam.parsers.utils.SampleData;

public class OsuManiaChart extends Chart {
    private EventList events = new EventList();
    private String archiveEntryName = "";

    public OsuManiaChart() {
        type = TYPE.OSU;
        keys = 7;
        players = 1;
    }

    void setSource(File source) {
        this.source = source;
    }

    void setTitle(String title) {
        this.title = title;
    }

    void setArtist(String artist) {
        this.artist = artist;
    }

    void setNoter(String noter) {
        this.noter = noter;
    }

    void setGenre(String genre) {
        this.genre = genre;
    }

    void setBPM(double bpm) {
        this.bpm = bpm;
    }

    void setNoteCount(int notes) {
        this.notes = notes;
    }

    void setLevel(int level) {
        this.level = level;
    }

    void setDuration(int duration) {
        this.duration = duration;
    }

    void setEvents(EventList events) {
        this.events = events;
    }

    void setAudioFilename(String filename) {
        if (filename != null && filename.length() > 0) {
            sample_index.put(1, filename);
        }
    }

    void addSample(int id, String filename) {
        if (filename != null && filename.length() > 0) {
            sample_index.put(id, filename);
        }
    }

    void setArchiveEntryName(String archiveEntryName) {
        this.archiveEntryName = archiveEntryName == null ? "" : archiveEntryName;
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

    public BufferedImage getCover() {
        return getNoImage();
    }

    public EventList getEvents() {
        return events;
    }

    public Map<Integer, SampleData> getSamples() {
        HashMap<Integer, SampleData> samples = new HashMap<Integer, SampleData>();
        if (source == null || source.getParentFile() == null) {
            return samples;
        }

        if (source.getName().toLowerCase().endsWith(".osz")) {
            return getArchiveSamples();
        }

        for (Map.Entry<Integer, String> entry : sample_index.entrySet()) {
            File file = new File(source.getParentFile(), entry.getValue());
            if (!file.isFile()) {
                continue;
            }
            try {
                String name = file.getName();
                String lower = name.toLowerCase();
                SampleData.Type type;
                if (lower.endsWith(".ogg")) {
                    type = SampleData.Type.OGG;
                } else if (lower.endsWith(".mp3")) {
                    type = SampleData.Type.MP3;
                } else if (lower.endsWith(".wav")) {
                    type = SampleData.Type.WAV;
                } else {
                    continue;
                }
                samples.put(entry.getKey(), new SampleData(new java.io.FileInputStream(file), type, name));
            } catch (java.io.FileNotFoundException ex) {
                continue;
            }
        }
        return samples;
    }

    private Map<Integer, SampleData> getArchiveSamples() {
        HashMap<Integer, SampleData> samples = new HashMap<Integer, SampleData>();
        try {
            ZipFile zip = new ZipFile(source);
            for (Map.Entry<Integer, String> entry : sample_index.entrySet()) {
                ZipEntry zipEntry = findAudioEntry(zip, entry.getValue());
                if (zipEntry == null) {
                    continue;
                }
                SampleData.Type type = sampleType(zipEntry.getName());
                if (type == null) {
                    continue;
                }
                samples.put(entry.getKey(), new SampleData(new ZipEntryInputStream(zip.getInputStream(zipEntry), zip),
                        type,
                        new File(zipEntry.getName()).getName()));
            }
        } catch (IOException ex) {
            return samples;
        }
        return samples;
    }

    private ZipEntry findAudioEntry(ZipFile zip, String audioFilename) {
        String normalized = audioFilename.replace('\\', '/');
        ZipEntry direct = zip.getEntry(normalized);
        if (direct != null) {
            return direct;
        }

        int slash = archiveEntryName.lastIndexOf('/');
        if (slash >= 0) {
            ZipEntry relative = zip.getEntry(archiveEntryName.substring(0, slash + 1) + normalized);
            if (relative != null) {
                return relative;
            }
        }

        java.util.Enumeration<? extends ZipEntry> entries = zip.entries();
        while (entries.hasMoreElements()) {
            ZipEntry entry = entries.nextElement();
            if (!entry.isDirectory() && new File(entry.getName()).getName().equalsIgnoreCase(audioFilename)) {
                return entry;
            }
        }
        return null;
    }

    private static final class ZipEntryInputStream extends FilterInputStream {
        private final ZipFile zip;

        ZipEntryInputStream(InputStream input, ZipFile zip) {
            super(input);
            this.zip = zip;
        }

        public void close() throws IOException {
            try {
                super.close();
            } finally {
                zip.close();
            }
        }
    }

    private SampleData.Type sampleType(String filename) {
        String lower = filename.toLowerCase();
        if (lower.endsWith(".ogg")) {
            return SampleData.Type.OGG;
        }
        if (lower.endsWith(".mp3")) {
            return SampleData.Type.MP3;
        }
        if (lower.endsWith(".wav")) {
            return SampleData.Type.WAV;
        }
        return null;
    }
}
