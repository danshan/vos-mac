package org.open2jam.sound;

import com.sun.media.sound.AudioSynthesizer;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import javax.sound.midi.InvalidMidiDataException;
import javax.sound.midi.MetaMessage;
import javax.sound.midi.MidiDevice;
import javax.sound.midi.MidiEvent;
import javax.sound.midi.MidiMessage;
import javax.sound.midi.MidiSystem;
import javax.sound.midi.MidiUnavailableException;
import javax.sound.midi.Receiver;
import javax.sound.midi.Sequence;
import javax.sound.midi.ShortMessage;
import javax.sound.midi.Soundbank;
import javax.sound.midi.Synthesizer;
import javax.sound.sampled.AudioFormat;
import javax.sound.sampled.AudioInputStream;

final class MidiSampleRenderer {
    private static final int SAMPLE_RATE = 44100;
    private static final int BITS_PER_SAMPLE = 16;
    private static final int CHANNELS = 2;
    private static final long MIN_NOTE_GATE_MICROSECONDS = 60_000L;
    private static final long TAIL_MICROSECONDS = 500_000L;
    private static final File MACOS_DLS = new File(
            "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls");

    RenderedAudio render(byte[] midiData) throws SoundSystemException {
        AudioSynthesizer synth = findAudioSynthesizer();
        if (synth == null) {
            throw new SoundSystemException("No audio synthesizer available for MIDI rendering");
        }

        try {
            Sequence sequence = MidiSystem.getSequence(new ByteArrayInputStream(midiData));
            AudioFormat format = new AudioFormat(SAMPLE_RATE, BITS_PER_SAMPLE, CHANNELS, true, false);
            AudioInputStream stream = synth.openStream(format, null);
            loadMacOSSoundsIfAvailable(synth);
            Receiver receiver = synth.getReceiver();
            long renderedLength = sendSequence(sequence, receiver) + TAIL_MICROSECONDS;
            receiver.close();

            int frameSize = format.getFrameSize();
            long frames = Math.max(1L, renderedLength * SAMPLE_RATE / 1_000_000L);
            long bytesToRead = frames * frameSize;
            ByteArrayOutputStream output = new ByteArrayOutputStream((int) Math.min(bytesToRead, 64L * 1024L * 1024L));
            byte[] buffer = new byte[8192];
            long remaining = bytesToRead;
            while (remaining > 0) {
                int read = stream.read(buffer, 0, (int) Math.min(buffer.length, remaining));
                if (read < 0) {
                    break;
                }
                output.write(buffer, 0, read);
                remaining -= read;
            }
            stream.close();
            return new RenderedAudio(output.toByteArray(), SAMPLE_RATE, CHANNELS, BITS_PER_SAMPLE);
        } catch (InvalidMidiDataException e) {
            throw new SoundSystemException(e);
        } catch (MidiUnavailableException e) {
            throw new SoundSystemException(e);
        } catch (IOException e) {
            throw new SoundSystemException(e);
        } finally {
            synth.close();
        }
    }

    private static AudioSynthesizer findAudioSynthesizer() throws SoundSystemException {
        Synthesizer defaultSynth;
        try {
            defaultSynth = MidiSystem.getSynthesizer();
            if (defaultSynth instanceof AudioSynthesizer) {
                return (AudioSynthesizer) defaultSynth;
            }
        } catch (Exception ignored) {
        }

        MidiDevice.Info[] infos = MidiSystem.getMidiDeviceInfo();
        for (MidiDevice.Info info : infos) {
            try {
                MidiDevice device = MidiSystem.getMidiDevice(info);
                if (device instanceof AudioSynthesizer) {
                    return (AudioSynthesizer) device;
                }
            } catch (Exception ignored) {
            }
        }
        return null;
    }

    private static void loadMacOSSoundsIfAvailable(Synthesizer synth) {
        if (!MACOS_DLS.isFile()) {
            return;
        }
        try {
            Soundbank soundbank = MidiSystem.getSoundbank(MACOS_DLS);
            if (soundbank == null) {
                return;
            }
            Soundbank defaultSoundbank = synth.getDefaultSoundbank();
            if (defaultSoundbank != null) {
                synth.unloadAllInstruments(defaultSoundbank);
            }
            synth.loadAllInstruments(soundbank);
        } catch (Exception ignored) {
        }
    }

