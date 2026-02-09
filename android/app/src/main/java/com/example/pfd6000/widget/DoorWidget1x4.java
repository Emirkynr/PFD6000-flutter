package com.example.pfd6000.widget;

import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.util.Log;
import android.widget.RemoteViews;

import com.example.pfd6000.R;

/**
 * 1x4 Door Widget - Horizontally resizable
 * Shows door name and "Giriş yapmak için dokun" text
 */
public class DoorWidget1x4 extends AppWidgetProvider {
    private static final String TAG = "WIDGET_1x4";

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        Log.d(TAG, "onUpdate: widgetCount=" + appWidgetIds.length);
        for (int appWidgetId : appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId);
        }
    }

    public static void updateAppWidget(Context context, AppWidgetManager appWidgetManager, int appWidgetId) {
        Log.d(TAG, "updateAppWidget: widgetId=" + appWidgetId);
        
        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.widget_door_1x4);
        
        // Get stored door info
        WidgetStorageManager storage = new WidgetStorageManager(context);
        WidgetStorageManager.DoorInfo doorInfo = storage.getDoorInfo(appWidgetId);
        
        // Set door icon with color tint based on configuration state
        views.setImageViewResource(R.id.widget_door_icon, R.drawable.ic_door);
        
        if (doorInfo != null) {
            // Door is configured: WHITE icon + door name
            Log.d(TAG, "updateAppWidget: configured door=" + doorInfo.doorName);
            views.setInt(R.id.widget_door_icon, "setColorFilter", 0xFFFFFFFF); // White
            views.setTextViewText(R.id.widget_door_name, doorInfo.doorName);
            views.setTextViewText(R.id.widget_action_text, "Giriş yapmak için dokun");
        } else {
            // Not configured: RED icon + setup prompt
            Log.d(TAG, "updateAppWidget: NOT configured");
            views.setInt(R.id.widget_door_icon, "setColorFilter", 0xFFE53935); // Material Red 600
            views.setTextViewText(R.id.widget_door_name, "");
            views.setTextViewText(R.id.widget_action_text, "Kapı kaydetmek için dokun");
        }
        
        // Set click action
        Intent intent = new Intent(context, WidgetActionActivity.class);
        intent.setAction(WidgetActionActivity.ACTION_WIDGET_CLICK);
        intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId);
        intent.putExtra(WidgetActionActivity.EXTRA_WIDGET_TYPE, "1x4");
        // Make intent unique per widget
        intent.setData(android.net.Uri.parse("widget://door/" + appWidgetId));
        
        PendingIntent pendingIntent = PendingIntent.getActivity(
            context, 
            appWidgetId, 
            intent, 
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );
        views.setOnClickPendingIntent(R.id.widget_container, pendingIntent);
        
        appWidgetManager.updateAppWidget(appWidgetId, views);
        Log.d(TAG, "updateAppWidget: complete for widgetId=" + appWidgetId);
    }


    @Override
    public void onDeleted(Context context, int[] appWidgetIds) {
        // Clean up storage when widget is removed
        WidgetStorageManager storage = new WidgetStorageManager(context);
        for (int appWidgetId : appWidgetIds) {
            storage.removeDoorInfo(appWidgetId);
        }
    }

    @Override
    public void onEnabled(Context context) {
        // First widget added
    }

    @Override
    public void onDisabled(Context context) {
        // Last widget removed
    }
}
