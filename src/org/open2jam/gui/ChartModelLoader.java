package org.open2jam.gui;

import java.io.File;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.logging.Level;
import javax.swing.SwingWorker;
import org.open2jam.Config;
import org.open2jam.parsers.ChartList;
import org.open2jam.parsers.ChartParser;
import org.open2jam.util.Logger;

/**
 *
 * @author fox
 */
public class ChartModelLoader extends SwingWorker<ChartListTableModel,ChartList>
{

    private final ChartListTableModel table_model;
    private final File dir;

    public ChartModelLoader(ChartListTableModel table_model, File dir){
        this.table_model = table_model;
        this.dir = dir;
    }

    @Override
    protected ChartListTableModel doInBackground() {
        table_model.clear();
        ArrayList<ChartList> chartLists = loadChartLists(dir);
        for (ChartList chartList : chartLists) {
            publish(chartList);
        }
        setProgress(100);
        return table_model;
    }

    static ArrayList<ChartList> loadChartLists(File dir) {
        ArrayList<ChartList> chartLists = new ArrayList<ChartList>();
        ArrayList<File> files = new ArrayList<File>(Arrays.asList(listFilesSafely(dir)));
        double perc = files.size() / 100d;
        for(int i=0;i<files.size();i++)
        {
            ChartList cl = ChartParser.parseFile(files.get(i));
            if(cl != null) chartLists.add(cl);
            else if(files.get(i).isDirectory()){
                List<File> nl = Arrays.asList(listFilesSafely(files.get(i)));
                files.addAll(nl);
                perc = files.size() / 100d;
            }
        }
        return chartLists;
    }

    @Override
    protected void done() {
        Config.setCache(dir, table_model.getRawList());
    }

    @Override
     protected void process(List<ChartList> chunks) {
        table_model.addRows(chunks);
     }

    static File[] listFilesSafely(File directory) {
        if(directory == null) return new File[0];
        File[] files = directory.listFiles();
        if(files == null) {
            Logger.global.log(Level.WARNING, "Skipping unreadable chart directory: {0}", directory);
            return new File[0];
        }
        return files;
    }
}
