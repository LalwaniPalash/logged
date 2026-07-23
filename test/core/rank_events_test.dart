import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/muscle.dart';
import 'package:logged/core/domain/muscle_progress.dart';
import 'package:logged/core/domain/rank_events.dart';

void main() {
  test('a rise fires once while a decrease never fires', () {
    final before = {MuscleId.lats: MuscleRank.bronze};
    final after = {MuscleId.lats: MuscleRank.silver};
    expect(detectRankUps(previous: before, current: after), hasLength(1));
    expect(detectRankUps(previous: after, current: after), isEmpty);
    expect(detectRankUps(previous: after, current: before), isEmpty);
  });
}
