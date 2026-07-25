import 'enums.dart';

const double _epsilon = 1e-6;
const int _centsPerUnit = 100;

/// 1000 kg / lb of plates on ONE side. Above this the solver stops allocating a
/// DP table and falls back to greedy — see [_bestStack].
const int _maxStackCents = 100 * _centsPerUnit * 10;
const List<double> _defaultKgPlateSizes = [25, 20, 15, 10, 5, 2.5, 1.25];
const List<double> _defaultLbPlateSizes = [45, 35, 25, 10, 5, 2.5];

double defaultBarWeightFor(WeightUnit unit) =>
    unit == WeightUnit.kg ? 20.0 : 45.0;

List<double> standardPlateSizesFor(WeightUnit unit) =>
    unit == WeightUnit.kg ? _defaultKgPlateSizes : _defaultLbPlateSizes;

class PlateInventory {
  factory PlateInventory({
    double kgBarWeight = 20.0,
    double lbBarWeight = 45.0,
    List<double>? kgPlateSizes,
    List<double>? lbPlateSizes,
    Map<double, int?>? kgPairCounts,
    Map<double, int?>? lbPairCounts,
  }) {
    final normalizedKgPlateSizes = _normalizePlateSizes(
      kgPlateSizes,
      unit: WeightUnit.kg,
    );
    final normalizedLbPlateSizes = _normalizePlateSizes(
      lbPlateSizes,
      unit: WeightUnit.lb,
    );
    return PlateInventory._(
      kgBarWeight: _normalizeBarWeight(kgBarWeight, WeightUnit.kg),
      lbBarWeight: _normalizeBarWeight(lbBarWeight, WeightUnit.lb),
      kgPlateSizes: List.unmodifiable(normalizedKgPlateSizes),
      lbPlateSizes: List.unmodifiable(normalizedLbPlateSizes),
      kgPairCounts: Map.unmodifiable(
        _normalizePairCounts(kgPairCounts, normalizedKgPlateSizes),
      ),
      lbPairCounts: Map.unmodifiable(
        _normalizePairCounts(lbPairCounts, normalizedLbPlateSizes),
      ),
    );
  }

  factory PlateInventory.fromJson(Object? json) {
    if (json is! Map) return PlateInventory();
    final kg = _decodeUnitConfig(json[WeightUnit.kg.name], WeightUnit.kg);
    final lb = _decodeUnitConfig(json[WeightUnit.lb.name], WeightUnit.lb);
    return PlateInventory(
      kgBarWeight: kg.barWeight,
      lbBarWeight: lb.barWeight,
      kgPlateSizes: kg.plateSizes,
      lbPlateSizes: lb.plateSizes,
      kgPairCounts: kg.pairCounts,
      lbPairCounts: lb.pairCounts,
    );
  }

  const PlateInventory._({
    required this.kgBarWeight,
    required this.lbBarWeight,
    required this.kgPlateSizes,
    required this.lbPlateSizes,
    required this.kgPairCounts,
    required this.lbPairCounts,
  });

  final double kgBarWeight;
  final double lbBarWeight;
  final List<double> kgPlateSizes;
  final List<double> lbPlateSizes;
  final Map<double, int?> kgPairCounts;
  final Map<double, int?> lbPairCounts;

  double barWeightFor(WeightUnit unit) =>
      unit == WeightUnit.kg ? kgBarWeight : lbBarWeight;

  List<double> plateSizesFor(WeightUnit unit) =>
      unit == WeightUnit.kg ? kgPlateSizes : lbPlateSizes;

  Map<double, int?> pairCountsFor(WeightUnit unit) =>
      unit == WeightUnit.kg ? kgPairCounts : lbPairCounts;

  int? pairCountFor(WeightUnit unit, double size) =>
      pairCountsFor(unit)[size];

  PlateInventory copyWithUnit({
    required WeightUnit unit,
    double? barWeight,
    List<double>? plateSizes,
    Map<double, int?>? pairCounts,
  }) => switch (unit) {
    WeightUnit.kg => PlateInventory(
      kgBarWeight: barWeight ?? kgBarWeight,
      lbBarWeight: lbBarWeight,
      kgPlateSizes: plateSizes ?? kgPlateSizes,
      lbPlateSizes: lbPlateSizes,
      kgPairCounts: pairCounts ?? kgPairCounts,
      lbPairCounts: lbPairCounts,
    ),
    WeightUnit.lb => PlateInventory(
      kgBarWeight: kgBarWeight,
      lbBarWeight: barWeight ?? lbBarWeight,
      kgPlateSizes: kgPlateSizes,
      lbPlateSizes: plateSizes ?? lbPlateSizes,
      kgPairCounts: kgPairCounts,
      lbPairCounts: pairCounts ?? lbPairCounts,
    ),
  };

