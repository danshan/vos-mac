package org.open2jam.export;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;
import org.open2jam.parsers.Chart;
import org.open2jam.parsers.ChartList;
import org.open2jam.parsers.ChartParser;
import org.open2jam.parsers.VOSChart;

public final class VosCatalogExporter {
    public String exportCatalog(File input) throws Exception {
        List<File> files = listFiles(input);
        List<String> entries = new ArrayList<String>();

        for (File file : files) {
            ChartList charts = ChartParser.parseFile(file);
            if (charts == null) {
                continue;
            }
            for (Chart chart : charts) {
                if (chart instanceof VOSChart) {
                    entries.add(entry((VOSChart) chart));
                }
            }
        }

        return JsonWriter.object(
                JsonWriter.field("schemaVersion", 1),
                JsonWriter.rawField("entries", JsonWriter.array(entries.toArray(new String[0]))));
    }

    private static List<File> listFiles(File input) throws Exception {
        List<File> files = new ArrayList<File>();
        collectFiles(input, files);
        Collections.sort(files, new Comparator<File>() {
            public int compare(File left, File right) {
                try {
                    return left.getCanonicalPath().compareTo(right.getCanonicalPath());
                } catch (Exception e) {
                    return left.getAbsolutePath().compareTo(right.getAbsolutePath());
                }
            }
        });
        return files;
    }

    private static void collectFiles(File input, List<File> files) {
        if (input == null || !input.exists()) {
            return;
        }
        if (!input.isDirectory()) {
            files.add(input);
            return;
        }

        File[] children = input.listFiles();
        if (children == null) {
            return;
        }
        for (File child : children) {
            collectFiles(child, files);
        }
    }

    private static String entry(VOSChart chart) throws Exception {
        String sourcePath = chart.getSource().getCanonicalPath();
        return JsonWriter.object(
                JsonWriter.field("id", idFor(sourcePath)),
                JsonWriter.field("format", "VOS"),
                JsonWriter.field("sourcePath", sourcePath),
                JsonWriter.field("title", chart.getTitle()),
                JsonWriter.field("artist", chart.getArtist()),
                JsonWriter.field("noter", chart.getNoter()),
                JsonWriter.field("genre", chart.getGenre()),
                JsonWriter.field("keys", chart.getKeys()),
                JsonWriter.field("level", chart.getLevel()),
                JsonWriter.field("levelKnown", chart.hasKnownLevel()),
                JsonWriter.field("bpm", chart.getBPM()),
                JsonWriter.field("durationMs", chart.getDuration() * 1000),
                JsonWriter.field("noteCount", chart.getNoteCount()),
                JsonWriter.field("coverAsset", coverAsset(chart)),
                JsonWriter.field("exportStatus", "ok"));
    }

    private static String idFor(String sourcePath) throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        byte[] hash = digest.digest(sourcePath.getBytes(StandardCharsets.UTF_8));
        StringBuilder id = new StringBuilder("vos:sha256:");
        for (int i = 0; i < 8; i++) {
            id.append(String.format("%02x", hash[i] & 0xFF));
        }
        return id.toString();
    }

    private static String coverAsset(VOSChart chart) {
        return chart.hasCover() && chart.getCoverName() != null ? chart.getCoverName() : "";
    }
}
