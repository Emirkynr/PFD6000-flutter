package com.example.pfd6000;

import android.appwidget.AppWidgetManager;
import android.content.Intent;
import android.os.Bundle;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.FlutterEngineCache;
import io.flutter.plugin.common.MethodChannel;

import com.example.pfd6000.widget.WidgetStorageManager;
import com.example.pfd6000.widget.DoorWidget1x4;
import com.example.pfd6000.widget.DoorWidget1x1;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL_NAME = "enka_gs_widget";
    private MethodChannel methodChannel;
    
    // Pending widget configuration
    private int pendingWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID;
    private String pendingWidgetType = null;
    private String pendingAction = null;
    private String pendingDoorIdentifier = null;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        
        // Cache the engine for widget access
        FlutterEngineCache.getInstance().put("main_engine", flutterEngine);
        
        // Set up MethodChannel
        methodChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_NAME);
        
        methodChannel.setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "updateWidget":
                    handleUpdateWidget(call.arguments, result);
                    break;
                case "showNotFound":
                    handleShowNotFound(call.arguments, result);
                    break;
                case "saveDoorConfig":
                    handleSaveDoorConfig(call.arguments, result);
                    break;
                default:
                    result.notImplemented();
            }
        });
    }

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        handleIntent(getIntent());
    }

    @Override
    protected void onNewIntent(@NonNull Intent intent) {
        super.onNewIntent(intent);
        handleIntent(intent);
    }

    private void handleIntent(Intent intent) {
        if (intent == null) return;
        
        // Check for widget configuration route
        String route = intent.getStringExtra("route");
        if ("/widget-config".equals(route)) {
            pendingWidgetId = intent.getIntExtra("widgetId", AppWidgetManager.INVALID_APPWIDGET_ID);
            pendingWidgetType = intent.getStringExtra("widgetType");
            // Flutter will query this via getWidgetConfigParams
        }
        
        // Check for openDoor action (when app is launched from widget)
        String action = intent.getStringExtra("action");
        if ("openDoor".equals(action)) {
            pendingAction = action;
            pendingWidgetId = intent.getIntExtra("widgetId", AppWidgetManager.INVALID_APPWIDGET_ID);
            pendingDoorIdentifier = intent.getStringExtra("doorIdentifier");
        }
    }

    private void handleUpdateWidget(Object arguments, MethodChannel.Result result) {
        try {
            java.util.Map<String, Object> args = (java.util.Map<String, Object>) arguments;
            int widgetId = (int) args.get("widgetId");
            String doorName = (String) args.get("doorName");
            
            // Update the widget UI
            AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(this);
            
            // Determine widget type and update accordingly
            // For simplicity, update both types (one will be correct)
            DoorWidget1x4.updateAppWidget(this, appWidgetManager, widgetId);
            DoorWidget1x1.updateAppWidget(this, appWidgetManager, widgetId);
            
            result.success(true);
        } catch (Exception e) {
            result.error("UPDATE_ERROR", e.getMessage(), null);
        }
    }

    private void handleShowNotFound(Object arguments, MethodChannel.Result result) {
        // This would show a native toast/dialog
        // For now, just acknowledge
        result.success(true);
    }

    private void handleSaveDoorConfig(Object arguments, MethodChannel.Result result) {
        try {
            java.util.Map<String, Object> args = (java.util.Map<String, Object>) arguments;
            int widgetId = (int) args.get("widgetId");
            String doorName = (String) args.get("doorName");
            String doorIdentifier = (String) args.get("doorIdentifier");
            
            // Save to storage
            WidgetStorageManager storage = new WidgetStorageManager(this);
            storage.saveDoorInfo(widgetId, doorName, doorIdentifier);
            
            // Update widget UI
            AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(this);
            DoorWidget1x4.updateAppWidget(this, appWidgetManager, widgetId);
            DoorWidget1x1.updateAppWidget(this, appWidgetManager, widgetId);
            
            result.success(true);
        } catch (Exception e) {
            result.error("SAVE_ERROR", e.getMessage(), null);
        }
    }
    
    // Called by Flutter to get pending widget config params
    public int getPendingWidgetId() {
        return pendingWidgetId;
    }
    
    public String getPendingWidgetType() {
        return pendingWidgetType;
    }
    
    public void clearPendingConfig() {
        pendingWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID;
        pendingWidgetType = null;
        pendingAction = null;
        pendingDoorIdentifier = null;
    }
}
