package org.open2jam.export;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.zip.ZipFile;
import org.open2jam.parsers.Chart;
import org.open2jam.parsers.ChartList;
import org.open2jam.parsers.ChartParser;
import org.open2jam.parsers.utils.SampleData;

final class MigrationGoldenInputOracle {
    private static final int OJN_SIGNATURE = 0x006E6A6F;

    private MigrationGoldenInputOracle() {
    }

    static String render(
            Path corpusRoot,
            List<MigrationGoldenFixtureFactory.CaseDefinition> definitions) throws Exception {
        StringBuilder json = new StringBuilder();
        json.append("{\n  \"schemaVersion\": 1,\n  \"cases\": [\n");
        for (int i = 0; i < definitions.size(); i++) {
            MigrationGoldenFixtureFactory.CaseDefinition definition = definitions.get(i);
            OracleResult result = evaluate(corpusRoot, definition);
            assertExpected(definition, result);
            json.append("    ").append(renderResult(definition, result));
            json.append(i + 1 == definitions.size() ? "\n" : ",\n");
        }
        return json.append("  ]\n}\n").toString();
    }

    private static OracleResult evaluate(
            Path corpusRoot,
            MigrationGoldenFixtureFactory.CaseDefinition definition) {
        Path source = corpusRoot.resolve(definition.source());
        try {
            if (!Files.isRegularFile(source)) {
                return rejected(MigrationGoldenFixtureFactory.ErrorCode.CORRUPT_CHART);
            }
            return switch (definition.format()) {
                case VOS -> evaluateVos(source);
                case OJN_OJM -> evaluateOjn(corpusRoot, definition, source);
                case OSU_OSZ -> evaluateOsu(source);
            };
        } catch (Exception failure) {
            return rejected(MigrationGoldenFixtureFactory.ErrorCode.CORRUPT_CHART);
        }
    }

    private static OracleResult evaluateVos(Path source) throws Exception {
        ChartList charts = ChartParser.parseFile(source.toFile());
        if (charts == null || charts.isEmpty()) {
            return rejected(MigrationGoldenFixtureFactory.ErrorCode.CORRUPT_CHART);
        }
        return accepted(charts, SampleScope.ALL_CHARTS);
    }

    private static OracleResult evaluateOjn(
            Path corpusRoot,
            MigrationGoldenFixtureFactory.CaseDefinition definition,
            Path source) throws Exception {
        if (!hasOjnHeader(source)) {
            return rejected(MigrationGoldenFixtureFactory.ErrorCode.CORRUPT_CHART);
        }
        ChartList charts = ChartParser.parseFile(source.toFile());
        if (charts == null || charts.isEmpty()) {
            return rejected(MigrationGoldenFixtureFactory.ErrorCode.CORRUPT_CHART);
        }
        if (definition.relatedFiles().isEmpty()
                || definition.relatedFiles().stream()
                        .map(corpusRoot::resolve)
                        .anyMatch(path -> !Files.isRegularFile(path))) {
            return rejected(MigrationGoldenFixtureFactory.ErrorCode.MISSING_COMPANION);
        }
        OracleResult result = accepted(charts, SampleScope.FIRST_CHART);
        if (result.sampleCount() == 0) {
            return rejected(MigrationGoldenFixtureFactory.ErrorCode.CORRUPT_CHART);
        }
        return result;
    }

    private static OracleResult evaluateOsu(Path source) throws Exception {
        String lowerName = source.getFileName().toString().toLowerCase();
        if (lowerName.endsWith(".osz")) {
            try (ZipFile ignored = new ZipFile(source.toFile())) {
                // Opening the central directory distinguishes corrupt archives from unsupported charts.
            }
        } else if (lowerName.endsWith(".osu")) {
            String content = Files.readString(source, StandardCharsets.UTF_8);
            if (!content.startsWith("osu file format v")) {
                return rejected(MigrationGoldenFixtureFactory.ErrorCode.CORRUPT_CHART);
            }
        } else {
            return rejected(MigrationGoldenFixtureFactory.ErrorCode.UNSUPPORTED_FORMAT);
        }

        ChartList charts = ChartParser.parseFile(source.toFile());
        if (charts == null || charts.isEmpty()) {
            return rejected(MigrationGoldenFixtureFactory.ErrorCode.UNSUPPORTED_FORMAT);
        }
        OracleResult result = accepted(charts, SampleScope.ALL_CHARTS);
        int expectedSamples = charts.stream().mapToInt(chart -> chart.getSampleIndex().size()).sum();
        if (result.sampleCount() != expectedSamples) {
            return rejected(MigrationGoldenFixtureFactory.ErrorCode.MISSING_ASSET);
        }
        return result;
    }