    private static long sendSequence(Sequence sequence, Receiver receiver) {
        List<TimedMidiMessage> messages = sortedMessages(sequence);
        List<ScheduledMidiMessage> scheduledMessages = new ArrayList<ScheduledMidiMessage>();
        int resolution = Math.max(1, sequence.getResolution());
        long currentTick = 0;
        long currentMicros = 0;
        int tempo = 500_000;
        long lastMicros = 0;
        Map<String, Long> activeNotes = new HashMap<String, Long>();

        for (TimedMidiMessage timed : messages) {
            if (sequence.getDivisionType() == Sequence.PPQ) {
                long deltaTicks = Math.max(0, timed.tick - currentTick);
                currentMicros += deltaTicks * tempo / resolution;
            } else {
                currentMicros = sequence.getMicrosecondLength() * timed.tick
                        / Math.max(1, sequence.getTickLength());
            }
            currentTick = timed.tick;
            lastMicros = Math.max(lastMicros, currentMicros);

            Integer newTempo = tempoFrom(timed.message);
            if (newTempo != null) {
                tempo = newTempo;
            } else if (!(timed.message instanceof MetaMessage)) {
                long sendMicros = adjustedSendMicros(timed.message, currentMicros, activeNotes);
                scheduledMessages.add(new ScheduledMidiMessage(sendMicros, timed.message));
                lastMicros = Math.max(lastMicros, sendMicros);
            }
        }
        Collections.sort(scheduledMessages);
        for (ScheduledMidiMessage scheduled : scheduledMessages) {
            receiver.send(scheduled.message, scheduled.micros);
        }
        return Math.max(lastMicros, sequence.getMicrosecondLength());
    }

    private static long adjustedSendMicros(MidiMessage message, long currentMicros, Map<String, Long> activeNotes) {
        if (!(message instanceof ShortMessage)) {
            return currentMicros;
        }
        ShortMessage shortMessage = (ShortMessage) message;
        int command = shortMessage.getCommand();
        if (command != ShortMessage.NOTE_ON && command != ShortMessage.NOTE_OFF) {
            return currentMicros;
        }

        String key = shortMessage.getChannel() + ":" + shortMessage.getData1();
        if (command == ShortMessage.NOTE_ON && shortMessage.getData2() > 0) {
            activeNotes.put(key, currentMicros);
            return currentMicros;
        }

        Long startMicros = activeNotes.remove(key);
        if (startMicros == null) {
            return currentMicros;
        }
        return Math.max(currentMicros, startMicros + MIN_NOTE_GATE_MICROSECONDS);
    }

    private static List<TimedMidiMessage> sortedMessages(Sequence sequence) {
        List<TimedMidiMessage> messages = new ArrayList<TimedMidiMessage>();
        for (javax.sound.midi.Track track : sequence.getTracks()) {
            for (int i = 0; i < track.size(); i++) {
                MidiEvent event = track.get(i);
                messages.add(new TimedMidiMessage(event.getTick(), event.getMessage()));
            }
        }
        Collections.sort(messages);
        return messages;
    }

    private static Integer tempoFrom(MidiMessage message) {
        if (!(message instanceof MetaMessage)) {
            return null;
        }
        MetaMessage meta = (MetaMessage) message;
        if (meta.getType() != 0x51 || meta.getData().length != 3) {
            return null;
        }
        byte[] data = meta.getData();
        return ((data[0] & 0xFF) << 16) | ((data[1] & 0xFF) << 8) | (data[2] & 0xFF);
    }

    static final class RenderedAudio {
        private final byte[] pcm;
        private final int sampleRate;
        private final int channels;
        private final int bitsPerSample;

        RenderedAudio(byte[] pcm, int sampleRate, int channels, int bitsPerSample) {
            this.pcm = pcm;
            this.sampleRate = sampleRate;
            this.channels = channels;
            this.bitsPerSample = bitsPerSample;
        }

        byte[] pcm() {
            return pcm;
        }

        int sampleRate() {
            return sampleRate;
        }

        int channels() {
            return channels;
        }

        int bitsPerSample() {
            return bitsPerSample;
        }
    }

    private static final class TimedMidiMessage implements Comparable<TimedMidiMessage> {
        final long tick;
        final MidiMessage message;

        TimedMidiMessage(long tick, MidiMessage message) {
            this.tick = tick;
            this.message = message;
        }

        public int compareTo(TimedMidiMessage other) {
            if (tick == other.tick) {
                return priority(message) - priority(other.message);
            }
            return tick < other.tick ? -1 : 1;
        }

        private static int priority(MidiMessage message) {
            Integer tempo = tempoFrom(message);
            if (tempo != null) {
                return 0;
            }
            return message instanceof MetaMessage ? 2 : 1;
        }
    }

    private static final class ScheduledMidiMessage implements Comparable<ScheduledMidiMessage> {
        final long micros;
        final MidiMessage message;

        ScheduledMidiMessage(long micros, MidiMessage message) {
            this.micros = micros;
            this.message = message;
        }

        public int compareTo(ScheduledMidiMessage other) {
            if (micros == other.micros) {
                return 0;
            }
            return micros < other.micros ? -1 : 1;
        }
    }
}
