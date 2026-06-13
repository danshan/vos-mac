# VOS Format Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add VOS chart-file support to the existing open2jam gameplay pipeline, including parser registration, metadata display, `Unknown` level display, format type display, default cover behavior, and verification.

**Architecture:** Implement VOS as another parser-backed `Chart` type. `VOSParser` reads `.vos` files and emits existing `EventList` events so render, timing, judgment, and gameplay code remain unchanged. UI changes stay in table models and use small display helpers instead of changing the `Chart.getLevel()` integer contract.

**Tech Stack:** Java 17, Maven, Swing table models, existing `org.open2jam.parsers.Chart` and `EventList` abstractions, JUnit Jupiter for parser/unit tests.

---

## File Structure

- Modify `pom.xml`: add JUnit Jupiter test dependency and Surefire plugin so parser behavior can be tested with `mvn test`.
- Modify `parsers/src/org/open2jam/parsers/Chart.java`: add `VOS` to `Chart.TYPE`.
- Modify `parsers/src/org/open2jam/parsers/ChartParser.java`: register `VOSParser` in the same dispatch path as OJN, BMS, SM, and SNP.
- Create `parsers/src/org/open2jam/parsers/VOSChart.java`: VOS metadata holder and `Chart` implementation.
- Create `parsers/src/org/open2jam/parsers/VOSParser.java`: VOS file detection, header parsing, note parsing, event generation.
- Create `src/org/open2jam/gui/ChartDisplay.java`: small UI helper for level display and chart format display.
- Modify `src/org/open2jam/gui/ChartTableModel.java`: show `Unknown` level for VOS with missing level, and add `Format` column.
- Modify `src/org/open2jam/gui/ChartListTableModel.java`: show `Unknown` level for VOS with missing level, and add `Format` column.
- Create `src/test/java/org/open2jam/parsers/VOSParserTest.java`: parser tests using generated in-memory fixture bytes written to temp files.
- Create `src/test/java/org/open2jam/gui/ChartDisplayTest.java`: UI display helper tests.

---

### Task 1: Add Test Harness

**Files:**
- Modify: `pom.xml`

- [ ] **Step 1: Add JUnit Jupiter dependency**

Add this dependency inside the existing `<dependencies>` block:

```xml
<dependency>
    <groupId>org.junit.jupiter</groupId>
    <artifactId>junit-jupiter</artifactId>
    <version>5.11.4</version>
    <scope>test</scope>
</dependency>
```

- [ ] **Step 2: Add Maven Surefire plugin**

Add this plugin inside `<build><plugins>`:

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-surefire-plugin</artifactId>
    <version>3.5.2</version>
</plugin>
```

- [ ] **Step 3: Run test command before adding tests**

Run:

```bash
mvn -s .mvn/settings.xml test
```

Expected: build succeeds with no test failures. If dependency download is blocked by sandbox/network policy, rerun with approved network access.

- [ ] **Step 4: Commit**

```bash
git add pom.xml
git commit -m "test: add junit harness"
```

---

### Task 2: Add VOS Chart Metadata Model

**Files:**
- Modify: `parsers/src/org/open2jam/parsers/Chart.java`
- Create: `parsers/src/org/open2jam/parsers/VOSChart.java`
- Test: `src/test/java/org/open2jam/parsers/VOSChartTest.java`

- [ ] **Step 1: Write chart metadata tests**

Create `src/test/java/org/open2jam/parsers/VOSChartTest.java`:

```java
package org.open2jam.parsers;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.File;
import org.junit.jupiter.api.Test;

class VOSChartTest {
    @Test
    void storesKnownLevelMetadata() {
        VOSChart chart = new VOSChart();
        chart.setSource(new File("known.vos"));
        chart.setTitle("Canon in D");
        chart.setArtist("Pachelbel");
        chart.setGenre("Classical");
        chart.setNoter("ReVanTis");
        chart.setDuration(123);
        chart.setLevel(7);
        chart.setNoteCount(11);

        assertEquals(Chart.TYPE.VOS, chart.type);
        assertEquals("Canon in D", chart.getTitle());
        assertEquals("Pachelbel", chart.getArtist());
        assertEquals("Classical", chart.getGenre());
        assertEquals("ReVanTis", chart.getNoter());
        assertEquals(123, chart.getDuration());
        assertTrue(chart.hasKnownLevel());
        assertEquals(7, chart.getLevel());
        assertEquals(11, chart.getNoteCount());
        assertFalse(chart.hasCover());
    }

