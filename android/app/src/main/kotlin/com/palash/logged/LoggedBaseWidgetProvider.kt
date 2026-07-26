package com.palash.logged

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Shared plumbing for every Logged widget variant: read the data once, inflate
 * the variant's layout, make the whole card open the app, then let the subclass
 * fill in the fields it shows.
 *
 * Layouts may only use views annotated `@RemoteView` — a bare `<View>` makes the
 * launcher fail to inflate and show "couldn't add widget". Every layout must
 * also carry an `@+id/widget_root` for the tap target.
 */
abstract class LoggedBaseWidgetProvider : HomeWidgetProvider() {

  protected abstract val layoutId: Int

  protected abstract fun RemoteViews.bind(texts: LoggedWidgetTexts)

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val texts = LoggedWidgetTexts(context, widgetData)
    appWidgetIds.forEach { widgetId ->
      val views =
          RemoteViews(context.packageName, layoutId).apply {
            setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
            bind(texts)
          }
      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
