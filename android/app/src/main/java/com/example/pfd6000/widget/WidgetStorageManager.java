package com.example.pfd6000.widget;

import android.content.Context;
import android.content.SharedPreferences;
import org.json.JSONException;
import org.json.JSONObject;

/**
 * Manages per-widget door configuration storage
 * Uses SharedPreferences with versioned JSON format
 */
public class WidgetStorageManager {
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
        try {
            JSONObject json = new JSONObject();
            json.put("doorName", doorName);
            json.put("doorIdentifier", doorIdentifier);
            json.put("version", CURRENT_VERSION);
            prefs.edit().putString(KEY_WIDGET_PREFIX + widgetId, json.toString()).apply();
        } catch (JSONException e) {
            e.printStackTrace();
        }
    }
    
    /**
     * Get door info for a widget
     */
    public DoorInfo getDoorInfo(int widgetId) {
        String json = prefs.getString(KEY_WIDGET_PREFIX + widgetId, null);
        if (json == null) return null;
        
        try {
            JSONObject obj = new JSONObject(json);
            return new DoorInfo(
                obj.getString("doorName"),
                obj.getString("doorIdentifier")
            );
        } catch (JSONException e) {
            e.printStackTrace();
            return null;
        }
    }
    
    /**
     * Remove door info when widget is deleted
     */
    public void removeDoorInfo(int widgetId) {
        prefs.edit().remove(KEY_WIDGET_PREFIX + widgetId).apply();
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
