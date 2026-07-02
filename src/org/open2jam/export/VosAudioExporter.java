package org.open2jam.export;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import org.open2jam.parsers.Chart;
import org.open2jam.parsers.utils.SampleData;
import org.open2jam.sound.JavaSoundPcmDecoder;
import org.open2jam.sound.MidiSampleRenderer;
import org.open2jam.sound.OggPcmDecoder;

public final class VosAudioExporter {
    public String exportAudio(File input, File assetDir) throws Exception {
        return exportAudio(input, assetDir, 0);
    }

    public String exportAudio(File input, File assetDir, int chartIndex) throws Exception {
        Chart chart = PlayableChartSelector.select(input, chartIndex);
        File outputDir = ExportPaths.ensureDirectory(assetDir);
        Map<Integer, SampleData> samples = chart.getSamples();
        List<Integer> sampleIds = new ArrayList<Integer>(samples.keySet());
        Collections.sort(sampleIds);

        List<String> assets = new ArrayList<String>();
        MidiSampleRenderer renderer = new MidiSampleRenderer();
        for (Integer sampleId : sampleIds) {
            SampleData sample = samples.get(sampleId);
            int exportedSampleId = exportedSampleId(sampleId.intValue(), chart);
            String fileName = "sample-" + exportedSampleId + ".wav";
            File output = ExportPaths.child(outputDir, fileName);
            exportSample(renderer, sample, output);
            assets.add(asset(exportedSampleId, fileName, output));
        }

        return JsonWriter.object(
                JsonWriter.field("schemaVersion", 1),
                JsonWriter.field("format", formatFor(chart)),
                JsonWriter.field("sourcePath", input.getCanonicalPath()),
                JsonWriter.field("assetDir", outputDir.getCanonicalPath()),
                JsonWriter.rawField("assets", JsonWriter.array(assets.toArray(new String[0]))));
    }

    private static String formatFor(Chart chart) {
        if (chart.type == Chart.TYPE.OSU) {
            return "OSU";
        }
        if (chart.type == Chart.TYPE.OJN) {
            return "OJN";
        }
        return "VOS";
    }

    private static int exportedSampleId(int sampleId, Chart chart) {
        if (chart.type == Chart.TYPE.OJN) {
            return sampleId + 1;
        }
        return sampleId;
    }

    private static void exportSample(MidiSampleRenderer renderer, SampleData sample, File output) throws Exception {
        try {
            if (sample.getType() == SampleData.Type.MIDI) {
                ByteArrayOutputStream midi = new ByteArrayOutputStream();
                sample.copyTo(midi);
                MidiSampleRenderer.RenderedAudio audio = renderer.render(midi.toByteArray());
                writeWav(output, audio.pcm(), audio.channels(), audio.sampleRate(), audio.bitsPerSample());
                return;
            }

            ByteArrayOutputStream encoded = new ByteArrayOutputStream();
            sample.copyTo(encoded);
            JavaSoundPcmDecoder.DecodedPcm audio = sample.getType() == SampleData.Type.OGG
                    ? OggPcmDecoder.decode(encoded.toByteArray())
                    : JavaSoundPcmDecoder.decode(encoded.toByteArray());
            writeWav(output, audio.pcm, audio.channels, audio.sampleRate, audio.bitsPerSample);
        } finally {
            sample.dispose();
        }
    }

    private static void writeWav(File output, byte[] pcm, int channels, int sampleRate, int bitsPerSample)
            throws IOException {
        FileOutputStream out = new FileOutputStream(output);
        try {
            int blockAlign = channels * bitsPerSample / 8;
            int byteRate = sampleRate * blockAlign;

            writeAscii(out, "RIFF");
            writeLittleEndianInt(out, 36 + pcm.length);
            writeAscii(out, "WAVE");
            writeAscii(out, "fmt ");
            writeLittleEndianInt(out, 16);
            writeLittleEndianShort(out, 1);
            writeLittleEndianShort(out, channels);
            writeLittleEndianInt(out, sampleRate);
            writeLittleEndianInt(out, byteRate);
            writeLittleEndianShort(out, blockAlign);
            writeLittleEndianShort(out, bitsPerSample);
            writeAscii(out, "data");
            writeLittleEndianInt(out, pcm.length);
            out.write(pcm);
        } finally {
            out.close();
        }
    }

    private static String asset(int sampleId, String fileName, File output) throws IOException {
        return JsonWriter.object(
                JsonWriter.field("sampleId", sampleId),
                JsonWriter.field("fileName", fileName),
                JsonWriter.field("path", output.getCanonicalPath()),
                JsonWriter.field("type", "wav"),
                JsonWriter.field("role", "sample"),
                JsonWriter.field("preload", true));
    }

    private static void writeAscii(OutputStream out, String value) throws IOException {
        out.write(value.getBytes(StandardCharsets.US_ASCII));
    }

    private static void writeLittleEndianInt(OutputStream out, int value) throws IOException {
        out.write(value & 0xFF);
        out.write((value >>> 8) & 0xFF);
        out.write((value >>> 16) & 0xFF);
        out.write((value >>> 24) & 0xFF);
    }

    private static void writeLittleEndianShort(OutputStream out, int value) throws IOException {
        out.write(value & 0xFF);
        out.write((value >>> 8) & 0xFF);
    }
}