    @Test
    void storesMissingLevelAsUnknownLevel() {
        VOSChart chart = new VOSChart();
        chart.markLevelUnknown();

        assertFalse(chart.hasKnownLevel());
        assertEquals(0, chart.getLevel());
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
mvn -s .mvn/settings.xml -Dtest=VOSChartTest test
```

Expected: compile fails because `VOSChart` is not defined and `Chart.TYPE.VOS` does not exist.

- [ ] **Step 3: Add `VOS` chart type**

Modify `parsers/src/org/open2jam/parsers/Chart.java`:

```java
public static enum TYPE {NONE, BMS, OJN, VOS, SM, XNT};
```

- [ ] **Step 4: Create `VOSChart`**

Create `parsers/src/org/open2jam/parsers/VOSChart.java`:

```java
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
```

- [ ] **Step 5: Run the test again**

Run:

```bash
mvn -s .mvn/settings.xml -Dtest=VOSChartTest test
```

Expected: `VOSChartTest` passes and the repository remains compileable before parser behavior is added.

- [ ] **Step 6: Commit**

```bash
git add parsers/src/org/open2jam/parsers/Chart.java parsers/src/org/open2jam/parsers/VOSChart.java src/test/java/org/open2jam/parsers/VOSChartTest.java
git commit -m "feat: add vos chart metadata model"
```

---

### Task 3: Implement VOS Header Parsing and Parser Registration

**Files:**
- Create: `parsers/src/org/open2jam/parsers/VOSParser.java`
- Modify: `parsers/src/org/open2jam/parsers/ChartParser.java`
- Test: `src/test/java/org/open2jam/parsers/VOSParserTest.java`

- [ ] **Step 1: Write parser metadata tests**

Create `src/test/java/org/open2jam/parsers/VOSParserTest.java`:

```java
package org.open2jam.parsers;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.nio.charset.Charset;
import java.nio.file.Files;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class VOSParserTest {
    @TempDir
    File tempDir;

    @Test
    void parsesKnownLevelMetadata() throws Exception {
        File chartFile = writeFixture("known.vos", 7, true, false);

        ChartList charts = ChartParser.parseFile(chartFile);

        assertEquals(1, charts.size());
        VOSChart chart = (VOSChart) charts.get(0);
        assertEquals(Chart.TYPE.VOS, chart.type);
        assertEquals("Canon in D", chart.getTitle());
        assertEquals("Pachelbel", chart.getArtist());
        assertEquals("Classical", chart.getGenre());
        assertEquals("ReVanTis", chart.getNoter());
        assertEquals(123, chart.getDuration());
        assertTrue(chart.hasKnownLevel());
        assertEquals(7, chart.getLevel());
        assertFalse(chart.hasCover());
    }

    @Test
    void parsesMissingLevelAsUnknownLevel() throws Exception {
        File chartFile = writeFixture("missing-level.vos", 0, false, false);

        ChartList charts = ChartParser.parseFile(chartFile);

        assertEquals(1, charts.size());
        VOSChart chart = (VOSChart) charts.get(0);
        assertFalse(chart.hasKnownLevel());
        assertEquals(0, chart.getLevel());
    }

    File writeFixture(String fileName, int level, boolean includeLevel, boolean includeLongNote) throws IOException {
        byte[] bytes = buildFixture(level, includeLevel, includeLongNote);
        File file = new File(tempDir, fileName);
        Files.write(file.toPath(), bytes);
        return file;
    }

    static byte[] buildFixture(int level, boolean includeLevel, boolean includeLongNote) throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        writeInt(out, 3);
        writeSegment(out, 0, "INF");
        writeSegment(out, 0, "MID");
        writeSegment(out, 0, "EOF");
        writeString(out, "Canon in D");
        writeString(out, "Pachelbel");
        writeString(out, "");
        writeString(out, "ReVanTis");
        out.write(0x09);
        out.write(0x00);
        writeInt(out, 123000);
        if (includeLevel) {
            out.write(level);
        }
        out.write(new byte[1023]);
        writeInt(out, 1);
        writeInt(out, includeLongNote ? 2 : 1);
        out.write(new byte[14]);
        writeNote(out, 0x000, 0x000, 0, 60, 100, 0x80, 0x00);
        if (includeLongNote) {
            writeNote(out, 0x300, 0x180, 0, 62, 100, 0x81, 0x80);
        }
        return patchSegmentAddresses(out.toByteArray());
    }

    private static byte[] patchSegmentAddresses(byte[] bytes) {
        int infAddress = 64;
        int midAddress = bytes.length;
        writeInt(bytes, 4, infAddress);
        writeInt(bytes, 24, midAddress);
        writeInt(bytes, 44, midAddress);
        return bytes;
    }

    private static void writeSegment(ByteArrayOutputStream out, int address, String name) throws IOException {
        writeInt(out, address);
        byte[] nameBytes = new byte[16];
        byte[] rawName = name.getBytes(Charset.forName("GB2312"));
        System.arraycopy(rawName, 0, nameBytes, 0, rawName.length);
        out.write(nameBytes);
    }

    private static void writeString(ByteArrayOutputStream out, String value) throws IOException {
        byte[] bytes = value.getBytes(Charset.forName("GB2312"));
        out.write(bytes.length);
        out.write(bytes);
    }

    private static void writeNote(ByteArrayOutputStream out, int sequencer, int duration, int channel,
            int pitch, int volume, int keyboard, int type) throws IOException {
        writeInt(out, sequencer);
        writeInt(out, duration);
        out.write(channel);
        out.write(pitch);
        out.write(volume);
        out.write(keyboard);
        out.write(type);
    }

    private static void writeInt(ByteArrayOutputStream out, int value) throws IOException {
        out.write((value >>> 24) & 0xFF);
        out.write((value >>> 16) & 0xFF);
        out.write((value >>> 8) & 0xFF);
        out.write(value & 0xFF);
    }

    private static void writeInt(byte[] bytes, int offset, int value) {
        bytes[offset] = (byte) ((value >>> 24) & 0xFF);
        bytes[offset + 1] = (byte) ((value >>> 16) & 0xFF);
        bytes[offset + 2] = (byte) ((value >>> 8) & 0xFF);
        bytes[offset + 3] = (byte) (value & 0xFF);
    }
}
```

- [ ] **Step 2: Run parser tests to verify failure**

Run:

```bash
mvn -s .mvn/settings.xml -Dtest=VOSParserTest test
```

Expected: tests fail because `ChartParser` does not dispatch `.vos` files yet.

- [ ] **Step 3: Register VOS dispatch**

Modify `parsers/src/org/open2jam/parsers/ChartParser.java`:

```java
public static ChartList parseFile(File file)
{
    if(OJNParser.canRead(file))return OJNParser.parseFile(file);
    if(VOSParser.canRead(file))return VOSParser.parseFile(file);
    if(BMSParser.canRead(file))return BMSParser.parseFile(file);
    if(SMParser.canRead(file)) return SMParser.parseFile(file);
    if(SNPParser.canRead(file)) return SNPParser.parseFile(file);
    return null;
}
```

- [ ] **Step 4: Implement parser skeleton with header parsing**

Create `parsers/src/org/open2jam/parsers/VOSParser.java`:

```java
package org.open2jam.parsers;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileFilter;
import java.io.FileInputStream;
import java.io.IOException;
import java.nio.charset.Charset;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.logging.Level;
import org.open2jam.parsers.utils.Logger;

class VOSParser {
    private static final Charset VOS_CHARSET = Charset.forName("GB2312");
    private static final int HEADER_MAGIC = 3;
    private static final int INF_PADDING_LENGTH = 1023;

