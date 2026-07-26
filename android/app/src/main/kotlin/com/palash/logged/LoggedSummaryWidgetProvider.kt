package com.palash.logged

import android.widget.RemoteViews

/** Large variant: everything the medium card shows, plus weekly volume and the
 * shape of the last workout. */
class LoggedSummaryWidgetProvider : LoggedBaseWidgetProvider() {

  override val layoutId = R.layout.logged_summary_widget

  override fun RemoteViews.bind(texts: LoggedWidgetTexts) {
    setTextViewText(R.id.widget_streak_text, texts.streak)
    setTextViewText(R.id.widget_sets_text, texts.sets)
    setTextViewText(R.id.widget_volume_text, texts.volume)
    setTextViewText(R.id.widget_last_workout_title, texts.lastWorkoutTitle)
    setTextViewText(R.id.widget_last_workout_date, texts.lastWorkoutDate)
    setTextViewText(R.id.widget_last_workout_detail, texts.lastWorkoutDetail)
  }
}
