package com.palash.logged

import android.content.Context
import android.content.SharedPreferences

/**
 * The strings `HomeWidgetService.refresh()` writes from Dart, read once per
 * update with the placeholder each variant should show before the app has ever
 * pushed data. Keys must stay in sync with `HomeWidgetSnapshot.toWidgetData()`.
 */
class LoggedWidgetTexts(context: Context, data: SharedPreferences) {
  val streak: String = data.read(context, "logged_widget_streak_text", R.string.widget_streak_placeholder)
  val sets: String = data.read(context, "logged_widget_sets_text", R.string.widget_sets_placeholder)
  val volume: String = data.read(context, "logged_widget_weekly_volume_text", R.string.widget_volume_placeholder)
  val lastWorkoutTitle: String =
      data.read(context, "logged_widget_last_workout_title", R.string.widget_last_workout_placeholder)
  val lastWorkoutDate: String =
      data.read(context, "logged_widget_last_workout_date", R.string.widget_last_workout_date_placeholder)
  val lastWorkoutDetail: String =
      data.read(context, "logged_widget_last_workout_detail", R.string.widget_last_workout_detail_placeholder)
}

private fun SharedPreferences.read(context: Context, key: String, fallback: Int): String =
    getString(key, null) ?: context.getString(fallback)
