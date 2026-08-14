import 'package:flutter_test/flutter_test.dart';
import 'package:logged/features/templates/import/program_parser.dart';

void main() {
  const header = 'day,exercise,sets,min_reps,max_reps,rest_sec,rpe,notes\n';
  const fullHeader =
      'day,exercise,sets,min_reps,max_reps,duration_sec,distance_m,sides,'
      'rest_sec,rpe,notes\n';

  test('valid CSV groups complete prescription rows', () {
    final result = parseProgram(
      '${header}Push,Barbell Bench Press,4,6,8,120,8,"pause, then press"\n'
      'Pull,Barbell Bent-Over Row,3,8,10,90,8,\n',
    );
    expect(result.errors, isEmpty);
    expect(result.rows, hasLength(2));
    expect(result.rows.first.day, 'Push');
    expect(result.rows.first.notes, 'pause, then press');
  });

  test('malformed rows report row numbers while valid rows survive', () {
    final result = parseProgram(
      '${header}Push,Bench,zero,6,8,120,8,\n'
      'Pull,Row,3,10,8,-1,12,\n'
      'Legs,Squat,5,5,8,180,8,\n',
    );
    expect(result.rows.single.exercise, 'Squat');
    expect(result.errors.map((error) => error.rowNumber), [2, 3]);
  });

  test('empty input and missing cells never throw', () {
    expect(parseProgram('').errors.single.rowNumber, 1);
    final result = parseProgram('$header,,3,,,,,\n');
    expect(result.rows, isEmpty);
    expect(result.errors.single.message, contains('required'));
  });

  test('duplicate exercise names are preserved for explicit review', () {
    final result = parseProgram(
      '${header}Push,Bench,3,6,8,90,8,\n'
      'Push,Bench,2,10,12,60,9,backoff\n',
    );
    expect(result.rows, hasLength(2));
  });

  test('duration_sec parses when the optional column is present', () {
    final result = parseProgram(
      '${fullHeader}Push,Copenhagen Plank,3,,,30,,2,60,,\n',
    );
    expect(result.errors, isEmpty);
    expect(result.rows.single.targetDurationSec, 30);
    expect(result.rows.single.sidesPerSet, 2);
  });

  test('non-numeric duration_sec produces a per-row error', () {
    final result = parseProgram(
      '${fullHeader}Push,Copenhagen Plank,3,,,thirty,,2,60,,\n',
    );
    expect(result.rows, isEmpty);
    expect(result.errors.single.rowNumber, 2);
    expect(
      result.errors.single.message,
      contains('duration_sec must be a positive integer'),
    );
  });

  test('sides outside 1 or 2 produces a per-row error', () {
    final result = parseProgram(
      '${fullHeader}Push,Copenhagen Plank,3,,,30,,3,60,,\n',
    );
    expect(result.rows, isEmpty);
    expect(result.errors.single.rowNumber, 2);
    expect(result.errors.single.message, contains('sides must be 1 or 2'));
  });

  test('fuzzy matching handles safe near-misses conservatively', () {
    const library = [
      'Barbell Bench Press',
      'Incline Bench Press',
      'Barbell Back Squat',
    ];
    expect(
      fuzzyMatchExercise('barbell benchpress', library)?.name,
      'Barbell Bench Press',
    );
    expect(
      fuzzyMatchExercise('BARBELL   BACK-SQUAT', library)?.name,
      'Barbell Back Squat',
    );
    expect(fuzzyMatchExercise('Bench Dip', library), isNull);
    expect(fuzzyMatchExercise('Completely Unknown Move', library), isNull);
  });

  test('zero and negative duration or distance are rejected', () {
    // A 0 or negative prescription can never satisfy the completion rules, so
    // it must not reach template_exercises.
    final result = parseProgram(
      'day,exercise,sets,min_reps,max_reps,duration_sec,distance_m,sides,rest_sec,rpe,notes\n'
      'Day 1,Plank,3,,,0,,,60,,\n'
      'Day 1,Plank,3,,,-30,,,60,,\n'
      'Day 1,Farmer Carry,3,,,,0,,60,,\n'
      'Day 1,Farmer Carry,3,,,,-100,,60,,\n',
    );

    expect(result.rows, isEmpty);
    expect(result.errors, hasLength(4));
    expect(
      result.errors.where(
        (error) => error.message.contains('duration_sec must be a positive integer'),
      ),
      hasLength(2),
    );
    expect(
      result.errors.where(
        (error) => error.message.contains('distance_m must be a positive number'),
      ),
      hasLength(2),
    );
  });
}
