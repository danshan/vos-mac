package org.open2jam;

import java.beans.XMLDecoder;
import java.beans.XMLEncoder;
import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.InvalidClassException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.Serializable;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.logging.Level;
import java.util.logging.Logger;
import org.lwjgl.glfw.GLFW;
import org.open2jam.parsers.ChartList;
import org.open2jam.parsers.Event;
import org.open2jam.parsers.Event.Channel;
import org.voile.VoileMap;

/**
 *
 * @author fox
 */
public abstract class Config
{
    private static final String CONFIG_DIR_PROPERTY = "open2jam.config.dir";
    private static final String CONFIG_FILE_NAME = "config.vl";
    private static final String OPTIONS_FILE_NAME = "game-options.xml";
    private static final int CHART_CACHE_SCHEMA_VERSION = 2;
    
    private static VoileMap<String, Serializable> VMap;
    private static GameOptions options;
            
    public static final String OPTIONS_FILE = OPTIONS_FILE_NAME;

    private static GameOptions loadGameOptions() {
        try {
            XMLDecoder decoder = new XMLDecoder(new BufferedInputStream(new FileInputStream(optionsFile())));
            Object result = decoder.readObject();
            decoder.close();
            if (result instanceof GameOptions) return (GameOptions)result;
        } catch(FileNotFoundException fnf) {
            return null; // thats ok a new file will be created
        }
        return null;
    }
    
    public static void saveGameOptions() {
        try {
            ensureConfigDirectoryExists();
            XMLEncoder encoder = new XMLEncoder(new BufferedOutputStream(new FileOutputStream(optionsFile())));
            encoder.writeObject(options);
            encoder.close();
        } catch (IOException ex) {
            Logger.getLogger(GameOptions.class.getName()).log(Level.SEVERE, "{0}", ex);
        }
    }

    public enum KeyboardType {K4, K5, K6, K7, K8, /*K9*/}
    
    public enum MiscEvent {  
        NONE,                       //None
        SPEED_UP, SPEED_DOWN,       //speed changes
        MAIN_VOL_UP, MAIN_VOL_DOWN, //main volume changes
        KEY_VOL_UP, KEY_VOL_DOWN,   //key volume changes
        BGM_VOL_UP, BGM_VOL_DOWN,   //bgm volume changes
        //CHAT_TOGGLE,                //chat toggle... if we are going to add one
    }
    
