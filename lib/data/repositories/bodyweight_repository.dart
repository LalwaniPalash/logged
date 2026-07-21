import 'package:drift/drift.dart';

import '../../core/domain/enums.dart';
import '../database/app_database.dart';

class BodyweightRepository {
  const BodyweightRepository(this._database);

  final AppDatabase _database;

  Stream<List<BodyweightEntry>> watch() => (_database.select(
    _database.bodyweightEntries,
  )..orderBy([(row) => OrderingTerm.desc(row.date)])).watch();

  Future<List<BodyweightEntry>> all() => (_database.select(
    _database.bodyweightEntries,
  )..orderBy([(row) => OrderingTerm.desc(row.date)])).get();

  Future<BodyweightEntry?> latestOnOrBefore(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return (_database.select(_database.bodyweightEntries)
          ..where((row) => row.date.isSmallerOrEqualValue(day))
          ..orderBy([(row) => OrderingTerm.desc(row.date)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> upsert({
    required DateTime date,
    required double value,
    required WeightUnit unit,
  }) {
    final day = DateTime(date.year, date.month, date.day);
    return _database.transaction(() async {
      await (_database.delete(
        _database.bodyweightEntries,
      )..where((row) => row.date.equals(day))).go();
      await _database
          .into(_database.bodyweightEntries)
          .insert(
            BodyweightEntriesCompanion.insert(
              date: day,
              value: value,
              unit: unit,
            ),
          );
    });
  }

  Future<void> delete(int id) => (_database.delete(
    _database.bodyweightEntries,
  )..where((row) => row.id.equals(id))).go();
}
