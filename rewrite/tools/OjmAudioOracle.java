import java.nio.file.Files;
import java.nio.file.Path;
import org.open2jam.sound.OggPcmDecoder;
import org.open2jam.sound.JavaSoundPcmDecoder;

// Migration-only oracle generator. Rust tests consume the frozen PCM without Java.
class OjmAudioOracle {
    public static void main(String[] args) throws Exception {
        byte[] encoded = Files.readAllBytes(Path.of(args[0]));
        JavaSoundPcmDecoder.DecodedPcm audio = args[0].endsWith(".ogg")
                ? OggPcmDecoder.decode(encoded) : JavaSoundPcmDecoder.decode(encoded);
        Files.write(Path.of(args[1]), audio.pcm);
        System.out.println("channels=" + audio.channels + " rate=" + audio.sampleRate
                + " bits=" + audio.bitsPerSample + " bytes=" + audio.pcm.length);
    }
}
