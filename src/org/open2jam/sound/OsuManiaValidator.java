package org.open2jam.sound;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.util.ArrayList;
import org.open2jam.parsers.Chart;
import org.open2jam.parsers.ChartList;
import org.open2jam.parsers.ChartParser;
import org.open2jam.parsers.Event;
import org.open2jam.parsers.utils.SampleData;

public final class OsuManiaValidator {
    private OsuManiaValidator() {
    }

    public static Result validate(File input) throws SoundSystemException {
        if (input == null || !input.exists()) {
            throw new SoundSystemException("Input does not exist");
        }

        Result result = new Result();
        for (File file : chartFiles(input)) {
            ChartList chartList = ChartParser.parseFile(file);
            if (chartList == null || chartList.isEmpty()) {
                continue;
            }
            result.chartLists++;
            for (Chart chart : chartList) {
                if (chart.type != Chart.TYPE.OSU || chart.getKeys() != 7) {
                    continue;
                }
                result.charts++;
                result.playableNotes += playableNotes(chart);
                for (SampleData sample : chart.getSamples().values()) {
                    result.audioSamples++;
                    try {
                        ByteArrayOutputStream output = new ByteArrayOutputStream();
                        sample.copyTo(output);
                        if (sample.getType() == SampleData.Type.MP3) {
                            JavaSoundPcmDecoder.decode(output.toByteArray());
                            result.decodedMp3Samples++;
                        }
                    } catch (Exception ex) {
                        throw new SoundSystemException(ex);
                    } finally {
                        try {
                            sample.dispose();
                        } catch (java.io.IOException ex) {
                            throw new SoundSystemException(ex);
                        }
                    }
                }
            }
        }
        if (result.charts == 0) {
            throw new SoundSystemException("No osu!mania 7K charts found");
        }
        return result;
    }

    private static ArrayList<File> chartFiles(File input) {
        ArrayList<File> files = new ArrayList<File>();
        collectChartFiles(input, files);
        return files;
    }

    private static void collectChartFiles(File file, ArrayList<File> files) {
        if (file.isFile()) {
            String name = file.getName().toLowerCase();
            if (name.endsWith(".osu") || name.endsWith(".osz")) {
                files.add(file);
            }
            return;
        }
        File[] children = file.listFiles();
        if (children == null) {
            return;
        }
        for (File child : children) {
            collectChartFiles(child, files);
        }
    }

    private static int playableNotes(Chart chart) {
        int notes = 0;
        for (Event.Channel channel : Event.Channel.playableChannels()) {
            for (Event event : chart.getEvents().getEventsFromThisChannel(channel)) {
                if (event.getFlag() != Event.Flag.RELEASE) {
                    notes++;
                }
            }
        }
        return notes;
    }

    public static final class Result {
        public int chartLists;
        public int charts;
        public int playableNotes;
        public int audioSamples;
        public int decodedMp3Samples;
    }
}