  Map<String, dynamic> toJson() => {
    WeightUnit.kg.name: _encodeUnit(
      barWeight: kgBarWeight,
      plateSizes: kgPlateSizes,
      pairCounts: kgPairCounts,
    ),
    WeightUnit.lb.name: _encodeUnit(
      barWeight: lbBarWeight,
      plateSizes: lbPlateSizes,
      pairCounts: lbPairCounts,
    ),
  };

  @override
  bool operator ==(Object other) =>
      other is PlateInventory &&
      other.kgBarWeight == kgBarWeight &&
      other.lbBarWeight == lbBarWeight &&
      _listEquals(other.kgPlateSizes, kgPlateSizes) &&
      _listEquals(other.lbPlateSizes, lbPlateSizes) &&
      _mapEquals(other.kgPairCounts, kgPairCounts) &&
      _mapEquals(other.lbPairCounts, lbPairCounts);

  @override
  int get hashCode => Object.hash(
    kgBarWeight,
    lbBarWeight,
    Object.hashAll(kgPlateSizes),
    Object.hashAll(lbPlateSizes),
    _mapHash(kgPairCounts),
    _mapHash(lbPairCounts),
  );
}

class PlateSolution {
  PlateSolution({
    required List<double> perSidePlates,
    required this.achievedTotal,
    required this.shortfall,
  }) : perSidePlates = List.unmodifiable(perSidePlates);

  final List<double> perSidePlates;
  final double achievedTotal;
  final double shortfall;

  bool get isExact => shortfall.abs() <= _epsilon;
}

PlateSolution solvePlates({
  required double targetTotal,
  required WeightUnit unit,
  required PlateInventory inventory,
  bool perImplement = false,
}) {
  final barWeight = inventory.barWeightFor(unit);
  if (targetTotal <= barWeight + _epsilon) {
    final shortfall = _normalizeDelta(targetTotal - barWeight);
    return PlateSolution(
      perSidePlates: const [],
      achievedTotal: _roundWeight(barWeight),
      shortfall: shortfall,
    );
  }

  final targetStack = perImplement
      ? targetTotal - barWeight
      : (targetTotal - barWeight) / 2;
  final bestPlates = _bestStack(
    // Floor, nudged past float error, so the stack can never exceed the target:
    // (100.001 - 20) / 2 must not buy a hundredth of headroom it did not earn.
    targetCents: (targetStack * _centsPerUnit + _epsilon).floor(),
    plateSizes: inventory.plateSizesFor(unit),
    pairCounts: inventory.pairCountsFor(unit),
  );
  final bestTotal = bestPlates.fold<double>(0, (sum, plate) => sum + plate);

  final achievedTotal = perImplement
      ? barWeight + bestTotal
      : barWeight + (bestTotal * 2);
  return PlateSolution(
    perSidePlates: bestPlates,
    achievedTotal: _roundWeight(achievedTotal),
    shortfall: _normalizeDelta(targetTotal - achievedTotal),
  );
}

double roundToLoadable(
  double target, {
  required WeightUnit unit,
  required PlateInventory inventory,
  bool perImplement = false,
}) => solvePlates(
  targetTotal: target,
  unit: unit,
  inventory: inventory,
  perImplement: perImplement,
).achievedTotal;

