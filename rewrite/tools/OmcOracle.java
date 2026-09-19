import java.io.ByteArrayOutputStream;
import java.io.File;
import java.lang.reflect.Method;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HexFormat;
import java.util.Map;
import java.util.TreeMap;
import org.open2jam.parsers.utils.SampleData;
import org.open2jam.sound.JavaSoundPcmDecoder;

// Migration-only oracle: invoke the production Java bank decoder, then freeze its output.
class OmcOracle {
    public static void main(String[] args) throws Exception {
        Class<?> parser = Class.forName("org.open2jam.parsers.OJMParser");
        Method parse = parser.getDeclaredMethod("parseFile", File.class);
        parse.setAccessible(true);
        @SuppressWarnings("unchecked")
        Map<Integer, SampleData> samples = (Map<Integer, SampleData>) parse.invoke(null, new File(args[0]));
        StringBuilder json = new StringBuilder("{\"samples\":[");
        boolean first = true;
        for (var entry : new TreeMap<>(samples).entrySet()) {
            if (!first) json.append(',');
            first = false;
            ByteArrayOutputStream output = new ByteArrayOutputStream();
            entry.getValue().copyTo(output);
            byte[] wav = output.toByteArray();
            byte[] raw = java.util.Arrays.copyOfRange(wav, 44, wav.length);
            byte[] pcm = JavaSoundPcmDecoder.decode(wav).pcm;
            json.append("{\"index\":").append(entry.getKey())
                .append(",\"rawHex\":\"").append(HexFormat.of().formatHex(raw))
                .append("\",\"pcm16Hex\":\"").append(HexFormat.of().formatHex(pcm)).append("\"}");
            entry.getValue().dispose();
        }
        Files.writeString(Path.of(args[1]), json.append("]}\n").toString());
    }
}
