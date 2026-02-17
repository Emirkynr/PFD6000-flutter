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
 * 2x2 Door Widget - Large tap target for easy use while walking
 * Shows door icon, name, and status text
 */
public class DoorWidget2x2 extends AppWidgetProvider {
    private static final String TAG = "WIDGET_2x2";

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        Log.d(TAG, "onUpdate: widgetCount=" + appWidgetIds.length);
        for (int appWidgetId : appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId);
        }
    }

    public static void updateAppWidget(Context context, AppWidgetManager appWidgetManager, int appWidgetId) {
        Log.d(TAG, "updateAppWidget: widgetId=" + appWidgetId);

        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.widget_door_2x2);

        WidgetStorageManager storage = new WidgetStorageManager(context);
        WidgetStorageManager.DoorInfo doorInfo = storage.getDoorInfo(appWidgetId);

        views.setImageViewResource(R.id.widget_door_icon_2x2, R.drawable.ic_door);

        if (doorInfo != null) {
            Log.d(TAG, "updateAppWidget: configured door=" + doorInfo.doorName);
            views.setInt(R.id.widget_door_icon_2x2, "setColorFilter", 0xFFFFFFFF);
            views.setTextViewText(R.id.widget_door_name_2x2, doorInfo.doorName);
            views.setTextViewText(R.id.widget_status_text, "Giriş için dokun");
        } else {
            Log.d(TAG, "updateAppWidget: NOT configured");
            views.setInt(R.id.widget_door_icon_2x2, "setColorFilter", 0xFFE53935);
            views.setTextViewText(R.id.widget_door_name_2x2, "");
            views.setTextViewText(R.id.widget_status_text, "Kapı kaydetmek için dokun");
        }

        Intent intent = new Intent(context, WidgetActionActivity.class);
        intent.setAction(WidgetActionActivity.ACTION_WIDGET_CLICK);
        intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId);
        intent.putExtra(WidgetActionActivity.EXTRA_WIDGET_TYPE, "2x2");
        intent.setData(android.net.Uri.parse("widget://door/" + appWidgetId));

        PendingIntent pendingIntent = PendingIntent.getActivity(
            context,
            appWidgetId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );
        views.setOnClickPendingIntent(R.id.widget_container_2x2, pendingIntent);

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