    private static boolean hasOjnHeader(Path source) throws Exception {
        if (Files.size(source) < 300) {
            return false;
        }
        byte[] header = Files.readAllBytes(source);
        return ByteBuffer.wrap(header, 4, 4).order(ByteOrder.LITTLE_ENDIAN).getInt()
                == OJN_SIGNATURE;
    }

    private static OracleResult accepted(ChartList charts, SampleScope sampleScope)
            throws Exception {
        List<String> titles = new ArrayList<>();
        List<Integer> levels = new ArrayList<>();
        int notes = 0;
        int events = 0;
        int samples = 0;
        for (int i = 0; i < charts.size(); i++) {
            Chart chart = charts.get(i);
            titles.add(chart.getTitle());
            levels.add(chart.getLevel());
            notes += chart.getNoteCount();
            events += chart.getEvents().size();
            if (sampleScope == SampleScope.ALL_CHARTS || i == 0) {
                samples += countAndDispose(chart.getSamples());
            }
        }
        return new OracleResult(
                MigrationGoldenFixtureFactory.Outcome.ACCEPT,
                null,
                charts.size(),
                notes,
                events,
                samples,
                List.copyOf(titles),
                List.copyOf(levels));
    }

    private static int countAndDispose(Map<Integer, SampleData> samples) throws Exception {
        Exception failure = null;
        for (SampleData sample : samples.values()) {
            try {
                sample.dispose();
            } catch (IOException disposeFailure) {
                if (failure == null) {
                    failure = disposeFailure;
                } else {
                    failure.addSuppressed(disposeFailure);
                }
            }
        }
        if (failure != null) {
            throw failure;
        }
        return samples.size();
    }

    private static OracleResult rejected(MigrationGoldenFixtureFactory.ErrorCode error) {
        return new OracleResult(
                MigrationGoldenFixtureFactory.Outcome.REJECT,
                error,
                0,
                0,
                0,
                0,
                List.of(),
                List.of());
    }

    private static void assertExpected(
            MigrationGoldenFixtureFactory.CaseDefinition definition,
            OracleResult result) {
        if (result.outcome() != definition.expectedOutcome()
                || result.errorCode() != definition.expectedError()) {
            throw new IllegalStateException(
                    "Java input oracle drift for " + definition.id()
                            + ": expected " + definition.expectedOutcome() + "/"
                            + definition.expectedError() + ", got " + result.outcome() + "/"
                            + result.errorCode());
        }
        if (result.outcome() == MigrationGoldenFixtureFactory.Outcome.ACCEPT
                && result.eventCount() < definition.minimumEvents()) {
            throw new IllegalStateException(
                    "Java input oracle event floor drift for " + definition.id()
                            + ": expected at least " + definition.minimumEvents()
                            + ", got " + result.eventCount());
        }
    }

    private static String renderResult(
            MigrationGoldenFixtureFactory.CaseDefinition definition,
            OracleResult result) {
        return "{\"id\": \"" + jsonEscape(definition.id())
                + "\", \"format\": \"" + definition.format()
                + "\", \"outcome\": \"" + result.outcome()
                + "\", \"errorCode\": "
                + (result.errorCode() == null ? "null" : "\"" + result.errorCode() + "\"")
                + ", \"chartCount\": " + result.chartCount()
                + ", \"noteCount\": " + result.noteCount()
                + ", \"eventCount\": " + result.eventCount()
                + ", \"sampleCount\": " + result.sampleCount()
                + ", \"titles\": " + renderStrings(result.titles())
                + ", \"levels\": " + result.levels()
                + "}";
    }

    private static String renderStrings(List<String> values) {
        return values.stream()
                .map(value -> "\"" + jsonEscape(value) + "\"")
                .collect(java.util.stream.Collectors.joining(", ", "[", "]"));
    }

    static String jsonEscape(String value) {
        StringBuilder escaped = new StringBuilder();
        for (int i = 0; i < value.length(); i++) {
            char character = value.charAt(i);
            switch (character) {
                case '"' -> escaped.append("\\\"");
                case '\\' -> escaped.append("\\\\");
                case '\b' -> escaped.append("\\b");
                case '\f' -> escaped.append("\\f");
                case '\n' -> escaped.append("\\n");
                case '\r' -> escaped.append("\\r");
                case '\t' -> escaped.append("\\t");
                default -> {
                    if (character < 0x20) {
                        escaped.append(String.format("\\u%04x", (int) character));
                    } else {
                        escaped.append(character);
                    }
                }
            }
        }
        return escaped.toString();
    }

    private enum SampleScope {
        FIRST_CHART,
        ALL_CHARTS
    }

    private record OracleResult(
            MigrationGoldenFixtureFactory.Outcome outcome,
            MigrationGoldenFixtureFactory.ErrorCode errorCode,
            int chartCount,
            int noteCount,
            int eventCount,
            int sampleCount,
            List<String> titles,
            List<Integer> levels) {
    }
}
