enum ProgramFormat { csv }

class ParsedProgramRow {
  const ParsedProgramRow({
    required this.rowNumber,
    required this.day,
    required this.exercise,
    required this.sets,
    this.minReps,
    this.maxReps,
    this.restSeconds,
    this.rpe,
    this.notes,
  });

  final int rowNumber;
  final String day;
  final String exercise;
  final int sets;
  final int? minReps;
  final int? maxReps;
  final int? restSeconds;
  final double? rpe;
  final String? notes;
}

class ProgramParseError {
  const ProgramParseError({required this.rowNumber, required this.message});

  final int rowNumber;
  final String message;
}

class ProgramParseResult {
  const ProgramParseResult({required this.rows, required this.errors});

  final List<ParsedProgramRow> rows;
  final List<ProgramParseError> errors;
}

const programCsvHeader = [
  'day',
  'exercise',
  'sets',
  'min_reps',
  'max_reps',
  'rest_sec',
  'rpe',
  'notes',
];

ProgramParseResult parseProgram(
  String input, {
  ProgramFormat format = ProgramFormat.csv,
}) {
  if (input.trim().isEmpty) {
    return const ProgramParseResult(
      rows: [],
      errors: [ProgramParseError(rowNumber: 1, message: 'Input is empty.')],
    );
  }
  try {
    return switch (format) {
      ProgramFormat.csv => _parseCsvProgram(input),
    };
  } on Object {
    return const ProgramParseResult(
      rows: [],
      errors: [
        ProgramParseError(
          rowNumber: 1,
          message: 'The file could not be parsed as CSV.',
        ),
      ],
    );
  }
}

ProgramParseResult _parseCsvProgram(String input) {
  final records = _csvRecords(input);
  if (records.isEmpty) {
    return const ProgramParseResult(
      rows: [],
      errors: [ProgramParseError(rowNumber: 1, message: 'Input is empty.')],
    );
  }
  final header = records.first
      .map((cell) => cell.trim().toLowerCase())
      .toList();
  final missing = programCsvHeader.where((column) => !header.contains(column));
  if (missing.isNotEmpty) {
    return ProgramParseResult(
      rows: const [],
      errors: [
        ProgramParseError(
          rowNumber: 1,
          message: 'Missing columns: ${missing.join(', ')}.',
        ),
      ],
    );
  }
  final index = {
    for (final column in programCsvHeader) column: header.indexOf(column),
  };
  final rows = <ParsedProgramRow>[];
  final errors = <ProgramParseError>[];
  for (var recordIndex = 1; recordIndex < records.length; recordIndex++) {
    final rowNumber = recordIndex + 1;
    final record = records[recordIndex];
    if (record.every((cell) => cell.trim().isEmpty)) continue;
    String cell(String name) {
      final position = index[name]!;
      return position < record.length ? record[position].trim() : '';
    }

    final day = cell('day');
    final exercise = cell('exercise');
    final sets = int.tryParse(cell('sets'));
    final minReps = _optionalInt(cell('min_reps'));
    final maxReps = _optionalInt(cell('max_reps'));
    final rest = _optionalInt(cell('rest_sec'));
    final rpe = _optionalDouble(cell('rpe'));
    final rowErrors = <String>[
      if (day.isEmpty) 'day is required',
      if (exercise.isEmpty) 'exercise is required',
      if (sets == null || sets <= 0) 'sets must be a positive integer',
      if (cell('min_reps').isNotEmpty && minReps == null)
        'min_reps must be an integer',
      if (cell('max_reps').isNotEmpty && maxReps == null)
        'max_reps must be an integer',
      if (minReps != null && maxReps != null && minReps > maxReps)
        'min_reps cannot exceed max_reps',
      if (cell('rest_sec').isNotEmpty && (rest == null || rest < 0))
        'rest_sec must be a non-negative integer',
      if (cell('rpe').isNotEmpty && (rpe == null || rpe < 1 || rpe > 10))
        'rpe must be between 1 and 10',
    ];
    if (rowErrors.isNotEmpty) {
      errors.add(
        ProgramParseError(rowNumber: rowNumber, message: rowErrors.join('; ')),
      );
      continue;
    }
    rows.add(
      ParsedProgramRow(
        rowNumber: rowNumber,
        day: day,
        exercise: exercise,
        sets: sets!,
        minReps: minReps,
        maxReps: maxReps,
        restSeconds: rest,
        rpe: rpe,
        notes: cell('notes').isEmpty ? null : cell('notes'),
      ),
    );
  }
  return ProgramParseResult(rows: rows, errors: errors);
}

List<List<String>> _csvRecords(String input) {
  final records = <List<String>>[];
  var record = <String>[];
  var field = StringBuffer();
  var quoted = false;
  for (var index = 0; index < input.length; index++) {
    final character = input[index];
    if (character == '"') {
      if (quoted && index + 1 < input.length && input[index + 1] == '"') {
        field.write('"');
        index++;
      } else {
        quoted = !quoted;
      }
    } else if (character == ',' && !quoted) {
      record.add(field.toString());
      field = StringBuffer();
    } else if ((character == '\n' || character == '\r') && !quoted) {
      if (character == '\r' &&
          index + 1 < input.length &&
          input[index + 1] == '\n') {
        index++;
      }
      record.add(field.toString());
      records.add(record);
      record = <String>[];
      field = StringBuffer();
    } else {
      field.write(character);
    }
  }
  if (quoted) throw const FormatException('Unclosed quote');
  record.add(field.toString());
  if (record.length > 1 || record.single.trim().isNotEmpty) {
    records.add(record);
  }
  return records;
}

int? _optionalInt(String value) => value.isEmpty ? null : int.tryParse(value);
double? _optionalDouble(String value) =>
    value.isEmpty ? null : double.tryParse(value);

class FuzzyExerciseMatch {
  const FuzzyExerciseMatch({required this.name, required this.score});

  final String name;
  final double score;
}

FuzzyExerciseMatch? fuzzyMatchExercise(
  String input,
  Iterable<String> candidates,
) {
  final normalizedInput = _normalize(input);
  if (normalizedInput.isEmpty) return null;
  final compactInput = normalizedInput.replaceAll(' ', '');
  final scored = <FuzzyExerciseMatch>[];
  for (final candidate in candidates) {
    final normalized = _normalize(candidate);
    if (normalized == normalizedInput ||
        normalized.replaceAll(' ', '') == compactInput) {
      scored.add(FuzzyExerciseMatch(name: candidate, score: 1));
      continue;
    }
    final inputTokens = normalizedInput.split(' ').toSet();
    final candidateTokens = normalized.split(' ').toSet();
    final shared = inputTokens.intersection(candidateTokens).length;
    final union = inputTokens.union(candidateTokens).length;
    final score = union == 0 ? 0.0 : shared / union;
    if (score >= 0.6) {
      scored.add(FuzzyExerciseMatch(name: candidate, score: score));
    }
  }
  if (scored.isEmpty) return null;
  scored.sort((a, b) => b.score.compareTo(a.score));
  if (scored.length > 1 && scored.first.score - scored[1].score < 0.15) {
    return null;
  }
  return scored.first;
}

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');
