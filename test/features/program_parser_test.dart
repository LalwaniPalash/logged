import 'package:flutter_test/flutter_test.dart';
import 'package:logged/features/templates/import/program_parser.dart';

void main() {
  const header = 'day,exercise,sets,min_reps,max_reps,rest_sec,rpe,notes\n';

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
}
