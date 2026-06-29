package org.open2jam.export;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import org.junit.jupiter.api.Test;

class JsonWriterTest {
    @Test
    void escapesStringsDeterministically() {
        assertEquals("\"line\\nquote\\\"slash\\\\\"", JsonWriter.string("line\nquote\"slash\\"));
    }

    @Test
    void escapesAdditionalControlCharacters() {
        assertEquals("\"line\\rcolumn\\ttail\\u0001\"", JsonWriter.string("line\rcolumn\ttail\u0001"));
    }

    @Test
    void writesObjectWithStableFieldOrder() {
        String json = JsonWriter.object(
                JsonWriter.field("schemaVersion", 1),
                JsonWriter.field("format", "VOS"),
                JsonWriter.field("ready", true));

        assertEquals("{\"schemaVersion\":1,\"format\":\"VOS\",\"ready\":true}", json);
    }

    @Test
    void writesArrays() {
        String json = JsonWriter.array(JsonWriter.string("a"), JsonWriter.string("b"));

        assertEquals("[\"a\",\"b\"]", json);
    }

    @Test
    void writesRawFields() {
        assertEquals(
                "\"notes\":[\"a\"]",
                JsonWriter.rawField("notes", JsonWriter.array(JsonWriter.string("a"))));
    }

    @Test
    void writesFiniteDoubleFields() {
        assertEquals("\"rate\":1.25", JsonWriter.field("rate", 1.25));
    }

    @Test
    void rejectsNonFiniteDoubleFields() {
        assertNonFiniteDoubleRejected(Double.NaN);
        assertNonFiniteDoubleRejected(Double.POSITIVE_INFINITY);
        assertNonFiniteDoubleRejected(Double.NEGATIVE_INFINITY);
    }

    private static void assertNonFiniteDoubleRejected(double value) {
        IllegalArgumentException exception =
                assertThrows(IllegalArgumentException.class, () -> JsonWriter.field("rate", value));

        assertEquals("Non-finite JSON number for field: rate", exception.getMessage());
    }
}
