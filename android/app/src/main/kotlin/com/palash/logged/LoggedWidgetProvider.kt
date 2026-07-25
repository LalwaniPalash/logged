package com.palash.logged

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class LoggedWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val views =
          RemoteViews(context.packageName, R.layout.logged_widget).apply {
            val launchIntent =
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            setOnClickPendingIntent(R.id.widget_root, launchIntent)
            setTextViewText(
                R.id.widget_streak_text,
                widgetData.getString(
                    "logged_widget_streak_text",
                    context.getString(R.string.widget_streak_placeholder),
                ),
            )
            setTextViewText(
                R.id.widget_sets_text,
                widgetData.getString(
                    "logged_widget_sets_text",
                    context.getString(R.string.widget_sets_placeholder),
                ),
            )
            setTextViewText(
                R.id.widget_last_workout_title,
                widgetData.getString(
                    "logged_widget_last_workout_title",
                    context.getString(R.string.widget_last_workout_placeholder),
                ),
            )
            setTextViewText(
                R.id.widget_last_workout_date,
                widgetData.getString(
                    "logged_widget_last_workout_date",
                    context.getString(R.string.widget_last_workout_date_placeholder),
                ),
            )
          }
      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
