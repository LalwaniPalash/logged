package com.palash.logged

import android.widget.RemoteViews

/** Small variant: the streak on its own, for a 2x2 slot. */
class LoggedStreakWidgetProvider : LoggedBaseWidgetProvider() {

  override val layoutId = R.layout.logged_streak_widget

  override fun RemoteViews.bind(texts: LoggedWidgetTexts) {
    setTextViewText(R.id.widget_streak_text, texts.streak)
    setTextViewText(R.id.widget_sets_text, texts.sets)
  }
}
