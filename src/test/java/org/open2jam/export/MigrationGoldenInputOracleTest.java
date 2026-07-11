package org.open2jam.export;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;
import org.junit.jupiter.api.Test;

class MigrationGoldenInputOracleTest {
    private static final Path COMMITTED = Path.of("rewrite/golden/java-migration");

    @Test
    void caseCatalogCoversTwentySevenMeaningfulLogicalCases() {
        List<MigrationGoldenFixtureFactory.CaseDefinition> cases =
                MigrationGoldenFixtureFactory.definitions();

        assertEquals(27, cases.size());
        assertEquals(7, countFormat(cases, MigrationGoldenFixtureFactory.Format.VOS));
        assertEquals(10, countFormat(cases, MigrationGoldenFixtureFactory.Format.OJN_OJM));
        assertEquals(10, countFormat(cases, MigrationGoldenFixtureFactory.Format.OSU_OSZ));
        assertEquals(27, cases.stream().map(MigrationGoldenFixtureFactory.CaseDefinition::id)
                .collect(Collectors.toSet()).size());
        assertTrue(cases.stream().allMatch(item -> !item.provenance().isBlank()));
        assertTrue(cases.stream().allMatch(item -> !item.license().isBlank()));
        assertTrue(cases.stream()
                .filter(item -> item.coverage().contains("stress"))
                .allMatch(item -> item.minimumEvents() >= 4096));
        assertEquals(3, cases.stream().filter(item -> item.coverage().contains("stress")).count());
        assertTrue(coverageFor(cases, MigrationGoldenFixtureFactory.Format.VOS).containsAll(
                Set.of("minimal", "representative", "stress", "malformed", "truncated",
                        "encoding", "unicode", "basename")));
        assertTrue(coverageFor(cases, MigrationGoldenFixtureFactory.Format.OJN_OJM).containsAll(
                Set.of("minimal", "representative", "stress", "malformed", "truncated",
                        "encoding", "unicode", "basename", "missing-companion", "multi-chart",
                        "ojm-plain", "omc", "m30")));
        assertTrue(coverageFor(cases, MigrationGoldenFixtureFactory.Format.OSU_OSZ).containsAll(
                Set.of("minimal", "representative", "stress", "malformed", "truncated",
                        "encoding", "unicode", "basename", "missing-asset", "multi-chart",
                        "osz", "case-insensitive-basename")));
        assertEquals(
                Set.of(
                        MigrationGoldenFixtureFactory.ErrorCode.UNSUPPORTED_FORMAT,
                        MigrationGoldenFixtureFactory.ErrorCode.CORRUPT_CHART,
                        MigrationGoldenFixtureFactory.ErrorCode.MISSING_COMPANION,
                        MigrationGoldenFixtureFactory.ErrorCode.MISSING_ASSET),
                cases.stream()
                        .map(MigrationGoldenFixtureFactory.CaseDefinition::expectedError)
                        .filter(error -> error != null)
                        .collect(Collectors.toSet()));
        cases.stream()
                .filter(item -> item.expectedOutcome()
                        == MigrationGoldenFixtureFactory.Outcome.ACCEPT)
                .forEach(item -> assertNull(item.expectedError()));
    }

    @Test
    void committedCorpusMatchesExecutableJavaOracleWithoutExceptionText() throws Exception {
        List<MigrationGoldenFixtureFactory.CaseDefinition> cases =
                MigrationGoldenFixtureFactory.definitions();

        String actual = MigrationGoldenInputOracle.render(COMMITTED, cases);
        String committed = Files.readString(
                COMMITTED.resolve("expected/parser-oracle.json"), StandardCharsets.UTF_8);

        assertEquals(committed, actual);
        assertEquals(27, countOccurrences(actual, "\"id\": "));
        assertFalse(actual.contains("exception"));
        assertFalse(actual.contains("message"));
        assertFalse(actual.contains("detail"));
    }

    @Test
    void manifestPinsEveryCaseSourceHashOutcomeAndErrorCode() throws Exception {
        String manifest = Files.readString(COMMITTED.resolve("manifest.json"), StandardCharsets.UTF_8);

        for (MigrationGoldenFixtureFactory.CaseDefinition definition
                : MigrationGoldenFixtureFactory.definitions()) {
            Path source = COMMITTED.resolve(definition.source());
            String sourceSha256 = HexFormat.of().formatHex(
                    MessageDigest.getInstance("SHA-256").digest(Files.readAllBytes(source)));
            assertTrue(manifest.contains("\"id\": \"" + definition.id() + "\""));
            assertTrue(manifest.contains("\"sourceSha256\": \"" + sourceSha256 + "\""));
            assertTrue(manifest.contains(
                    "\"expectedOutcome\": \"" + definition.expectedOutcome() + "\""));
            if (definition.expectedError() != null) {
                assertTrue(manifest.contains(
                        "\"expectedError\": \"" + definition.expectedError() + "\""));
            }
        }
    }

    @Test
    void manifestPinsLegacyAliasesOutsideTheTwentySevenLogicalCases() throws Exception {
        String manifest = Files.readString(COMMITTED.resolve("manifest.json"), StandardCharsets.UTF_8);

        assertTrue(manifest.contains("\"legacyAliases\": ["));
        for (String alias : List.of(
                "sources/malformed/truncated.vos",
                "sources/malformed/truncated.ojn",
                "sources/malformed/non-mania.osu")) {
            Path source = COMMITTED.resolve(alias);
            String sha256 = HexFormat.of().formatHex(
                    MessageDigest.getInstance("SHA-256").digest(Files.readAllBytes(source)));
            assertTrue(manifest.contains("\"path\": \"" + alias + "\""));
            assertTrue(manifest.contains("\"sha256\": \"" + sha256 + "\""));
        }
        assertEquals(27, countOccurrences(manifest, "\"id\": "));
    }

    private static long countFormat(
            List<MigrationGoldenFixtureFactory.CaseDefinition> cases,
            MigrationGoldenFixtureFactory.Format format) {
        return cases.stream().filter(item -> item.format() == format).count();
    }

    private static Set<String> coverageFor(
            List<MigrationGoldenFixtureFactory.CaseDefinition> cases,
            MigrationGoldenFixtureFactory.Format format) {
        return cases.stream()
                .filter(item -> item.format() == format)
                .flatMap(item -> item.coverage().stream())
                .collect(Collectors.toSet());
    }

    private static int countOccurrences(String text, String token) {
        int count = 0;
        int offset = 0;
        while ((offset = text.indexOf(token, offset)) >= 0) {
            count++;
            offset += token.length();
        }
        return count;
    }
}