    public static void openDB() {
        ensureConfigDirectoryExists();
        File configFile = configFile();
        
        options = loadGameOptions();
        
        if (options == null) {
            options = new GameOptions();
        }
        
        if(!configFile.exists()) { // create now
            
            VMap = new VoileMap<String, Serializable>(configFile);
            
            setCwd(null);
            
            setDirsList(new ArrayList<File>());

            EnumMap<MiscEvent, Integer> keyboard_misc = new EnumMap<MiscEvent, Integer>(MiscEvent.class);
            keyboard_misc.put(MiscEvent.SPEED_DOWN,   GLFW.GLFW_KEY_DOWN);
            keyboard_misc.put(MiscEvent.SPEED_UP,     GLFW.GLFW_KEY_UP);
            keyboard_misc.put(MiscEvent.MAIN_VOL_UP,  GLFW.GLFW_KEY_2);
            keyboard_misc.put(MiscEvent.MAIN_VOL_DOWN,GLFW.GLFW_KEY_1);
            keyboard_misc.put(MiscEvent.KEY_VOL_UP,   GLFW.GLFW_KEY_4);
            keyboard_misc.put(MiscEvent.KEY_VOL_DOWN, GLFW.GLFW_KEY_3);
            keyboard_misc.put(MiscEvent.BGM_VOL_UP,   GLFW.GLFW_KEY_6);
            keyboard_misc.put(MiscEvent.BGM_VOL_DOWN, GLFW.GLFW_KEY_5);
            put("keyboard_misc", keyboard_misc);
            
            // TODO Needs the 2nd player keys, if we are going to add 2p support ofc xD
            EnumMap<Event.Channel, Integer> keyboard_map_4K = new EnumMap<Event.Channel, Integer>(Event.Channel.class);
            keyboard_map_4K.put(Event.Channel.NOTE_1, GLFW.GLFW_KEY_D);
            keyboard_map_4K.put(Event.Channel.NOTE_2, GLFW.GLFW_KEY_F);
            keyboard_map_4K.put(Event.Channel.NOTE_3, GLFW.GLFW_KEY_J);
            keyboard_map_4K.put(Event.Channel.NOTE_4, GLFW.GLFW_KEY_K);
            keyboard_map_4K.put(Event.Channel.NOTE_SC, GLFW.GLFW_KEY_LEFT_SHIFT);
            put("keyboard_map"+KeyboardType.K4.toString(), keyboard_map_4K);

            EnumMap<Event.Channel, Integer> keyboard_map_5K = new EnumMap<Event.Channel, Integer>(Event.Channel.class);
            keyboard_map_5K.put(Event.Channel.NOTE_1, GLFW.GLFW_KEY_D);
            keyboard_map_5K.put(Event.Channel.NOTE_2, GLFW.GLFW_KEY_F);
            keyboard_map_5K.put(Event.Channel.NOTE_3, GLFW.GLFW_KEY_SPACE);
            keyboard_map_5K.put(Event.Channel.NOTE_4, GLFW.GLFW_KEY_J);
            keyboard_map_5K.put(Event.Channel.NOTE_5, GLFW.GLFW_KEY_K);
            keyboard_map_5K.put(Event.Channel.NOTE_SC, GLFW.GLFW_KEY_LEFT_SHIFT);
            put("keyboard_map"+KeyboardType.K5.toString(), keyboard_map_5K);

            EnumMap<Event.Channel, Integer> keyboard_map_6K = new EnumMap<Event.Channel, Integer>(Event.Channel.class);
            keyboard_map_6K.put(Event.Channel.NOTE_1, GLFW.GLFW_KEY_S);
            keyboard_map_6K.put(Event.Channel.NOTE_2, GLFW.GLFW_KEY_D);
            keyboard_map_6K.put(Event.Channel.NOTE_3, GLFW.GLFW_KEY_F);
            keyboard_map_6K.put(Event.Channel.NOTE_4, GLFW.GLFW_KEY_J);
            keyboard_map_6K.put(Event.Channel.NOTE_5, GLFW.GLFW_KEY_K);
            keyboard_map_6K.put(Event.Channel.NOTE_6, GLFW.GLFW_KEY_L);
            keyboard_map_6K.put(Event.Channel.NOTE_SC, GLFW.GLFW_KEY_LEFT_SHIFT);
            put("keyboard_map"+KeyboardType.K6.toString(), keyboard_map_6K);

            EnumMap<Event.Channel, Integer> keyboard_map_7K = new EnumMap<Event.Channel, Integer>(Event.Channel.class);
            keyboard_map_7K.put(Event.Channel.NOTE_1, GLFW.GLFW_KEY_S);
            keyboard_map_7K.put(Event.Channel.NOTE_2, GLFW.GLFW_KEY_D);
            keyboard_map_7K.put(Event.Channel.NOTE_3, GLFW.GLFW_KEY_F);
            keyboard_map_7K.put(Event.Channel.NOTE_4, GLFW.GLFW_KEY_SPACE);
            keyboard_map_7K.put(Event.Channel.NOTE_5, GLFW.GLFW_KEY_J);
            keyboard_map_7K.put(Event.Channel.NOTE_6, GLFW.GLFW_KEY_K);
            keyboard_map_7K.put(Event.Channel.NOTE_7, GLFW.GLFW_KEY_L);
            keyboard_map_7K.put(Event.Channel.NOTE_SC, GLFW.GLFW_KEY_LEFT_SHIFT);
            put("keyboard_map"+KeyboardType.K7.toString(), keyboard_map_7K);

            EnumMap<Event.Channel, Integer> keyboard_map_8K = new EnumMap<Event.Channel, Integer>(Event.Channel.class);
            keyboard_map_8K.put(Event.Channel.NOTE_1, GLFW.GLFW_KEY_A);
            keyboard_map_8K.put(Event.Channel.NOTE_2, GLFW.GLFW_KEY_S);
            keyboard_map_8K.put(Event.Channel.NOTE_3, GLFW.GLFW_KEY_D);
            keyboard_map_8K.put(Event.Channel.NOTE_4, GLFW.GLFW_KEY_F);
            keyboard_map_8K.put(Event.Channel.NOTE_5, GLFW.GLFW_KEY_H);
            keyboard_map_8K.put(Event.Channel.NOTE_6, GLFW.GLFW_KEY_J);
            keyboard_map_8K.put(Event.Channel.NOTE_7, GLFW.GLFW_KEY_K);
            keyboard_map_8K.put(Event.Channel.NOTE_SC, GLFW.GLFW_KEY_L);
            put("keyboard_map"+KeyboardType.K8.toString(), keyboard_map_8K);

        } else {           
            VMap = new VoileMap<String, Serializable>(configFile);
        }
        
    }

