import java.io.File;
import java.lang.reflect.Method;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.Map;
import java.util.TreeMap;
import org.open2jam.parsers.utils.SampleData;
import org.open2jam.sound.OggPcmDecoder;

// Migration-only production decoder oracle; frozen output is consumed without Java.
class M30Oracle {
    public static void main(String[] args) throws Exception {
        Method parse = Class.forName("org.open2jam.parsers.OJMParser").getDeclaredMethod("parseFile", File.class);
        parse.setAccessible(true);
        @SuppressWarnings("unchecked")
        Map<Integer, SampleData> samples = (Map<Integer, SampleData>) parse.invoke(null, new File(args[0]));
        StringBuilder json = new StringBuilder("{\"samples\":[");
        boolean first = true;
        for (var entry : new TreeMap<>(samples).entrySet()) {
            if (!first) json.append(',');
            first = false;
            byte[] ogg = entry.getValue().getInputStream().readAllBytes();
            byte[] hash = MessageDigest.getInstance("SHA-256").digest(ogg);
            var decoded = OggPcmDecoder.decode(ogg);
            Files.write(Path.of(args[1] + "." + entry.getKey() + ".pcm"), decoded.pcm);
            json.append("{\"index\":").append(entry.getKey()).append(",\"sha256\":\"")
                .append(HexFormat.of().formatHex(hash)).append("\",\"channels\":").append(decoded.channels)
                .append(",\"sampleRate\":").append(decoded.sampleRate).append('}');
            entry.getValue().dispose();
        }
        Files.writeString(Path.of(args[1] + ".json"), json.append("]}\n").toString());
    }
}