    private static final FileFilter vosFilter = new FileFilter() {
        public boolean accept(File f) {
            return !f.isDirectory() && f.getName().toLowerCase().endsWith(".vos");
        }
    };

    public static boolean canRead(File file) {
        if (file == null) {
            return false;
        }
        if (file.isDirectory()) {
            File[] files = file.listFiles(vosFilter);
            return files != null && files.length > 0;
        }
        return file.getName().toLowerCase().endsWith(".vos") && hasVosHeader(file);
    }

    public static ChartList parseFile(File file) {
        ChartList list = new ChartList();
        list.source_file = file;
        List<File> files = listVosFiles(file);

        for (File vosFile : files) {
            try {
                VOSChart chart = parseVOS(vosFile);
                if (chart != null) {
                    list.add(chart);
                }
            } catch (IOException ex) {
                Logger.global.log(Level.WARNING, "IO error reading VOS file {0}: {1}",
                        new Object[] {vosFile.getName(), ex.getMessage()});
            } catch (IllegalArgumentException ex) {
                Logger.global.log(Level.WARNING, "Invalid VOS file {0}: {1}",
                        new Object[] {vosFile.getName(), ex.getMessage()});
            }
        }

        Collections.sort(list);
        return list.isEmpty() ? null : list;
    }

    public static EventList parseChart(VOSChart chart) {
        EventList events = chart.getEvents();
        return events == null ? new EventList() : events;
    }

