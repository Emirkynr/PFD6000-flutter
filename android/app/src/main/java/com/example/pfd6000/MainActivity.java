package com.example.pfd6000;

import android.appwidget.AppWidgetManager;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
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
    private static final String TAG = "WIDGET";
    private static final String CHANNEL_NAME = "enka_gs_widget";
    private MethodChannel methodChannel;
    
    // Pending widget configuration (used when engine not ready)
    private int pendingWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID;
    private String pendingWidgetType = null;
    private String pendingRoute = null;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        
        // Cache the engine for widget access
        FlutterEngineCache.getInstance().put("main_engine", flutterEngine);
        
        // Set up MethodChannel
        methodChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_NAME);
        
        methodChannel.setMethodCallHandler((call, result) -> {
            Log.d(TAG, "MethodChannel call: " + call.method);
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
                case "finishActivity":
                    Log.d(TAG, "finishActivity called");
                    result.success(true);
                    finish();
                    break;
                case "getPendingWidgetAction":
                    // Return pending action if any
                    if (pendingWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID && pendingRoute != null) {
                        java.util.Map<String, Object> response = new java.util.HashMap<>();
                        response.put("widgetId", pendingWidgetId);
                        response.put("widgetType", pendingWidgetType);
                        response.put("route", pendingRoute);
                        Log.d(TAG, "Returning pending action: widgetId=" + pendingWidgetId + " route=" + pendingRoute);
                        clearPendingConfig();
                        result.success(response);
                    } else {
                        result.success(null);
                    }
                    break;
                default:
                    result.notImplemented();
            }
        });
        
        // Process any pending intent after engine is ready
        if (pendingWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID && pendingRoute != null) {
            Log.d(TAG, "Processing pending intent after engine ready");
            forwardIntentToFlutter();
        }
    }

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        handleIntent(getIntent());
    }

    @Override
    protected void onNewIntent(@NonNull Intent intent) {
        super.onNewIntent(intent);
        Log.d(TAG, "onNewIntent received");
        setIntent(intent);
        handleIntent(intent);
    }

    private void handleIntent(Intent intent) {
        if (intent == null) return;
        
        // Check for widget configuration route
        String route = intent.getStringExtra("route");
        int widgetId = intent.getIntExtra("widgetId", AppWidgetManager.INVALID_APPWIDGET_ID);
        String widgetType = intent.getStringExtra("widgetType");
        
        Log.d(TAG, "handleIntent: route=" + route + " widgetId=" + widgetId);
        
        if ("/widget-config".equals(route) && widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
            pendingWidgetId = widgetId;
            pendingWidgetType = widgetType;
            pendingRoute = route;
            
            // If Flutter engine is ready, forward immediately
            if (methodChannel != null) {
                forwardIntentToFlutter();
            }
            // Otherwise, configureFlutterEngine will handle it
        }
        
        // Check for openDoor action
        String action = intent.getStringExtra("action");
        if ("openDoor".equals(action)) {
            String doorIdentifier = intent.getStringExtra("doorIdentifier");
            Log.d(TAG, "openDoor action: widgetId=" + widgetId + " door=" + doorIdentifier);
            // This will be handled by WidgetActionActivity directly via MethodChannel
        }
    }
    
    private void forwardIntentToFlutter() {
        if (methodChannel == null || pendingWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return;
        
        Log.d(TAG, "Forwarding to Flutter: widgetId=" + pendingWidgetId + " route=" + pendingRoute);
        
        java.util.Map<String, Object> args = new java.util.HashMap<>();
        args.put("widgetId", pendingWidgetId);
        args.put("widgetType", pendingWidgetType);
        
        methodChannel.invokeMethod("configureDoor", args);
        clearPendingConfig();
    }

    private void handleUpdateWidget(Object arguments, MethodChannel.Result result) {
        try {
            java.util.Map<String, Object> args = (java.util.Map<String, Object>) arguments;
            int widgetId = (int) args.get("widgetId");
            String doorName = (String) args.get("doorName");
            
            Log.d(TAG, "updateWidget: widgetId=" + widgetId + " doorName=" + doorName);
            
            // Update the widget UI
            AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(this);
            DoorWidget1x4.updateAppWidget(this, appWidgetManager, widgetId);
            DoorWidget1x1.updateAppWidget(this, appWidgetManager, widgetId);
            
            result.success(true);
        } catch (Exception e) {
            Log.e(TAG, "updateWidget error: " + e.getMessage());
            result.error("UPDATE_ERROR", e.getMessage(), null);
        }
    }

    private void handleShowNotFound(Object arguments, MethodChannel.Result result) {
        Log.d(TAG, "showNotFound called");
        result.success(true);
    }

    private void handleSaveDoorConfig(Object arguments, MethodChannel.Result result) {
        try {
            java.util.Map<String, Object> args = (java.util.Map<String, Object>) arguments;
            int widgetId = (int) args.get("widgetId");
            String doorName = (String) args.get("doorName");
            String doorIdentifier = (String) args.get("doorIdentifier");
            
            Log.d(TAG, "saveDoorConfig: widgetId=" + widgetId + " doorName=" + doorName + " doorId=" + doorIdentifier);
            
            // Save to storage
            WidgetStorageManager storage = new WidgetStorageManager(this);
            storage.saveDoorInfo(widgetId, doorName, doorIdentifier);
            
            // Verify save
            WidgetStorageManager.DoorInfo verify = storage.getDoorInfo(widgetId);
            Log.d(TAG, "saveDoorConfig verify: " + (verify != null ? "OK" : "FAILED"));
            
            // Update widget UI
            AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(this);
            DoorWidget1x4.updateAppWidget(this, appWidgetManager, widgetId);
            DoorWidget1x1.updateAppWidget(this, appWidgetManager, widgetId);
            
            result.success(true);
        } catch (Exception e) {
            Log.e(TAG, "saveDoorConfig error: " + e.getMessage());
            result.error("SAVE_ERROR", e.getMessage(), null);
        }
    }
    
    public void clearPendingConfig() {
        pendingWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID;
        pendingWidgetType = null;
        pendingRoute = null;
    }
}
