import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.Random;
import org.open2jam.sound.OggPcmDecoder;
import org.open2jam.sound.JavaSoundPcmDecoder;

// Migration-only oracle generator. Rust tests consume the frozen PCM without Java.
class OjmAudioOracle {
    public static void main(String[] args) throws Exception {
        if (args[0].equals("--integer-fixtures")) {
            writeIntegerFixtures(Path.of(args[1]));
            return;
        }
        if (args[0].equals("--extended-fixtures")) {
            writeExtendedFixtures(Path.of(args[1]));
            return;
        }
        byte[] encoded = Files.readAllBytes(Path.of(args[0]));
        JavaSoundPcmDecoder.DecodedPcm audio = args[0].endsWith(".ogg")
                ? OggPcmDecoder.decode(encoded) : JavaSoundPcmDecoder.decode(encoded);
        Files.write(Path.of(args[1]), audio.pcm);
        System.out.println("channels=" + audio.channels + " rate=" + audio.sampleRate
                + " bits=" + audio.bitsPerSample + " bytes=" + audio.pcm.length);
    }

    private static void writeIntegerFixtures(Path output) throws Exception {
        Random random = new Random(20260919L);
        StringBuilder json = new StringBuilder("{\"seed\":20260919,\"cases\":[\n");
        for (int bits : new int[] {8, 24, 32}) {
            if (bits != 8) json.append(",\n");
            int[] values = new int[256];
            int minimum = bits == 24 ? -8388608 : Integer.MIN_VALUE;
            int maximum = bits == 24 ? 8388607 : Integer.MAX_VALUE;
            for (int i = 0; i < values.length; i++) {
                values[i] = bits == 8 ? i : random.nextInt() >> (32 - bits);
            }
            if (bits != 8) {
                int[] edges = {minimum, minimum + 1, -65536, -256, -1, 0, 1, 256, 65536, maximum - 1, maximum};
                System.arraycopy(edges, 0, values, 0, edges.length);
            }
            int payloadSize = values.length * bits / 8;
            ByteBuffer wav = ByteBuffer.allocate(44 + payloadSize).order(ByteOrder.LITTLE_ENDIAN);
            wav.put(new byte[] {'R','I','F','F'}).putInt(36 + payloadSize);
            wav.put(new byte[] {'W','A','V','E','f','m','t',' '}).putInt(16);
            wav.putShort((short) 1).putShort((short) 1).putInt(8000).putInt(8000 * bits / 8);
            wav.putShort((short) (bits / 8)).putShort((short) bits);
            wav.put(new byte[] {'d','a','t','a'}).putInt(payloadSize);
            for (int value : values) for (int byteIndex = 0; byteIndex < bits / 8; byteIndex++) wav.put((byte) (value >>> (byteIndex * 8)));
            byte[] pcm = JavaSoundPcmDecoder.decode(wav.array()).pcm;
            json.append("{\"bits\":").append(bits).append(",\"input\":[");
            for (int i = 0; i < values.length; i++) { if (i != 0) json.append(','); json.append(values[i]); }
            json.append("],\"expected\":[");
            ByteBuffer decoded = ByteBuffer.wrap(pcm).order(ByteOrder.LITTLE_ENDIAN);
            for (int i = 0; decoded.hasRemaining(); i++) { if (i != 0) json.append(','); json.append(decoded.getShort()); }
            json.append("]}");
        }
        Files.writeString(output, json.append("\n]}\n").toString());
    }

    private static void writeExtendedFixtures(Path output) throws Exception {
        StringBuilder json = new StringBuilder("{\"cases\":[\n");
        for (int index = 0; index < 4; index++) {
            int tag = index < 2 ? 3 : index + 4;
            int bits = index == 0 ? 32 : index == 1 ? 64 : 8;
            ByteBuffer payload = ByteBuffer.allocate(index < 2 ? 11 * bits / 8 : 256).order(ByteOrder.LITTLE_ENDIAN);
            if (index < 2) {
                for (double value : new double[] {-2, -1, -0.75, -0.5, -0.0001, 0, 0.0001, 0.5, 0.75, 1, 2}) {
                    if (bits == 32) payload.putFloat((float) value); else payload.putDouble(value);
                }
            } else { for (int i = 0; i < 256; i++) payload.put((byte) i); }
            ByteBuffer wav = ByteBuffer.allocate(44 + payload.capacity()).order(ByteOrder.LITTLE_ENDIAN);
            wav.put(new byte[] {'R','I','F','F'}).putInt(36 + payload.capacity());
            wav.put(new byte[] {'W','A','V','E','f','m','t',' '}).putInt(16);
            wav.putShort((short) tag).putShort((short) 1).putInt(8000).putInt(8000 * bits / 8);
            wav.putShort((short) (bits / 8)).putShort((short) bits);
            wav.put(new byte[] {'d','a','t','a'}).putInt(payload.capacity()).put(payload.array());
            byte[] pcm = JavaSoundPcmDecoder.decode(wav.array()).pcm;
            if (index != 0) json.append(",\n");
            json.append("{\"format\":").append(tag).append(",\"bits\":").append(bits).append(",\"input\":[");
            for (int i = 0; i < payload.capacity(); i++) { if (i != 0) json.append(','); json.append(payload.array()[i] & 255); }
            json.append("],\"expected\":[");
            ByteBuffer decoded = ByteBuffer.wrap(pcm).order(ByteOrder.LITTLE_ENDIAN);
            for (int i = 0; decoded.hasRemaining(); i++) { if (i != 0) json.append(','); json.append(decoded.getShort()); }
            json.append("]}");
        }
        Files.writeString(output, json.append("\n]}\n").toString());
    }
}
