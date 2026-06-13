package org.open2jam.sound;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.Test;

class MidiSampleRendererTest {
    @Test
    void rendersMidiToPcmWithoutUsingRuntimeSequencer() throws Exception {
        MidiSampleRenderer renderer = new MidiSampleRenderer();

        MidiSampleRenderer.RenderedAudio audio = renderer.render(minimalMidiNote());

        assertNotNull(audio);
        assertEquals(2, audio.channels());
        assertEquals(16, audio.bitsPerSample());
        assertTrue(audio.sampleRate() >= 22050);
        assertTrue(audio.pcm().length > 4096);
        assertTrue(containsNonSilentSample(audio.pcm()));
    }

    @Test
    void preservesMidiEventTimingWhenRenderingToPcm() throws Exception {
        MidiSampleRenderer renderer = new MidiSampleRenderer();

        MidiSampleRenderer.RenderedAudio audio = renderer.render(twoSeparatedNotes());

        int firstPeak = firstPeakFrame(audio.pcm(), audio.channels(), 0);
        int secondPeak = firstPeakFrame(audio.pcm(), audio.channels(), audio.sampleRate() / 2);

        assertTrue(firstPeak >= 0);
        assertTrue(secondPeak >= 0);
        assertTrue(secondPeak - firstPeak > audio.sampleRate() / 3);
    }

    private static boolean containsNonSilentSample(byte[] pcm) {
        for (byte value : pcm) {
            if (value != 0) {
                return true;
            }
        }
        return false;
    }

    private static byte[] minimalMidiNote() throws Exception {
        return midiWithNotes(new int[] {0});
    }

    private static byte[] twoSeparatedNotes() throws Exception {
        return midiWithNotes(new int[] {0, 480});
    }

    private static byte[] midiWithNotes(int[] startTicks) throws Exception {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        out.write("MThd".getBytes(StandardCharsets.US_ASCII));
        writeIntBE(out, 6);
        writeShortBE(out, 1);
        writeShortBE(out, 1);
        writeShortBE(out, 480);

        ByteArrayOutputStream track = new ByteArrayOutputStream();
        track.write(0x00);
        track.write(new byte[] {(byte) 0xFF, 0x51, 0x03, 0x07, (byte) 0xA1, 0x20});
        track.write(0x00);
        track.write(0xC0);
        track.write(40);
        int previousTick = 0;
        for (int startTick : startTicks) {
            writeVariableLengthQuantity(track, startTick - previousTick);
            track.write(0x90);
            track.write(64);
            track.write(100);
            writeVariableLengthQuantity(track, 96);
            track.write(0x80);
            track.write(64);
            track.write(0);
            previousTick = startTick + 96;
        }
        track.write(0x00);
        track.write(new byte[] {(byte) 0xFF, 0x2F, 0x00});

        out.write("MTrk".getBytes(StandardCharsets.US_ASCII));
        writeIntBE(out, track.size());
        out.write(track.toByteArray());
        return out.toByteArray();
    }

    private static int firstPeakFrame(byte[] pcm, int channels, int startFrame) {
        int frameSize = channels * 2;
        int start = Math.max(0, startFrame * frameSize);
        for (int i = start; i + 1 < pcm.length; i += 2) {
            int sample = (pcm[i] & 0xFF) | (pcm[i + 1] << 8);
            if (Math.abs(sample) > 1000) {
                return i / frameSize;
            }
        }
        return -1;
    }

    private static void writeIntBE(ByteArrayOutputStream out, int value) {
        out.write((value >>> 24) & 0xFF);
        out.write((value >>> 16) & 0xFF);
        out.write((value >>> 8) & 0xFF);
        out.write(value & 0xFF);
    }

    private static void writeShortBE(ByteArrayOutputStream out, int value) {
        out.write((value >>> 8) & 0xFF);
        out.write(value & 0xFF);
    }

    private static void writeVariableLengthQuantity(ByteArrayOutputStream out, int value) {
        int buffer = value & 0x7F;
        while ((value >>= 7) > 0) {
            buffer <<= 8;
            buffer |= ((value & 0x7F) | 0x80);
        }
        while (true) {
            out.write(buffer & 0xFF);
            if ((buffer & 0x80) != 0) {
                buffer >>= 8;
            } else {
                break;
            }
        }
    }
}