    private static List<File> listVosFiles(File file) {
        List<File> files = new ArrayList<File>();
        if (file.isDirectory()) {
            File[] vosFiles = file.listFiles(vosFilter);
            if (vosFiles != null) {
                Collections.addAll(files, vosFiles);
            }
        } else {
            files.add(file);
        }
        return files;
    }

    private static boolean hasVosHeader(File file) {
        try {
            byte[] bytes = readAll(file);
            return bytes.length >= 4 && readInt(bytes, 0) == HEADER_MAGIC;
        } catch (IOException ex) {
            return false;
        }
    }

    private static VOSChart parseVOS(File file) throws IOException {
        byte[] bytes = readAll(file);
        Reader reader = new Reader(bytes);
        int header = reader.readInt();
        if (header != HEADER_MAGIC) {
            throw new IllegalArgumentException("unexpected header");
        }

        List<Segment> segments = readSegments(reader);
        if (segments.size() < 2) {
            throw new IllegalArgumentException("missing VOS segments");
        }

        VOSChart chart = new VOSChart();
        chart.setSource(file);
        chart.setBPM(130);
        chart.setTitle(stripExtension(file.getName()));

        chart.setTitle(defaultString(reader.readString(), stripExtension(file.getName())));
        chart.setArtist(reader.readString());
        reader.readString();
        chart.setNoter(reader.readString());
        int musicType = reader.readUnsignedByte();
        reader.readUnsignedByte();
        chart.setGenre(mapGenre(musicType));
        chart.setDuration(reader.readInt() / 1000);

        if (reader.remainingBefore(segments.get(1).address) > INF_PADDING_LENGTH) {
            chart.setLevel(reader.readUnsignedByte());
        } else {
            chart.markLevelUnknown();
        }
        reader.skipZeros(Math.min(INF_PADDING_LENGTH, reader.remainingBefore(segments.get(1).address)));

        EventList events = readChannels(reader, segments.get(1).address);
        chart.setEvents(events);
        chart.setNoteCount(events.playableNotes);
        return chart;
    }

    private static List<Segment> readSegments(Reader reader) {
        List<Segment> segments = new ArrayList<Segment>();
        while (reader.remaining() >= 20) {
            int address = reader.readInt();
            String name = reader.readFixedString(16);
            segments.add(new Segment(address, name));
            if ("EOF".equals(name) || name.length() == 0) {
                break;
            }
            if (segments.size() > 64) {
                throw new IllegalArgumentException("too many VOS segments");
            }
        }
        return segments;
    }

    private static EventList readChannels(Reader reader, int endAddress) {
        EventList events = new EventList();
        while (reader.position() < endAddress && reader.remainingBefore(endAddress) >= 22) {
            reader.readInt();
            int noteCount = reader.readInt();
            reader.skip(14);
            for (int i = 0; i < noteCount; i++) {
                if (reader.remainingBefore(endAddress) < 13) {
                    throw new IllegalArgumentException("truncated VOS note");
                }
                VOSNote note = readNote(reader);
                addNoteEvents(events, note);
            }
        }
        Collections.sort(events);
        events.fixEventList(EventList.FixMethod.OPEN2JAM, true);
        return events;
    }

    private static VOSNote readNote(Reader reader) {
        int sequencer = reader.readInt();
        int duration = reader.readInt();
        int channel = reader.readUnsignedByte();
        int pitch = reader.readUnsignedByte();
        int volume = reader.readUnsignedByte();
        int keyboard = reader.readUnsignedByte();
        int type = reader.readUnsignedByte();
        return new VOSNote(sequencer, duration, channel, pitch, volume, keyboard, type);
    }

    private static void addNoteEvents(EventList events, VOSNote note) {
        Event.Channel channel = mapKeyboard(note.keyboard);
        if (channel == Event.Channel.NONE) {
            return;
        }

        Position start = toPosition(note.sequencer);
        int value = Math.max(1, note.pitch);
        if (isLongNote(note)) {
            events.add(new Event(channel, start.measure, start.position, value, Event.Flag.HOLD));
            Position end = toPosition(note.sequencer + note.duration);
            events.add(new Event(channel, end.measure, end.position, value, Event.Flag.RELEASE));
        } else {
            events.add(new Event(channel, start.measure, start.position, value, Event.Flag.NONE));
        }
    }

