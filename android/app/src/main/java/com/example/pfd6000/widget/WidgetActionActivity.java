package com.example.pfd6000.widget;

import android.app.Activity;
import android.appwidget.AppWidgetManager;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.widget.Toast;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.FlutterEngineCache;
import io.flutter.embedding.engine.dart.DartExecutor;
import io.flutter.plugin.common.MethodChannel;

/**
 * Transparent activity that handles widget clicks
 * Routes actions to Flutter via MethodChannel
 * CRITICAL: Does NOT launch MainActivity for OPEN mode
 */
public class WidgetActionActivity extends Activity {
    private static final String TAG = "WIDGET_ACTION";
    public static final String ACTION_WIDGET_CLICK = "com.example.pfd6000.WIDGET_CLICK";
    public static final String EXTRA_WIDGET_TYPE = "widget_type";
    private static final String CHANNEL_NAME = "enka_gs_widget";
    private static final String ENGINE_ID = "main_engine";
    
    private MethodChannel methodChannel;
    private FlutterEngine localEngine;
    private boolean engineCreatedLocally = false;
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Log.d(TAG, "onCreate");
        handleIntent(getIntent());
    }
    
    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        Log.d(TAG, "onNewIntent");
        setIntent(intent);
        handleIntent(intent);
    }
    
    private void handleIntent(Intent intent) {
        if (intent == null) {
            Log.d(TAG, "handleIntent: null intent, finishing");
            finish();
            return;
        }
        
        int widgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID, 
            AppWidgetManager.INVALID_APPWIDGET_ID
        );
        String widgetType = intent.getStringExtra(EXTRA_WIDGET_TYPE);
        
        Log.d(TAG, "handleIntent: widgetId=" + widgetId + " type=" + widgetType);
        
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            Log.e(TAG, "handleIntent: invalid widgetId, finishing");
            finish();
            return;
        }
        
        // Check if door is configured
        WidgetStorageManager storage = new WidgetStorageManager(this);
        WidgetStorageManager.DoorInfo doorInfo = storage.getDoorInfo(widgetId);
        
        Log.d(TAG, "handleIntent: doorInfo=" + (doorInfo != null ? doorInfo.doorName : "NULL"));
        
        if (doorInfo == null) {
            // Not configured - open configuration flow
            Log.d(TAG, "handleIntent: mode=CONFIGURE -> opening config flow");
            openConfigureFlow(widgetId, widgetType);
        } else {
            // Configured - open door (NO MainActivity launch!)
            Log.d(TAG, "handleIntent: mode=OPEN -> opening door: " + doorInfo.doorName);
            openDoor(widgetId, doorInfo);
        }
    }
    
    private void openConfigureFlow(int widgetId, String widgetType) {
        Log.d(TAG, "openConfigureFlow: widgetId=" + widgetId);
        
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
        Log.d(TAG, "openDoor: START widgetId=" + widgetId + " door=" + doorInfo.doorName);
        
        // Try to get cached Flutter engine first
        FlutterEngine flutterEngine = FlutterEngineCache.getInstance().get(ENGINE_ID);
        
        if (flutterEngine != null) {
            Log.d(TAG, "openDoor: using cached FlutterEngine");
            executeOpenDoor(flutterEngine, widgetId, doorInfo);
        } else {
            // Engine not cached - create a headless one
            Log.d(TAG, "openDoor: no cached engine, creating headless FlutterEngine");
            createHeadlessEngineAndExecute(widgetId, doorInfo);
        }
    }
    
    private void createHeadlessEngineAndExecute(int widgetId, WidgetStorageManager.DoorInfo doorInfo) {
        try {
            // Create headless Flutter engine
            localEngine = new FlutterEngine(this);
            engineCreatedLocally = true;
            
            // Start executing Dart code
            localEngine.getDartExecutor().executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            );
            
            Log.d(TAG, "openDoor: headless engine created, waiting for initialization...");
            
            // Give Flutter time to initialize (1.5 seconds)
            new Handler(Looper.getMainLooper()).postDelayed(() -> {
                Log.d(TAG, "openDoor: executing on headless engine");
                executeOpenDoor(localEngine, widgetId, doorInfo);
            }, 1500);
            
        } catch (Exception e) {
            Log.e(TAG, "openDoor: failed to create headless engine: " + e.getMessage());
            showResult(false, "Engine başlatılamadı");
            cleanupAndFinish();
        }
    }
    
    private void executeOpenDoor(FlutterEngine engine, int widgetId, WidgetStorageManager.DoorInfo doorInfo) {
        Log.d(TAG, "executeOpenDoor: setting up MethodChannel");
        
        methodChannel = new MethodChannel(
            engine.getDartExecutor().getBinaryMessenger(), 
            CHANNEL_NAME
        );
        
        java.util.Map<String, Object> args = new java.util.HashMap<>();
        args.put("widgetId", widgetId);
        args.put("doorIdentifier", doorInfo.doorIdentifier);
        args.put("doorName", doorInfo.doorName);
        
        Log.d(TAG, "executeOpenDoor: invoking openDoor method");
        
        // Set a timeout in case Flutter doesn't respond
        Handler timeoutHandler = new Handler(Looper.getMainLooper());
        Runnable timeoutRunnable = () -> {
            Log.e(TAG, "executeOpenDoor: TIMEOUT - no response from Flutter");
            showResult(false, "Zaman aşımı");
            cleanupAndFinish();
        };
        timeoutHandler.postDelayed(timeoutRunnable, 15000); // 15 second timeout
        
        methodChannel.invokeMethod("openDoor", args, new MethodChannel.Result() {
            @Override
            public void success(Object result) {
                timeoutHandler.removeCallbacks(timeoutRunnable);
                boolean success = result != null && (Boolean) result;
                Log.d(TAG, "executeOpenDoor: result=" + success);
                showResult(success, success ? "Komut gönderildi ✓" : "Kapı tespit edilemedi");
                cleanupAndFinish();
            }
            
            @Override
            public void error(String errorCode, String errorMessage, Object errorDetails) {
                timeoutHandler.removeCallbacks(timeoutRunnable);
                Log.e(TAG, "executeOpenDoor: error=" + errorCode + " msg=" + errorMessage);
                showResult(false, "Hata: " + errorMessage);
                cleanupAndFinish();
            }
            
            @Override
            public void notImplemented() {
                timeoutHandler.removeCallbacks(timeoutRunnable);
                Log.e(TAG, "executeOpenDoor: notImplemented - handler not registered?");
                showResult(false, "Servis hazır değil");
                cleanupAndFinish();
            }
        });
    }
    
    private void showResult(boolean success, String message) {
        Log.d(TAG, "showResult: success=" + success + " msg=" + message);
        new Handler(Looper.getMainLooper()).post(() -> {
            Toast.makeText(this, message, Toast.LENGTH_SHORT).show();
        });
    }
    
    private void cleanupAndFinish() {
        Log.d(TAG, "cleanupAndFinish: engineCreatedLocally=" + engineCreatedLocally);
        
        // If we created a local engine, destroy it
        if (engineCreatedLocally && localEngine != null) {
            localEngine.destroy();
            localEngine = null;
        }
        
        finish();
    }
    
    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (engineCreatedLocally && localEngine != null) {
            localEngine.destroy();
        }
    }
}
