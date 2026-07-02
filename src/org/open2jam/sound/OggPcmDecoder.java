package org.open2jam.sound;

import static org.lwjgl.stb.STBVorbis.stb_vorbis_decode_memory;
import static org.lwjgl.system.MemoryUtil.memAlloc;
import static org.lwjgl.system.MemoryUtil.memFree;

import java.nio.ByteBuffer;
import java.nio.IntBuffer;
import java.nio.ShortBuffer;
import org.lwjgl.BufferUtils;

public final class OggPcmDecoder {
    private OggPcmDecoder() {
    }

    public static JavaSoundPcmDecoder.DecodedPcm decode(byte[] data) throws SoundSystemException {
        ByteBuffer encoded = memAlloc(data.length);
        ShortBuffer samples = null;
        try {
            encoded.put(data).flip();
            IntBuffer channels = BufferUtils.createIntBuffer(1);
            IntBuffer sampleRate = BufferUtils.createIntBuffer(1);
            samples = stb_vorbis_decode_memory(encoded, channels, sampleRate);
            if (samples == null) {
                throw new SoundSystemException("Unable to decode OGG sample");
            }

            byte[] pcm = new byte[samples.remaining() * 2];
            int output = 0;
            while (samples.hasRemaining()) {
                short sample = samples.get();
                pcm[output++] = (byte) (sample & 0xFF);
                pcm[output++] = (byte) ((sample >>> 8) & 0xFF);
            }
            return new JavaSoundPcmDecoder.DecodedPcm(pcm, channels.get(0), sampleRate.get(0), 16);
        } finally {
            if (samples != null) {
                memFree(samples);
            }
            memFree(encoded);
        }
    }
}