    private static boolean isLongNote(VOSNote note) {
        return (note.type & 0x80) == 0x80 && note.duration > 0;
    }

    private static Event.Channel mapKeyboard(int keyboard) {
        int key = ((keyboard >> 4) - 0x8) & 0x0F;
        switch (key) {
            case 0:
                return Event.Channel.NOTE_1;
            case 1:
                return Event.Channel.NOTE_2;
            case 2:
                return Event.Channel.NOTE_3;
            case 3:
                return Event.Channel.NOTE_4;
            case 4:
                return Event.Channel.NOTE_5;
            case 5:
                return Event.Channel.NOTE_6;
            case 6:
                return Event.Channel.NOTE_7;
            default:
                return Event.Channel.NONE;
        }
    }

    private static Position toPosition(int sequencer) {
        int measure = sequencer / 0x300;
        double position = (sequencer % 0x300) / (double) 0x300;
        return new Position(measure, position);
    }

    private static String mapGenre(int musicType) {
        switch (musicType) {
            case 1:
                return "Pop";
            case 2:
                return "New Age";
            case 3:
                return "Techno";
            case 4:
                return "Rock";
            case 5:
                return "SoundTrack";
            case 6:
                return "Game&Anime";
            case 7:
                return "Jazz";
            case 8:
                return "CenturyEnd";
            case 9:
                return "Classical";
            default:
                return "Other";
        }
    }

    private static String defaultString(String value, String fallback) {
        if (value == null || value.trim().isEmpty()) {
            return fallback;
        }
        return value.trim();
    }

    private static String stripExtension(String name) {
        int dot = name.lastIndexOf('.');
        return dot > 0 ? name.substring(0, dot) : name;
    }

    private static byte[] readAll(File file) throws IOException {
        FileInputStream input = new FileInputStream(file);
        try {
            ByteArrayOutputStream output = new ByteArrayOutputStream();
            byte[] buffer = new byte[8192];
            int read;
            while ((read = input.read(buffer)) != -1) {
                output.write(buffer, 0, read);
            }
            return output.toByteArray();
        } finally {
            input.close();
        }
    }

    private static int readInt(byte[] bytes, int offset) {
        return ((bytes[offset] & 0xFF) << 24)
                | ((bytes[offset + 1] & 0xFF) << 16)
                | ((bytes[offset + 2] & 0xFF) << 8)
                | (bytes[offset + 3] & 0xFF);
    }

    private static final class Segment {
        final int address;
        final String name;

        Segment(int address, String name) {
            this.address = address;
            this.name = name;
        }
    }

    private static final class VOSNote {
        final int sequencer;
        final int duration;
        final int channel;
        final int pitch;
        final int volume;
        final int keyboard;
        final int type;

