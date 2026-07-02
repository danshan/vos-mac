package org.open2jam.export;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;
import org.open2jam.parsers.Chart;
import org.open2jam.parsers.VOSChart;

public final class VosCatalogExporter {
    public String exportCatalog(File input) throws Exception {
        List<File> files = listFiles(input);
        List<String> entries = new ArrayList<String>();

        for (File file : files) {
            List<Chart> gameplayCharts = PlayableChartSelector.playableCharts(file);
            for (int i = 0; i < gameplayCharts.size(); i++) {
                entries.add(entry(gameplayCharts.get(i), gameplayCharts.size(), i));
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
            if (isSupportedChartFile(input)) {
                files.add(input);
            }
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

    private static boolean isSupportedChartFile(File file) {
        String name = file.getName().toLowerCase();
        return name.endsWith(".vos") || name.endsWith(".osu") || name.endsWith(".osz") || name.endsWith(".ojn");
    }

    private static String entry(Chart chart, int chartCount, int chartIndex) throws Exception {
        String sourcePath = chart.getSource().getCanonicalPath();
        List<String> fields = new ArrayList<String>();
        fields.add(JsonWriter.field("id",
                idFor(idPrefixFor(chart), identitySourcePath(sourcePath, chartCount, chartIndex))));
        fields.add(JsonWriter.field("format", formatFor(chart)));
        fields.add(JsonWriter.field("sourcePath", sourcePath));
        if (chartCount > 1) {
            fields.add(JsonWriter.field("chartIndex", chartIndex));
        }
        fields.add(JsonWriter.field("title", chart.getTitle()));
        fields.add(JsonWriter.field("artist", chart.getArtist()));
        fields.add(JsonWriter.field("noter", chart.getNoter()));
        fields.add(JsonWriter.field("genre", chart.getGenre()));
        fields.add(JsonWriter.field("keys", chart.getKeys()));
        fields.add(JsonWriter.field("level", chart.getLevel()));
        fields.add(JsonWriter.field("levelKnown", levelKnown(chart)));
        fields.add(JsonWriter.field("bpm", chart.getBPM()));
        fields.add(JsonWriter.field("durationMs", chart.getDuration() * 1000));
        fields.add(JsonWriter.field("noteCount", chart.getNoteCount()));
        fields.add(JsonWriter.field("coverAsset", coverAsset(chart)));
        fields.add(JsonWriter.field("exportStatus", "ready"));
        return JsonWriter.object(fields.toArray(new String[fields.size()]));
    }

    private static String idFor(String prefix, String sourcePath) throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        byte[] hash = digest.digest(sourcePath.getBytes(StandardCharsets.UTF_8));
        StringBuilder id = new StringBuilder(prefix + ":sha256:");
        for (int i = 0; i < 8; i++) {
            id.append(String.format("%02x", hash[i] & 0xFF));
        }
        return id.toString();
    }

    private static String identitySourcePath(String sourcePath, int chartCount, int chartIndex) {
        if (chartCount <= 1) {
            return sourcePath;
        }
        return sourcePath + "#chart=" + chartIndex;
    }

    private static String formatFor(Chart chart) {
        if (chart.type == Chart.TYPE.OSU) {
            return "OSU";
        }
        if (chart.type == Chart.TYPE.OJN) {
            return "OJN";
        }
        return "VOS";
    }

    private static String idPrefixFor(Chart chart) {
        if (chart.type == Chart.TYPE.OSU) {
            return "osu";
        }
        if (chart.type == Chart.TYPE.OJN) {
            return "ojn";
        }
        return "vos";
    }

    private static boolean levelKnown(Chart chart) {
        return !(chart instanceof VOSChart) || ((VOSChart) chart).hasKnownLevel();
    }

    private static String coverAsset(Chart chart) {
        return chart.hasCover() && chart.getCoverName() != null ? chart.getCoverName() : "";
    }
}
