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
 * 1x1 Door Widget - Icon sized, non-resizable
 * Quick action button for door entry
 */
public class DoorWidget1x1 extends AppWidgetProvider {
    private static final String TAG = "WIDGET_1x1";

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        Log.d(TAG, "onUpdate: widgetCount=" + appWidgetIds.length);
        for (int appWidgetId : appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId);
        }
    }

    public static void updateAppWidget(Context context, AppWidgetManager appWidgetManager, int appWidgetId) {
        Log.d(TAG, "updateAppWidget: widgetId=" + appWidgetId);
        
        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.widget_door_1x1);
        
        // Get stored door info
        WidgetStorageManager storage = new WidgetStorageManager(context);
        WidgetStorageManager.DoorInfo doorInfo = storage.getDoorInfo(appWidgetId);
        
        if (doorInfo != null) {
            // Door is configured - show door icon
            Log.d(TAG, "updateAppWidget: configured door=" + doorInfo.doorName);
            views.setImageViewResource(R.id.widget_icon, R.drawable.ic_door_configured);
        } else {
            // Not configured - show add icon
            Log.d(TAG, "updateAppWidget: NOT configured");
            views.setImageViewResource(R.id.widget_icon, R.drawable.ic_door_unconfigured);
        }
        
        // Set click action
        Intent intent = new Intent(context, WidgetActionActivity.class);
        intent.setAction(WidgetActionActivity.ACTION_WIDGET_CLICK);
        intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId);
        intent.putExtra(WidgetActionActivity.EXTRA_WIDGET_TYPE, "1x1");
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
        WidgetStorageManager storage = new WidgetStorageManager(context);
        for (int appWidgetId : appWidgetIds) {
            storage.removeDoorInfo(appWidgetId);
        }
    }

    @Override
    public void onEnabled(Context context) {
    }

    @Override
    public void onDisabled(Context context) {
    }
}