/// The heaviest per-side stack that is at most [targetCents], heaviest plate
/// first. Reachability DP over hundredths: linear in the target, where the
/// obvious exhaustive search is exponential. That matters because an *unloadable*
/// target has no early exit — searching a 500 kg target cost ~5s of UI-thread
/// time, and the sheet re-solves on every keystroke.
List<double> _bestStack({
  required int targetCents,
  required List<double> plateSizes,
  required Map<double, int?> pairCounts,
}) {
  if (targetCents <= 0 || plateSizes.isEmpty) return const [];
  // The DP allocates one slot per hundredth, so an absurd typed target would
  // otherwise allocate an absurd list. Past any real barbell load, plain greedy
  // is both sufficient and exact for evenly-divisible inventories.
  if (targetCents > _maxStackCents) {
    return _greedyStack(
      targetCents: targetCents,
      plateSizes: plateSizes,
      pairCounts: pairCounts,
    );
  }

  // Binary-split each size into 0/1 chunks so a single descending knapsack pass
  // covers unlimited and pair-capped inventories with the same code.
  final chunkCents = <int>[];
  final chunkPlate = <double>[];
  final chunkPlates = <int>[];
  for (final plate in plateSizes) {
    final cents = (plate * _centsPerUnit).round();
    if (cents <= 0 || cents > targetCents) continue;
    final fits = targetCents ~/ cents;
    final owned = pairCounts[plate];
    var remaining = owned == null || owned > fits ? fits : owned;
    var step = 1;
    while (remaining > 0) {
      final take = step <= remaining ? step : remaining;
      chunkCents.add(cents * take);
      chunkPlate.add(plate);
      chunkPlates.add(take);
      remaining -= take;
      step *= 2;
    }
  }

  final reachable = List<bool>.filled(targetCents + 1, false);
  reachable[0] = true;
  for (var chunk = 0; chunk < chunkCents.length; chunk++) {
    final weight = chunkCents[chunk];
    // Descending, so each chunk is consumed at most once per stack.
    for (var cents = targetCents; cents >= weight; cents--) {
      if (reachable[cents] || !reachable[cents - weight]) continue;
      reachable[cents] = true;
    }
  }

  var best = targetCents;
  while (best > 0 && !reachable[best]) {
    best--;
  }

  return _layoutExact(
    exactCents: best,
    plateSizes: plateSizes,
    pairCounts: pairCounts,
  );
}

/// Lays out [exactCents] heaviest plate first. The DP above only answers *how
/// much* is loadable; several stacks hit the same total (40 kg a side is both
/// 20+20 and 25+15) and a lifter expects the heaviest-first one. Backtracking is
/// safe here in a way it is not when searching for the total: [exactCents] is
/// known reachable, so the heaviest-first descent terminates on a hit instead of
/// exhausting the space.
List<double> _layoutExact({
  required int exactCents,
  required List<double> plateSizes,
  required Map<double, int?> pairCounts,
}) {
  if (exactCents <= 0) return const [];
  final chosen = <double>[];

  bool fill(int index, int remaining) {
    if (remaining == 0) return true;
    if (index >= plateSizes.length) return false;
    final plate = plateSizes[index];
    final cents = (plate * _centsPerUnit).round();
    if (cents <= 0) return fill(index + 1, remaining);
    final fits = remaining ~/ cents;
    final owned = pairCounts[plate];
    final maxCount = owned == null || owned > fits ? fits : owned;
    for (var count = maxCount; count >= 0; count--) {
      for (var i = 0; i < count; i++) {
        chosen.add(plate);
      }
      if (fill(index + 1, remaining - (cents * count))) return true;
      if (count > 0) chosen.removeRange(chosen.length - count, chosen.length);
    }
    return false;
  }

  fill(0, exactCents);
  return chosen;
}

List<double> _greedyStack({
  required int targetCents,
  required List<double> plateSizes,
  required Map<double, int?> pairCounts,
}) {
  final plates = <double>[];
  var remaining = targetCents;
  for (final plate in plateSizes) {
    final cents = (plate * _centsPerUnit).round();
    if (cents <= 0) continue;
    final fits = remaining ~/ cents;
    final owned = pairCounts[plate];
    final take = owned == null || owned > fits ? fits : owned;
    for (var i = 0; i < take; i++) {
      plates.add(plate);
    }
    remaining -= cents * take;
  }
  return plates;
}

_UnitInventoryConfig _decodeUnitConfig(Object? raw, WeightUnit unit) {
  if (raw is! Map) {
    return _UnitInventoryConfig(
      barWeight: defaultBarWeightFor(unit),
      plateSizes: standardPlateSizesFor(unit),
      pairCounts: const {},
    );
  }

  final plateSizes = _decodePlateSizes(raw['plateSizes'], unit);
  final resolvedPlateSizes = plateSizes.valid
      ? plateSizes.plateSizes
      : standardPlateSizesFor(unit);
  return _UnitInventoryConfig(
    barWeight: _readPositiveDouble(raw['barWeight']) ?? defaultBarWeightFor(unit),
    plateSizes: resolvedPlateSizes,
    pairCounts: _decodePairCounts(raw['pairCounts'], resolvedPlateSizes),
  );
}