        VOSNote(int sequencer, int duration, int channel, int pitch, int volume, int keyboard, int type) {
            this.sequencer = sequencer;
            this.duration = duration;
            this.channel = channel;
            this.pitch = pitch;
            this.volume = volume;
            this.keyboard = keyboard;
            this.type = type;
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

    private static final class Reader {
        private final byte[] bytes;
        private int position;

        Reader(byte[] bytes) {
            this.bytes = bytes;
        }

        int position() {
            return position;
        }

        int remaining() {
            return bytes.length - position;
        }

        int remainingBefore(int endAddress) {
            return Math.max(0, Math.min(endAddress, bytes.length) - position);
        }

        int readUnsignedByte() {
            require(1);
            return bytes[position++] & 0xFF;
        }

        int readInt() {
            require(4);
            int value = VOSParser.readInt(bytes, position);
            position += 4;
            return value;
        }

        String readString() {
            int length = readUnsignedByte();
            require(length);
            String value = new String(bytes, position, length, VOS_CHARSET).trim();
            position += length;
            return value;
        }

        String readFixedString(int length) {
            require(length);
            int end = position;
            while (end < position + length && bytes[end] != 0) {
                end++;
            }
            String value = new String(bytes, position, end - position, VOS_CHARSET).trim();
            position += length;
            return value;
        }

        void skip(int count) {
            require(count);
            position += count;
        }

        void skipZeros(int count) {
            require(count);
            position += count;
        }

        private void require(int count) {
            if (position + count > bytes.length) {
                throw new IllegalArgumentException("unexpected end of VOS file");
            }
        }
    }
}
```

- [ ] **Step 5: Run metadata tests**

Run:

```bash
mvn -s .mvn/settings.xml -Dtest=VOSParserTest test
```

Expected: `parsesKnownLevelMetadata` and `parsesMissingLevelAsUnknownLevel` pass.

- [ ] **Step 6: Commit**

```bash
git add parsers/src/org/open2jam/parsers/ChartParser.java parsers/src/org/open2jam/parsers/VOSParser.java src/test/java/org/open2jam/parsers/VOSParserTest.java
git commit -m "feat: parse vos chart metadata"
```

---

### Task 4: Cover VOS Event Mapping

**Files:**
- Modify: `src/test/java/org/open2jam/parsers/VOSParserTest.java`
- Modify: `parsers/src/org/open2jam/parsers/VOSParser.java`

- [ ] **Step 1: Add event mapping tests**

Append these tests to `VOSParserTest`:

```java
@Test
void mapsTapNotesToExistingNoteChannels() throws Exception {
    File chartFile = writeFixture("tap.vos", 5, true, false);

    VOSChart chart = (VOSChart) ChartParser.parseFile(chartFile).get(0);
    EventList events = chart.getEvents();

    assertEquals(1, events.size());
    Event event = events.get(0);
    assertEquals(Event.Channel.NOTE_1, event.getChannel());
    assertEquals(Event.Flag.NONE, event.getFlag());
    assertEquals(0, event.getMeasure());
    assertEquals(0.0, event.getPosition(), 0.0001);
}

@Test
void mapsLongNotesToHoldAndReleaseEvents() throws Exception {
    File chartFile = writeFixture("long.vos", 5, true, true);

    VOSChart chart = (VOSChart) ChartParser.parseFile(chartFile).get(0);
    EventList events = chart.getEvents().getOnlyLongNotes();

    assertEquals(2, events.size());
    assertEquals(Event.Flag.HOLD, events.get(0).getFlag());
    assertEquals(Event.Flag.RELEASE, events.get(1).getFlag());
    assertEquals(1, events.get(0).getMeasure());
    assertEquals(1, events.get(1).getMeasure());
    assertEquals(0.5, events.get(1).getPosition(), 0.0001);
}
```

- [ ] **Step 2: Run event tests**

Run:

```bash
mvn -s .mvn/settings.xml -Dtest=VOSParserTest test
```

Expected: both event tests pass with the `VOSParser` implementation from Task 3. If the long-note test fails because `fixEventList` rewrites or removes events, remove `events.fixEventList(EventList.FixMethod.OPEN2JAM, true);` from `VOSParser.readChannels()` and set `events.playableNotes` manually while adding playable start notes.

- [ ] **Step 3: If needed, replace playable count logic**

If `fixEventList` interferes with synthetic VOS long notes, update `addNoteEvents` and `readChannels` like this:

```java
private static EventList readChannels(Reader reader, int endAddress) {
    EventList events = new EventList();
    while (reader.position() < endAddress && reader.remainingBefore(endAddress) >= 22) {
        reader.readInt();
        int noteCount = reader.readInt();
        reader.skip(14);
        for (int i = 0; i < noteCount; i++) {
            if (reader.remainingBefore(endAddress) < 13) {
                throw new IllegalArgumentException("truncated VOS note");
            }
            VOSNote note = readNote(reader);
            if (addNoteEvents(events, note)) {
                events.playableNotes++;
            }
        }
    }
    Collections.sort(events);
    return events;
}

private static boolean addNoteEvents(EventList events, VOSNote note) {
    Event.Channel channel = mapKeyboard(note.keyboard);
    if (channel == Event.Channel.NONE) {
        return false;
    }

    Position start = toPosition(note.sequencer);
    int value = Math.max(1, note.pitch);
    if (isLongNote(note)) {
        events.add(new Event(channel, start.measure, start.position, value, Event.Flag.HOLD));
        Position end = toPosition(note.sequencer + note.duration);
        events.add(new Event(channel, end.measure, end.position, value, Event.Flag.RELEASE));
    } else {
        events.add(new Event(channel, start.measure, start.position, value, Event.Flag.NONE));
    }
    return true;
}
```

- [ ] **Step 4: Run event tests again**

Run:

```bash
mvn -s .mvn/settings.xml -Dtest=VOSParserTest test
```

Expected: all `VOSParserTest` tests pass.

- [ ] **Step 5: Commit**

```bash
git add parsers/src/org/open2jam/parsers/VOSParser.java src/test/java/org/open2jam/parsers/VOSParserTest.java
git commit -m "feat: map vos notes to events"
```

---

### Task 5: Add Level and Format Display Helpers

**Files:**
- Create: `src/org/open2jam/gui/ChartDisplay.java`
- Create: `src/test/java/org/open2jam/gui/ChartDisplayTest.java`

- [ ] **Step 1: Write display helper tests**

Create `src/test/java/org/open2jam/gui/ChartDisplayTest.java`:

```java
package org.open2jam.gui;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;
import org.open2jam.parsers.Chart;
import org.open2jam.parsers.VOSChart;

class ChartDisplayTest {
    @Test
    void displaysUnknownForVosMissingLevel() {
        VOSChart chart = new VOSChart();
        chart.markLevelUnknown();

        assertEquals("Unknown", ChartDisplay.level(chart));
    }

