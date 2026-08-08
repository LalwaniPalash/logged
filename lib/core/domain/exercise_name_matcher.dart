List<String> tokenizeExerciseName(String name) => name
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9\s-]+'), ' ')
    .split(RegExp(r'[\s-]+'))
    .where((token) => token.isNotEmpty)
    .toList(growable: false);

bool exerciseNameContainsPhrase(List<String> exerciseTokens, String phrase) {
  final phraseTokens = tokenizeExerciseName(phrase);
  if (phraseTokens.isEmpty || phraseTokens.length > exerciseTokens.length) {
    return false;
  }

  for (
    var start = 0;
    start <= exerciseTokens.length - phraseTokens.length;
    start++
  ) {
    var matches = true;
    for (var offset = 0; offset < phraseTokens.length; offset++) {
      if (exerciseTokens[start + offset] != phraseTokens[offset]) {
        matches = false;
        break;
      }
    }
    if (matches) return true;
  }

  return false;
}

String? mostSpecificExercisePhraseMatch(
  List<String> exerciseTokens,
  Iterable<String> phrases,
) {
  String? bestMatch;
  var bestTokenCount = -1;
  var bestLength = -1;

  for (final phrase in phrases) {
    if (!exerciseNameContainsPhrase(exerciseTokens, phrase)) continue;
    final tokenCount = tokenizeExerciseName(phrase).length;
    if (tokenCount > bestTokenCount ||
        (tokenCount == bestTokenCount && phrase.length > bestLength)) {
      bestMatch = phrase;
      bestTokenCount = tokenCount;
      bestLength = phrase.length;
    }
  }

  return bestMatch;
}
