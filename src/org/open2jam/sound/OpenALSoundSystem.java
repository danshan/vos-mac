package org.open2jam.sound;

import static org.lwjgl.openal.AL10.AL_BUFFER;
import static org.lwjgl.openal.AL10.AL_FORMAT_MONO16;
import static org.lwjgl.openal.AL10.AL_FORMAT_MONO8;
import static org.lwjgl.openal.AL10.AL_FORMAT_STEREO16;
import static org.lwjgl.openal.AL10.AL_FORMAT_STEREO8;
import static org.lwjgl.openal.AL10.AL_GAIN;
import static org.lwjgl.openal.AL10.AL_PITCH;
import static org.lwjgl.openal.AL10.AL_PLAYING;
import static org.lwjgl.openal.AL10.AL_POSITION;
import static org.lwjgl.openal.AL10.AL_SOURCE_STATE;
import static org.lwjgl.openal.AL10.alBufferData;
import static org.lwjgl.openal.AL10.alDeleteBuffers;
import static org.lwjgl.openal.AL10.alDeleteSources;
import static org.lwjgl.openal.AL10.alGenBuffers;
import static org.lwjgl.openal.AL10.alGenSources;
import static org.lwjgl.openal.AL10.alGetSourcei;
import static org.lwjgl.openal.AL10.alSource3f;
import static org.lwjgl.openal.AL10.alSourcePlay;
import static org.lwjgl.openal.AL10.alSourceStop;
import static org.lwjgl.openal.AL10.alSourcef;
import static org.lwjgl.openal.AL10.alSourcei;
import static org.lwjgl.openal.ALC10.alcCloseDevice;
import static org.lwjgl.openal.ALC10.alcCreateContext;
import static org.lwjgl.openal.ALC10.alcDestroyContext;
import static org.lwjgl.openal.ALC10.alcMakeContextCurrent;
import static org.lwjgl.openal.ALC10.alcOpenDevice;
import static org.lwjgl.stb.STBVorbis.stb_vorbis_decode_memory;
import static org.lwjgl.system.MemoryUtil.NULL;
import static org.lwjgl.system.MemoryUtil.memAlloc;
import static org.lwjgl.system.MemoryUtil.memFree;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.IntBuffer;
import java.nio.ShortBuffer;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import javax.sound.midi.InvalidMidiDataException;
import javax.sound.midi.MidiSystem;
import javax.sound.midi.Sequence;
import javax.sound.midi.Sequencer;
import org.lwjgl.BufferUtils;
import org.lwjgl.openal.AL;
import org.lwjgl.openal.ALC;
import org.lwjgl.openal.ALCCapabilities;
import org.open2jam.parsers.utils.SampleData;

public class OpenALSoundSystem implements SoundSystem {
    private final long device;
    private final long context;
    private final List<Integer> buffers = new ArrayList<Integer>();
    private final List<OpenALSoundInstance> activeSources = new ArrayList<OpenALSoundInstance>();
    private final List<MidiSoundInstance> activeMidi = new ArrayList<MidiSoundInstance>();
    private float masterVolume = 1.0f;
    private float bgmVolume = 1.0f;
    private float keyVolume = 1.0f;
    private float speed = 1.0f;

    public OpenALSoundSystem() throws SoundSystemException {
        device = alcOpenDevice((ByteBuffer) null);
        if(device == NULL) throw new SoundSystemException("Unable to open OpenAL device");

        ALCCapabilities capabilities = ALC.createCapabilities(device);
        context = alcCreateContext(device, (IntBuffer) null);
        if(context == NULL) {
            alcCloseDevice(device);
            throw new SoundSystemException("Unable to create OpenAL context");
        }
        alcMakeContextCurrent(context);
        AL.createCapabilities(capabilities);
        System.out.println("Audio engine : OpenAL via LWJGL 3");
    }

    @Override
    public Sound load(SampleData sample) throws SoundSystemException {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        try {
            sample.copyTo(out);
        } catch (IOException e) {
            throw new SoundSystemException(e);
        }

        byte[] data = out.toByteArray();
        if(sample.getType() == SampleData.Type.MIDI) return new MidiSound(data);

        DecodedAudio audio = decode(data, sample.getType());
        if(audio == null) return new SilentSound();

        int buffer = alGenBuffers();
        audio.uploadTo(buffer);
        audio.release();
        buffers.add(buffer);
        return new OpenALSound(buffer);
    }

    @Override
    public void release() {
        for(OpenALSoundInstance instance : new ArrayList<OpenALSoundInstance>(activeSources)) {
            instance.stop();
        }
        for(MidiSoundInstance instance : new ArrayList<MidiSoundInstance>(activeMidi)) {
            instance.stop();
        }
        for(Integer buffer : buffers) {
            alDeleteBuffers(buffer);
        }
        buffers.clear();
        alcMakeContextCurrent(NULL);
        alcDestroyContext(context);
        alcCloseDevice(device);
    }

