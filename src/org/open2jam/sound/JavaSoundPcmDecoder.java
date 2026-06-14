package org.open2jam.sound;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import javax.sound.sampled.AudioFormat;
import javax.sound.sampled.AudioInputStream;
import javax.sound.sampled.AudioSystem;

final class JavaSoundPcmDecoder {
    private JavaSoundPcmDecoder() {
    }

    static DecodedPcm decode(byte[] data) throws SoundSystemException {
        try {
            AudioInputStream source = AudioSystem.getAudioInputStream(new ByteArrayInputStream(data));
            AudioFormat sourceFormat = source.getFormat();
            AudioFormat targetFormat = new AudioFormat(
                    AudioFormat.Encoding.PCM_SIGNED,
                    sourceFormat.getSampleRate(),
                    16,
                    sourceFormat.getChannels(),
                    sourceFormat.getChannels() * 2,
                    sourceFormat.getSampleRate(),
                    false);
            AudioInputStream pcmStream = AudioSystem.getAudioInputStream(targetFormat, source);
            ByteArrayOutputStream output = new ByteArrayOutputStream();
            byte[] buffer = new byte[8192];
            int read;
            while ((read = pcmStream.read(buffer)) >= 0) {
                output.write(buffer, 0, read);
            }
            pcmStream.close();
            source.close();
            return new DecodedPcm(output.toByteArray(), targetFormat.getChannels(),
                    (int) targetFormat.getSampleRate(), targetFormat.getSampleSizeInBits());
        } catch (Exception ex) {
            throw new SoundSystemException(ex);
        }
    }

    static final class DecodedPcm {
        final byte[] pcm;
        final int channels;
        final int sampleRate;
        final int bitsPerSample;

        DecodedPcm(byte[] pcm, int channels, int sampleRate, int bitsPerSample) {
            this.pcm = pcm;
            this.channels = channels;
            this.sampleRate = sampleRate;
            this.bitsPerSample = bitsPerSample;
        }
    }
}
