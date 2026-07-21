import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/data/repositories/bodyweight_repository.dart';

void main() {
  test('upserts dated bodyweight entries and watches newest first', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = BodyweightRepository(database);

    await repository.upsert(
      date: DateTime(2026, 7, 1, 12),
      value: 80,
      unit: WeightUnit.kg,
    );
    await repository.upsert(
      date: DateTime(2026, 7, 20, 12),
      value: 178,
      unit: WeightUnit.lb,
    );
    await repository.upsert(
      date: DateTime(2026, 7, 1, 18),
      value: 81,
      unit: WeightUnit.kg,
    );

    final entries = await repository.all();
    expect(entries, hasLength(2));
    expect(entries.first.date, DateTime(2026, 7, 20));
    expect(entries.last.date, DateTime(2026, 7, 1));
    expect(entries.last.value, 81);

    await repository.delete(entries.last.id);
    expect(await repository.all(), hasLength(1));
  });
}