    @Override
    public void update() {
        Iterator<OpenALSoundInstance> iterator = activeSources.iterator();
        while(iterator.hasNext()) {
            OpenALSoundInstance instance = iterator.next();
            if(!instance.isPlaying()) {
                instance.delete();
                iterator.remove();
            }
        }
        Iterator<MidiSoundInstance> midiIterator = activeMidi.iterator();
        while(midiIterator.hasNext()) {
            MidiSoundInstance instance = midiIterator.next();
            if(!instance.isPlaying()) {
                instance.close();
                midiIterator.remove();
            }
        }
    }

    @Override
    public void setBGMVolume(float factor) {
        bgmVolume = clamp(factor);
        updateActiveVolumes();
    }

    @Override
    public void setKeyVolume(float factor) {
        keyVolume = clamp(factor);
        updateActiveVolumes();
    }

    @Override
    public void setMasterVolume(float factor) {
        masterVolume = clamp(factor);
        updateActiveVolumes();
    }

    @Override
    public void setSpeed(float factor) {
        speed = Math.max(0.25f, Math.min(4.0f, factor));
        for(OpenALSoundInstance instance : activeSources) {
            alSourcef(instance.source, AL_PITCH, speed);
        }
        for(MidiSoundInstance instance : activeMidi) {
            instance.setTempoFactor(speed);
        }
    }

    private DecodedAudio decode(byte[] data, SampleData.Type type) throws SoundSystemException {
        if(type == SampleData.Type.OGG) return decodeOgg(data);
        if(type == SampleData.Type.WAV || type == SampleData.Type.WAV_NO_HEADER) return decodeWav(data);
        return null;
    }

    private DecodedAudio decodeOgg(byte[] data) throws SoundSystemException {
        ByteBuffer encoded = memAlloc(data.length);
        encoded.put(data).flip();
        IntBuffer channels = BufferUtils.createIntBuffer(1);
        IntBuffer sampleRate = BufferUtils.createIntBuffer(1);
        ShortBuffer samples = stb_vorbis_decode_memory(encoded, channels, sampleRate);
        memFree(encoded);
        if(samples == null) return null;
        int format = channels.get(0) == 1 ? AL_FORMAT_MONO16 : AL_FORMAT_STEREO16;
        return new DecodedAudio(samples, format, sampleRate.get(0), true);
    }

    private DecodedAudio decodeWav(byte[] data) throws SoundSystemException {
        if(data.length < 44) return null;
        ByteBuffer input = ByteBuffer.wrap(data).order(ByteOrder.LITTLE_ENDIAN);
        if(input.getInt(0) != 0x46464952 || input.getInt(8) != 0x45564157) return null;

        int cursor = 12;
        int channels = 0;
        int sampleRate = 0;
        int bitsPerSample = 0;
        int dataOffset = -1;
        int dataSize = 0;

        while(cursor + 8 <= data.length) {
            int chunkId = input.getInt(cursor);
            int chunkSize = input.getInt(cursor + 4);
            int chunkData = cursor + 8;
            if(chunkData + chunkSize > data.length) break;

            if(chunkId == 0x20746d66) {
                int audioFormat = input.getShort(chunkData) & 0xffff;
                channels = input.getShort(chunkData + 2) & 0xffff;
                sampleRate = input.getInt(chunkData + 4);
                bitsPerSample = input.getShort(chunkData + 14) & 0xffff;
                if(audioFormat != 1) return null;
            } else if(chunkId == 0x61746164) {
                dataOffset = chunkData;
                dataSize = chunkSize;
            }
            cursor = chunkData + chunkSize + (chunkSize & 1);
        }

        if(dataOffset < 0 || channels == 0 || sampleRate == 0) return null;
        ByteBuffer samples = memAlloc(dataSize);
        samples.put(data, dataOffset, dataSize).flip();
        int format = openAlFormat(channels, bitsPerSample);
        if(format == 0) {
            memFree(samples);
            return null;
        }
        return new DecodedAudio(samples, format, sampleRate, true);
    }

    private int openAlFormat(int channels, int bitsPerSample) {
        if(channels == 1 && bitsPerSample == 8) return AL_FORMAT_MONO8;
        if(channels == 1 && bitsPerSample == 16) return AL_FORMAT_MONO16;
        if(channels == 2 && bitsPerSample == 8) return AL_FORMAT_STEREO8;
        if(channels == 2 && bitsPerSample == 16) return AL_FORMAT_STEREO16;
        return 0;
    }

    private float volumeFor(SoundChannel soundChannel, float volume) {
        float channelVolume = soundChannel == SoundChannel.BGM ? bgmVolume : keyVolume;
        return clamp(masterVolume * channelVolume * volume);
    }

