package com.example.pfd6000.widget;

import android.app.Activity;
import android.appwidget.AppWidgetManager;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.widget.Toast;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.FlutterEngineCache;
import io.flutter.plugin.common.MethodChannel;

/**
 * Transparent activity that handles widget clicks
 * Routes actions to Flutter via MethodChannel
 */
public class WidgetActionActivity extends Activity {
    public static final String ACTION_WIDGET_CLICK = "com.example.pfd6000.WIDGET_CLICK";
    public static final String EXTRA_WIDGET_TYPE = "widget_type";
    private static final String CHANNEL_NAME = "enka_gs_widget";
    
    private MethodChannel methodChannel;
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        handleIntent(getIntent());
    }
    
    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        handleIntent(intent);
    }
    
    private void handleIntent(Intent intent) {
        if (intent == null) {
            finish();
            return;
        }
        
        int widgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID, 
            AppWidgetManager.INVALID_APPWIDGET_ID
        );
        
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish();
            return;
        }
        
        String widgetType = intent.getStringExtra(EXTRA_WIDGET_TYPE);
        
        // Check if door is configured
        WidgetStorageManager storage = new WidgetStorageManager(this);
        WidgetStorageManager.DoorInfo doorInfo = storage.getDoorInfo(widgetId);
        
        if (doorInfo == null) {
            // Not configured - open configuration
            openConfigureFlow(widgetId, widgetType);
        } else {
            // Configured - try to open door
            openDoor(widgetId, doorInfo);
        }
    }
    
    private void openConfigureFlow(int widgetId, String widgetType) {
        // Launch main app with configuration route
        Intent launchIntent = getPackageManager().getLaunchIntentForPackage(getPackageName());
        if (launchIntent != null) {
            launchIntent.putExtra("route", "/widget-config");
            launchIntent.putExtra("widgetId", widgetId);
            launchIntent.putExtra("widgetType", widgetType);
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            startActivity(launchIntent);
        }
        finish();
    }
    
    private void openDoor(int widgetId, WidgetStorageManager.DoorInfo doorInfo) {
        // Get Flutter engine from cache or create a headless one
        FlutterEngine flutterEngine = FlutterEngineCache.getInstance().get("main_engine");
        
        if (flutterEngine != null) {
            methodChannel = new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(), 
                CHANNEL_NAME
            );
            
            // Call Flutter to open door
            methodChannel.invokeMethod("openDoor", 
                new java.util.HashMap<String, Object>() {{
                    put("widgetId", widgetId);
                    put("doorIdentifier", doorInfo.doorIdentifier);
                    put("doorName", doorInfo.doorName);
                }},
                new MethodChannel.Result() {
                    @Override
                    public void success(Object result) {
                        boolean success = result != null && (Boolean) result;
                        showResult(success);
                        finish();
                    }
                    
                    @Override
                    public void error(String errorCode, String errorMessage, Object errorDetails) {
                        showResult(false);
                        finish();
                    }
                    
                    @Override
                    public void notImplemented() {
                        showResult(false);
                        finish();
                    }
                }
            );
        } else {
            // Flutter engine not available - launch app in background mode
            Toast.makeText(this, "Uygulama başlatılıyor...", Toast.LENGTH_SHORT).show();
            Intent launchIntent = getPackageManager().getLaunchIntentForPackage(getPackageName());
            if (launchIntent != null) {
                launchIntent.putExtra("action", "openDoor");
                launchIntent.putExtra("widgetId", widgetId);
                launchIntent.putExtra("doorIdentifier", doorInfo.doorIdentifier);
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                startActivity(launchIntent);
            }
            finish();
        }
    }
    
    private void showResult(boolean success) {
        new Handler(Looper.getMainLooper()).post(() -> {
            if (success) {
                Toast.makeText(this, "Komut gönderildi ✓", Toast.LENGTH_SHORT).show();
            } else {
                Toast.makeText(this, "Kapı tespit edilemedi", Toast.LENGTH_LONG).show();
            }
        });
    }
}
