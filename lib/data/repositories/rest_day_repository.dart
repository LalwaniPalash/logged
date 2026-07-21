import 'package:drift/drift.dart';

import '../../core/domain/streak.dart';
import '../database/app_database.dart';

class RestDayRepository {
  const RestDayRepository(this._database);

  final AppDatabase _database;

  Stream<List<DateTime>> watch() => _database
      .select(_database.restDays)
      .watch()
      .map((rows) => rows.map((row) => dateOnly(row.date)).toList());

  Future<void> log(DateTime date, {String? note}) => _database
      .into(_database.restDays)
      .insert(
        RestDaysCompanion.insert(date: dateOnly(date), note: Value(note)),
        mode: InsertMode.insertOrIgnore,
      );

  Future<void> remove(DateTime date) => (_database.delete(
    _database.restDays,
  )..where((row) => row.date.equals(dateOnly(date)))).go();

  Future<bool> isLogged(DateTime date) async {
    final row = await (_database.select(
      _database.restDays,
    )..where((r) => r.date.equals(dateOnly(date)))).getSingleOrNull();
    return row != null;
  }
}
