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

/// Case/whitespace-insensitive check for whether [candidate] already names
/// an exercise in [existingNames] — used to warn before a custom-exercise
/// insert would hit the DB's unique constraint on name.
bool isDuplicateExerciseName(
  String candidate,
  Iterable<String> existingNames,
) {
  final normalized = candidate.trim().toLowerCase();
  if (normalized.isEmpty) return false;
  return existingNames.any((name) => name.trim().toLowerCase() == normalized);
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