    @Test
    void displaysKnownVosLevel() {
        VOSChart chart = new VOSChart();
        chart.setLevel(9);

        assertEquals("9", ChartDisplay.level(chart));
    }

    @Test
    void displaysOjnAsO2Jam() {
        Chart chart = new StubChart(Chart.TYPE.OJN, 3);

        assertEquals("O2Jam", ChartDisplay.format(chart));
    }

    @Test
    void displaysVosAsVos() {
        VOSChart chart = new VOSChart();

        assertEquals("VOS", ChartDisplay.format(chart));
    }

    private static class StubChart extends VOSChart {
        StubChart(TYPE type, int level) {
            this.type = type;
            setLevel(level);
        }
    }
}
```

- [ ] **Step 2: Run display tests to verify failure**

Run:

```bash
mvn -s .mvn/settings.xml -Dtest=ChartDisplayTest test
```

Expected: compile fails because `ChartDisplay` does not exist.

- [ ] **Step 3: Create `ChartDisplay`**

Create `src/org/open2jam/gui/ChartDisplay.java`:

```java
package org.open2jam.gui;

import org.open2jam.parsers.Chart;
import org.open2jam.parsers.VOSChart;

public final class ChartDisplay {
    private ChartDisplay() {
    }

    public static String level(Chart chart) {
        if (chart instanceof VOSChart) {
            VOSChart vosChart = (VOSChart) chart;
            if (!vosChart.hasKnownLevel()) {
                return "Unknown";
            }
        }
        return String.valueOf(chart.getLevel());
    }