Map<String, dynamic> _encodeUnit({
  required double barWeight,
  required List<double> plateSizes,
  required Map<double, int?> pairCounts,
}) => {
  'barWeight': barWeight,
  'plateSizes': plateSizes,
  if (pairCounts.isNotEmpty)
    'pairCounts': {
      for (final entry in pairCounts.entries)
        if (entry.value != null) _formatPlateKey(entry.key): entry.value,
    },
};

List<double> _normalizePlateSizes(List<double>? values, {required WeightUnit unit}) {
  final source = values ?? standardPlateSizesFor(unit);
  if (source.isEmpty) return const [];
  final unique = <double>[];
  for (final value in source) {
    if (value <= 0) continue;
    final rounded = _roundWeight(value);
    if (unique.any((existing) => (existing - rounded).abs() <= _epsilon)) {
      continue;
    }
    unique.add(rounded);
  }
  unique.sort((left, right) => right.compareTo(left));
  if (unique.isNotEmpty || source.isEmpty) return unique;
  return List<double>.from(standardPlateSizesFor(unit));
}

Map<double, int?> _normalizePairCounts(
  Map<double, int?>? raw,
  List<double> plateSizes,
) {
  if (raw == null || raw.isEmpty || plateSizes.isEmpty) return const {};
  final normalized = <double, int?>{};
  for (final size in plateSizes) {
    final count = raw[size];
    if (count == null) continue;
    if (count > 0) normalized[size] = count;
  }
  return normalized;
}

_DecodedPlateSizes _decodePlateSizes(Object? raw, WeightUnit unit) {
  if (raw == null) {
    return const _DecodedPlateSizes(
      valid: false,
      plateSizes: _defaultKgPlateSizes,
    );
  }
  if (raw is! List) {
    return _DecodedPlateSizes(
      valid: false,
      plateSizes: standardPlateSizesFor(unit),
    );
  }
  if (raw.isEmpty) {
    return const _DecodedPlateSizes(valid: true, plateSizes: []);
  }
  final parsed = <double>[];
  for (final value in raw) {
    final parsedValue = _readPositiveDouble(value);
    if (parsedValue != null) parsed.add(parsedValue);
  }
  if (parsed.isEmpty) {
    return _DecodedPlateSizes(
      valid: false,
      plateSizes: standardPlateSizesFor(unit),
    );
  }
  return _DecodedPlateSizes(
    valid: true,
    plateSizes: _normalizePlateSizes(parsed, unit: unit),
  );
}

Map<double, int?> _decodePairCounts(Object? raw, List<double> plateSizes) {
  if (raw is! Map || plateSizes.isEmpty) return const {};
  final normalized = <double, int?>{};
  for (final entry in raw.entries) {
    final size = _readPositiveDouble(entry.key);
    if (size == null ||
        !plateSizes.any((plate) => (plate - size).abs() <= _epsilon)) {
      continue;
    }
    final count = _readPositiveInt(entry.value);
    if (count != null) normalized[_roundWeight(size)] = count;
  }
  return normalized;
}

double _normalizeBarWeight(double value, WeightUnit unit) {
  if (value <= 0) return defaultBarWeightFor(unit);
  return _roundWeight(value);
}

double _normalizeDelta(double value) {
  if (value.abs() <= _epsilon) return 0.0;
  return _roundWeight(value);
}

double _roundWeight(double value) => (value * 100).roundToDouble() / 100;

double? _readPositiveDouble(Object? value) {
  if (value is num && value.toDouble() > 0) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value.trim());
    if (parsed != null && parsed > 0) return parsed;
  }
  return null;
}

int? _readPositiveInt(Object? value) {
  if (value is int && value > 0) return value;
  if (value is num && value > 0) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null && parsed > 0) return parsed;
  }
  return null;
}

String _formatPlateKey(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

bool _listEquals(List<double> left, List<double> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

bool _mapEquals(Map<double, int?> left, Map<double, int?> right) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) return false;
  }
  return true;
}

int _mapHash(Map<double, int?> map) {
  final sorted = map.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  return Object.hashAll([
    for (final entry in sorted) entry.key,
    for (final entry in sorted) entry.value,
  ]);
}

class _UnitInventoryConfig {
  const _UnitInventoryConfig({
    required this.barWeight,
    required this.plateSizes,
    required this.pairCounts,
  });

  final double barWeight;
  final List<double> plateSizes;
  final Map<double, int?> pairCounts;
}

class _DecodedPlateSizes {
  const _DecodedPlateSizes({required this.valid, required this.plateSizes});

  final bool valid;
  final List<double> plateSizes;
}
