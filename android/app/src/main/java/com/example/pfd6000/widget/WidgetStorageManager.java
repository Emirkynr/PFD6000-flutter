package com.example.pfd6000.widget;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Log;
import org.json.JSONException;
import org.json.JSONObject;

/**
 * Manages per-widget door configuration storage
 * Uses SharedPreferences with versioned JSON format
 */
public class WidgetStorageManager {
    private static final String TAG = "WIDGET_STORAGE";
    private static final String PREFS_NAME = "enka_gs_widgets";
    private static final String KEY_VERSION = "storage_version";
    private static final String KEY_WIDGET_PREFIX = "widget_";
    private static final int CURRENT_VERSION = 1;
    
    private final SharedPreferences prefs;
    
    public WidgetStorageManager(Context context) {
        prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        migrateIfNeeded();
    }
    
    private void migrateIfNeeded() {
        int version = prefs.getInt(KEY_VERSION, 0);
        if (version < CURRENT_VERSION) {
            // Future migrations go here
            prefs.edit().putInt(KEY_VERSION, CURRENT_VERSION).apply();
        }
    }
    
    /**
     * Save door info for a widget
     */
    public void saveDoorInfo(int widgetId, String doorName, String doorIdentifier) {
        String key = KEY_WIDGET_PREFIX + widgetId;
        Log.d(TAG, "saveDoorInfo: widgetId=" + widgetId + " key=" + key + " door=" + doorName);
        
        try {
            JSONObject json = new JSONObject();
            json.put("doorName", doorName);
            json.put("doorIdentifier", doorIdentifier);
            json.put("version", CURRENT_VERSION);
            
            prefs.edit().putString(key, json.toString()).commit(); // Use commit() for synchronous save
            
            Log.d(TAG, "saveDoorInfo: saved successfully to key=" + key);
        } catch (JSONException e) {
            Log.e(TAG, "saveDoorInfo: JSON error - " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    /**
     * Get door info for a widget
     */
    public DoorInfo getDoorInfo(int widgetId) {
        String key = KEY_WIDGET_PREFIX + widgetId;
        String json = prefs.getString(key, null);
        
        Log.d(TAG, "getDoorInfo: widgetId=" + widgetId + " key=" + key + " found=" + (json != null));
        
        if (json == null) {
            Log.d(TAG, "getDoorInfo: no data for widgetId=" + widgetId);
            return null;
        }
        
        try {
            JSONObject obj = new JSONObject(json);
            DoorInfo info = new DoorInfo(
                obj.getString("doorName"),
                obj.getString("doorIdentifier")
            );
            Log.d(TAG, "getDoorInfo: returning door=" + info.doorName);
            return info;
        } catch (JSONException e) {
            Log.e(TAG, "getDoorInfo: JSON parse error - " + e.getMessage());
            e.printStackTrace();
            return null;
        }
    }
    
    /**
     * Remove door info when widget is deleted
     */
    public void removeDoorInfo(int widgetId) {
        String key = KEY_WIDGET_PREFIX + widgetId;
        Log.d(TAG, "removeDoorInfo: widgetId=" + widgetId + " key=" + key);
        prefs.edit().remove(key).apply();
    }
    
    /**
     * Door info data class
     */
    public static class DoorInfo {
        public final String doorName;
        public final String doorIdentifier;
        
        public DoorInfo(String doorName, String doorIdentifier) {
            this.doorName = doorName;
            this.doorIdentifier = doorIdentifier;
        }
    }
}
