package org.open2jam.export;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class JsonWriterTest {
    @Test
    void escapesStringsDeterministically() {
        assertEquals("\"line\\nquote\\\"slash\\\\\"", JsonWriter.string("line\nquote\"slash\\"));
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
}
