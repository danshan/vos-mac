import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import org.open2jam.game.TimingData;
import org.open2jam.parsers.Event;
import org.open2jam.parsers.ChartParser;
import org.open2jam.render.RenderTimingCompiler;

// Migration-only oracle before long-note repair; tests consume the frozen JSON.
class OsuTimingOracle {
    public static void main(String[] args) throws Exception {
        var chart = ChartParser.parseFile(new File(args[0])).get(0);
        var judgment = new TimingData();
        var visual = new TimingData();
        var events = RenderTimingCompiler.compile(chart.getEvents(), chart.type, chart.getBPM(),
                1500.0, judgment, visual);
        var samples = new StringBuilder();
        var measures = new StringBuilder();
        for (var event : events) {
            if (event.getChannel() == Event.Channel.MEASURE) {
                append(measures, Long.toString(Math.round(event.getTime() * 1000)));
                continue;
            }
            int lane = -1;
            for (int i = 0; i < 7; i++) {
                if (event.getChannel() == Event.Channel.playableChannels()[i]) lane = i;
            }
            if (lane < 0 && event.getChannel() != Event.Channel.AUTO_PLAY) continue;
            var sample = event.getSample();
            append(samples, "[" + Math.round(event.getTime() * 1000) + "," + event.getMeasure()
                    + "," + lane + ",\"" + event.getFlag().name() + "\"," + sample.sample_id
                    + "," + Double.toString((double) sample.volume) + "]");
        }
        Files.writeString(Path.of(args[1]), "{\"samples\":[" + samples + "],\"measures\":["
                + measures + "],\"judgmentTiming\":[" + timing(judgment) + "],\"visualTiming\":["
                + timing(visual) + "]}\n");
    }

    private static String timing(TimingData data) {
        var json = new StringBuilder();
        TimingData.VelocityChange previous = null;
        for (var change : data.getChanges()) {
            if (previous != null && previous.getTime() == change.getTime()
                    && previous.getBpm() == change.getBpm()) continue;
            append(json, "[" + Math.round(change.getTime() * 1000) + "," + change.getBpm() + "]");
            previous = change;
        }
        return json.toString();
    }

    private static void append(StringBuilder json, String value) {
        if (json.length() > 0) json.append(',');
        json.append(value);
    }
}