    private void updateActiveVolumes() {
        for(OpenALSoundInstance instance : activeSources) {
            alSourcef(instance.source, AL_GAIN, volumeFor(instance.soundChannel, instance.volume));
        }
    }

    private float clamp(float value) {
        return Math.max(0f, Math.min(1f, value));
    }

    private class OpenALSound implements Sound {
        private final int buffer;

        private OpenALSound(int buffer) {
            this.buffer = buffer;
        }

        @Override
        public SoundInstance play(SoundChannel soundChannel, float volume, float pan) {
            int source = alGenSources();
            alSourcei(source, AL_BUFFER, buffer);
            alSourcef(source, AL_GAIN, volumeFor(soundChannel, volume));
            alSourcef(source, AL_PITCH, speed);
            alSource3f(source, AL_POSITION, Math.max(-1f, Math.min(1f, pan)), 0.0f, 0.0f);
            OpenALSoundInstance instance = new OpenALSoundInstance(source, soundChannel, volume);
            activeSources.add(instance);
            alSourcePlay(source);
            return instance;
        }
    }

    private static class SilentSound implements Sound {
        @Override
        public SoundInstance play(SoundChannel soundChannel, float volume, float pan) {
            return new SilentSoundInstance();
        }
    }

    private static class SilentSoundInstance implements SoundInstance {
        @Override
        public void stop() {
        }
    }

    private class MidiSound implements Sound {
        private final byte[] data;

        private MidiSound(byte[] data) {
            this.data = data;
        }

        @Override
        public SoundInstance play(SoundChannel soundChannel, float volume, float pan) throws SoundSystemException {
            try {
                Sequence sequence = MidiSystem.getSequence(new java.io.ByteArrayInputStream(data));
                Sequencer sequencer = MidiSystem.getSequencer();
                sequencer.open();
                sequencer.setSequence(sequence);
                sequencer.setTempoFactor(speed);
                MidiSoundInstance instance = new MidiSoundInstance(sequencer);
                activeMidi.add(instance);
                sequencer.start();
                return instance;
            } catch (InvalidMidiDataException e) {
                throw new SoundSystemException(e);
            } catch (javax.sound.midi.MidiUnavailableException e) {
                throw new SoundSystemException(e);
            } catch (IOException e) {
                throw new SoundSystemException(e);
            }
        }
    }

    private class MidiSoundInstance implements SoundInstance {
        private final Sequencer sequencer;

        private MidiSoundInstance(Sequencer sequencer) {
            this.sequencer = sequencer;
        }

        @Override
        public void stop() {
            if(sequencer.isOpen()) {
                sequencer.stop();
                close();
            }
            activeMidi.remove(this);
        }

        private boolean isPlaying() {
            return sequencer.isOpen() && sequencer.isRunning();
        }

        private void setTempoFactor(float factor) {
            if(sequencer.isOpen()) {
                sequencer.setTempoFactor(factor);
            }
        }

        private void close() {
            if(sequencer.isOpen()) sequencer.close();
        }
    }

    private class OpenALSoundInstance implements SoundInstance {
        private final int source;
        private final SoundChannel soundChannel;
        private final float volume;
        private boolean deleted;

        private OpenALSoundInstance(int source, SoundChannel soundChannel, float volume) {
            this.source = source;
            this.soundChannel = soundChannel;
            this.volume = volume;
        }

        @Override
        public void stop() {
            alSourceStop(source);
            delete();
            activeSources.remove(this);
        }

        private boolean isPlaying() {
            return !deleted && alGetSourcei(source, AL_SOURCE_STATE) == AL_PLAYING;
        }

        private void delete() {
            if(deleted) return;
            alDeleteSources(source);
            deleted = true;
        }
    }

    private static class DecodedAudio {
        private final java.nio.Buffer samples;
        private final int format;
        private final int sampleRate;
        private final boolean nativeMemory;

        private DecodedAudio(java.nio.Buffer samples, int format, int sampleRate, boolean nativeMemory) {
            this.samples = samples;
            this.format = format;
            this.sampleRate = sampleRate;
            this.nativeMemory = nativeMemory;
        }

        private void uploadTo(int buffer) throws SoundSystemException {
            if(samples instanceof ByteBuffer) {
                alBufferData(buffer, format, (ByteBuffer) samples, sampleRate);
                return;
            }
            if(samples instanceof ShortBuffer) {
                alBufferData(buffer, format, (ShortBuffer) samples, sampleRate);
                return;
            }
            throw new SoundSystemException("Unsupported decoded audio buffer type: " + samples.getClass().getName());
        }

        private void release() {
            if(nativeMemory) memFree(samples);
        }
    }
}