    public static String format(Chart chart) {
        if (chart == null || chart.type == null) {
            return "";
        }
        switch (chart.type) {
            case OJN:
                return "O2Jam";
            case VOS:
                return "VOS";
            case BMS:
                return "BMS";
            case SM:
                return "SM";
            case XNT:
                return "XNT";
            case NONE:
            default:
                return "";
        }
    }
}
```

- [ ] **Step 4: Run display tests**

Run:

```bash
mvn -s .mvn/settings.xml -Dtest=ChartDisplayTest test
```

Expected: all `ChartDisplayTest` tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/org/open2jam/gui/ChartDisplay.java src/test/java/org/open2jam/gui/ChartDisplayTest.java
git commit -m "feat: add chart display helpers"
```

---

### Task 6: Show Level and Format in File Lists

**Files:**
- Modify: `src/org/open2jam/gui/ChartTableModel.java`
- Modify: `src/org/open2jam/gui/ChartListTableModel.java`
- Test: `src/test/java/org/open2jam/gui/ChartDisplayTest.java`

- [ ] **Step 1: Update chart-detail table columns**

In `src/org/open2jam/gui/ChartTableModel.java`, change:

```java
private final String[] col_names = new String[] { "Level", "Notes", "Keys" };
```

to:

```java
private final String[] col_names = new String[] { "Level", "Format", "Notes", "Keys" };
```

Update `getColumnClass`:

```java
public Class<?> getColumnClass(int columnIndex) {
    switch(columnIndex)
    {
        case 0:return String.class;
        case 1:return String.class;
        case 2:return Integer.class;
        case 3:return Integer.class;
    }
    return Object.class;
}
```

Update `getValueAt`:

```java
public Object getValueAt(int rowIndex, int columnIndex) {
    Chart c = items.get(rowIndex);
    switch(columnIndex)
    {
        case 0:return ChartDisplay.level(c);
        case 1:return ChartDisplay.format(c);
        case 2:return c.getNoteCount();
        case 3:return c.getKeys();
    }
    return null;
}
```

- [ ] **Step 2: Update song-list table columns**

In `src/org/open2jam/gui/ChartListTableModel.java`, change:

```java
private final String[] col_names = new String[] { "Name", "Level", "Genre" };
```

to:

```java
private final String[] col_names = new String[] { "Name", "Level", "Format", "Genre" };
```

Update `getColumnClass`:

```java
public Class<?> getColumnClass(int columnIndex) {
   switch(columnIndex)
    {
        case 0:return String.class;
        case 1:return String.class;
        case 2:return String.class;
        case 3:return String.class;
    }
   return Object.class;
}
```

Update `getValueAt`:

```java
public Object getValueAt(int rowIndex, int columnIndex) {
    Chart c;
    if(items.size() <= rowIndex)return null;
    if(items.get(rowIndex).isEmpty()) return null;
    if(items.get(rowIndex).size()-1 < rank)
        c = items.get(rowIndex).get(0);
    else
        c = items.get(rowIndex).get(rank);
    switch(columnIndex)
    {
        case 0:
            String str = c.getTitle();
            if(items.get(rowIndex).size()-1 < rank)
                str = "[AUTO-EASY] "+str;
            return str;
        case 1:return ChartDisplay.level(c);
        case 2:return ChartDisplay.format(c);
        case 3:return c.getGenre();
    }
    return null;
}
```

- [ ] **Step 3: Add table model smoke assertions**

Append this test to `ChartDisplayTest`:

```java
@Test
void tableModelsExposeFormatColumns() {
    ChartTableModel chartTable = new ChartTableModel();
    ChartListTableModel listTable = new ChartListTableModel();

    assertEquals("Format", chartTable.getColumnName(1));
    assertEquals("Format", listTable.getColumnName(2));
}
```

- [ ] **Step 4: Run UI tests**

Run:

```bash
mvn -s .mvn/settings.xml -Dtest=ChartDisplayTest test
```

Expected: all display tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/org/open2jam/gui/ChartTableModel.java src/org/open2jam/gui/ChartListTableModel.java src/test/java/org/open2jam/gui/ChartDisplayTest.java
git commit -m "feat: show chart format in song lists"
```

---

### Task 7: Full Verification and Documentation Sync

**Files:**
- Modify: `README.md`
- Modify: `docs/superpowers/specs/2026-06-13-vos-format-support-design.md` only if implementation intentionally differs from the confirmed design.

- [ ] **Step 1: Update README supported formats**

In `README.md`, change the supported formats bullet from:

```markdown
* Supports OJN/OJM files and BMS files.
```

to:

```markdown
* Supports OJN/OJM files, VOS files, and BMS files.
```

- [ ] **Step 2: Run parser tests**

Run:

```bash
mvn -s .mvn/settings.xml -Dtest=VOSParserTest,ChartDisplayTest test
```

Expected: all tests pass.

- [ ] **Step 3: Run full test suite**

Run:

```bash
mvn -s .mvn/settings.xml test
```

Expected: build succeeds and all tests pass.

- [ ] **Step 4: Run package verification**

Run:

```bash
mvn -s .mvn/settings.xml -DskipTests package
```

Expected: package succeeds and writes the project jar under `target/`.

- [ ] **Step 5: Check whitespace**

Run:

```bash
git diff --check
```

Expected: no output and exit code 0.

- [ ] **Step 6: Commit**

```bash
git add README.md docs/superpowers/specs/2026-06-13-vos-format-support-design.md
git commit -m "docs: mention vos format support"
```

If `docs/superpowers/specs/2026-06-13-vos-format-support-design.md` is unchanged, commit only `README.md`.

---

## Self-Review

- Spec coverage: parser registration is covered by Tasks 2 and 3. VOS metadata and `Unknown` level are covered by Tasks 2, 3, and 5. VOS event mapping is covered by Task 4. File type display is covered by Tasks 5 and 6. Default thumbnail behavior is covered by `VOSChart.getCover()` in Task 2. Verification is covered by Task 7.
- Placeholder scan: the plan contains no red-flag placeholder tokens or unspecified implementation steps.
- Type consistency: `VOSChart.hasKnownLevel()`, `ChartDisplay.level(Chart)`, `ChartDisplay.format(Chart)`, and `VOSParser.parseChart(VOSChart)` are defined before later tasks reference them.