    @SuppressWarnings("unchecked")
    public static EnumMap<Event.Channel,Integer> getKeyboardMap(KeyboardType kt){
        return (EnumMap<Channel, Integer>) get("keyboard_map"+kt.toString());
    }
    
    @SuppressWarnings("unchecked")
    public static EnumMap<MiscEvent,Integer> getKeyboardMisc(){
        return (EnumMap<MiscEvent, Integer>) get("keyboard_misc");
    }
    
    public static void setKeyboardMisc(EnumMap<MiscEvent,Integer> km_map)
    {
        put("keyboard_misc", km_map);
    }

    public static void setKeyboardMap(EnumMap<Event.Channel,Integer> kb_map, KeyboardType kt){
        put("keyboard_map"+kt.toString(), kb_map);
    }

    public static File getCwd() {
        return (File) get("cwd");
    }
    public static void setCwd(File new_file) {
        put("cwd",new_file);
    }

    public static void setDirsList(ArrayList<File> dl) {
        put("dir_list",dl);
    }
    
    @SuppressWarnings("unchecked")
    public static ArrayList<File> getDirsList() {
        return (ArrayList<File>) get("dir_list");
    }
    
    public static void setGameOptions(GameOptions go) {
        options = go;
        saveGameOptions();
    }
    
    public static GameOptions getGameOptions() {
        return options;
    }
    
    @SuppressWarnings("unchecked")
    public static ArrayList<ChartList> getCache(File dir) {
        String key = cacheKey(dir);
        try {
            return (ArrayList<ChartList>) get(key);
        } catch (RuntimeException ex) {
            if(!isStaleCacheFailure(ex)) throw ex;
            deleteStaleCache(key, ex);
            return null;
        }
    }

    public static void setCache(File dir, ArrayList<ChartList> data) {
        String key = cacheKey(dir);
        put(key,data);
    }

    public static void delCache(File dir){
        delete(cacheKey(dir));
    }
    
    private static Serializable get(String key) {
        return VMap.get(key);
    }
    
    private static void put(String key, Serializable value) {
        VMap.put(key, value);
    }

    private static void delete(String key) {
        VMap.remove(key);
    }

    static String cacheKey(File dir) {
        return "cache:v" + CHART_CACHE_SCHEMA_VERSION + ":" + dir.getAbsolutePath();
    }

    static boolean isStaleCacheFailure(RuntimeException ex) {
        Throwable cause = ex;
        while(cause != null) {
            if(cause instanceof InvalidClassException) return true;
            cause = cause.getCause();
        }
        return false;
    }

    private static void deleteStaleCache(String key, RuntimeException original) {
        try {
            delete(key);
        } catch (RuntimeException ex) {
            if(!isStaleCacheFailure(ex)) throw ex;
        }
        Logger.getLogger(Config.class.getName()).log(Level.INFO,
                "Ignored stale chart cache entry {0}: {1}", new Object[] {key, original.getMessage()});
    }

    static File configFile() {
        return new File(configDirectory(), CONFIG_FILE_NAME);
    }

    static File optionsFile() {
        return new File(configDirectory(), OPTIONS_FILE_NAME);
    }

    static File configDirectory() {
        String override = System.getProperty(CONFIG_DIR_PROPERTY);
        if(override != null && !override.isBlank()) return new File(override);

        String home = System.getProperty("user.home");
        if(home == null || home.isBlank()) return new File(".").getAbsoluteFile();

        if("macosx".equals(getOS())) {
            return new File(new File(new File(home, "Library"), "Application Support"), "VosMac");
        }
        if("windows".equals(getOS())) {
            String appData = System.getenv("APPDATA");
            if(appData != null && !appData.isBlank()) return new File(appData, "VosMac");
        }
        return new File(home, ".vosmac");
    }

    private static void ensureConfigDirectoryExists() {
        try {
            Files.createDirectories(configDirectory().toPath());
        } catch (IOException ex) {
            throw new RuntimeException("Unable to create config directory: " + configDirectory(), ex);
        }
    }

    private static String getOS()
    {
        String os = System.getProperty("os.name").toLowerCase();
        if(os.contains("win")){
            return "windows";
        }else if(os.contains("mac")){
            return "macosx";
        }else if(os.contains("nix") || os.contains("nux")){
            return "linux";
        }else if(os.contains("solaris")){
            return "solaris";
        }else{
            return os;
        }
    }
}
