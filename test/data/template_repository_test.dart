import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/data/repositories/template_repository.dart';

void main() {
  late AppDatabase database;
  late TemplateRepository repository;
  late int exerciseId;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = TemplateRepository(database);
    exerciseId = await database
        .into(database.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: 'Barbell Back Squat',
            category: ExerciseCategory.strength,
            muscleGroup: 'quads',
          ),
        );
  });

  tearDown(() => database.close());

  test('rename and reorder persist', () async {
    final first = await repository.create('First');
    final second = await repository.create('Second');
    final third = await repository.create('Third');

    await repository.rename(first, '  Renamed  ');
    await repository.reorder([third, first, second]);

    final templates = await repository.watchAll().first;
    expect(templates.map((item) => item.id), [third, first, second]);
    expect(templates.firstWhere((item) => item.id == first).name, 'Renamed');
    expect(templates.map((item) => item.position), [0, 1, 2]);
  });

  test('duplicate copies every prescription field independently', () async {
    final source = await repository.create('Leg day');
    await repository.replaceExerciseDetails(source, [
      TemplateExercisesCompanion.insert(
        templateId: source,
        exerciseId: exerciseId,
        position: 0,
        targetSets: const Value(4),
        sidesPerSet: const Value(2),
        minReps: const Value(6),
        maxReps: const Value(8),
        targetDurationSec: const Value(45),
        targetDistanceMeters: const Value(100),
        restSeconds: const Value(120),
        eccentricSec: const Value(3),
        bottomPauseSec: const Value(1),
        concentricSec: const Value(2),
        topPauseSec: const Value(1),
        prescriptionNotes: const Value('Controlled'),
        formUrl: const Value('https://example.com/form'),
      ),
    ]);

    final copy = await repository.duplicate(source);
    final copyTemplate = (await repository.watchAll().first).last;
    final copied = (await repository.exerciseDetails(copy)).single;

    expect(copyTemplate.name, 'Leg day (copy)');
    expect(copied.templateExercise.targetSets, 4);
    expect(copied.templateExercise.sidesPerSet, 2);
    expect(copied.templateExercise.minReps, 6);
    expect(copied.templateExercise.maxReps, 8);
    expect(copied.templateExercise.targetDurationSec, 45);
    expect(copied.templateExercise.targetDistanceMeters, 100);
    expect(copied.templateExercise.restSeconds, 120);
    expect(copied.templateExercise.eccentricSec, 3);
    expect(copied.templateExercise.bottomPauseSec, 1);
    expect(copied.templateExercise.concentricSec, 2);
    expect(copied.templateExercise.topPauseSec, 1);
    expect(copied.templateExercise.prescriptionNotes, 'Controlled');
    expect(copied.templateExercise.formUrl, 'https://example.com/form');

    await repository.replaceExercises(copy, const []);
    expect(await repository.exerciseIds(source), [exerciseId]);
  });

  test('delete preserves historical session and logged sets', () async {
    final templateId = await repository.create('Push');
    await repository.replaceExercises(templateId, [exerciseId]);
    final sessionId = await database
        .into(database.sessions)
        .insert(
          SessionsCompanion.insert(
            startedAt: DateTime(2026, 7, 20),
            endedAt: Value(DateTime(2026, 7, 20, 1)),
            templateId: Value(templateId),
          ),
        );
    final linkId = await database
        .into(database.sessionExercises)
        .insert(
          SessionExercisesCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            position: 0,
          ),
        );
    await database
        .into(database.setEntries)
        .insert(
          SetEntriesCompanion.insert(
            sessionExerciseId: linkId,
            setNumber: 1,
            reps: const Value(8),
            weightValue: const Value(80),
            unit: const Value(WeightUnit.kg),
          ),
        );

    await repository.delete(templateId);

    expect(await repository.watchAll().first, isEmpty);
    expect(
      (await database.select(database.sessions).getSingle()).templateId,
      equals(null),
    );
    expect(
      await database.select(database.sessionExercises).get(),
      hasLength(1),
    );
    expect(await database.select(database.setEntries).get(), hasLength(1));
  });

  test(
    'deload template uses the most recent trained week at half volume',
    () async {
      final trainedWeekDay = DateTime(2026, 7, 23);
      final sessionId = await database
          .into(database.sessions)
          .insert(
            SessionsCompanion.insert(
              startedAt: trainedWeekDay,
              endedAt: Value(trainedWeekDay.add(const Duration(hours: 1))),
            ),
          );
      final linkId = await database
          .into(database.sessionExercises)
          .insert(
            SessionExercisesCompanion.insert(
              sessionId: sessionId,
              exerciseId: exerciseId,
              position: 0,
            ),
          );
      await database.batch((batch) {
        batch.insertAll(database.setEntries, [
          for (var index = 0; index < 5; index++)
            SetEntriesCompanion.insert(
              sessionExerciseId: linkId,
              setNumber: index + 1,
              reps: const Value(8),
              weightValue: const Value(80),
              unit: const Value(WeightUnit.kg),
            ),
        ]);
      });

      final template = await repository.createDeloadWeek();
      final detail = (await repository.exerciseDetails(template.id)).single;

      expect(template.name, contains('Deload'));
      expect(detail.exercise.id, exerciseId);
      expect(detail.templateExercise.targetSets, 3);
      expect(detail.templateExercise.prescriptionNotes, contains('3–4 reps'));
    },
  );

  test(
    'deload template requires at least one completed workout ever',
    () async {
      await expectLater(
        () => repository.createDeloadWeek(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Complete at least one workout before generating a deload.',
          ),
        ),
      );
    },
  );

  test('program import commits templates and prescriptions together', () async {
    final imported = await repository.importProgram([
      ProgramImportExercise(
        day: 'Push',
        exerciseName: 'Barbell Back Squat',
        exerciseId: exerciseId,
        targetSets: 4,
        minReps: 6,
        maxReps: 8,
        restSeconds: 120,
        rpe: 8,
        notes: 'Controlled',
      ),
      const ProgramImportExercise(
        day: 'Pull',
        exerciseName: 'My custom row',
        targetSets: 3,
        createCustom: true,
      ),
    ]);

    expect(imported.map((template) => template.name), ['Push', 'Pull']);
    final push = (await repository.exerciseDetails(imported.first.id)).single;
    expect(push.templateExercise.targetSets, 4);
    expect(push.templateExercise.minReps, 6);
    expect(push.templateExercise.maxReps, 8);
    expect(push.templateExercise.restSeconds, 120);
    expect(push.templateExercise.prescriptionNotes, 'RPE 8.0 · Controlled');
    final pull = (await repository.exerciseDetails(imported.last.id)).single;
    expect(pull.exercise.isCustom, isTrue);
  });

  test('invalid program import rolls back without partial templates', () async {
    await expectLater(
      repository.importProgram([
        const ProgramImportExercise(
          day: 'Push',
          exerciseName: 'Unmapped',
          targetSets: 3,
        ),
      ]),
      throwsArgumentError,
    );
    expect(await repository.watchAll().first, isEmpty);
  });
}
