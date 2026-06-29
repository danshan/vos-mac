package org.open2jam.export;

final class JsonWriter {
    private JsonWriter() {
    }

    static String object(String... fields) {
        StringBuilder out = new StringBuilder();
        out.append('{');
        for (int i = 0; i < fields.length; i++) {
            if (i > 0) {
                out.append(',');
            }
            out.append(fields[i]);
        }
        out.append('}');
        return out.toString();
    }

    static String array(String... values) {
        StringBuilder out = new StringBuilder();
        out.append('[');
        for (int i = 0; i < values.length; i++) {
            if (i > 0) {
                out.append(',');
            }
            out.append(values[i]);
        }
        out.append(']');
        return out.toString();
    }

    static String field(String name, String value) {
        return string(name) + ":" + string(value);
    }

    static String field(String name, int value) {
        return string(name) + ":" + value;
    }

    static String field(String name, double value) {
        if (Double.isNaN(value) || Double.isInfinite(value)) {
            throw new IllegalArgumentException("Non-finite JSON number for field: " + name);
        }
        return string(name) + ":" + value;
    }

    static String field(String name, boolean value) {
        return string(name) + ":" + value;
    }

    static String rawField(String name, String rawJson) {
        return string(name) + ":" + rawJson;
    }

    static String string(String value) {
        StringBuilder out = new StringBuilder();
        out.append('"');
        for (int i = 0; i < value.length(); i++) {
            char c = value.charAt(i);
            switch (c) {
                case '"':
                    out.append("\\\"");
                    break;
                case '\\':
                    out.append("\\\\");
                    break;
                case '\n':
                    out.append("\\n");
                    break;
                case '\r':
                    out.append("\\r");
                    break;
                case '\t':
                    out.append("\\t");
                    break;
                default:
                    if (c < 0x20) {
                        out.append(String.format("\\u%04x", (int) c));
                    } else {
                        out.append(c);
                    }
                    break;
            }
        }
        out.append('"');
        return out.toString();
    }
}
