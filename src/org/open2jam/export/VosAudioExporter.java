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
import org.open2jam.parsers.ChartList;
import org.open2jam.parsers.ChartParser;
import org.open2jam.parsers.VOSChart;
import org.open2jam.parsers.utils.SampleData;
import org.open2jam.sound.MidiSampleRenderer;

public final class VosAudioExporter {
    public String exportAudio(File input, File assetDir) throws Exception {
        VOSChart chart = firstVosChart(input);
        File outputDir = ExportPaths.ensureDirectory(assetDir);
        Map<Integer, SampleData> samples = chart.getSamples();
        List<Integer> sampleIds = new ArrayList<Integer>(samples.keySet());
        Collections.sort(sampleIds);

        List<String> assets = new ArrayList<String>();
        MidiSampleRenderer renderer = new MidiSampleRenderer();
        for (Integer sampleId : sampleIds) {
            SampleData sample = samples.get(sampleId);
            String fileName = "sample-" + sampleId + ".wav";
            File output = ExportPaths.child(outputDir, fileName);
            exportSample(renderer, sample, output);
            assets.add(asset(sampleId, fileName, output));
        }

        return JsonWriter.object(
                JsonWriter.field("schemaVersion", 1),
                JsonWriter.field("format", "VOS"),
                JsonWriter.field("sourcePath", input.getCanonicalPath()),
                JsonWriter.field("assetDir", outputDir.getCanonicalPath()),
                JsonWriter.rawField("assets", JsonWriter.array(assets.toArray(new String[0]))));
    }

    private static VOSChart firstVosChart(File input) {
        ChartList charts = ChartParser.parseFile(input);
        if (charts != null) {
            for (Chart chart : charts) {
                if (chart instanceof VOSChart) {
                    return (VOSChart) chart;
                }
            }
        }
        throw new IllegalArgumentException("No VOS chart found: " + input);
    }

    private static void exportSample(MidiSampleRenderer renderer, SampleData sample, File output) throws Exception {
        try {
            if (sample.getType() != SampleData.Type.MIDI) {
                throw new IllegalArgumentException("Expected VOS MIDI sample: " + sample.getName());
            }
            ByteArrayOutputStream midi = new ByteArrayOutputStream();
            sample.copyTo(midi);
            MidiSampleRenderer.RenderedAudio audio = renderer.render(midi.toByteArray());
            writeWav(output, audio);
        } finally {
            sample.dispose();
        }
    }

    private static void writeWav(File output, MidiSampleRenderer.RenderedAudio audio) throws IOException {
        FileOutputStream out = new FileOutputStream(output);
        try {
            byte[] pcm = audio.pcm();
            int blockAlign = audio.channels() * audio.bitsPerSample() / 8;
            int byteRate = audio.sampleRate() * blockAlign;

            writeAscii(out, "RIFF");
            writeLittleEndianInt(out, 36 + pcm.length);
            writeAscii(out, "WAVE");
            writeAscii(out, "fmt ");
            writeLittleEndianInt(out, 16);
            writeLittleEndianShort(out, 1);
            writeLittleEndianShort(out, audio.channels());
            writeLittleEndianInt(out, audio.sampleRate());
            writeLittleEndianInt(out, byteRate);
            writeLittleEndianShort(out, blockAlign);
            writeLittleEndianShort(out, audio.bitsPerSample());
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
