package com.example.pfd6000.widget;

import android.app.Activity;
import android.appwidget.AppWidgetManager;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.os.VibratorManager;
import android.util.Log;
import android.widget.RemoteViews;
import android.widget.Toast;

import com.example.pfd6000.R;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.FlutterEngineCache;
import io.flutter.embedding.engine.dart.DartExecutor;
import io.flutter.plugin.common.MethodChannel;

/**
 * Transparent activity that handles widget clicks
 * Routes actions to Flutter via MethodChannel
 * Provides visual + haptic feedback during BLE operations
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
    private int currentWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID;
    private String currentWidgetType = null;

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

        currentWidgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        );
        currentWidgetType = intent.getStringExtra(EXTRA_WIDGET_TYPE);

        Log.d(TAG, "handleIntent: widgetId=" + currentWidgetId + " type=" + currentWidgetType);

        if (currentWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            Log.e(TAG, "handleIntent: invalid widgetId, finishing");
            finish();
            return;
        }

        WidgetStorageManager storage = new WidgetStorageManager(this);
        WidgetStorageManager.DoorInfo doorInfo = storage.getDoorInfo(currentWidgetId);

        Log.d(TAG, "handleIntent: doorInfo=" + (doorInfo != null ? doorInfo.doorName : "NULL"));

        if (doorInfo == null) {
            Log.d(TAG, "handleIntent: mode=CONFIGURE -> opening config flow");
            openConfigureFlow(currentWidgetId, currentWidgetType);
        } else {
            Log.d(TAG, "handleIntent: mode=OPEN -> opening door: " + doorInfo.doorName);
            vibrateShort();
            Toast.makeText(this, "Kapı açılıyor...", Toast.LENGTH_SHORT).show();
            updateWidgetLoading(currentWidgetId, currentWidgetType);
            openDoor(currentWidgetId, doorInfo);
        }
    }

    private void openConfigureFlow(int widgetId, String widgetType) {
        Log.d(TAG, "openConfigureFlow: widgetId=" + widgetId);

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

        FlutterEngine flutterEngine = FlutterEngineCache.getInstance().get(ENGINE_ID);

        if (flutterEngine != null) {
            Log.d(TAG, "openDoor: using cached FlutterEngine");
            executeOpenDoor(flutterEngine, widgetId, doorInfo);
        } else {
            Log.d(TAG, "openDoor: no cached engine, creating headless FlutterEngine");
            createHeadlessEngineAndExecute(widgetId, doorInfo);
        }
    }

    private void createHeadlessEngineAndExecute(int widgetId, WidgetStorageManager.DoorInfo doorInfo) {
        try {
            localEngine = new FlutterEngine(this);
            engineCreatedLocally = true;

            localEngine.getDartExecutor().executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            );

            Log.d(TAG, "openDoor: headless engine created, waiting for initialization...");

            // Reduced from 1500ms to 800ms for faster response
            new Handler(Looper.getMainLooper()).postDelayed(() -> {
                Log.d(TAG, "openDoor: executing on headless engine");
                executeOpenDoor(localEngine, widgetId, doorInfo);
            }, 800);

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

        Handler timeoutHandler = new Handler(Looper.getMainLooper());
        Runnable timeoutRunnable = () -> {
            Log.e(TAG, "executeOpenDoor: TIMEOUT - no response from Flutter");
            showResult(false, "Zaman aşımı");
            cleanupAndFinish();
        };
        timeoutHandler.postDelayed(timeoutRunnable, 15000);

        methodChannel.invokeMethod("openDoor", args, new MethodChannel.Result() {
            @Override
            public void success(Object result) {
                timeoutHandler.removeCallbacks(timeoutRunnable);
                boolean success = result != null && (Boolean) result;
                Log.d(TAG, "executeOpenDoor: result=" + success);
                showResult(success, success ? "Komut gönderildi" : "Kapı tespit edilemedi");
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

            if (success) {
                vibrateSuccess();
            } else {
                vibrateError();
            }

            updateWidgetResult(currentWidgetId, currentWidgetType, success);

            // Revert widget to normal state after 3 seconds
            new Handler(Looper.getMainLooper()).postDelayed(() -> {
                revertWidget(currentWidgetId, currentWidgetType);
            }, 3000);
        });
    }

    private void updateWidgetLoading(int widgetId, String widgetType) {
        try {
            AppWidgetManager awm = AppWidgetManager.getInstance(this);
            if ("1x4".equals(widgetType)) {
                RemoteViews views = new RemoteViews(getPackageName(), R.layout.widget_door_1x4);
                views.setInt(R.id.widget_door_icon, "setColorFilter", 0xFFFFC107);
                views.setTextViewText(R.id.widget_action_text, "Bağlanıyor...");
                awm.updateAppWidget(widgetId, views);
            } else if ("1x1".equals(widgetType)) {
                RemoteViews views = new RemoteViews(getPackageName(), R.layout.widget_door_1x1);
                views.setInt(R.id.widget_icon, "setColorFilter", 0xFFFFC107);
                awm.updateAppWidget(widgetId, views);
            } else if ("2x2".equals(widgetType)) {
                RemoteViews views = new RemoteViews(getPackageName(), R.layout.widget_door_2x2);
                views.setInt(R.id.widget_door_icon_2x2, "setColorFilter", 0xFFFFC107);
                views.setTextViewText(R.id.widget_status_text, "Bağlanıyor...");
                awm.updateAppWidget(widgetId, views);
            }
        } catch (Exception e) {
            Log.e(TAG, "updateWidgetLoading error: " + e.getMessage());
        }
    }

    private void updateWidgetResult(int widgetId, String widgetType, boolean success) {
        try {
            AppWidgetManager awm = AppWidgetManager.getInstance(this);
            int color = success ? 0xFF4CAF50 : 0xFFE53935;
            String text = success ? "Başarılı!" : "Başarısız";

            if ("1x4".equals(widgetType)) {
                RemoteViews views = new RemoteViews(getPackageName(), R.layout.widget_door_1x4);
                views.setInt(R.id.widget_door_icon, "setColorFilter", color);
                views.setTextViewText(R.id.widget_action_text, text);
                awm.updateAppWidget(widgetId, views);
            } else if ("1x1".equals(widgetType)) {
                RemoteViews views = new RemoteViews(getPackageName(), R.layout.widget_door_1x1);
                views.setInt(R.id.widget_icon, "setColorFilter", color);
                awm.updateAppWidget(widgetId, views);
            } else if ("2x2".equals(widgetType)) {
                RemoteViews views = new RemoteViews(getPackageName(), R.layout.widget_door_2x2);
                views.setInt(R.id.widget_door_icon_2x2, "setColorFilter", color);
                views.setTextViewText(R.id.widget_status_text, text);
                awm.updateAppWidget(widgetId, views);
            }
        } catch (Exception e) {
            Log.e(TAG, "updateWidgetResult error: " + e.getMessage());
        }
    }

    private void revertWidget(int widgetId, String widgetType) {
        try {
            AppWidgetManager awm = AppWidgetManager.getInstance(this);
            if ("1x4".equals(widgetType)) {
                DoorWidget1x4.updateAppWidget(this, awm, widgetId);
            } else if ("1x1".equals(widgetType)) {
                DoorWidget1x1.updateAppWidget(this, awm, widgetId);
            } else if ("2x2".equals(widgetType)) {
                DoorWidget2x2.updateAppWidget(this, awm, widgetId);
            }
        } catch (Exception e) {
            Log.e(TAG, "revertWidget error: " + e.getMessage());
        }
    }

    private void vibrateShort() {
        try {
            Vibrator vibrator = getVibrator();
            if (vibrator != null && vibrator.hasVibrator()) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator.vibrate(VibrationEffect.createOneShot(50, VibrationEffect.DEFAULT_AMPLITUDE));
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "vibrateShort error: " + e.getMessage());
        }
    }

    private void vibrateSuccess() {
        try {
            Vibrator vibrator = getVibrator();
            if (vibrator != null && vibrator.hasVibrator()) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator.vibrate(VibrationEffect.createOneShot(200, VibrationEffect.DEFAULT_AMPLITUDE));
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "vibrateSuccess error: " + e.getMessage());
        }
    }

    private void vibrateError() {
        try {
            Vibrator vibrator = getVibrator();
            if (vibrator != null && vibrator.hasVibrator()) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator.vibrate(VibrationEffect.createWaveform(new long[]{0, 100, 100, 100}, -1));
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "vibrateError error: " + e.getMessage());
        }
    }

    private Vibrator getVibrator() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            VibratorManager vm = (VibratorManager) getSystemService(Context.VIBRATOR_MANAGER_SERVICE);
            return vm != null ? vm.getDefaultVibrator() : null;
        } else {
            return (Vibrator) getSystemService(Context.VIBRATOR_SERVICE);
        }
    }

    private void cleanupAndFinish() {
        Log.d(TAG, "cleanupAndFinish: engineCreatedLocally=" + engineCreatedLocally);

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
