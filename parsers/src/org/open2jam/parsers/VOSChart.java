package org.open2jam.parsers;

import java.awt.image.BufferedImage;
import java.io.File;

public class VOSChart extends Chart {
    private boolean levelKnown;
    private EventList events;

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

    public EventList getEvents() {
        return events == null ? new EventList() : events;
    }
}
