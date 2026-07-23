// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ExercisesTable extends Exercises
    with TableInfo<$ExercisesTable, Exercise> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExercisesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<ExerciseCategory, String>
  category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<ExerciseCategory>($ExercisesTable.$convertercategory);
  static const VerificationMeta _muscleGroupMeta = const VerificationMeta(
    'muscleGroup',
  );
  @override
  late final GeneratedColumn<String> muscleGroup = GeneratedColumn<String>(
    'muscle_group',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _primaryMusclesMeta = const VerificationMeta(
    'primaryMuscles',
  );
  @override
  late final GeneratedColumn<String> primaryMuscles = GeneratedColumn<String>(
    'primary_muscles',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _secondaryMusclesMeta = const VerificationMeta(
    'secondaryMuscles',
  );
  @override
  late final GeneratedColumn<String> secondaryMuscles = GeneratedColumn<String>(
    'secondary_muscles',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<WeightUnit, String> defaultUnit =
      GeneratedColumn<String>(
        'default_unit',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('kg'),
      ).withConverter<WeightUnit>($ExercisesTable.$converterdefaultUnit);
  @override
  late final GeneratedColumnWithTypeConverter<WeightEntry, String> weightEntry =
      GeneratedColumn<String>(
        'weight_entry',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('total'),
      ).withConverter<WeightEntry>($ExercisesTable.$converterweightEntry);
  @override
  late final GeneratedColumnWithTypeConverter<LoadingMode, String>
  preferredLoadingMode = GeneratedColumn<String>(
    'preferred_loading_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('external'),
  ).withConverter<LoadingMode>($ExercisesTable.$converterpreferredLoadingMode);
  static const VerificationMeta _bodyweightFactorMeta = const VerificationMeta(
    'bodyweightFactor',
  );
  @override
  late final GeneratedColumn<double> bodyweightFactor = GeneratedColumn<double>(
    'bodyweight_factor',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  static const VerificationMeta _videoUrlMeta = const VerificationMeta(
    'videoUrl',
  );
  @override
  late final GeneratedColumn<String> videoUrl = GeneratedColumn<String>(
    'video_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isCustomMeta = const VerificationMeta(
    'isCustom',
  );
  @override
  late final GeneratedColumn<bool> isCustom = GeneratedColumn<bool>(
    'is_custom',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_custom" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    category,
    muscleGroup,
    primaryMuscles,
    secondaryMuscles,
    defaultUnit,
    weightEntry,
    preferredLoadingMode,
    bodyweightFactor,
    videoUrl,
    isCustom,
    isArchived,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercises';
  @override
  VerificationContext validateIntegrity(
    Insertable<Exercise> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('muscle_group')) {
      context.handle(
        _muscleGroupMeta,
        muscleGroup.isAcceptableOrUnknown(
          data['muscle_group']!,
          _muscleGroupMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_muscleGroupMeta);
    }
    if (data.containsKey('primary_muscles')) {
      context.handle(
        _primaryMusclesMeta,
        primaryMuscles.isAcceptableOrUnknown(
          data['primary_muscles']!,
          _primaryMusclesMeta,
        ),
      );
    }
    if (data.containsKey('secondary_muscles')) {
      context.handle(
        _secondaryMusclesMeta,
        secondaryMuscles.isAcceptableOrUnknown(
          data['secondary_muscles']!,
          _secondaryMusclesMeta,
        ),
      );
    }
    if (data.containsKey('bodyweight_factor')) {
      context.handle(
        _bodyweightFactorMeta,
        bodyweightFactor.isAcceptableOrUnknown(
          data['bodyweight_factor']!,
          _bodyweightFactorMeta,
        ),
      );
    }
    if (data.containsKey('video_url')) {
      context.handle(
        _videoUrlMeta,
        videoUrl.isAcceptableOrUnknown(data['video_url']!, _videoUrlMeta),
      );
    }
    if (data.containsKey('is_custom')) {
      context.handle(
        _isCustomMeta,
        isCustom.isAcceptableOrUnknown(data['is_custom']!, _isCustomMeta),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Exercise map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Exercise(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      category: $ExercisesTable.$convertercategory.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}category'],
        )!,
      ),
      muscleGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}muscle_group'],
      )!,
      primaryMuscles: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}primary_muscles'],
      )!,
      secondaryMuscles: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}secondary_muscles'],
      )!,
      defaultUnit: $ExercisesTable.$converterdefaultUnit.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}default_unit'],
        )!,
      ),
      weightEntry: $ExercisesTable.$converterweightEntry.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}weight_entry'],
        )!,
      ),
      preferredLoadingMode: $ExercisesTable.$converterpreferredLoadingMode
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}preferred_loading_mode'],
            )!,
          ),
      bodyweightFactor: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bodyweight_factor'],
      )!,
      videoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_url'],
      ),
      isCustom: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_custom'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ExercisesTable createAlias(String alias) {
    return $ExercisesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ExerciseCategory, String, String>
  $convertercategory = const EnumNameConverter<ExerciseCategory>(
    ExerciseCategory.values,
  );
  static JsonTypeConverter2<WeightUnit, String, String> $converterdefaultUnit =
      const EnumNameConverter<WeightUnit>(WeightUnit.values);
  static JsonTypeConverter2<WeightEntry, String, String> $converterweightEntry =
      const EnumNameConverter<WeightEntry>(WeightEntry.values);
  static JsonTypeConverter2<LoadingMode, String, String>
  $converterpreferredLoadingMode = const EnumNameConverter<LoadingMode>(
    LoadingMode.values,
  );
}

class Exercise extends DataClass implements Insertable<Exercise> {
  final int id;
  final String name;
  final ExerciseCategory category;
  final String muscleGroup;
  final String primaryMuscles;
  final String secondaryMuscles;
  final WeightUnit defaultUnit;
  final WeightEntry weightEntry;
  final LoadingMode preferredLoadingMode;
  final double bodyweightFactor;
  final String? videoUrl;
  final bool isCustom;
  final bool isArchived;
  final DateTime createdAt;
  const Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.muscleGroup,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.defaultUnit,
    required this.weightEntry,
    required this.preferredLoadingMode,
    required this.bodyweightFactor,
    this.videoUrl,
    required this.isCustom,
    required this.isArchived,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    {
      map['category'] = Variable<String>(
        $ExercisesTable.$convertercategory.toSql(category),
      );
    }
    map['muscle_group'] = Variable<String>(muscleGroup);
    map['primary_muscles'] = Variable<String>(primaryMuscles);
    map['secondary_muscles'] = Variable<String>(secondaryMuscles);
    {
      map['default_unit'] = Variable<String>(
        $ExercisesTable.$converterdefaultUnit.toSql(defaultUnit),
      );
    }
    {
      map['weight_entry'] = Variable<String>(
        $ExercisesTable.$converterweightEntry.toSql(weightEntry),
      );
    }
    {
      map['preferred_loading_mode'] = Variable<String>(
        $ExercisesTable.$converterpreferredLoadingMode.toSql(
          preferredLoadingMode,
        ),
      );
    }
    map['bodyweight_factor'] = Variable<double>(bodyweightFactor);
    if (!nullToAbsent || videoUrl != null) {
      map['video_url'] = Variable<String>(videoUrl);
    }
    map['is_custom'] = Variable<bool>(isCustom);
    map['is_archived'] = Variable<bool>(isArchived);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ExercisesCompanion toCompanion(bool nullToAbsent) {
    return ExercisesCompanion(
      id: Value(id),
      name: Value(name),
      category: Value(category),
      muscleGroup: Value(muscleGroup),
      primaryMuscles: Value(primaryMuscles),
      secondaryMuscles: Value(secondaryMuscles),
      defaultUnit: Value(defaultUnit),
      weightEntry: Value(weightEntry),
      preferredLoadingMode: Value(preferredLoadingMode),
      bodyweightFactor: Value(bodyweightFactor),
      videoUrl: videoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(videoUrl),
      isCustom: Value(isCustom),
      isArchived: Value(isArchived),
      createdAt: Value(createdAt),
    );
  }

  factory Exercise.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Exercise(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      category: $ExercisesTable.$convertercategory.fromJson(
        serializer.fromJson<String>(json['category']),
      ),
      muscleGroup: serializer.fromJson<String>(json['muscleGroup']),
      primaryMuscles: serializer.fromJson<String>(json['primaryMuscles']),
      secondaryMuscles: serializer.fromJson<String>(json['secondaryMuscles']),
      defaultUnit: $ExercisesTable.$converterdefaultUnit.fromJson(
        serializer.fromJson<String>(json['defaultUnit']),
      ),
      weightEntry: $ExercisesTable.$converterweightEntry.fromJson(
        serializer.fromJson<String>(json['weightEntry']),
      ),
      preferredLoadingMode: $ExercisesTable.$converterpreferredLoadingMode
          .fromJson(serializer.fromJson<String>(json['preferredLoadingMode'])),
      bodyweightFactor: serializer.fromJson<double>(json['bodyweightFactor']),
      videoUrl: serializer.fromJson<String?>(json['videoUrl']),
      isCustom: serializer.fromJson<bool>(json['isCustom']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String>(
        $ExercisesTable.$convertercategory.toJson(category),
      ),
      'muscleGroup': serializer.toJson<String>(muscleGroup),
      'primaryMuscles': serializer.toJson<String>(primaryMuscles),
      'secondaryMuscles': serializer.toJson<String>(secondaryMuscles),
      'defaultUnit': serializer.toJson<String>(
        $ExercisesTable.$converterdefaultUnit.toJson(defaultUnit),
      ),
      'weightEntry': serializer.toJson<String>(
        $ExercisesTable.$converterweightEntry.toJson(weightEntry),
      ),
      'preferredLoadingMode': serializer.toJson<String>(
        $ExercisesTable.$converterpreferredLoadingMode.toJson(
          preferredLoadingMode,
        ),
      ),
      'bodyweightFactor': serializer.toJson<double>(bodyweightFactor),
      'videoUrl': serializer.toJson<String?>(videoUrl),
      'isCustom': serializer.toJson<bool>(isCustom),
      'isArchived': serializer.toJson<bool>(isArchived),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Exercise copyWith({
    int? id,
    String? name,
    ExerciseCategory? category,
    String? muscleGroup,
    String? primaryMuscles,
    String? secondaryMuscles,
    WeightUnit? defaultUnit,
    WeightEntry? weightEntry,
    LoadingMode? preferredLoadingMode,
    double? bodyweightFactor,
    Value<String?> videoUrl = const Value.absent(),
    bool? isCustom,
    bool? isArchived,
    DateTime? createdAt,
  }) => Exercise(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    muscleGroup: muscleGroup ?? this.muscleGroup,
    primaryMuscles: primaryMuscles ?? this.primaryMuscles,
    secondaryMuscles: secondaryMuscles ?? this.secondaryMuscles,
    defaultUnit: defaultUnit ?? this.defaultUnit,
    weightEntry: weightEntry ?? this.weightEntry,
    preferredLoadingMode: preferredLoadingMode ?? this.preferredLoadingMode,
    bodyweightFactor: bodyweightFactor ?? this.bodyweightFactor,
    videoUrl: videoUrl.present ? videoUrl.value : this.videoUrl,
    isCustom: isCustom ?? this.isCustom,
    isArchived: isArchived ?? this.isArchived,
    createdAt: createdAt ?? this.createdAt,
  );
  Exercise copyWithCompanion(ExercisesCompanion data) {
    return Exercise(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      muscleGroup: data.muscleGroup.present
          ? data.muscleGroup.value
          : this.muscleGroup,
      primaryMuscles: data.primaryMuscles.present
          ? data.primaryMuscles.value
          : this.primaryMuscles,
      secondaryMuscles: data.secondaryMuscles.present
          ? data.secondaryMuscles.value
          : this.secondaryMuscles,
      defaultUnit: data.defaultUnit.present
          ? data.defaultUnit.value
          : this.defaultUnit,
      weightEntry: data.weightEntry.present
          ? data.weightEntry.value
          : this.weightEntry,
      preferredLoadingMode: data.preferredLoadingMode.present
          ? data.preferredLoadingMode.value
          : this.preferredLoadingMode,
      bodyweightFactor: data.bodyweightFactor.present
          ? data.bodyweightFactor.value
          : this.bodyweightFactor,
      videoUrl: data.videoUrl.present ? data.videoUrl.value : this.videoUrl,
      isCustom: data.isCustom.present ? data.isCustom.value : this.isCustom,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Exercise(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('muscleGroup: $muscleGroup, ')
          ..write('primaryMuscles: $primaryMuscles, ')
          ..write('secondaryMuscles: $secondaryMuscles, ')
          ..write('defaultUnit: $defaultUnit, ')
          ..write('weightEntry: $weightEntry, ')
          ..write('preferredLoadingMode: $preferredLoadingMode, ')
          ..write('bodyweightFactor: $bodyweightFactor, ')
          ..write('videoUrl: $videoUrl, ')
          ..write('isCustom: $isCustom, ')
          ..write('isArchived: $isArchived, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    category,
    muscleGroup,
    primaryMuscles,
    secondaryMuscles,
    defaultUnit,
    weightEntry,
    preferredLoadingMode,
    bodyweightFactor,
    videoUrl,
    isCustom,
    isArchived,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Exercise &&
          other.id == this.id &&
          other.name == this.name &&
          other.category == this.category &&
          other.muscleGroup == this.muscleGroup &&
          other.primaryMuscles == this.primaryMuscles &&
          other.secondaryMuscles == this.secondaryMuscles &&
          other.defaultUnit == this.defaultUnit &&
          other.weightEntry == this.weightEntry &&
          other.preferredLoadingMode == this.preferredLoadingMode &&
          other.bodyweightFactor == this.bodyweightFactor &&
          other.videoUrl == this.videoUrl &&
          other.isCustom == this.isCustom &&
          other.isArchived == this.isArchived &&
          other.createdAt == this.createdAt);
}

class ExercisesCompanion extends UpdateCompanion<Exercise> {
  final Value<int> id;
  final Value<String> name;
  final Value<ExerciseCategory> category;
  final Value<String> muscleGroup;
  final Value<String> primaryMuscles;
  final Value<String> secondaryMuscles;
  final Value<WeightUnit> defaultUnit;
  final Value<WeightEntry> weightEntry;
  final Value<LoadingMode> preferredLoadingMode;
  final Value<double> bodyweightFactor;
  final Value<String?> videoUrl;
  final Value<bool> isCustom;
  final Value<bool> isArchived;
  final Value<DateTime> createdAt;
  const ExercisesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.muscleGroup = const Value.absent(),
    this.primaryMuscles = const Value.absent(),
    this.secondaryMuscles = const Value.absent(),
    this.defaultUnit = const Value.absent(),
    this.weightEntry = const Value.absent(),
    this.preferredLoadingMode = const Value.absent(),
    this.bodyweightFactor = const Value.absent(),
    this.videoUrl = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ExercisesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required ExerciseCategory category,
    required String muscleGroup,
    this.primaryMuscles = const Value.absent(),
    this.secondaryMuscles = const Value.absent(),
    this.defaultUnit = const Value.absent(),
    this.weightEntry = const Value.absent(),
    this.preferredLoadingMode = const Value.absent(),
    this.bodyweightFactor = const Value.absent(),
    this.videoUrl = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name),
       category = Value(category),
       muscleGroup = Value(muscleGroup);
  static Insertable<Exercise> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? category,
    Expression<String>? muscleGroup,
    Expression<String>? primaryMuscles,
    Expression<String>? secondaryMuscles,
    Expression<String>? defaultUnit,
    Expression<String>? weightEntry,
    Expression<String>? preferredLoadingMode,
    Expression<double>? bodyweightFactor,
    Expression<String>? videoUrl,
    Expression<bool>? isCustom,
    Expression<bool>? isArchived,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (muscleGroup != null) 'muscle_group': muscleGroup,
      if (primaryMuscles != null) 'primary_muscles': primaryMuscles,
      if (secondaryMuscles != null) 'secondary_muscles': secondaryMuscles,
      if (defaultUnit != null) 'default_unit': defaultUnit,
      if (weightEntry != null) 'weight_entry': weightEntry,
      if (preferredLoadingMode != null)
        'preferred_loading_mode': preferredLoadingMode,
      if (bodyweightFactor != null) 'bodyweight_factor': bodyweightFactor,
      if (videoUrl != null) 'video_url': videoUrl,
      if (isCustom != null) 'is_custom': isCustom,
      if (isArchived != null) 'is_archived': isArchived,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ExercisesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<ExerciseCategory>? category,
    Value<String>? muscleGroup,
    Value<String>? primaryMuscles,
    Value<String>? secondaryMuscles,
    Value<WeightUnit>? defaultUnit,
    Value<WeightEntry>? weightEntry,
    Value<LoadingMode>? preferredLoadingMode,
    Value<double>? bodyweightFactor,
    Value<String?>? videoUrl,
    Value<bool>? isCustom,
    Value<bool>? isArchived,
    Value<DateTime>? createdAt,
  }) {
    return ExercisesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      primaryMuscles: primaryMuscles ?? this.primaryMuscles,
      secondaryMuscles: secondaryMuscles ?? this.secondaryMuscles,
      defaultUnit: defaultUnit ?? this.defaultUnit,
      weightEntry: weightEntry ?? this.weightEntry,
      preferredLoadingMode: preferredLoadingMode ?? this.preferredLoadingMode,
      bodyweightFactor: bodyweightFactor ?? this.bodyweightFactor,
      videoUrl: videoUrl ?? this.videoUrl,
      isCustom: isCustom ?? this.isCustom,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(
        $ExercisesTable.$convertercategory.toSql(category.value),
      );
    }
    if (muscleGroup.present) {
      map['muscle_group'] = Variable<String>(muscleGroup.value);
    }
    if (primaryMuscles.present) {
      map['primary_muscles'] = Variable<String>(primaryMuscles.value);
    }
    if (secondaryMuscles.present) {
      map['secondary_muscles'] = Variable<String>(secondaryMuscles.value);
    }
    if (defaultUnit.present) {
      map['default_unit'] = Variable<String>(
        $ExercisesTable.$converterdefaultUnit.toSql(defaultUnit.value),
      );
    }
    if (weightEntry.present) {
      map['weight_entry'] = Variable<String>(
        $ExercisesTable.$converterweightEntry.toSql(weightEntry.value),
      );
    }
    if (preferredLoadingMode.present) {
      map['preferred_loading_mode'] = Variable<String>(
        $ExercisesTable.$converterpreferredLoadingMode.toSql(
          preferredLoadingMode.value,
        ),
      );
    }
    if (bodyweightFactor.present) {
      map['bodyweight_factor'] = Variable<double>(bodyweightFactor.value);
    }
    if (videoUrl.present) {
      map['video_url'] = Variable<String>(videoUrl.value);
    }
    if (isCustom.present) {
      map['is_custom'] = Variable<bool>(isCustom.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExercisesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('muscleGroup: $muscleGroup, ')
          ..write('primaryMuscles: $primaryMuscles, ')
          ..write('secondaryMuscles: $secondaryMuscles, ')
          ..write('defaultUnit: $defaultUnit, ')
          ..write('weightEntry: $weightEntry, ')
          ..write('preferredLoadingMode: $preferredLoadingMode, ')
          ..write('bodyweightFactor: $bodyweightFactor, ')
          ..write('videoUrl: $videoUrl, ')
          ..write('isCustom: $isCustom, ')
          ..write('isArchived: $isArchived, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $TemplatesTable extends Templates
    with TableInfo<$TemplatesTable, Template> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, position, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<Template> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Template map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Template(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TemplatesTable createAlias(String alias) {
    return $TemplatesTable(attachedDatabase, alias);
  }
}

class Template extends DataClass implements Insertable<Template> {
  final int id;
  final String name;
  final int position;
  final DateTime createdAt;
  const Template({
    required this.id,
    required this.name,
    required this.position,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['position'] = Variable<int>(position);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TemplatesCompanion toCompanion(bool nullToAbsent) {
    return TemplatesCompanion(
      id: Value(id),
      name: Value(name),
      position: Value(position),
      createdAt: Value(createdAt),
    );
  }

  factory Template.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Template(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      position: serializer.fromJson<int>(json['position']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'position': serializer.toJson<int>(position),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Template copyWith({
    int? id,
    String? name,
    int? position,
    DateTime? createdAt,
  }) => Template(
    id: id ?? this.id,
    name: name ?? this.name,
    position: position ?? this.position,
    createdAt: createdAt ?? this.createdAt,
  );
  Template copyWithCompanion(TemplatesCompanion data) {
    return Template(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      position: data.position.present ? data.position.value : this.position,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Template(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('position: $position, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, position, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Template &&
          other.id == this.id &&
          other.name == this.name &&
          other.position == this.position &&
          other.createdAt == this.createdAt);
}

class TemplatesCompanion extends UpdateCompanion<Template> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> position;
  final Value<DateTime> createdAt;
  const TemplatesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.position = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TemplatesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int position,
    this.createdAt = const Value.absent(),
  }) : name = Value(name),
       position = Value(position);
  static Insertable<Template> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? position,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (position != null) 'position': position,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TemplatesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? position,
    Value<DateTime>? createdAt,
  }) {
    return TemplatesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TemplatesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('position: $position, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $TemplateExercisesTable extends TemplateExercises
    with TableInfo<$TemplateExercisesTable, TemplateExercise> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TemplateExercisesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _templateIdMeta = const VerificationMeta(
    'templateId',
  );
  @override
  late final GeneratedColumn<int> templateId = GeneratedColumn<int>(
    'template_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES templates (id)',
    ),
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<int> exerciseId = GeneratedColumn<int>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES exercises (id)',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetSetsMeta = const VerificationMeta(
    'targetSets',
  );
  @override
  late final GeneratedColumn<int> targetSets = GeneratedColumn<int>(
    'target_sets',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sidesPerSetMeta = const VerificationMeta(
    'sidesPerSet',
  );
  @override
  late final GeneratedColumn<int> sidesPerSet = GeneratedColumn<int>(
    'sides_per_set',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _minRepsMeta = const VerificationMeta(
    'minReps',
  );
  @override
  late final GeneratedColumn<int> minReps = GeneratedColumn<int>(
    'min_reps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxRepsMeta = const VerificationMeta(
    'maxReps',
  );
  @override
  late final GeneratedColumn<int> maxReps = GeneratedColumn<int>(
    'max_reps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetDurationSecMeta = const VerificationMeta(
    'targetDurationSec',
  );
  @override
  late final GeneratedColumn<int> targetDurationSec = GeneratedColumn<int>(
    'target_duration_sec',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetDistanceMetersMeta =
      const VerificationMeta('targetDistanceMeters');
  @override
  late final GeneratedColumn<double> targetDistanceMeters =
      GeneratedColumn<double>(
        'target_distance_meters',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _restSecondsMeta = const VerificationMeta(
    'restSeconds',
  );
  @override
  late final GeneratedColumn<int> restSeconds = GeneratedColumn<int>(
    'rest_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _eccentricSecMeta = const VerificationMeta(
    'eccentricSec',
  );
  @override
  late final GeneratedColumn<int> eccentricSec = GeneratedColumn<int>(
    'eccentric_sec',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bottomPauseSecMeta = const VerificationMeta(
    'bottomPauseSec',
  );
  @override
  late final GeneratedColumn<int> bottomPauseSec = GeneratedColumn<int>(
    'bottom_pause_sec',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _concentricSecMeta = const VerificationMeta(
    'concentricSec',
  );
  @override
  late final GeneratedColumn<int> concentricSec = GeneratedColumn<int>(
    'concentric_sec',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _topPauseSecMeta = const VerificationMeta(
    'topPauseSec',
  );
  @override
  late final GeneratedColumn<int> topPauseSec = GeneratedColumn<int>(
    'top_pause_sec',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _prescriptionNotesMeta = const VerificationMeta(
    'prescriptionNotes',
  );
  @override
  late final GeneratedColumn<String> prescriptionNotes =
      GeneratedColumn<String>(
        'prescription_notes',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _formUrlMeta = const VerificationMeta(
    'formUrl',
  );
  @override
  late final GeneratedColumn<String> formUrl = GeneratedColumn<String>(
    'form_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    templateId,
    exerciseId,
    position,
    targetSets,
    sidesPerSet,
    minReps,
    maxReps,
    targetDurationSec,
    targetDistanceMeters,
    restSeconds,
    eccentricSec,
    bottomPauseSec,
    concentricSec,
    topPauseSec,
    prescriptionNotes,
    formUrl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'template_exercises';
  @override
  VerificationContext validateIntegrity(
    Insertable<TemplateExercise> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('template_id')) {
      context.handle(
        _templateIdMeta,
        templateId.isAcceptableOrUnknown(data['template_id']!, _templateIdMeta),
      );
    } else if (isInserting) {
      context.missing(_templateIdMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('target_sets')) {
      context.handle(
        _targetSetsMeta,
        targetSets.isAcceptableOrUnknown(data['target_sets']!, _targetSetsMeta),
      );
    }
    if (data.containsKey('sides_per_set')) {
      context.handle(
        _sidesPerSetMeta,
        sidesPerSet.isAcceptableOrUnknown(
          data['sides_per_set']!,
          _sidesPerSetMeta,
        ),
      );
    }
    if (data.containsKey('min_reps')) {
      context.handle(
        _minRepsMeta,
        minReps.isAcceptableOrUnknown(data['min_reps']!, _minRepsMeta),
      );
    }
    if (data.containsKey('max_reps')) {
      context.handle(
        _maxRepsMeta,
        maxReps.isAcceptableOrUnknown(data['max_reps']!, _maxRepsMeta),
      );
    }
    if (data.containsKey('target_duration_sec')) {
      context.handle(
        _targetDurationSecMeta,
        targetDurationSec.isAcceptableOrUnknown(
          data['target_duration_sec']!,
          _targetDurationSecMeta,
        ),
      );
    }
    if (data.containsKey('target_distance_meters')) {
      context.handle(
        _targetDistanceMetersMeta,
        targetDistanceMeters.isAcceptableOrUnknown(
          data['target_distance_meters']!,
          _targetDistanceMetersMeta,
        ),
      );
    }
    if (data.containsKey('rest_seconds')) {
      context.handle(
        _restSecondsMeta,
        restSeconds.isAcceptableOrUnknown(
          data['rest_seconds']!,
          _restSecondsMeta,
        ),
      );
    }
    if (data.containsKey('eccentric_sec')) {
      context.handle(
        _eccentricSecMeta,
        eccentricSec.isAcceptableOrUnknown(
          data['eccentric_sec']!,
          _eccentricSecMeta,
        ),
      );
    }
    if (data.containsKey('bottom_pause_sec')) {
      context.handle(
        _bottomPauseSecMeta,
        bottomPauseSec.isAcceptableOrUnknown(
          data['bottom_pause_sec']!,
          _bottomPauseSecMeta,
        ),
      );
    }
    if (data.containsKey('concentric_sec')) {
      context.handle(
        _concentricSecMeta,
        concentricSec.isAcceptableOrUnknown(
          data['concentric_sec']!,
          _concentricSecMeta,
        ),
      );
    }
    if (data.containsKey('top_pause_sec')) {
      context.handle(
        _topPauseSecMeta,
        topPauseSec.isAcceptableOrUnknown(
          data['top_pause_sec']!,
          _topPauseSecMeta,
        ),
      );
    }
    if (data.containsKey('prescription_notes')) {
      context.handle(
        _prescriptionNotesMeta,
        prescriptionNotes.isAcceptableOrUnknown(
          data['prescription_notes']!,
          _prescriptionNotesMeta,
        ),
      );
    }
    if (data.containsKey('form_url')) {
      context.handle(
        _formUrlMeta,
        formUrl.isAcceptableOrUnknown(data['form_url']!, _formUrlMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TemplateExercise map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TemplateExercise(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      templateId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}template_id'],
      )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}exercise_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      targetSets: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_sets'],
      ),
      sidesPerSet: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sides_per_set'],
      ),
      minReps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}min_reps'],
      ),
      maxReps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_reps'],
      ),
      targetDurationSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_duration_sec'],
      ),
      targetDistanceMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}target_distance_meters'],
      ),
      restSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rest_seconds'],
      ),
      eccentricSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}eccentric_sec'],
      ),
      bottomPauseSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bottom_pause_sec'],
      ),
      concentricSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}concentric_sec'],
      ),
      topPauseSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}top_pause_sec'],
      ),
      prescriptionNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prescription_notes'],
      ),
      formUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}form_url'],
      ),
    );
  }

  @override
  $TemplateExercisesTable createAlias(String alias) {
    return $TemplateExercisesTable(attachedDatabase, alias);
  }
}

class TemplateExercise extends DataClass
    implements Insertable<TemplateExercise> {
  final int id;
  final int templateId;
  final int exerciseId;
  final int position;
  final int? targetSets;
  final int? sidesPerSet;
  final int? minReps;
  final int? maxReps;
  final int? targetDurationSec;
  final double? targetDistanceMeters;
  final int? restSeconds;
  final int? eccentricSec;
  final int? bottomPauseSec;
  final int? concentricSec;
  final int? topPauseSec;
  final String? prescriptionNotes;
  final String? formUrl;
  const TemplateExercise({
    required this.id,
    required this.templateId,
    required this.exerciseId,
    required this.position,
    this.targetSets,
    this.sidesPerSet,
    this.minReps,
    this.maxReps,
    this.targetDurationSec,
    this.targetDistanceMeters,
    this.restSeconds,
    this.eccentricSec,
    this.bottomPauseSec,
    this.concentricSec,
    this.topPauseSec,
    this.prescriptionNotes,
    this.formUrl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['template_id'] = Variable<int>(templateId);
    map['exercise_id'] = Variable<int>(exerciseId);
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || targetSets != null) {
      map['target_sets'] = Variable<int>(targetSets);
    }
    if (!nullToAbsent || sidesPerSet != null) {
      map['sides_per_set'] = Variable<int>(sidesPerSet);
    }
    if (!nullToAbsent || minReps != null) {
      map['min_reps'] = Variable<int>(minReps);
    }
    if (!nullToAbsent || maxReps != null) {
      map['max_reps'] = Variable<int>(maxReps);
    }
    if (!nullToAbsent || targetDurationSec != null) {
      map['target_duration_sec'] = Variable<int>(targetDurationSec);
    }
    if (!nullToAbsent || targetDistanceMeters != null) {
      map['target_distance_meters'] = Variable<double>(targetDistanceMeters);
    }
    if (!nullToAbsent || restSeconds != null) {
      map['rest_seconds'] = Variable<int>(restSeconds);
    }
    if (!nullToAbsent || eccentricSec != null) {
      map['eccentric_sec'] = Variable<int>(eccentricSec);
    }
    if (!nullToAbsent || bottomPauseSec != null) {
      map['bottom_pause_sec'] = Variable<int>(bottomPauseSec);
    }
    if (!nullToAbsent || concentricSec != null) {
      map['concentric_sec'] = Variable<int>(concentricSec);
    }
    if (!nullToAbsent || topPauseSec != null) {
      map['top_pause_sec'] = Variable<int>(topPauseSec);
    }
    if (!nullToAbsent || prescriptionNotes != null) {
      map['prescription_notes'] = Variable<String>(prescriptionNotes);
    }
    if (!nullToAbsent || formUrl != null) {
      map['form_url'] = Variable<String>(formUrl);
    }
    return map;
  }

  TemplateExercisesCompanion toCompanion(bool nullToAbsent) {
    return TemplateExercisesCompanion(
      id: Value(id),
      templateId: Value(templateId),
      exerciseId: Value(exerciseId),
      position: Value(position),
      targetSets: targetSets == null && nullToAbsent
          ? const Value.absent()
          : Value(targetSets),
      sidesPerSet: sidesPerSet == null && nullToAbsent
          ? const Value.absent()
          : Value(sidesPerSet),
      minReps: minReps == null && nullToAbsent
          ? const Value.absent()
          : Value(minReps),
      maxReps: maxReps == null && nullToAbsent
          ? const Value.absent()
          : Value(maxReps),
      targetDurationSec: targetDurationSec == null && nullToAbsent
          ? const Value.absent()
          : Value(targetDurationSec),
      targetDistanceMeters: targetDistanceMeters == null && nullToAbsent
          ? const Value.absent()
          : Value(targetDistanceMeters),
      restSeconds: restSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(restSeconds),
      eccentricSec: eccentricSec == null && nullToAbsent
          ? const Value.absent()
          : Value(eccentricSec),
      bottomPauseSec: bottomPauseSec == null && nullToAbsent
          ? const Value.absent()
          : Value(bottomPauseSec),
      concentricSec: concentricSec == null && nullToAbsent
          ? const Value.absent()
          : Value(concentricSec),
      topPauseSec: topPauseSec == null && nullToAbsent
          ? const Value.absent()
          : Value(topPauseSec),
      prescriptionNotes: prescriptionNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(prescriptionNotes),
      formUrl: formUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(formUrl),
    );
  }

  factory TemplateExercise.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TemplateExercise(
      id: serializer.fromJson<int>(json['id']),
      templateId: serializer.fromJson<int>(json['templateId']),
      exerciseId: serializer.fromJson<int>(json['exerciseId']),
      position: serializer.fromJson<int>(json['position']),
      targetSets: serializer.fromJson<int?>(json['targetSets']),
      sidesPerSet: serializer.fromJson<int?>(json['sidesPerSet']),
      minReps: serializer.fromJson<int?>(json['minReps']),
      maxReps: serializer.fromJson<int?>(json['maxReps']),
      targetDurationSec: serializer.fromJson<int?>(json['targetDurationSec']),
      targetDistanceMeters: serializer.fromJson<double?>(
        json['targetDistanceMeters'],
      ),
      restSeconds: serializer.fromJson<int?>(json['restSeconds']),
      eccentricSec: serializer.fromJson<int?>(json['eccentricSec']),
      bottomPauseSec: serializer.fromJson<int?>(json['bottomPauseSec']),
      concentricSec: serializer.fromJson<int?>(json['concentricSec']),
      topPauseSec: serializer.fromJson<int?>(json['topPauseSec']),
      prescriptionNotes: serializer.fromJson<String?>(
        json['prescriptionNotes'],
      ),
      formUrl: serializer.fromJson<String?>(json['formUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'templateId': serializer.toJson<int>(templateId),
      'exerciseId': serializer.toJson<int>(exerciseId),
      'position': serializer.toJson<int>(position),
      'targetSets': serializer.toJson<int?>(targetSets),
      'sidesPerSet': serializer.toJson<int?>(sidesPerSet),
      'minReps': serializer.toJson<int?>(minReps),
      'maxReps': serializer.toJson<int?>(maxReps),
      'targetDurationSec': serializer.toJson<int?>(targetDurationSec),
      'targetDistanceMeters': serializer.toJson<double?>(targetDistanceMeters),
      'restSeconds': serializer.toJson<int?>(restSeconds),
      'eccentricSec': serializer.toJson<int?>(eccentricSec),
      'bottomPauseSec': serializer.toJson<int?>(bottomPauseSec),
      'concentricSec': serializer.toJson<int?>(concentricSec),
      'topPauseSec': serializer.toJson<int?>(topPauseSec),
      'prescriptionNotes': serializer.toJson<String?>(prescriptionNotes),
      'formUrl': serializer.toJson<String?>(formUrl),
    };
  }

  TemplateExercise copyWith({
    int? id,
    int? templateId,
    int? exerciseId,
    int? position,
    Value<int?> targetSets = const Value.absent(),
    Value<int?> sidesPerSet = const Value.absent(),
    Value<int?> minReps = const Value.absent(),
    Value<int?> maxReps = const Value.absent(),
    Value<int?> targetDurationSec = const Value.absent(),
    Value<double?> targetDistanceMeters = const Value.absent(),
    Value<int?> restSeconds = const Value.absent(),
    Value<int?> eccentricSec = const Value.absent(),
    Value<int?> bottomPauseSec = const Value.absent(),
    Value<int?> concentricSec = const Value.absent(),
    Value<int?> topPauseSec = const Value.absent(),
    Value<String?> prescriptionNotes = const Value.absent(),
    Value<String?> formUrl = const Value.absent(),
  }) => TemplateExercise(
    id: id ?? this.id,
    templateId: templateId ?? this.templateId,
    exerciseId: exerciseId ?? this.exerciseId,
    position: position ?? this.position,
    targetSets: targetSets.present ? targetSets.value : this.targetSets,
    sidesPerSet: sidesPerSet.present ? sidesPerSet.value : this.sidesPerSet,
    minReps: minReps.present ? minReps.value : this.minReps,
    maxReps: maxReps.present ? maxReps.value : this.maxReps,
    targetDurationSec: targetDurationSec.present
        ? targetDurationSec.value
        : this.targetDurationSec,
    targetDistanceMeters: targetDistanceMeters.present
        ? targetDistanceMeters.value
        : this.targetDistanceMeters,
    restSeconds: restSeconds.present ? restSeconds.value : this.restSeconds,
    eccentricSec: eccentricSec.present ? eccentricSec.value : this.eccentricSec,
    bottomPauseSec: bottomPauseSec.present
        ? bottomPauseSec.value
        : this.bottomPauseSec,
    concentricSec: concentricSec.present
        ? concentricSec.value
        : this.concentricSec,
    topPauseSec: topPauseSec.present ? topPauseSec.value : this.topPauseSec,
    prescriptionNotes: prescriptionNotes.present
        ? prescriptionNotes.value
        : this.prescriptionNotes,
    formUrl: formUrl.present ? formUrl.value : this.formUrl,
  );
  TemplateExercise copyWithCompanion(TemplateExercisesCompanion data) {
    return TemplateExercise(
      id: data.id.present ? data.id.value : this.id,
      templateId: data.templateId.present
          ? data.templateId.value
          : this.templateId,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      position: data.position.present ? data.position.value : this.position,
      targetSets: data.targetSets.present
          ? data.targetSets.value
          : this.targetSets,
      sidesPerSet: data.sidesPerSet.present
          ? data.sidesPerSet.value
          : this.sidesPerSet,
      minReps: data.minReps.present ? data.minReps.value : this.minReps,
      maxReps: data.maxReps.present ? data.maxReps.value : this.maxReps,
      targetDurationSec: data.targetDurationSec.present
          ? data.targetDurationSec.value
          : this.targetDurationSec,
      targetDistanceMeters: data.targetDistanceMeters.present
          ? data.targetDistanceMeters.value
          : this.targetDistanceMeters,
      restSeconds: data.restSeconds.present
          ? data.restSeconds.value
          : this.restSeconds,
      eccentricSec: data.eccentricSec.present
          ? data.eccentricSec.value
          : this.eccentricSec,
      bottomPauseSec: data.bottomPauseSec.present
          ? data.bottomPauseSec.value
          : this.bottomPauseSec,
      concentricSec: data.concentricSec.present
          ? data.concentricSec.value
          : this.concentricSec,
      topPauseSec: data.topPauseSec.present
          ? data.topPauseSec.value
          : this.topPauseSec,
      prescriptionNotes: data.prescriptionNotes.present
          ? data.prescriptionNotes.value
          : this.prescriptionNotes,
      formUrl: data.formUrl.present ? data.formUrl.value : this.formUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TemplateExercise(')
          ..write('id: $id, ')
          ..write('templateId: $templateId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('position: $position, ')
          ..write('targetSets: $targetSets, ')
          ..write('sidesPerSet: $sidesPerSet, ')
          ..write('minReps: $minReps, ')
          ..write('maxReps: $maxReps, ')
          ..write('targetDurationSec: $targetDurationSec, ')
          ..write('targetDistanceMeters: $targetDistanceMeters, ')
          ..write('restSeconds: $restSeconds, ')
          ..write('eccentricSec: $eccentricSec, ')
          ..write('bottomPauseSec: $bottomPauseSec, ')
          ..write('concentricSec: $concentricSec, ')
          ..write('topPauseSec: $topPauseSec, ')
          ..write('prescriptionNotes: $prescriptionNotes, ')
          ..write('formUrl: $formUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    templateId,
    exerciseId,
    position,
    targetSets,
    sidesPerSet,
    minReps,
    maxReps,
    targetDurationSec,
    targetDistanceMeters,
    restSeconds,
    eccentricSec,
    bottomPauseSec,
    concentricSec,
    topPauseSec,
    prescriptionNotes,
    formUrl,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TemplateExercise &&
          other.id == this.id &&
          other.templateId == this.templateId &&
          other.exerciseId == this.exerciseId &&
          other.position == this.position &&
          other.targetSets == this.targetSets &&
          other.sidesPerSet == this.sidesPerSet &&
          other.minReps == this.minReps &&
          other.maxReps == this.maxReps &&
          other.targetDurationSec == this.targetDurationSec &&
          other.targetDistanceMeters == this.targetDistanceMeters &&
          other.restSeconds == this.restSeconds &&
          other.eccentricSec == this.eccentricSec &&
          other.bottomPauseSec == this.bottomPauseSec &&
          other.concentricSec == this.concentricSec &&
          other.topPauseSec == this.topPauseSec &&
          other.prescriptionNotes == this.prescriptionNotes &&
          other.formUrl == this.formUrl);
}

class TemplateExercisesCompanion extends UpdateCompanion<TemplateExercise> {
  final Value<int> id;
  final Value<int> templateId;
  final Value<int> exerciseId;
  final Value<int> position;
  final Value<int?> targetSets;
  final Value<int?> sidesPerSet;
  final Value<int?> minReps;
  final Value<int?> maxReps;
  final Value<int?> targetDurationSec;
  final Value<double?> targetDistanceMeters;
  final Value<int?> restSeconds;
  final Value<int?> eccentricSec;
  final Value<int?> bottomPauseSec;
  final Value<int?> concentricSec;
  final Value<int?> topPauseSec;
  final Value<String?> prescriptionNotes;
  final Value<String?> formUrl;
  const TemplateExercisesCompanion({
    this.id = const Value.absent(),
    this.templateId = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.position = const Value.absent(),
    this.targetSets = const Value.absent(),
    this.sidesPerSet = const Value.absent(),
    this.minReps = const Value.absent(),
    this.maxReps = const Value.absent(),
    this.targetDurationSec = const Value.absent(),
    this.targetDistanceMeters = const Value.absent(),
    this.restSeconds = const Value.absent(),
    this.eccentricSec = const Value.absent(),
    this.bottomPauseSec = const Value.absent(),
    this.concentricSec = const Value.absent(),
    this.topPauseSec = const Value.absent(),
    this.prescriptionNotes = const Value.absent(),
    this.formUrl = const Value.absent(),
  });
  TemplateExercisesCompanion.insert({
    this.id = const Value.absent(),
    required int templateId,
    required int exerciseId,
    required int position,
    this.targetSets = const Value.absent(),
    this.sidesPerSet = const Value.absent(),
    this.minReps = const Value.absent(),
    this.maxReps = const Value.absent(),
    this.targetDurationSec = const Value.absent(),
    this.targetDistanceMeters = const Value.absent(),
    this.restSeconds = const Value.absent(),
    this.eccentricSec = const Value.absent(),
    this.bottomPauseSec = const Value.absent(),
    this.concentricSec = const Value.absent(),
    this.topPauseSec = const Value.absent(),
    this.prescriptionNotes = const Value.absent(),
    this.formUrl = const Value.absent(),
  }) : templateId = Value(templateId),
       exerciseId = Value(exerciseId),
       position = Value(position);
  static Insertable<TemplateExercise> custom({
    Expression<int>? id,
    Expression<int>? templateId,
    Expression<int>? exerciseId,
    Expression<int>? position,
    Expression<int>? targetSets,
    Expression<int>? sidesPerSet,
    Expression<int>? minReps,
    Expression<int>? maxReps,
    Expression<int>? targetDurationSec,
    Expression<double>? targetDistanceMeters,
    Expression<int>? restSeconds,
    Expression<int>? eccentricSec,
    Expression<int>? bottomPauseSec,
    Expression<int>? concentricSec,
    Expression<int>? topPauseSec,
    Expression<String>? prescriptionNotes,
    Expression<String>? formUrl,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (templateId != null) 'template_id': templateId,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (position != null) 'position': position,
      if (targetSets != null) 'target_sets': targetSets,
      if (sidesPerSet != null) 'sides_per_set': sidesPerSet,
      if (minReps != null) 'min_reps': minReps,
      if (maxReps != null) 'max_reps': maxReps,
      if (targetDurationSec != null) 'target_duration_sec': targetDurationSec,
      if (targetDistanceMeters != null)
        'target_distance_meters': targetDistanceMeters,
      if (restSeconds != null) 'rest_seconds': restSeconds,
      if (eccentricSec != null) 'eccentric_sec': eccentricSec,
      if (bottomPauseSec != null) 'bottom_pause_sec': bottomPauseSec,
      if (concentricSec != null) 'concentric_sec': concentricSec,
      if (topPauseSec != null) 'top_pause_sec': topPauseSec,
      if (prescriptionNotes != null) 'prescription_notes': prescriptionNotes,
      if (formUrl != null) 'form_url': formUrl,
    });
  }

  TemplateExercisesCompanion copyWith({
    Value<int>? id,
    Value<int>? templateId,
    Value<int>? exerciseId,
    Value<int>? position,
    Value<int?>? targetSets,
    Value<int?>? sidesPerSet,
    Value<int?>? minReps,
    Value<int?>? maxReps,
    Value<int?>? targetDurationSec,
    Value<double?>? targetDistanceMeters,
    Value<int?>? restSeconds,
    Value<int?>? eccentricSec,
    Value<int?>? bottomPauseSec,
    Value<int?>? concentricSec,
    Value<int?>? topPauseSec,
    Value<String?>? prescriptionNotes,
    Value<String?>? formUrl,
  }) {
    return TemplateExercisesCompanion(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      exerciseId: exerciseId ?? this.exerciseId,
      position: position ?? this.position,
      targetSets: targetSets ?? this.targetSets,
      sidesPerSet: sidesPerSet ?? this.sidesPerSet,
      minReps: minReps ?? this.minReps,
      maxReps: maxReps ?? this.maxReps,
      targetDurationSec: targetDurationSec ?? this.targetDurationSec,
      targetDistanceMeters: targetDistanceMeters ?? this.targetDistanceMeters,
      restSeconds: restSeconds ?? this.restSeconds,
      eccentricSec: eccentricSec ?? this.eccentricSec,
      bottomPauseSec: bottomPauseSec ?? this.bottomPauseSec,
      concentricSec: concentricSec ?? this.concentricSec,
      topPauseSec: topPauseSec ?? this.topPauseSec,
      prescriptionNotes: prescriptionNotes ?? this.prescriptionNotes,
      formUrl: formUrl ?? this.formUrl,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<int>(templateId.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<int>(exerciseId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (targetSets.present) {
      map['target_sets'] = Variable<int>(targetSets.value);
    }
    if (sidesPerSet.present) {
      map['sides_per_set'] = Variable<int>(sidesPerSet.value);
    }
    if (minReps.present) {
      map['min_reps'] = Variable<int>(minReps.value);
    }
    if (maxReps.present) {
      map['max_reps'] = Variable<int>(maxReps.value);
    }
    if (targetDurationSec.present) {
      map['target_duration_sec'] = Variable<int>(targetDurationSec.value);
    }
    if (targetDistanceMeters.present) {
      map['target_distance_meters'] = Variable<double>(
        targetDistanceMeters.value,
      );
    }
    if (restSeconds.present) {
      map['rest_seconds'] = Variable<int>(restSeconds.value);
    }
    if (eccentricSec.present) {
      map['eccentric_sec'] = Variable<int>(eccentricSec.value);
    }
    if (bottomPauseSec.present) {
      map['bottom_pause_sec'] = Variable<int>(bottomPauseSec.value);
    }
    if (concentricSec.present) {
      map['concentric_sec'] = Variable<int>(concentricSec.value);
    }
    if (topPauseSec.present) {
      map['top_pause_sec'] = Variable<int>(topPauseSec.value);
    }
    if (prescriptionNotes.present) {
      map['prescription_notes'] = Variable<String>(prescriptionNotes.value);
    }
    if (formUrl.present) {
      map['form_url'] = Variable<String>(formUrl.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TemplateExercisesCompanion(')
          ..write('id: $id, ')
          ..write('templateId: $templateId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('position: $position, ')
          ..write('targetSets: $targetSets, ')
          ..write('sidesPerSet: $sidesPerSet, ')
          ..write('minReps: $minReps, ')
          ..write('maxReps: $maxReps, ')
          ..write('targetDurationSec: $targetDurationSec, ')
          ..write('targetDistanceMeters: $targetDistanceMeters, ')
          ..write('restSeconds: $restSeconds, ')
          ..write('eccentricSec: $eccentricSec, ')
          ..write('bottomPauseSec: $bottomPauseSec, ')
          ..write('concentricSec: $concentricSec, ')
          ..write('topPauseSec: $topPauseSec, ')
          ..write('prescriptionNotes: $prescriptionNotes, ')
          ..write('formUrl: $formUrl')
          ..write(')'))
        .toString();
  }
}

class $SessionsTable extends Sessions with TableInfo<$SessionsTable, Session> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _templateIdMeta = const VerificationMeta(
    'templateId',
  );
  @override
  late final GeneratedColumn<int> templateId = GeneratedColumn<int>(
    'template_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES templates (id)',
    ),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startedAt,
    endedAt,
    templateId,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Session> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('template_id')) {
      context.handle(
        _templateIdMeta,
        templateId.isAcceptableOrUnknown(data['template_id']!, _templateIdMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Session map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Session(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      templateId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}template_id'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class Session extends DataClass implements Insertable<Session> {
  final int id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? templateId;
  final String? notes;
  const Session({
    required this.id,
    required this.startedAt,
    this.endedAt,
    this.templateId,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    if (!nullToAbsent || templateId != null) {
      map['template_id'] = Variable<int>(templateId);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      templateId: templateId == null && nullToAbsent
          ? const Value.absent()
          : Value(templateId),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory Session.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      id: serializer.fromJson<int>(json['id']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      templateId: serializer.fromJson<int?>(json['templateId']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'templateId': serializer.toJson<int?>(templateId),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  Session copyWith({
    int? id,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    Value<int?> templateId = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => Session(
    id: id ?? this.id,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    templateId: templateId.present ? templateId.value : this.templateId,
    notes: notes.present ? notes.value : this.notes,
  );
  Session copyWithCompanion(SessionsCompanion data) {
    return Session(
      id: data.id.present ? data.id.value : this.id,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      templateId: data.templateId.present
          ? data.templateId.value
          : this.templateId,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('templateId: $templateId, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, startedAt, endedAt, templateId, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.id == this.id &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.templateId == this.templateId &&
          other.notes == this.notes);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<int> id;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<int?> templateId;
  final Value<String?> notes;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.templateId = const Value.absent(),
    this.notes = const Value.absent(),
  });
  SessionsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.templateId = const Value.absent(),
    this.notes = const Value.absent(),
  }) : startedAt = Value(startedAt);
  static Insertable<Session> custom({
    Expression<int>? id,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<int>? templateId,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (templateId != null) 'template_id': templateId,
      if (notes != null) 'notes': notes,
    });
  }

  SessionsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<int?>? templateId,
    Value<String?>? notes,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      templateId: templateId ?? this.templateId,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<int>(templateId.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('templateId: $templateId, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $SessionExercisesTable extends SessionExercises
    with TableInfo<$SessionExercisesTable, SessionExercise> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionExercisesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id)',
    ),
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<int> exerciseId = GeneratedColumn<int>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES exercises (id)',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetSetsMeta = const VerificationMeta(
    'targetSets',
  );
  @override
  late final GeneratedColumn<int> targetSets = GeneratedColumn<int>(
    'target_sets',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sidesPerSetMeta = const VerificationMeta(
    'sidesPerSet',
  );
  @override
  late final GeneratedColumn<int> sidesPerSet = GeneratedColumn<int>(
    'sides_per_set',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _minRepsMeta = const VerificationMeta(
    'minReps',
  );
  @override
  late final GeneratedColumn<int> minReps = GeneratedColumn<int>(
    'min_reps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxRepsMeta = const VerificationMeta(
    'maxReps',
  );
  @override
  late final GeneratedColumn<int> maxReps = GeneratedColumn<int>(
    'max_reps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetDurationSecMeta = const VerificationMeta(
    'targetDurationSec',
  );
  @override
  late final GeneratedColumn<int> targetDurationSec = GeneratedColumn<int>(
    'target_duration_sec',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetDistanceMetersMeta =
      const VerificationMeta('targetDistanceMeters');
  @override
  late final GeneratedColumn<double> targetDistanceMeters =
      GeneratedColumn<double>(
        'target_distance_meters',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _restSecondsMeta = const VerificationMeta(
    'restSeconds',
  );
  @override
  late final GeneratedColumn<int> restSeconds = GeneratedColumn<int>(
    'rest_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _eccentricSecMeta = const VerificationMeta(
    'eccentricSec',
  );
  @override
  late final GeneratedColumn<int> eccentricSec = GeneratedColumn<int>(
    'eccentric_sec',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bottomPauseSecMeta = const VerificationMeta(
    'bottomPauseSec',
  );
  @override
  late final GeneratedColumn<int> bottomPauseSec = GeneratedColumn<int>(
    'bottom_pause_sec',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _concentricSecMeta = const VerificationMeta(
    'concentricSec',
  );
  @override
  late final GeneratedColumn<int> concentricSec = GeneratedColumn<int>(
    'concentric_sec',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _topPauseSecMeta = const VerificationMeta(
    'topPauseSec',
  );
  @override
  late final GeneratedColumn<int> topPauseSec = GeneratedColumn<int>(
    'top_pause_sec',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _prescriptionNotesMeta = const VerificationMeta(
    'prescriptionNotes',
  );
  @override
  late final GeneratedColumn<String> prescriptionNotes =
      GeneratedColumn<String>(
        'prescription_notes',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _formUrlMeta = const VerificationMeta(
    'formUrl',
  );
  @override
  late final GeneratedColumn<String> formUrl = GeneratedColumn<String>(
    'form_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    exerciseId,
    position,
    targetSets,
    sidesPerSet,
    minReps,
    maxReps,
    targetDurationSec,
    targetDistanceMeters,
    restSeconds,
    eccentricSec,
    bottomPauseSec,
    concentricSec,
    topPauseSec,
    prescriptionNotes,
    formUrl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_exercises';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionExercise> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('target_sets')) {
      context.handle(
        _targetSetsMeta,
        targetSets.isAcceptableOrUnknown(data['target_sets']!, _targetSetsMeta),
      );
    }
    if (data.containsKey('sides_per_set')) {
      context.handle(
        _sidesPerSetMeta,
        sidesPerSet.isAcceptableOrUnknown(
          data['sides_per_set']!,
          _sidesPerSetMeta,
        ),
      );
    }
    if (data.containsKey('min_reps')) {
      context.handle(
        _minRepsMeta,
        minReps.isAcceptableOrUnknown(data['min_reps']!, _minRepsMeta),
      );
    }
    if (data.containsKey('max_reps')) {
      context.handle(
        _maxRepsMeta,
        maxReps.isAcceptableOrUnknown(data['max_reps']!, _maxRepsMeta),
      );
    }
    if (data.containsKey('target_duration_sec')) {
      context.handle(
        _targetDurationSecMeta,
        targetDurationSec.isAcceptableOrUnknown(
          data['target_duration_sec']!,
          _targetDurationSecMeta,
        ),
      );
    }
    if (data.containsKey('target_distance_meters')) {
      context.handle(
        _targetDistanceMetersMeta,
        targetDistanceMeters.isAcceptableOrUnknown(
          data['target_distance_meters']!,
          _targetDistanceMetersMeta,
        ),
      );
    }
    if (data.containsKey('rest_seconds')) {
      context.handle(
        _restSecondsMeta,
        restSeconds.isAcceptableOrUnknown(
          data['rest_seconds']!,
          _restSecondsMeta,
        ),
      );
    }
    if (data.containsKey('eccentric_sec')) {
      context.handle(
        _eccentricSecMeta,
        eccentricSec.isAcceptableOrUnknown(
          data['eccentric_sec']!,
          _eccentricSecMeta,
        ),
      );
    }
    if (data.containsKey('bottom_pause_sec')) {
      context.handle(
        _bottomPauseSecMeta,
        bottomPauseSec.isAcceptableOrUnknown(
          data['bottom_pause_sec']!,
          _bottomPauseSecMeta,
        ),
      );
    }
    if (data.containsKey('concentric_sec')) {
      context.handle(
        _concentricSecMeta,
        concentricSec.isAcceptableOrUnknown(
          data['concentric_sec']!,
          _concentricSecMeta,
        ),
      );
    }
    if (data.containsKey('top_pause_sec')) {
      context.handle(
        _topPauseSecMeta,
        topPauseSec.isAcceptableOrUnknown(
          data['top_pause_sec']!,
          _topPauseSecMeta,
        ),
      );
    }
    if (data.containsKey('prescription_notes')) {
      context.handle(
        _prescriptionNotesMeta,
        prescriptionNotes.isAcceptableOrUnknown(
          data['prescription_notes']!,
          _prescriptionNotesMeta,
        ),
      );
    }
    if (data.containsKey('form_url')) {
      context.handle(
        _formUrlMeta,
        formUrl.isAcceptableOrUnknown(data['form_url']!, _formUrlMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionExercise map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionExercise(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}exercise_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      targetSets: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_sets'],
      ),
      sidesPerSet: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sides_per_set'],
      ),
      minReps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}min_reps'],
      ),
      maxReps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_reps'],
      ),
      targetDurationSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_duration_sec'],
      ),
      targetDistanceMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}target_distance_meters'],
      ),
      restSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rest_seconds'],
      ),
      eccentricSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}eccentric_sec'],
      ),
      bottomPauseSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bottom_pause_sec'],
      ),
      concentricSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}concentric_sec'],
      ),
      topPauseSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}top_pause_sec'],
      ),
      prescriptionNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prescription_notes'],
      ),
      formUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}form_url'],
      ),
    );
  }

  @override
  $SessionExercisesTable createAlias(String alias) {
    return $SessionExercisesTable(attachedDatabase, alias);
  }
}

class SessionExercise extends DataClass implements Insertable<SessionExercise> {
  final int id;
  final int sessionId;
  final int exerciseId;
  final int position;
  final int? targetSets;
  final int? sidesPerSet;
  final int? minReps;
  final int? maxReps;
  final int? targetDurationSec;
  final double? targetDistanceMeters;
  final int? restSeconds;
  final int? eccentricSec;
  final int? bottomPauseSec;
  final int? concentricSec;
  final int? topPauseSec;
  final String? prescriptionNotes;
  final String? formUrl;
  const SessionExercise({
    required this.id,
    required this.sessionId,
    required this.exerciseId,
    required this.position,
    this.targetSets,
    this.sidesPerSet,
    this.minReps,
    this.maxReps,
    this.targetDurationSec,
    this.targetDistanceMeters,
    this.restSeconds,
    this.eccentricSec,
    this.bottomPauseSec,
    this.concentricSec,
    this.topPauseSec,
    this.prescriptionNotes,
    this.formUrl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<int>(sessionId);
    map['exercise_id'] = Variable<int>(exerciseId);
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || targetSets != null) {
      map['target_sets'] = Variable<int>(targetSets);
    }
    if (!nullToAbsent || sidesPerSet != null) {
      map['sides_per_set'] = Variable<int>(sidesPerSet);
    }
    if (!nullToAbsent || minReps != null) {
      map['min_reps'] = Variable<int>(minReps);
    }
    if (!nullToAbsent || maxReps != null) {
      map['max_reps'] = Variable<int>(maxReps);
    }
    if (!nullToAbsent || targetDurationSec != null) {
      map['target_duration_sec'] = Variable<int>(targetDurationSec);
    }
    if (!nullToAbsent || targetDistanceMeters != null) {
      map['target_distance_meters'] = Variable<double>(targetDistanceMeters);
    }
    if (!nullToAbsent || restSeconds != null) {
      map['rest_seconds'] = Variable<int>(restSeconds);
    }
    if (!nullToAbsent || eccentricSec != null) {
      map['eccentric_sec'] = Variable<int>(eccentricSec);
    }
    if (!nullToAbsent || bottomPauseSec != null) {
      map['bottom_pause_sec'] = Variable<int>(bottomPauseSec);
    }
    if (!nullToAbsent || concentricSec != null) {
      map['concentric_sec'] = Variable<int>(concentricSec);
    }
    if (!nullToAbsent || topPauseSec != null) {
      map['top_pause_sec'] = Variable<int>(topPauseSec);
    }
    if (!nullToAbsent || prescriptionNotes != null) {
      map['prescription_notes'] = Variable<String>(prescriptionNotes);
    }
    if (!nullToAbsent || formUrl != null) {
      map['form_url'] = Variable<String>(formUrl);
    }
    return map;
  }

  SessionExercisesCompanion toCompanion(bool nullToAbsent) {
    return SessionExercisesCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      exerciseId: Value(exerciseId),
      position: Value(position),
      targetSets: targetSets == null && nullToAbsent
          ? const Value.absent()
          : Value(targetSets),
      sidesPerSet: sidesPerSet == null && nullToAbsent
          ? const Value.absent()
          : Value(sidesPerSet),
      minReps: minReps == null && nullToAbsent
          ? const Value.absent()
          : Value(minReps),
      maxReps: maxReps == null && nullToAbsent
          ? const Value.absent()
          : Value(maxReps),
      targetDurationSec: targetDurationSec == null && nullToAbsent
          ? const Value.absent()
          : Value(targetDurationSec),
      targetDistanceMeters: targetDistanceMeters == null && nullToAbsent
          ? const Value.absent()
          : Value(targetDistanceMeters),
      restSeconds: restSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(restSeconds),
      eccentricSec: eccentricSec == null && nullToAbsent
          ? const Value.absent()
          : Value(eccentricSec),
      bottomPauseSec: bottomPauseSec == null && nullToAbsent
          ? const Value.absent()
          : Value(bottomPauseSec),
      concentricSec: concentricSec == null && nullToAbsent
          ? const Value.absent()
          : Value(concentricSec),
      topPauseSec: topPauseSec == null && nullToAbsent
          ? const Value.absent()
          : Value(topPauseSec),
      prescriptionNotes: prescriptionNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(prescriptionNotes),
      formUrl: formUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(formUrl),
    );
  }

  factory SessionExercise.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionExercise(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      exerciseId: serializer.fromJson<int>(json['exerciseId']),
      position: serializer.fromJson<int>(json['position']),
      targetSets: serializer.fromJson<int?>(json['targetSets']),
      sidesPerSet: serializer.fromJson<int?>(json['sidesPerSet']),
      minReps: serializer.fromJson<int?>(json['minReps']),
      maxReps: serializer.fromJson<int?>(json['maxReps']),
      targetDurationSec: serializer.fromJson<int?>(json['targetDurationSec']),
      targetDistanceMeters: serializer.fromJson<double?>(
        json['targetDistanceMeters'],
      ),
      restSeconds: serializer.fromJson<int?>(json['restSeconds']),
      eccentricSec: serializer.fromJson<int?>(json['eccentricSec']),
      bottomPauseSec: serializer.fromJson<int?>(json['bottomPauseSec']),
      concentricSec: serializer.fromJson<int?>(json['concentricSec']),
      topPauseSec: serializer.fromJson<int?>(json['topPauseSec']),
      prescriptionNotes: serializer.fromJson<String?>(
        json['prescriptionNotes'],
      ),
      formUrl: serializer.fromJson<String?>(json['formUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int>(sessionId),
      'exerciseId': serializer.toJson<int>(exerciseId),
      'position': serializer.toJson<int>(position),
      'targetSets': serializer.toJson<int?>(targetSets),
      'sidesPerSet': serializer.toJson<int?>(sidesPerSet),
      'minReps': serializer.toJson<int?>(minReps),
      'maxReps': serializer.toJson<int?>(maxReps),
      'targetDurationSec': serializer.toJson<int?>(targetDurationSec),
      'targetDistanceMeters': serializer.toJson<double?>(targetDistanceMeters),
      'restSeconds': serializer.toJson<int?>(restSeconds),
      'eccentricSec': serializer.toJson<int?>(eccentricSec),
      'bottomPauseSec': serializer.toJson<int?>(bottomPauseSec),
      'concentricSec': serializer.toJson<int?>(concentricSec),
      'topPauseSec': serializer.toJson<int?>(topPauseSec),
      'prescriptionNotes': serializer.toJson<String?>(prescriptionNotes),
      'formUrl': serializer.toJson<String?>(formUrl),
    };
  }

  SessionExercise copyWith({
    int? id,
    int? sessionId,
    int? exerciseId,
    int? position,
    Value<int?> targetSets = const Value.absent(),
    Value<int?> sidesPerSet = const Value.absent(),
    Value<int?> minReps = const Value.absent(),
    Value<int?> maxReps = const Value.absent(),
    Value<int?> targetDurationSec = const Value.absent(),
    Value<double?> targetDistanceMeters = const Value.absent(),
    Value<int?> restSeconds = const Value.absent(),
    Value<int?> eccentricSec = const Value.absent(),
    Value<int?> bottomPauseSec = const Value.absent(),
    Value<int?> concentricSec = const Value.absent(),
    Value<int?> topPauseSec = const Value.absent(),
    Value<String?> prescriptionNotes = const Value.absent(),
    Value<String?> formUrl = const Value.absent(),
  }) => SessionExercise(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    exerciseId: exerciseId ?? this.exerciseId,
    position: position ?? this.position,
    targetSets: targetSets.present ? targetSets.value : this.targetSets,
    sidesPerSet: sidesPerSet.present ? sidesPerSet.value : this.sidesPerSet,
    minReps: minReps.present ? minReps.value : this.minReps,
    maxReps: maxReps.present ? maxReps.value : this.maxReps,
    targetDurationSec: targetDurationSec.present
        ? targetDurationSec.value
        : this.targetDurationSec,
    targetDistanceMeters: targetDistanceMeters.present
        ? targetDistanceMeters.value
        : this.targetDistanceMeters,
    restSeconds: restSeconds.present ? restSeconds.value : this.restSeconds,
    eccentricSec: eccentricSec.present ? eccentricSec.value : this.eccentricSec,
    bottomPauseSec: bottomPauseSec.present
        ? bottomPauseSec.value
        : this.bottomPauseSec,
    concentricSec: concentricSec.present
        ? concentricSec.value
        : this.concentricSec,
    topPauseSec: topPauseSec.present ? topPauseSec.value : this.topPauseSec,
    prescriptionNotes: prescriptionNotes.present
        ? prescriptionNotes.value
        : this.prescriptionNotes,
    formUrl: formUrl.present ? formUrl.value : this.formUrl,
  );
  SessionExercise copyWithCompanion(SessionExercisesCompanion data) {
    return SessionExercise(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      position: data.position.present ? data.position.value : this.position,
      targetSets: data.targetSets.present
          ? data.targetSets.value
          : this.targetSets,
      sidesPerSet: data.sidesPerSet.present
          ? data.sidesPerSet.value
          : this.sidesPerSet,
      minReps: data.minReps.present ? data.minReps.value : this.minReps,
      maxReps: data.maxReps.present ? data.maxReps.value : this.maxReps,
      targetDurationSec: data.targetDurationSec.present
          ? data.targetDurationSec.value
          : this.targetDurationSec,
      targetDistanceMeters: data.targetDistanceMeters.present
          ? data.targetDistanceMeters.value
          : this.targetDistanceMeters,
      restSeconds: data.restSeconds.present
          ? data.restSeconds.value
          : this.restSeconds,
      eccentricSec: data.eccentricSec.present
          ? data.eccentricSec.value
          : this.eccentricSec,
      bottomPauseSec: data.bottomPauseSec.present
          ? data.bottomPauseSec.value
          : this.bottomPauseSec,
      concentricSec: data.concentricSec.present
          ? data.concentricSec.value
          : this.concentricSec,
      topPauseSec: data.topPauseSec.present
          ? data.topPauseSec.value
          : this.topPauseSec,
      prescriptionNotes: data.prescriptionNotes.present
          ? data.prescriptionNotes.value
          : this.prescriptionNotes,
      formUrl: data.formUrl.present ? data.formUrl.value : this.formUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionExercise(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('position: $position, ')
          ..write('targetSets: $targetSets, ')
          ..write('sidesPerSet: $sidesPerSet, ')
          ..write('minReps: $minReps, ')
          ..write('maxReps: $maxReps, ')
          ..write('targetDurationSec: $targetDurationSec, ')
          ..write('targetDistanceMeters: $targetDistanceMeters, ')
          ..write('restSeconds: $restSeconds, ')
          ..write('eccentricSec: $eccentricSec, ')
          ..write('bottomPauseSec: $bottomPauseSec, ')
          ..write('concentricSec: $concentricSec, ')
          ..write('topPauseSec: $topPauseSec, ')
          ..write('prescriptionNotes: $prescriptionNotes, ')
          ..write('formUrl: $formUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    exerciseId,
    position,
    targetSets,
    sidesPerSet,
    minReps,
    maxReps,
    targetDurationSec,
    targetDistanceMeters,
    restSeconds,
    eccentricSec,
    bottomPauseSec,
    concentricSec,
    topPauseSec,
    prescriptionNotes,
    formUrl,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionExercise &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.exerciseId == this.exerciseId &&
          other.position == this.position &&
          other.targetSets == this.targetSets &&
          other.sidesPerSet == this.sidesPerSet &&
          other.minReps == this.minReps &&
          other.maxReps == this.maxReps &&
          other.targetDurationSec == this.targetDurationSec &&
          other.targetDistanceMeters == this.targetDistanceMeters &&
          other.restSeconds == this.restSeconds &&
          other.eccentricSec == this.eccentricSec &&
          other.bottomPauseSec == this.bottomPauseSec &&
          other.concentricSec == this.concentricSec &&
          other.topPauseSec == this.topPauseSec &&
          other.prescriptionNotes == this.prescriptionNotes &&
          other.formUrl == this.formUrl);
}

class SessionExercisesCompanion extends UpdateCompanion<SessionExercise> {
  final Value<int> id;
  final Value<int> sessionId;
  final Value<int> exerciseId;
  final Value<int> position;
  final Value<int?> targetSets;
  final Value<int?> sidesPerSet;
  final Value<int?> minReps;
  final Value<int?> maxReps;
  final Value<int?> targetDurationSec;
  final Value<double?> targetDistanceMeters;
  final Value<int?> restSeconds;
  final Value<int?> eccentricSec;
  final Value<int?> bottomPauseSec;
  final Value<int?> concentricSec;
  final Value<int?> topPauseSec;
  final Value<String?> prescriptionNotes;
  final Value<String?> formUrl;
  const SessionExercisesCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.position = const Value.absent(),
    this.targetSets = const Value.absent(),
    this.sidesPerSet = const Value.absent(),
    this.minReps = const Value.absent(),
    this.maxReps = const Value.absent(),
    this.targetDurationSec = const Value.absent(),
    this.targetDistanceMeters = const Value.absent(),
    this.restSeconds = const Value.absent(),
    this.eccentricSec = const Value.absent(),
    this.bottomPauseSec = const Value.absent(),
    this.concentricSec = const Value.absent(),
    this.topPauseSec = const Value.absent(),
    this.prescriptionNotes = const Value.absent(),
    this.formUrl = const Value.absent(),
  });
  SessionExercisesCompanion.insert({
    this.id = const Value.absent(),
    required int sessionId,
    required int exerciseId,
    required int position,
    this.targetSets = const Value.absent(),
    this.sidesPerSet = const Value.absent(),
    this.minReps = const Value.absent(),
    this.maxReps = const Value.absent(),
    this.targetDurationSec = const Value.absent(),
    this.targetDistanceMeters = const Value.absent(),
    this.restSeconds = const Value.absent(),
    this.eccentricSec = const Value.absent(),
    this.bottomPauseSec = const Value.absent(),
    this.concentricSec = const Value.absent(),
    this.topPauseSec = const Value.absent(),
    this.prescriptionNotes = const Value.absent(),
    this.formUrl = const Value.absent(),
  }) : sessionId = Value(sessionId),
       exerciseId = Value(exerciseId),
       position = Value(position);
  static Insertable<SessionExercise> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<int>? exerciseId,
    Expression<int>? position,
    Expression<int>? targetSets,
    Expression<int>? sidesPerSet,
    Expression<int>? minReps,
    Expression<int>? maxReps,
    Expression<int>? targetDurationSec,
    Expression<double>? targetDistanceMeters,
    Expression<int>? restSeconds,
    Expression<int>? eccentricSec,
    Expression<int>? bottomPauseSec,
    Expression<int>? concentricSec,
    Expression<int>? topPauseSec,
    Expression<String>? prescriptionNotes,
    Expression<String>? formUrl,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (position != null) 'position': position,
      if (targetSets != null) 'target_sets': targetSets,
      if (sidesPerSet != null) 'sides_per_set': sidesPerSet,
      if (minReps != null) 'min_reps': minReps,
      if (maxReps != null) 'max_reps': maxReps,
      if (targetDurationSec != null) 'target_duration_sec': targetDurationSec,
      if (targetDistanceMeters != null)
        'target_distance_meters': targetDistanceMeters,
      if (restSeconds != null) 'rest_seconds': restSeconds,
      if (eccentricSec != null) 'eccentric_sec': eccentricSec,
      if (bottomPauseSec != null) 'bottom_pause_sec': bottomPauseSec,
      if (concentricSec != null) 'concentric_sec': concentricSec,
      if (topPauseSec != null) 'top_pause_sec': topPauseSec,
      if (prescriptionNotes != null) 'prescription_notes': prescriptionNotes,
      if (formUrl != null) 'form_url': formUrl,
    });
  }

  SessionExercisesCompanion copyWith({
    Value<int>? id,
    Value<int>? sessionId,
    Value<int>? exerciseId,
    Value<int>? position,
    Value<int?>? targetSets,
    Value<int?>? sidesPerSet,
    Value<int?>? minReps,
    Value<int?>? maxReps,
    Value<int?>? targetDurationSec,
    Value<double?>? targetDistanceMeters,
    Value<int?>? restSeconds,
    Value<int?>? eccentricSec,
    Value<int?>? bottomPauseSec,
    Value<int?>? concentricSec,
    Value<int?>? topPauseSec,
    Value<String?>? prescriptionNotes,
    Value<String?>? formUrl,
  }) {
    return SessionExercisesCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      exerciseId: exerciseId ?? this.exerciseId,
      position: position ?? this.position,
      targetSets: targetSets ?? this.targetSets,
      sidesPerSet: sidesPerSet ?? this.sidesPerSet,
      minReps: minReps ?? this.minReps,
      maxReps: maxReps ?? this.maxReps,
      targetDurationSec: targetDurationSec ?? this.targetDurationSec,
      targetDistanceMeters: targetDistanceMeters ?? this.targetDistanceMeters,
      restSeconds: restSeconds ?? this.restSeconds,
      eccentricSec: eccentricSec ?? this.eccentricSec,
      bottomPauseSec: bottomPauseSec ?? this.bottomPauseSec,
      concentricSec: concentricSec ?? this.concentricSec,
      topPauseSec: topPauseSec ?? this.topPauseSec,
      prescriptionNotes: prescriptionNotes ?? this.prescriptionNotes,
      formUrl: formUrl ?? this.formUrl,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<int>(exerciseId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (targetSets.present) {
      map['target_sets'] = Variable<int>(targetSets.value);
    }
    if (sidesPerSet.present) {
      map['sides_per_set'] = Variable<int>(sidesPerSet.value);
    }
    if (minReps.present) {
      map['min_reps'] = Variable<int>(minReps.value);
    }
    if (maxReps.present) {
      map['max_reps'] = Variable<int>(maxReps.value);
    }
    if (targetDurationSec.present) {
      map['target_duration_sec'] = Variable<int>(targetDurationSec.value);
    }
    if (targetDistanceMeters.present) {
      map['target_distance_meters'] = Variable<double>(
        targetDistanceMeters.value,
      );
    }
    if (restSeconds.present) {
      map['rest_seconds'] = Variable<int>(restSeconds.value);
    }
    if (eccentricSec.present) {
      map['eccentric_sec'] = Variable<int>(eccentricSec.value);
    }
    if (bottomPauseSec.present) {
      map['bottom_pause_sec'] = Variable<int>(bottomPauseSec.value);
    }
    if (concentricSec.present) {
      map['concentric_sec'] = Variable<int>(concentricSec.value);
    }
    if (topPauseSec.present) {
      map['top_pause_sec'] = Variable<int>(topPauseSec.value);
    }
    if (prescriptionNotes.present) {
      map['prescription_notes'] = Variable<String>(prescriptionNotes.value);
    }
    if (formUrl.present) {
      map['form_url'] = Variable<String>(formUrl.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionExercisesCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('position: $position, ')
          ..write('targetSets: $targetSets, ')
          ..write('sidesPerSet: $sidesPerSet, ')
          ..write('minReps: $minReps, ')
          ..write('maxReps: $maxReps, ')
          ..write('targetDurationSec: $targetDurationSec, ')
          ..write('targetDistanceMeters: $targetDistanceMeters, ')
          ..write('restSeconds: $restSeconds, ')
          ..write('eccentricSec: $eccentricSec, ')
          ..write('bottomPauseSec: $bottomPauseSec, ')
          ..write('concentricSec: $concentricSec, ')
          ..write('topPauseSec: $topPauseSec, ')
          ..write('prescriptionNotes: $prescriptionNotes, ')
          ..write('formUrl: $formUrl')
          ..write(')'))
        .toString();
  }
}

class $SetEntriesTable extends SetEntries
    with TableInfo<$SetEntriesTable, SetEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SetEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sessionExerciseIdMeta = const VerificationMeta(
    'sessionExerciseId',
  );
  @override
  late final GeneratedColumn<int> sessionExerciseId = GeneratedColumn<int>(
    'session_exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES session_exercises (id)',
    ),
  );
  static const VerificationMeta _setNumberMeta = const VerificationMeta(
    'setNumber',
  );
  @override
  late final GeneratedColumn<int> setNumber = GeneratedColumn<int>(
    'set_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weightValueMeta = const VerificationMeta(
    'weightValue',
  );
  @override
  late final GeneratedColumn<double> weightValue = GeneratedColumn<double>(
    'weight_value',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<WeightUnit?, String> unit =
      GeneratedColumn<String>(
        'unit',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<WeightUnit?>($SetEntriesTable.$converterunitn);
  @override
  late final GeneratedColumnWithTypeConverter<WeightEntry, String> weightEntry =
      GeneratedColumn<String>(
        'weight_entry',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('total'),
      ).withConverter<WeightEntry>($SetEntriesTable.$converterweightEntry);
  static const VerificationMeta _sideCountMeta = const VerificationMeta(
    'sideCount',
  );
  @override
  late final GeneratedColumn<int> sideCount = GeneratedColumn<int>(
    'side_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  late final GeneratedColumnWithTypeConverter<LoadingMode, String> loadingMode =
      GeneratedColumn<String>(
        'loading_mode',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('external'),
      ).withConverter<LoadingMode>($SetEntriesTable.$converterloadingMode);
  static const VerificationMeta _distanceMetersMeta = const VerificationMeta(
    'distanceMeters',
  );
  @override
  late final GeneratedColumn<double> distanceMeters = GeneratedColumn<double>(
    'distance_meters',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecMeta = const VerificationMeta(
    'durationSec',
  );
  @override
  late final GeneratedColumn<int> durationSec = GeneratedColumn<int>(
    'duration_sec',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isWarmupMeta = const VerificationMeta(
    'isWarmup',
  );
  @override
  late final GeneratedColumn<bool> isWarmup = GeneratedColumn<bool>(
    'is_warmup',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_warmup" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _rpeMeta = const VerificationMeta('rpe');
  @override
  late final GeneratedColumn<double> rpe = GeneratedColumn<double>(
    'rpe',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionExerciseId,
    setNumber,
    reps,
    weightValue,
    unit,
    weightEntry,
    sideCount,
    loadingMode,
    distanceMeters,
    durationSec,
    isWarmup,
    rpe,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'set_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SetEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_exercise_id')) {
      context.handle(
        _sessionExerciseIdMeta,
        sessionExerciseId.isAcceptableOrUnknown(
          data['session_exercise_id']!,
          _sessionExerciseIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sessionExerciseIdMeta);
    }
    if (data.containsKey('set_number')) {
      context.handle(
        _setNumberMeta,
        setNumber.isAcceptableOrUnknown(data['set_number']!, _setNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_setNumberMeta);
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    }
    if (data.containsKey('weight_value')) {
      context.handle(
        _weightValueMeta,
        weightValue.isAcceptableOrUnknown(
          data['weight_value']!,
          _weightValueMeta,
        ),
      );
    }
    if (data.containsKey('side_count')) {
      context.handle(
        _sideCountMeta,
        sideCount.isAcceptableOrUnknown(data['side_count']!, _sideCountMeta),
      );
    }
    if (data.containsKey('distance_meters')) {
      context.handle(
        _distanceMetersMeta,
        distanceMeters.isAcceptableOrUnknown(
          data['distance_meters']!,
          _distanceMetersMeta,
        ),
      );
    }
    if (data.containsKey('duration_sec')) {
      context.handle(
        _durationSecMeta,
        durationSec.isAcceptableOrUnknown(
          data['duration_sec']!,
          _durationSecMeta,
        ),
      );
    }
    if (data.containsKey('is_warmup')) {
      context.handle(
        _isWarmupMeta,
        isWarmup.isAcceptableOrUnknown(data['is_warmup']!, _isWarmupMeta),
      );
    }
    if (data.containsKey('rpe')) {
      context.handle(
        _rpeMeta,
        rpe.isAcceptableOrUnknown(data['rpe']!, _rpeMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SetEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SetEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionExerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_exercise_id'],
      )!,
      setNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}set_number'],
      )!,
      reps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps'],
      ),
      weightValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_value'],
      ),
      unit: $SetEntriesTable.$converterunitn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}unit'],
        ),
      ),
      weightEntry: $SetEntriesTable.$converterweightEntry.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}weight_entry'],
        )!,
      ),
      sideCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}side_count'],
      )!,
      loadingMode: $SetEntriesTable.$converterloadingMode.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}loading_mode'],
        )!,
      ),
      distanceMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}distance_meters'],
      ),
      durationSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_sec'],
      ),
      isWarmup: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_warmup'],
      )!,
      rpe: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rpe'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $SetEntriesTable createAlias(String alias) {
    return $SetEntriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<WeightUnit, String, String> $converterunit =
      const EnumNameConverter<WeightUnit>(WeightUnit.values);
  static JsonTypeConverter2<WeightUnit?, String?, String?> $converterunitn =
      JsonTypeConverter2.asNullable($converterunit);
  static JsonTypeConverter2<WeightEntry, String, String> $converterweightEntry =
      const EnumNameConverter<WeightEntry>(WeightEntry.values);
  static JsonTypeConverter2<LoadingMode, String, String> $converterloadingMode =
      const EnumNameConverter<LoadingMode>(LoadingMode.values);
}

class SetEntry extends DataClass implements Insertable<SetEntry> {
  final int id;
  final int sessionExerciseId;
  final int setNumber;
  final int? reps;
  final double? weightValue;
  final WeightUnit? unit;
  final WeightEntry weightEntry;
  final int sideCount;
  final LoadingMode loadingMode;
  final double? distanceMeters;
  final int? durationSec;
  final bool isWarmup;
  final double? rpe;
  final String? notes;
  const SetEntry({
    required this.id,
    required this.sessionExerciseId,
    required this.setNumber,
    this.reps,
    this.weightValue,
    this.unit,
    required this.weightEntry,
    required this.sideCount,
    required this.loadingMode,
    this.distanceMeters,
    this.durationSec,
    required this.isWarmup,
    this.rpe,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_exercise_id'] = Variable<int>(sessionExerciseId);
    map['set_number'] = Variable<int>(setNumber);
    if (!nullToAbsent || reps != null) {
      map['reps'] = Variable<int>(reps);
    }
    if (!nullToAbsent || weightValue != null) {
      map['weight_value'] = Variable<double>(weightValue);
    }
    if (!nullToAbsent || unit != null) {
      map['unit'] = Variable<String>(
        $SetEntriesTable.$converterunitn.toSql(unit),
      );
    }
    {
      map['weight_entry'] = Variable<String>(
        $SetEntriesTable.$converterweightEntry.toSql(weightEntry),
      );
    }
    map['side_count'] = Variable<int>(sideCount);
    {
      map['loading_mode'] = Variable<String>(
        $SetEntriesTable.$converterloadingMode.toSql(loadingMode),
      );
    }
    if (!nullToAbsent || distanceMeters != null) {
      map['distance_meters'] = Variable<double>(distanceMeters);
    }
    if (!nullToAbsent || durationSec != null) {
      map['duration_sec'] = Variable<int>(durationSec);
    }
    map['is_warmup'] = Variable<bool>(isWarmup);
    if (!nullToAbsent || rpe != null) {
      map['rpe'] = Variable<double>(rpe);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  SetEntriesCompanion toCompanion(bool nullToAbsent) {
    return SetEntriesCompanion(
      id: Value(id),
      sessionExerciseId: Value(sessionExerciseId),
      setNumber: Value(setNumber),
      reps: reps == null && nullToAbsent ? const Value.absent() : Value(reps),
      weightValue: weightValue == null && nullToAbsent
          ? const Value.absent()
          : Value(weightValue),
      unit: unit == null && nullToAbsent ? const Value.absent() : Value(unit),
      weightEntry: Value(weightEntry),
      sideCount: Value(sideCount),
      loadingMode: Value(loadingMode),
      distanceMeters: distanceMeters == null && nullToAbsent
          ? const Value.absent()
          : Value(distanceMeters),
      durationSec: durationSec == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSec),
      isWarmup: Value(isWarmup),
      rpe: rpe == null && nullToAbsent ? const Value.absent() : Value(rpe),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory SetEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SetEntry(
      id: serializer.fromJson<int>(json['id']),
      sessionExerciseId: serializer.fromJson<int>(json['sessionExerciseId']),
      setNumber: serializer.fromJson<int>(json['setNumber']),
      reps: serializer.fromJson<int?>(json['reps']),
      weightValue: serializer.fromJson<double?>(json['weightValue']),
      unit: $SetEntriesTable.$converterunitn.fromJson(
        serializer.fromJson<String?>(json['unit']),
      ),
      weightEntry: $SetEntriesTable.$converterweightEntry.fromJson(
        serializer.fromJson<String>(json['weightEntry']),
      ),
      sideCount: serializer.fromJson<int>(json['sideCount']),
      loadingMode: $SetEntriesTable.$converterloadingMode.fromJson(
        serializer.fromJson<String>(json['loadingMode']),
      ),
      distanceMeters: serializer.fromJson<double?>(json['distanceMeters']),
      durationSec: serializer.fromJson<int?>(json['durationSec']),
      isWarmup: serializer.fromJson<bool>(json['isWarmup']),
      rpe: serializer.fromJson<double?>(json['rpe']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionExerciseId': serializer.toJson<int>(sessionExerciseId),
      'setNumber': serializer.toJson<int>(setNumber),
      'reps': serializer.toJson<int?>(reps),
      'weightValue': serializer.toJson<double?>(weightValue),
      'unit': serializer.toJson<String?>(
        $SetEntriesTable.$converterunitn.toJson(unit),
      ),
      'weightEntry': serializer.toJson<String>(
        $SetEntriesTable.$converterweightEntry.toJson(weightEntry),
      ),
      'sideCount': serializer.toJson<int>(sideCount),
      'loadingMode': serializer.toJson<String>(
        $SetEntriesTable.$converterloadingMode.toJson(loadingMode),
      ),
      'distanceMeters': serializer.toJson<double?>(distanceMeters),
      'durationSec': serializer.toJson<int?>(durationSec),
      'isWarmup': serializer.toJson<bool>(isWarmup),
      'rpe': serializer.toJson<double?>(rpe),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  SetEntry copyWith({
    int? id,
    int? sessionExerciseId,
    int? setNumber,
    Value<int?> reps = const Value.absent(),
    Value<double?> weightValue = const Value.absent(),
    Value<WeightUnit?> unit = const Value.absent(),
    WeightEntry? weightEntry,
    int? sideCount,
    LoadingMode? loadingMode,
    Value<double?> distanceMeters = const Value.absent(),
    Value<int?> durationSec = const Value.absent(),
    bool? isWarmup,
    Value<double?> rpe = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => SetEntry(
    id: id ?? this.id,
    sessionExerciseId: sessionExerciseId ?? this.sessionExerciseId,
    setNumber: setNumber ?? this.setNumber,
    reps: reps.present ? reps.value : this.reps,
    weightValue: weightValue.present ? weightValue.value : this.weightValue,
    unit: unit.present ? unit.value : this.unit,
    weightEntry: weightEntry ?? this.weightEntry,
    sideCount: sideCount ?? this.sideCount,
    loadingMode: loadingMode ?? this.loadingMode,
    distanceMeters: distanceMeters.present
        ? distanceMeters.value
        : this.distanceMeters,
    durationSec: durationSec.present ? durationSec.value : this.durationSec,
    isWarmup: isWarmup ?? this.isWarmup,
    rpe: rpe.present ? rpe.value : this.rpe,
    notes: notes.present ? notes.value : this.notes,
  );
  SetEntry copyWithCompanion(SetEntriesCompanion data) {
    return SetEntry(
      id: data.id.present ? data.id.value : this.id,
      sessionExerciseId: data.sessionExerciseId.present
          ? data.sessionExerciseId.value
          : this.sessionExerciseId,
      setNumber: data.setNumber.present ? data.setNumber.value : this.setNumber,
      reps: data.reps.present ? data.reps.value : this.reps,
      weightValue: data.weightValue.present
          ? data.weightValue.value
          : this.weightValue,
      unit: data.unit.present ? data.unit.value : this.unit,
      weightEntry: data.weightEntry.present
          ? data.weightEntry.value
          : this.weightEntry,
      sideCount: data.sideCount.present ? data.sideCount.value : this.sideCount,
      loadingMode: data.loadingMode.present
          ? data.loadingMode.value
          : this.loadingMode,
      distanceMeters: data.distanceMeters.present
          ? data.distanceMeters.value
          : this.distanceMeters,
      durationSec: data.durationSec.present
          ? data.durationSec.value
          : this.durationSec,
      isWarmup: data.isWarmup.present ? data.isWarmup.value : this.isWarmup,
      rpe: data.rpe.present ? data.rpe.value : this.rpe,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SetEntry(')
          ..write('id: $id, ')
          ..write('sessionExerciseId: $sessionExerciseId, ')
          ..write('setNumber: $setNumber, ')
          ..write('reps: $reps, ')
          ..write('weightValue: $weightValue, ')
          ..write('unit: $unit, ')
          ..write('weightEntry: $weightEntry, ')
          ..write('sideCount: $sideCount, ')
          ..write('loadingMode: $loadingMode, ')
          ..write('distanceMeters: $distanceMeters, ')
          ..write('durationSec: $durationSec, ')
          ..write('isWarmup: $isWarmup, ')
          ..write('rpe: $rpe, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionExerciseId,
    setNumber,
    reps,
    weightValue,
    unit,
    weightEntry,
    sideCount,
    loadingMode,
    distanceMeters,
    durationSec,
    isWarmup,
    rpe,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SetEntry &&
          other.id == this.id &&
          other.sessionExerciseId == this.sessionExerciseId &&
          other.setNumber == this.setNumber &&
          other.reps == this.reps &&
          other.weightValue == this.weightValue &&
          other.unit == this.unit &&
          other.weightEntry == this.weightEntry &&
          other.sideCount == this.sideCount &&
          other.loadingMode == this.loadingMode &&
          other.distanceMeters == this.distanceMeters &&
          other.durationSec == this.durationSec &&
          other.isWarmup == this.isWarmup &&
          other.rpe == this.rpe &&
          other.notes == this.notes);
}

class SetEntriesCompanion extends UpdateCompanion<SetEntry> {
  final Value<int> id;
  final Value<int> sessionExerciseId;
  final Value<int> setNumber;
  final Value<int?> reps;
  final Value<double?> weightValue;
  final Value<WeightUnit?> unit;
  final Value<WeightEntry> weightEntry;
  final Value<int> sideCount;
  final Value<LoadingMode> loadingMode;
  final Value<double?> distanceMeters;
  final Value<int?> durationSec;
  final Value<bool> isWarmup;
  final Value<double?> rpe;
  final Value<String?> notes;
  const SetEntriesCompanion({
    this.id = const Value.absent(),
    this.sessionExerciseId = const Value.absent(),
    this.setNumber = const Value.absent(),
    this.reps = const Value.absent(),
    this.weightValue = const Value.absent(),
    this.unit = const Value.absent(),
    this.weightEntry = const Value.absent(),
    this.sideCount = const Value.absent(),
    this.loadingMode = const Value.absent(),
    this.distanceMeters = const Value.absent(),
    this.durationSec = const Value.absent(),
    this.isWarmup = const Value.absent(),
    this.rpe = const Value.absent(),
    this.notes = const Value.absent(),
  });
  SetEntriesCompanion.insert({
    this.id = const Value.absent(),
    required int sessionExerciseId,
    required int setNumber,
    this.reps = const Value.absent(),
    this.weightValue = const Value.absent(),
    this.unit = const Value.absent(),
    this.weightEntry = const Value.absent(),
    this.sideCount = const Value.absent(),
    this.loadingMode = const Value.absent(),
    this.distanceMeters = const Value.absent(),
    this.durationSec = const Value.absent(),
    this.isWarmup = const Value.absent(),
    this.rpe = const Value.absent(),
    this.notes = const Value.absent(),
  }) : sessionExerciseId = Value(sessionExerciseId),
       setNumber = Value(setNumber);
  static Insertable<SetEntry> custom({
    Expression<int>? id,
    Expression<int>? sessionExerciseId,
    Expression<int>? setNumber,
    Expression<int>? reps,
    Expression<double>? weightValue,
    Expression<String>? unit,
    Expression<String>? weightEntry,
    Expression<int>? sideCount,
    Expression<String>? loadingMode,
    Expression<double>? distanceMeters,
    Expression<int>? durationSec,
    Expression<bool>? isWarmup,
    Expression<double>? rpe,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionExerciseId != null) 'session_exercise_id': sessionExerciseId,
      if (setNumber != null) 'set_number': setNumber,
      if (reps != null) 'reps': reps,
      if (weightValue != null) 'weight_value': weightValue,
      if (unit != null) 'unit': unit,
      if (weightEntry != null) 'weight_entry': weightEntry,
      if (sideCount != null) 'side_count': sideCount,
      if (loadingMode != null) 'loading_mode': loadingMode,
      if (distanceMeters != null) 'distance_meters': distanceMeters,
      if (durationSec != null) 'duration_sec': durationSec,
      if (isWarmup != null) 'is_warmup': isWarmup,
      if (rpe != null) 'rpe': rpe,
      if (notes != null) 'notes': notes,
    });
  }

  SetEntriesCompanion copyWith({
    Value<int>? id,
    Value<int>? sessionExerciseId,
    Value<int>? setNumber,
    Value<int?>? reps,
    Value<double?>? weightValue,
    Value<WeightUnit?>? unit,
    Value<WeightEntry>? weightEntry,
    Value<int>? sideCount,
    Value<LoadingMode>? loadingMode,
    Value<double?>? distanceMeters,
    Value<int?>? durationSec,
    Value<bool>? isWarmup,
    Value<double?>? rpe,
    Value<String?>? notes,
  }) {
    return SetEntriesCompanion(
      id: id ?? this.id,
      sessionExerciseId: sessionExerciseId ?? this.sessionExerciseId,
      setNumber: setNumber ?? this.setNumber,
      reps: reps ?? this.reps,
      weightValue: weightValue ?? this.weightValue,
      unit: unit ?? this.unit,
      weightEntry: weightEntry ?? this.weightEntry,
      sideCount: sideCount ?? this.sideCount,
      loadingMode: loadingMode ?? this.loadingMode,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSec: durationSec ?? this.durationSec,
      isWarmup: isWarmup ?? this.isWarmup,
      rpe: rpe ?? this.rpe,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionExerciseId.present) {
      map['session_exercise_id'] = Variable<int>(sessionExerciseId.value);
    }
    if (setNumber.present) {
      map['set_number'] = Variable<int>(setNumber.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (weightValue.present) {
      map['weight_value'] = Variable<double>(weightValue.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(
        $SetEntriesTable.$converterunitn.toSql(unit.value),
      );
    }
    if (weightEntry.present) {
      map['weight_entry'] = Variable<String>(
        $SetEntriesTable.$converterweightEntry.toSql(weightEntry.value),
      );
    }
    if (sideCount.present) {
      map['side_count'] = Variable<int>(sideCount.value);
    }
    if (loadingMode.present) {
      map['loading_mode'] = Variable<String>(
        $SetEntriesTable.$converterloadingMode.toSql(loadingMode.value),
      );
    }
    if (distanceMeters.present) {
      map['distance_meters'] = Variable<double>(distanceMeters.value);
    }
    if (durationSec.present) {
      map['duration_sec'] = Variable<int>(durationSec.value);
    }
    if (isWarmup.present) {
      map['is_warmup'] = Variable<bool>(isWarmup.value);
    }
    if (rpe.present) {
      map['rpe'] = Variable<double>(rpe.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SetEntriesCompanion(')
          ..write('id: $id, ')
          ..write('sessionExerciseId: $sessionExerciseId, ')
          ..write('setNumber: $setNumber, ')
          ..write('reps: $reps, ')
          ..write('weightValue: $weightValue, ')
          ..write('unit: $unit, ')
          ..write('weightEntry: $weightEntry, ')
          ..write('sideCount: $sideCount, ')
          ..write('loadingMode: $loadingMode, ')
          ..write('distanceMeters: $distanceMeters, ')
          ..write('durationSec: $durationSec, ')
          ..write('isWarmup: $isWarmup, ')
          ..write('rpe: $rpe, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $BodyweightEntriesTable extends BodyweightEntries
    with TableInfo<$BodyweightEntriesTable, BodyweightEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BodyweightEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<double> value = GeneratedColumn<double>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<WeightUnit, String> unit =
      GeneratedColumn<String>(
        'unit',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<WeightUnit>($BodyweightEntriesTable.$converterunit);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, date, value, unit, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bodyweight_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<BodyweightEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BodyweightEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BodyweightEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}value'],
      )!,
      unit: $BodyweightEntriesTable.$converterunit.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}unit'],
        )!,
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BodyweightEntriesTable createAlias(String alias) {
    return $BodyweightEntriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<WeightUnit, String, String> $converterunit =
      const EnumNameConverter<WeightUnit>(WeightUnit.values);
}

class BodyweightEntry extends DataClass implements Insertable<BodyweightEntry> {
  final int id;
  final DateTime date;
  final double value;
  final WeightUnit unit;
  final DateTime createdAt;
  const BodyweightEntry({
    required this.id,
    required this.date,
    required this.value,
    required this.unit,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    map['value'] = Variable<double>(value);
    {
      map['unit'] = Variable<String>(
        $BodyweightEntriesTable.$converterunit.toSql(unit),
      );
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BodyweightEntriesCompanion toCompanion(bool nullToAbsent) {
    return BodyweightEntriesCompanion(
      id: Value(id),
      date: Value(date),
      value: Value(value),
      unit: Value(unit),
      createdAt: Value(createdAt),
    );
  }

  factory BodyweightEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BodyweightEntry(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      value: serializer.fromJson<double>(json['value']),
      unit: $BodyweightEntriesTable.$converterunit.fromJson(
        serializer.fromJson<String>(json['unit']),
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'value': serializer.toJson<double>(value),
      'unit': serializer.toJson<String>(
        $BodyweightEntriesTable.$converterunit.toJson(unit),
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  BodyweightEntry copyWith({
    int? id,
    DateTime? date,
    double? value,
    WeightUnit? unit,
    DateTime? createdAt,
  }) => BodyweightEntry(
    id: id ?? this.id,
    date: date ?? this.date,
    value: value ?? this.value,
    unit: unit ?? this.unit,
    createdAt: createdAt ?? this.createdAt,
  );
  BodyweightEntry copyWithCompanion(BodyweightEntriesCompanion data) {
    return BodyweightEntry(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      value: data.value.present ? data.value.value : this.value,
      unit: data.unit.present ? data.unit.value : this.unit,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BodyweightEntry(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('value: $value, ')
          ..write('unit: $unit, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, date, value, unit, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BodyweightEntry &&
          other.id == this.id &&
          other.date == this.date &&
          other.value == this.value &&
          other.unit == this.unit &&
          other.createdAt == this.createdAt);
}

class BodyweightEntriesCompanion extends UpdateCompanion<BodyweightEntry> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<double> value;
  final Value<WeightUnit> unit;
  final Value<DateTime> createdAt;
  const BodyweightEntriesCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.value = const Value.absent(),
    this.unit = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  BodyweightEntriesCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    required double value,
    required WeightUnit unit,
    this.createdAt = const Value.absent(),
  }) : date = Value(date),
       value = Value(value),
       unit = Value(unit);
  static Insertable<BodyweightEntry> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<double>? value,
    Expression<String>? unit,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (value != null) 'value': value,
      if (unit != null) 'unit': unit,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  BodyweightEntriesCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<double>? value,
    Value<WeightUnit>? unit,
    Value<DateTime>? createdAt,
  }) {
    return BodyweightEntriesCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (value.present) {
      map['value'] = Variable<double>(value.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(
        $BodyweightEntriesTable.$converterunit.toSql(unit.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BodyweightEntriesCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('value: $value, ')
          ..write('unit: $unit, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $RestDaysTable extends RestDays with TableInfo<$RestDaysTable, RestDay> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RestDaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, date, note];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rest_days';
  @override
  VerificationContext validateIntegrity(
    Insertable<RestDay> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RestDay map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RestDay(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $RestDaysTable createAlias(String alias) {
    return $RestDaysTable(attachedDatabase, alias);
  }
}

class RestDay extends DataClass implements Insertable<RestDay> {
  final int id;
  final DateTime date;
  final String? note;
  const RestDay({required this.id, required this.date, this.note});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  RestDaysCompanion toCompanion(bool nullToAbsent) {
    return RestDaysCompanion(
      id: Value(id),
      date: Value(date),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory RestDay.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RestDay(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'note': serializer.toJson<String?>(note),
    };
  }

  RestDay copyWith({
    int? id,
    DateTime? date,
    Value<String?> note = const Value.absent(),
  }) => RestDay(
    id: id ?? this.id,
    date: date ?? this.date,
    note: note.present ? note.value : this.note,
  );
  RestDay copyWithCompanion(RestDaysCompanion data) {
    return RestDay(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RestDay(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, date, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RestDay &&
          other.id == this.id &&
          other.date == this.date &&
          other.note == this.note);
}

class RestDaysCompanion extends UpdateCompanion<RestDay> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<String?> note;
  const RestDaysCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.note = const Value.absent(),
  });
  RestDaysCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    this.note = const Value.absent(),
  }) : date = Value(date);
  static Insertable<RestDay> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<String>? note,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (note != null) 'note': note,
    });
  }

  RestDaysCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<String?>? note,
  }) {
    return RestDaysCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RestDaysCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  const AppSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSetting copyWith({String? key, String? value}) =>
      AppSetting(key: key ?? this.key, value: value ?? this.value);
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ExercisesTable exercises = $ExercisesTable(this);
  late final $TemplatesTable templates = $TemplatesTable(this);
  late final $TemplateExercisesTable templateExercises =
      $TemplateExercisesTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $SessionExercisesTable sessionExercises = $SessionExercisesTable(
    this,
  );
  late final $SetEntriesTable setEntries = $SetEntriesTable(this);
  late final $BodyweightEntriesTable bodyweightEntries =
      $BodyweightEntriesTable(this);
  late final $RestDaysTable restDays = $RestDaysTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    exercises,
    templates,
    templateExercises,
    sessions,
    sessionExercises,
    setEntries,
    bodyweightEntries,
    restDays,
    appSettings,
  ];
}

typedef $$ExercisesTableCreateCompanionBuilder =
    ExercisesCompanion Function({
      Value<int> id,
      required String name,
      required ExerciseCategory category,
      required String muscleGroup,
      Value<String> primaryMuscles,
      Value<String> secondaryMuscles,
      Value<WeightUnit> defaultUnit,
      Value<WeightEntry> weightEntry,
      Value<LoadingMode> preferredLoadingMode,
      Value<double> bodyweightFactor,
      Value<String?> videoUrl,
      Value<bool> isCustom,
      Value<bool> isArchived,
      Value<DateTime> createdAt,
    });
typedef $$ExercisesTableUpdateCompanionBuilder =
    ExercisesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<ExerciseCategory> category,
      Value<String> muscleGroup,
      Value<String> primaryMuscles,
      Value<String> secondaryMuscles,
      Value<WeightUnit> defaultUnit,
      Value<WeightEntry> weightEntry,
      Value<LoadingMode> preferredLoadingMode,
      Value<double> bodyweightFactor,
      Value<String?> videoUrl,
      Value<bool> isCustom,
      Value<bool> isArchived,
      Value<DateTime> createdAt,
    });

final class $$ExercisesTableReferences
    extends BaseReferences<_$AppDatabase, $ExercisesTable, Exercise> {
  $$ExercisesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TemplateExercisesTable, List<TemplateExercise>>
  _templateExercisesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.templateExercises,
        aliasName: 'exercises__id__template_exercises__exercise_id',
      );

  $$TemplateExercisesTableProcessedTableManager get templateExercisesRefs {
    final manager = $$TemplateExercisesTableTableManager(
      $_db,
      $_db.templateExercises,
    ).filter((f) => f.exerciseId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _templateExercisesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SessionExercisesTable, List<SessionExercise>>
  _sessionExercisesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sessionExercises,
    aliasName: 'exercises__id__session_exercises__exercise_id',
  );

  $$SessionExercisesTableProcessedTableManager get sessionExercisesRefs {
    final manager = $$SessionExercisesTableTableManager(
      $_db,
      $_db.sessionExercises,
    ).filter((f) => f.exerciseId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _sessionExercisesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ExercisesTableFilterComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ExerciseCategory, ExerciseCategory, String>
  get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get muscleGroup => $composableBuilder(
    column: $table.muscleGroup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get primaryMuscles => $composableBuilder(
    column: $table.primaryMuscles,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get secondaryMuscles => $composableBuilder(
    column: $table.secondaryMuscles,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<WeightUnit, WeightUnit, String>
  get defaultUnit => $composableBuilder(
    column: $table.defaultUnit,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<WeightEntry, WeightEntry, String>
  get weightEntry => $composableBuilder(
    column: $table.weightEntry,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<LoadingMode, LoadingMode, String>
  get preferredLoadingMode => $composableBuilder(
    column: $table.preferredLoadingMode,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<double> get bodyweightFactor => $composableBuilder(
    column: $table.bodyweightFactor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoUrl => $composableBuilder(
    column: $table.videoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> templateExercisesRefs(
    Expression<bool> Function($$TemplateExercisesTableFilterComposer f) f,
  ) {
    final $$TemplateExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.templateExercises,
      getReferencedColumn: (t) => t.exerciseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TemplateExercisesTableFilterComposer(
            $db: $db,
            $table: $db.templateExercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> sessionExercisesRefs(
    Expression<bool> Function($$SessionExercisesTableFilterComposer f) f,
  ) {
    final $$SessionExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessionExercises,
      getReferencedColumn: (t) => t.exerciseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionExercisesTableFilterComposer(
            $db: $db,
            $table: $db.sessionExercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ExercisesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get muscleGroup => $composableBuilder(
    column: $table.muscleGroup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get primaryMuscles => $composableBuilder(
    column: $table.primaryMuscles,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get secondaryMuscles => $composableBuilder(
    column: $table.secondaryMuscles,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultUnit => $composableBuilder(
    column: $table.defaultUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weightEntry => $composableBuilder(
    column: $table.weightEntry,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredLoadingMode => $composableBuilder(
    column: $table.preferredLoadingMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get bodyweightFactor => $composableBuilder(
    column: $table.bodyweightFactor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoUrl => $composableBuilder(
    column: $table.videoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExercisesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ExerciseCategory, String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get muscleGroup => $composableBuilder(
    column: $table.muscleGroup,
    builder: (column) => column,
  );

  GeneratedColumn<String> get primaryMuscles => $composableBuilder(
    column: $table.primaryMuscles,
    builder: (column) => column,
  );

  GeneratedColumn<String> get secondaryMuscles => $composableBuilder(
    column: $table.secondaryMuscles,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<WeightUnit, String> get defaultUnit =>
      $composableBuilder(
        column: $table.defaultUnit,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<WeightEntry, String> get weightEntry =>
      $composableBuilder(
        column: $table.weightEntry,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<LoadingMode, String>
  get preferredLoadingMode => $composableBuilder(
    column: $table.preferredLoadingMode,
    builder: (column) => column,
  );

  GeneratedColumn<double> get bodyweightFactor => $composableBuilder(
    column: $table.bodyweightFactor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get videoUrl =>
      $composableBuilder(column: $table.videoUrl, builder: (column) => column);

  GeneratedColumn<bool> get isCustom =>
      $composableBuilder(column: $table.isCustom, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> templateExercisesRefs<T extends Object>(
    Expression<T> Function($$TemplateExercisesTableAnnotationComposer a) f,
  ) {
    final $$TemplateExercisesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.templateExercises,
          getReferencedColumn: (t) => t.exerciseId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TemplateExercisesTableAnnotationComposer(
                $db: $db,
                $table: $db.templateExercises,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> sessionExercisesRefs<T extends Object>(
    Expression<T> Function($$SessionExercisesTableAnnotationComposer a) f,
  ) {
    final $$SessionExercisesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessionExercises,
      getReferencedColumn: (t) => t.exerciseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionExercisesTableAnnotationComposer(
            $db: $db,
            $table: $db.sessionExercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ExercisesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExercisesTable,
          Exercise,
          $$ExercisesTableFilterComposer,
          $$ExercisesTableOrderingComposer,
          $$ExercisesTableAnnotationComposer,
          $$ExercisesTableCreateCompanionBuilder,
          $$ExercisesTableUpdateCompanionBuilder,
          (Exercise, $$ExercisesTableReferences),
          Exercise,
          PrefetchHooks Function({
            bool templateExercisesRefs,
            bool sessionExercisesRefs,
          })
        > {
  $$ExercisesTableTableManager(_$AppDatabase db, $ExercisesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExercisesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExercisesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExercisesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<ExerciseCategory> category = const Value.absent(),
                Value<String> muscleGroup = const Value.absent(),
                Value<String> primaryMuscles = const Value.absent(),
                Value<String> secondaryMuscles = const Value.absent(),
                Value<WeightUnit> defaultUnit = const Value.absent(),
                Value<WeightEntry> weightEntry = const Value.absent(),
                Value<LoadingMode> preferredLoadingMode = const Value.absent(),
                Value<double> bodyweightFactor = const Value.absent(),
                Value<String?> videoUrl = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ExercisesCompanion(
                id: id,
                name: name,
                category: category,
                muscleGroup: muscleGroup,
                primaryMuscles: primaryMuscles,
                secondaryMuscles: secondaryMuscles,
                defaultUnit: defaultUnit,
                weightEntry: weightEntry,
                preferredLoadingMode: preferredLoadingMode,
                bodyweightFactor: bodyweightFactor,
                videoUrl: videoUrl,
                isCustom: isCustom,
                isArchived: isArchived,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required ExerciseCategory category,
                required String muscleGroup,
                Value<String> primaryMuscles = const Value.absent(),
                Value<String> secondaryMuscles = const Value.absent(),
                Value<WeightUnit> defaultUnit = const Value.absent(),
                Value<WeightEntry> weightEntry = const Value.absent(),
                Value<LoadingMode> preferredLoadingMode = const Value.absent(),
                Value<double> bodyweightFactor = const Value.absent(),
                Value<String?> videoUrl = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ExercisesCompanion.insert(
                id: id,
                name: name,
                category: category,
                muscleGroup: muscleGroup,
                primaryMuscles: primaryMuscles,
                secondaryMuscles: secondaryMuscles,
                defaultUnit: defaultUnit,
                weightEntry: weightEntry,
                preferredLoadingMode: preferredLoadingMode,
                bodyweightFactor: bodyweightFactor,
                videoUrl: videoUrl,
                isCustom: isCustom,
                isArchived: isArchived,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ExercisesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({templateExercisesRefs = false, sessionExercisesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (templateExercisesRefs) db.templateExercises,
                    if (sessionExercisesRefs) db.sessionExercises,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (templateExercisesRefs)
                        await $_getPrefetchedData<
                          Exercise,
                          $ExercisesTable,
                          TemplateExercise
                        >(
                          currentTable: table,
                          referencedTable: $$ExercisesTableReferences
                              ._templateExercisesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ExercisesTableReferences(
                                db,
                                table,
                                p0,
                              ).templateExercisesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.exerciseId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (sessionExercisesRefs)
                        await $_getPrefetchedData<
                          Exercise,
                          $ExercisesTable,
                          SessionExercise
                        >(
                          currentTable: table,
                          referencedTable: $$ExercisesTableReferences
                              ._sessionExercisesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ExercisesTableReferences(
                                db,
                                table,
                                p0,
                              ).sessionExercisesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.exerciseId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ExercisesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExercisesTable,
      Exercise,
      $$ExercisesTableFilterComposer,
      $$ExercisesTableOrderingComposer,
      $$ExercisesTableAnnotationComposer,
      $$ExercisesTableCreateCompanionBuilder,
      $$ExercisesTableUpdateCompanionBuilder,
      (Exercise, $$ExercisesTableReferences),
      Exercise,
      PrefetchHooks Function({
        bool templateExercisesRefs,
        bool sessionExercisesRefs,
      })
    >;
typedef $$TemplatesTableCreateCompanionBuilder =
    TemplatesCompanion Function({
      Value<int> id,
      required String name,
      required int position,
      Value<DateTime> createdAt,
    });
typedef $$TemplatesTableUpdateCompanionBuilder =
    TemplatesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> position,
      Value<DateTime> createdAt,
    });

final class $$TemplatesTableReferences
    extends BaseReferences<_$AppDatabase, $TemplatesTable, Template> {
  $$TemplatesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TemplateExercisesTable, List<TemplateExercise>>
  _templateExercisesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.templateExercises,
        aliasName: 'templates__id__template_exercises__template_id',
      );

  $$TemplateExercisesTableProcessedTableManager get templateExercisesRefs {
    final manager = $$TemplateExercisesTableTableManager(
      $_db,
      $_db.templateExercises,
    ).filter((f) => f.templateId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _templateExercisesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SessionsTable, List<Session>> _sessionsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.sessions,
    aliasName: 'templates__id__sessions__template_id',
  );

  $$SessionsTableProcessedTableManager get sessionsRefs {
    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.templateId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_sessionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $TemplatesTable> {
  $$TemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> templateExercisesRefs(
    Expression<bool> Function($$TemplateExercisesTableFilterComposer f) f,
  ) {
    final $$TemplateExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.templateExercises,
      getReferencedColumn: (t) => t.templateId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TemplateExercisesTableFilterComposer(
            $db: $db,
            $table: $db.templateExercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> sessionsRefs(
    Expression<bool> Function($$SessionsTableFilterComposer f) f,
  ) {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.templateId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $TemplatesTable> {
  $$TemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TemplatesTable> {
  $$TemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> templateExercisesRefs<T extends Object>(
    Expression<T> Function($$TemplateExercisesTableAnnotationComposer a) f,
  ) {
    final $$TemplateExercisesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.templateExercises,
          getReferencedColumn: (t) => t.templateId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TemplateExercisesTableAnnotationComposer(
                $db: $db,
                $table: $db.templateExercises,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> sessionsRefs<T extends Object>(
    Expression<T> Function($$SessionsTableAnnotationComposer a) f,
  ) {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.templateId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TemplatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TemplatesTable,
          Template,
          $$TemplatesTableFilterComposer,
          $$TemplatesTableOrderingComposer,
          $$TemplatesTableAnnotationComposer,
          $$TemplatesTableCreateCompanionBuilder,
          $$TemplatesTableUpdateCompanionBuilder,
          (Template, $$TemplatesTableReferences),
          Template,
          PrefetchHooks Function({
            bool templateExercisesRefs,
            bool sessionsRefs,
          })
        > {
  $$TemplatesTableTableManager(_$AppDatabase db, $TemplatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TemplatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TemplatesCompanion(
                id: id,
                name: name,
                position: position,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required int position,
                Value<DateTime> createdAt = const Value.absent(),
              }) => TemplatesCompanion.insert(
                id: id,
                name: name,
                position: position,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TemplatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({templateExercisesRefs = false, sessionsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (templateExercisesRefs) db.templateExercises,
                    if (sessionsRefs) db.sessions,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (templateExercisesRefs)
                        await $_getPrefetchedData<
                          Template,
                          $TemplatesTable,
                          TemplateExercise
                        >(
                          currentTable: table,
                          referencedTable: $$TemplatesTableReferences
                              ._templateExercisesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TemplatesTableReferences(
                                db,
                                table,
                                p0,
                              ).templateExercisesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.templateId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (sessionsRefs)
                        await $_getPrefetchedData<
                          Template,
                          $TemplatesTable,
                          Session
                        >(
                          currentTable: table,
                          referencedTable: $$TemplatesTableReferences
                              ._sessionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TemplatesTableReferences(
                                db,
                                table,
                                p0,
                              ).sessionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.templateId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TemplatesTable,
      Template,
      $$TemplatesTableFilterComposer,
      $$TemplatesTableOrderingComposer,
      $$TemplatesTableAnnotationComposer,
      $$TemplatesTableCreateCompanionBuilder,
      $$TemplatesTableUpdateCompanionBuilder,
      (Template, $$TemplatesTableReferences),
      Template,
      PrefetchHooks Function({bool templateExercisesRefs, bool sessionsRefs})
    >;
typedef $$TemplateExercisesTableCreateCompanionBuilder =
    TemplateExercisesCompanion Function({
      Value<int> id,
      required int templateId,
      required int exerciseId,
      required int position,
      Value<int?> targetSets,
      Value<int?> sidesPerSet,
      Value<int?> minReps,
      Value<int?> maxReps,
      Value<int?> targetDurationSec,
      Value<double?> targetDistanceMeters,
      Value<int?> restSeconds,
      Value<int?> eccentricSec,
      Value<int?> bottomPauseSec,
      Value<int?> concentricSec,
      Value<int?> topPauseSec,
      Value<String?> prescriptionNotes,
      Value<String?> formUrl,
    });
typedef $$TemplateExercisesTableUpdateCompanionBuilder =
    TemplateExercisesCompanion Function({
      Value<int> id,
      Value<int> templateId,
      Value<int> exerciseId,
      Value<int> position,
      Value<int?> targetSets,
      Value<int?> sidesPerSet,
      Value<int?> minReps,
      Value<int?> maxReps,
      Value<int?> targetDurationSec,
      Value<double?> targetDistanceMeters,
      Value<int?> restSeconds,
      Value<int?> eccentricSec,
      Value<int?> bottomPauseSec,
      Value<int?> concentricSec,
      Value<int?> topPauseSec,
      Value<String?> prescriptionNotes,
      Value<String?> formUrl,
    });

final class $$TemplateExercisesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $TemplateExercisesTable,
          TemplateExercise
        > {
  $$TemplateExercisesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TemplatesTable _templateIdTable(_$AppDatabase db) => db.templates
      .createAlias('template_exercises__template_id__templates__id');

  $$TemplatesTableProcessedTableManager get templateId {
    final $_column = $_itemColumn<int>('template_id')!;

    final manager = $$TemplatesTableTableManager(
      $_db,
      $_db.templates,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_templateIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ExercisesTable _exerciseIdTable(_$AppDatabase db) => db.exercises
      .createAlias('template_exercises__exercise_id__exercises__id');

  $$ExercisesTableProcessedTableManager get exerciseId {
    final $_column = $_itemColumn<int>('exercise_id')!;

    final manager = $$ExercisesTableTableManager(
      $_db,
      $_db.exercises,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_exerciseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TemplateExercisesTableFilterComposer
    extends Composer<_$AppDatabase, $TemplateExercisesTable> {
  $$TemplateExercisesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetSets => $composableBuilder(
    column: $table.targetSets,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sidesPerSet => $composableBuilder(
    column: $table.sidesPerSet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minReps => $composableBuilder(
    column: $table.minReps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxReps => $composableBuilder(
    column: $table.maxReps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetDurationSec => $composableBuilder(
    column: $table.targetDurationSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get targetDistanceMeters => $composableBuilder(
    column: $table.targetDistanceMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get eccentricSec => $composableBuilder(
    column: $table.eccentricSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bottomPauseSec => $composableBuilder(
    column: $table.bottomPauseSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get concentricSec => $composableBuilder(
    column: $table.concentricSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get topPauseSec => $composableBuilder(
    column: $table.topPauseSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prescriptionNotes => $composableBuilder(
    column: $table.prescriptionNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get formUrl => $composableBuilder(
    column: $table.formUrl,
    builder: (column) => ColumnFilters(column),
  );

  $$TemplatesTableFilterComposer get templateId {
    final $$TemplatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateId,
      referencedTable: $db.templates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TemplatesTableFilterComposer(
            $db: $db,
            $table: $db.templates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableFilterComposer get exerciseId {
    final $$ExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableFilterComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TemplateExercisesTableOrderingComposer
    extends Composer<_$AppDatabase, $TemplateExercisesTable> {
  $$TemplateExercisesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetSets => $composableBuilder(
    column: $table.targetSets,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sidesPerSet => $composableBuilder(
    column: $table.sidesPerSet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minReps => $composableBuilder(
    column: $table.minReps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxReps => $composableBuilder(
    column: $table.maxReps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetDurationSec => $composableBuilder(
    column: $table.targetDurationSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get targetDistanceMeters => $composableBuilder(
    column: $table.targetDistanceMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get eccentricSec => $composableBuilder(
    column: $table.eccentricSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bottomPauseSec => $composableBuilder(
    column: $table.bottomPauseSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get concentricSec => $composableBuilder(
    column: $table.concentricSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get topPauseSec => $composableBuilder(
    column: $table.topPauseSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prescriptionNotes => $composableBuilder(
    column: $table.prescriptionNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get formUrl => $composableBuilder(
    column: $table.formUrl,
    builder: (column) => ColumnOrderings(column),
  );

  $$TemplatesTableOrderingComposer get templateId {
    final $$TemplatesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateId,
      referencedTable: $db.templates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TemplatesTableOrderingComposer(
            $db: $db,
            $table: $db.templates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableOrderingComposer get exerciseId {
    final $$ExercisesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableOrderingComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TemplateExercisesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TemplateExercisesTable> {
  $$TemplateExercisesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get targetSets => $composableBuilder(
    column: $table.targetSets,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sidesPerSet => $composableBuilder(
    column: $table.sidesPerSet,
    builder: (column) => column,
  );

  GeneratedColumn<int> get minReps =>
      $composableBuilder(column: $table.minReps, builder: (column) => column);

  GeneratedColumn<int> get maxReps =>
      $composableBuilder(column: $table.maxReps, builder: (column) => column);

  GeneratedColumn<int> get targetDurationSec => $composableBuilder(
    column: $table.targetDurationSec,
    builder: (column) => column,
  );

  GeneratedColumn<double> get targetDistanceMeters => $composableBuilder(
    column: $table.targetDistanceMeters,
    builder: (column) => column,
  );

  GeneratedColumn<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get eccentricSec => $composableBuilder(
    column: $table.eccentricSec,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bottomPauseSec => $composableBuilder(
    column: $table.bottomPauseSec,
    builder: (column) => column,
  );

  GeneratedColumn<int> get concentricSec => $composableBuilder(
    column: $table.concentricSec,
    builder: (column) => column,
  );

  GeneratedColumn<int> get topPauseSec => $composableBuilder(
    column: $table.topPauseSec,
    builder: (column) => column,
  );

  GeneratedColumn<String> get prescriptionNotes => $composableBuilder(
    column: $table.prescriptionNotes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get formUrl =>
      $composableBuilder(column: $table.formUrl, builder: (column) => column);

  $$TemplatesTableAnnotationComposer get templateId {
    final $$TemplatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateId,
      referencedTable: $db.templates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TemplatesTableAnnotationComposer(
            $db: $db,
            $table: $db.templates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableAnnotationComposer get exerciseId {
    final $$ExercisesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableAnnotationComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TemplateExercisesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TemplateExercisesTable,
          TemplateExercise,
          $$TemplateExercisesTableFilterComposer,
          $$TemplateExercisesTableOrderingComposer,
          $$TemplateExercisesTableAnnotationComposer,
          $$TemplateExercisesTableCreateCompanionBuilder,
          $$TemplateExercisesTableUpdateCompanionBuilder,
          (TemplateExercise, $$TemplateExercisesTableReferences),
          TemplateExercise,
          PrefetchHooks Function({bool templateId, bool exerciseId})
        > {
  $$TemplateExercisesTableTableManager(
    _$AppDatabase db,
    $TemplateExercisesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TemplateExercisesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TemplateExercisesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TemplateExercisesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> templateId = const Value.absent(),
                Value<int> exerciseId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int?> targetSets = const Value.absent(),
                Value<int?> sidesPerSet = const Value.absent(),
                Value<int?> minReps = const Value.absent(),
                Value<int?> maxReps = const Value.absent(),
                Value<int?> targetDurationSec = const Value.absent(),
                Value<double?> targetDistanceMeters = const Value.absent(),
                Value<int?> restSeconds = const Value.absent(),
                Value<int?> eccentricSec = const Value.absent(),
                Value<int?> bottomPauseSec = const Value.absent(),
                Value<int?> concentricSec = const Value.absent(),
                Value<int?> topPauseSec = const Value.absent(),
                Value<String?> prescriptionNotes = const Value.absent(),
                Value<String?> formUrl = const Value.absent(),
              }) => TemplateExercisesCompanion(
                id: id,
                templateId: templateId,
                exerciseId: exerciseId,
                position: position,
                targetSets: targetSets,
                sidesPerSet: sidesPerSet,
                minReps: minReps,
                maxReps: maxReps,
                targetDurationSec: targetDurationSec,
                targetDistanceMeters: targetDistanceMeters,
                restSeconds: restSeconds,
                eccentricSec: eccentricSec,
                bottomPauseSec: bottomPauseSec,
                concentricSec: concentricSec,
                topPauseSec: topPauseSec,
                prescriptionNotes: prescriptionNotes,
                formUrl: formUrl,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int templateId,
                required int exerciseId,
                required int position,
                Value<int?> targetSets = const Value.absent(),
                Value<int?> sidesPerSet = const Value.absent(),
                Value<int?> minReps = const Value.absent(),
                Value<int?> maxReps = const Value.absent(),
                Value<int?> targetDurationSec = const Value.absent(),
                Value<double?> targetDistanceMeters = const Value.absent(),
                Value<int?> restSeconds = const Value.absent(),
                Value<int?> eccentricSec = const Value.absent(),
                Value<int?> bottomPauseSec = const Value.absent(),
                Value<int?> concentricSec = const Value.absent(),
                Value<int?> topPauseSec = const Value.absent(),
                Value<String?> prescriptionNotes = const Value.absent(),
                Value<String?> formUrl = const Value.absent(),
              }) => TemplateExercisesCompanion.insert(
                id: id,
                templateId: templateId,
                exerciseId: exerciseId,
                position: position,
                targetSets: targetSets,
                sidesPerSet: sidesPerSet,
                minReps: minReps,
                maxReps: maxReps,
                targetDurationSec: targetDurationSec,
                targetDistanceMeters: targetDistanceMeters,
                restSeconds: restSeconds,
                eccentricSec: eccentricSec,
                bottomPauseSec: bottomPauseSec,
                concentricSec: concentricSec,
                topPauseSec: topPauseSec,
                prescriptionNotes: prescriptionNotes,
                formUrl: formUrl,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TemplateExercisesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({templateId = false, exerciseId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (templateId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.templateId,
                                referencedTable:
                                    $$TemplateExercisesTableReferences
                                        ._templateIdTable(db),
                                referencedColumn:
                                    $$TemplateExercisesTableReferences
                                        ._templateIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (exerciseId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.exerciseId,
                                referencedTable:
                                    $$TemplateExercisesTableReferences
                                        ._exerciseIdTable(db),
                                referencedColumn:
                                    $$TemplateExercisesTableReferences
                                        ._exerciseIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TemplateExercisesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TemplateExercisesTable,
      TemplateExercise,
      $$TemplateExercisesTableFilterComposer,
      $$TemplateExercisesTableOrderingComposer,
      $$TemplateExercisesTableAnnotationComposer,
      $$TemplateExercisesTableCreateCompanionBuilder,
      $$TemplateExercisesTableUpdateCompanionBuilder,
      (TemplateExercise, $$TemplateExercisesTableReferences),
      TemplateExercise,
      PrefetchHooks Function({bool templateId, bool exerciseId})
    >;
typedef $$SessionsTableCreateCompanionBuilder =
    SessionsCompanion Function({
      Value<int> id,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      Value<int?> templateId,
      Value<String?> notes,
    });
typedef $$SessionsTableUpdateCompanionBuilder =
    SessionsCompanion Function({
      Value<int> id,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<int?> templateId,
      Value<String?> notes,
    });

final class $$SessionsTableReferences
    extends BaseReferences<_$AppDatabase, $SessionsTable, Session> {
  $$SessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TemplatesTable _templateIdTable(_$AppDatabase db) =>
      db.templates.createAlias('sessions__template_id__templates__id');

  $$TemplatesTableProcessedTableManager? get templateId {
    final $_column = $_itemColumn<int>('template_id');
    if ($_column == null) return null;
    final manager = $$TemplatesTableTableManager(
      $_db,
      $_db.templates,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_templateIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SessionExercisesTable, List<SessionExercise>>
  _sessionExercisesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sessionExercises,
    aliasName: 'sessions__id__session_exercises__session_id',
  );

  $$SessionExercisesTableProcessedTableManager get sessionExercisesRefs {
    final manager = $$SessionExercisesTableTableManager(
      $_db,
      $_db.sessionExercises,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _sessionExercisesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$TemplatesTableFilterComposer get templateId {
    final $$TemplatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateId,
      referencedTable: $db.templates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TemplatesTableFilterComposer(
            $db: $db,
            $table: $db.templates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> sessionExercisesRefs(
    Expression<bool> Function($$SessionExercisesTableFilterComposer f) f,
  ) {
    final $$SessionExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessionExercises,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionExercisesTableFilterComposer(
            $db: $db,
            $table: $db.sessionExercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$TemplatesTableOrderingComposer get templateId {
    final $$TemplatesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateId,
      referencedTable: $db.templates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TemplatesTableOrderingComposer(
            $db: $db,
            $table: $db.templates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$TemplatesTableAnnotationComposer get templateId {
    final $$TemplatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateId,
      referencedTable: $db.templates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TemplatesTableAnnotationComposer(
            $db: $db,
            $table: $db.templates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> sessionExercisesRefs<T extends Object>(
    Expression<T> Function($$SessionExercisesTableAnnotationComposer a) f,
  ) {
    final $$SessionExercisesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessionExercises,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionExercisesTableAnnotationComposer(
            $db: $db,
            $table: $db.sessionExercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionsTable,
          Session,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (Session, $$SessionsTableReferences),
          Session,
          PrefetchHooks Function({bool templateId, bool sessionExercisesRefs})
        > {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int?> templateId = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                startedAt: startedAt,
                endedAt: endedAt,
                templateId: templateId,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int?> templateId = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => SessionsCompanion.insert(
                id: id,
                startedAt: startedAt,
                endedAt: endedAt,
                templateId: templateId,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({templateId = false, sessionExercisesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (sessionExercisesRefs) db.sessionExercises,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (templateId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.templateId,
                                    referencedTable: $$SessionsTableReferences
                                        ._templateIdTable(db),
                                    referencedColumn: $$SessionsTableReferences
                                        ._templateIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (sessionExercisesRefs)
                        await $_getPrefetchedData<
                          Session,
                          $SessionsTable,
                          SessionExercise
                        >(
                          currentTable: table,
                          referencedTable: $$SessionsTableReferences
                              ._sessionExercisesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).sessionExercisesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionsTable,
      Session,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (Session, $$SessionsTableReferences),
      Session,
      PrefetchHooks Function({bool templateId, bool sessionExercisesRefs})
    >;
typedef $$SessionExercisesTableCreateCompanionBuilder =
    SessionExercisesCompanion Function({
      Value<int> id,
      required int sessionId,
      required int exerciseId,
      required int position,
      Value<int?> targetSets,
      Value<int?> sidesPerSet,
      Value<int?> minReps,
      Value<int?> maxReps,
      Value<int?> targetDurationSec,
      Value<double?> targetDistanceMeters,
      Value<int?> restSeconds,
      Value<int?> eccentricSec,
      Value<int?> bottomPauseSec,
      Value<int?> concentricSec,
      Value<int?> topPauseSec,
      Value<String?> prescriptionNotes,
      Value<String?> formUrl,
    });
typedef $$SessionExercisesTableUpdateCompanionBuilder =
    SessionExercisesCompanion Function({
      Value<int> id,
      Value<int> sessionId,
      Value<int> exerciseId,
      Value<int> position,
      Value<int?> targetSets,
      Value<int?> sidesPerSet,
      Value<int?> minReps,
      Value<int?> maxReps,
      Value<int?> targetDurationSec,
      Value<double?> targetDistanceMeters,
      Value<int?> restSeconds,
      Value<int?> eccentricSec,
      Value<int?> bottomPauseSec,
      Value<int?> concentricSec,
      Value<int?> topPauseSec,
      Value<String?> prescriptionNotes,
      Value<String?> formUrl,
    });

final class $$SessionExercisesTableReferences
    extends
        BaseReferences<_$AppDatabase, $SessionExercisesTable, SessionExercise> {
  $$SessionExercisesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.sessions.createAlias('session_exercises__session_id__sessions__id');

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<int>('session_id')!;

    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ExercisesTable _exerciseIdTable(_$AppDatabase db) =>
      db.exercises.createAlias('session_exercises__exercise_id__exercises__id');

  $$ExercisesTableProcessedTableManager get exerciseId {
    final $_column = $_itemColumn<int>('exercise_id')!;

    final manager = $$ExercisesTableTableManager(
      $_db,
      $_db.exercises,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_exerciseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SetEntriesTable, List<SetEntry>>
  _setEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.setEntries,
    aliasName: 'session_exercises__id__set_entries__session_exercise_id',
  );

  $$SetEntriesTableProcessedTableManager get setEntriesRefs {
    final manager = $$SetEntriesTableTableManager(
      $_db,
      $_db.setEntries,
    ).filter((f) => f.sessionExerciseId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_setEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SessionExercisesTableFilterComposer
    extends Composer<_$AppDatabase, $SessionExercisesTable> {
  $$SessionExercisesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetSets => $composableBuilder(
    column: $table.targetSets,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sidesPerSet => $composableBuilder(
    column: $table.sidesPerSet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minReps => $composableBuilder(
    column: $table.minReps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxReps => $composableBuilder(
    column: $table.maxReps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetDurationSec => $composableBuilder(
    column: $table.targetDurationSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get targetDistanceMeters => $composableBuilder(
    column: $table.targetDistanceMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get eccentricSec => $composableBuilder(
    column: $table.eccentricSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bottomPauseSec => $composableBuilder(
    column: $table.bottomPauseSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get concentricSec => $composableBuilder(
    column: $table.concentricSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get topPauseSec => $composableBuilder(
    column: $table.topPauseSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prescriptionNotes => $composableBuilder(
    column: $table.prescriptionNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get formUrl => $composableBuilder(
    column: $table.formUrl,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableFilterComposer get exerciseId {
    final $$ExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableFilterComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> setEntriesRefs(
    Expression<bool> Function($$SetEntriesTableFilterComposer f) f,
  ) {
    final $$SetEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.setEntries,
      getReferencedColumn: (t) => t.sessionExerciseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetEntriesTableFilterComposer(
            $db: $db,
            $table: $db.setEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionExercisesTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionExercisesTable> {
  $$SessionExercisesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetSets => $composableBuilder(
    column: $table.targetSets,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sidesPerSet => $composableBuilder(
    column: $table.sidesPerSet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minReps => $composableBuilder(
    column: $table.minReps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxReps => $composableBuilder(
    column: $table.maxReps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetDurationSec => $composableBuilder(
    column: $table.targetDurationSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get targetDistanceMeters => $composableBuilder(
    column: $table.targetDistanceMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get eccentricSec => $composableBuilder(
    column: $table.eccentricSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bottomPauseSec => $composableBuilder(
    column: $table.bottomPauseSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get concentricSec => $composableBuilder(
    column: $table.concentricSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get topPauseSec => $composableBuilder(
    column: $table.topPauseSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prescriptionNotes => $composableBuilder(
    column: $table.prescriptionNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get formUrl => $composableBuilder(
    column: $table.formUrl,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableOrderingComposer get exerciseId {
    final $$ExercisesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableOrderingComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionExercisesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionExercisesTable> {
  $$SessionExercisesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get targetSets => $composableBuilder(
    column: $table.targetSets,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sidesPerSet => $composableBuilder(
    column: $table.sidesPerSet,
    builder: (column) => column,
  );

  GeneratedColumn<int> get minReps =>
      $composableBuilder(column: $table.minReps, builder: (column) => column);

  GeneratedColumn<int> get maxReps =>
      $composableBuilder(column: $table.maxReps, builder: (column) => column);

  GeneratedColumn<int> get targetDurationSec => $composableBuilder(
    column: $table.targetDurationSec,
    builder: (column) => column,
  );

  GeneratedColumn<double> get targetDistanceMeters => $composableBuilder(
    column: $table.targetDistanceMeters,
    builder: (column) => column,
  );

  GeneratedColumn<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get eccentricSec => $composableBuilder(
    column: $table.eccentricSec,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bottomPauseSec => $composableBuilder(
    column: $table.bottomPauseSec,
    builder: (column) => column,
  );

  GeneratedColumn<int> get concentricSec => $composableBuilder(
    column: $table.concentricSec,
    builder: (column) => column,
  );

  GeneratedColumn<int> get topPauseSec => $composableBuilder(
    column: $table.topPauseSec,
    builder: (column) => column,
  );

  GeneratedColumn<String> get prescriptionNotes => $composableBuilder(
    column: $table.prescriptionNotes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get formUrl =>
      $composableBuilder(column: $table.formUrl, builder: (column) => column);

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableAnnotationComposer get exerciseId {
    final $$ExercisesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableAnnotationComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> setEntriesRefs<T extends Object>(
    Expression<T> Function($$SetEntriesTableAnnotationComposer a) f,
  ) {
    final $$SetEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.setEntries,
      getReferencedColumn: (t) => t.sessionExerciseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.setEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionExercisesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionExercisesTable,
          SessionExercise,
          $$SessionExercisesTableFilterComposer,
          $$SessionExercisesTableOrderingComposer,
          $$SessionExercisesTableAnnotationComposer,
          $$SessionExercisesTableCreateCompanionBuilder,
          $$SessionExercisesTableUpdateCompanionBuilder,
          (SessionExercise, $$SessionExercisesTableReferences),
          SessionExercise,
          PrefetchHooks Function({
            bool sessionId,
            bool exerciseId,
            bool setEntriesRefs,
          })
        > {
  $$SessionExercisesTableTableManager(
    _$AppDatabase db,
    $SessionExercisesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionExercisesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionExercisesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionExercisesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> sessionId = const Value.absent(),
                Value<int> exerciseId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int?> targetSets = const Value.absent(),
                Value<int?> sidesPerSet = const Value.absent(),
                Value<int?> minReps = const Value.absent(),
                Value<int?> maxReps = const Value.absent(),
                Value<int?> targetDurationSec = const Value.absent(),
                Value<double?> targetDistanceMeters = const Value.absent(),
                Value<int?> restSeconds = const Value.absent(),
                Value<int?> eccentricSec = const Value.absent(),
                Value<int?> bottomPauseSec = const Value.absent(),
                Value<int?> concentricSec = const Value.absent(),
                Value<int?> topPauseSec = const Value.absent(),
                Value<String?> prescriptionNotes = const Value.absent(),
                Value<String?> formUrl = const Value.absent(),
              }) => SessionExercisesCompanion(
                id: id,
                sessionId: sessionId,
                exerciseId: exerciseId,
                position: position,
                targetSets: targetSets,
                sidesPerSet: sidesPerSet,
                minReps: minReps,
                maxReps: maxReps,
                targetDurationSec: targetDurationSec,
                targetDistanceMeters: targetDistanceMeters,
                restSeconds: restSeconds,
                eccentricSec: eccentricSec,
                bottomPauseSec: bottomPauseSec,
                concentricSec: concentricSec,
                topPauseSec: topPauseSec,
                prescriptionNotes: prescriptionNotes,
                formUrl: formUrl,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sessionId,
                required int exerciseId,
                required int position,
                Value<int?> targetSets = const Value.absent(),
                Value<int?> sidesPerSet = const Value.absent(),
                Value<int?> minReps = const Value.absent(),
                Value<int?> maxReps = const Value.absent(),
                Value<int?> targetDurationSec = const Value.absent(),
                Value<double?> targetDistanceMeters = const Value.absent(),
                Value<int?> restSeconds = const Value.absent(),
                Value<int?> eccentricSec = const Value.absent(),
                Value<int?> bottomPauseSec = const Value.absent(),
                Value<int?> concentricSec = const Value.absent(),
                Value<int?> topPauseSec = const Value.absent(),
                Value<String?> prescriptionNotes = const Value.absent(),
                Value<String?> formUrl = const Value.absent(),
              }) => SessionExercisesCompanion.insert(
                id: id,
                sessionId: sessionId,
                exerciseId: exerciseId,
                position: position,
                targetSets: targetSets,
                sidesPerSet: sidesPerSet,
                minReps: minReps,
                maxReps: maxReps,
                targetDurationSec: targetDurationSec,
                targetDistanceMeters: targetDistanceMeters,
                restSeconds: restSeconds,
                eccentricSec: eccentricSec,
                bottomPauseSec: bottomPauseSec,
                concentricSec: concentricSec,
                topPauseSec: topPauseSec,
                prescriptionNotes: prescriptionNotes,
                formUrl: formUrl,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SessionExercisesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                sessionId = false,
                exerciseId = false,
                setEntriesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [if (setEntriesRefs) db.setEntries],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (sessionId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.sessionId,
                                    referencedTable:
                                        $$SessionExercisesTableReferences
                                            ._sessionIdTable(db),
                                    referencedColumn:
                                        $$SessionExercisesTableReferences
                                            ._sessionIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (exerciseId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.exerciseId,
                                    referencedTable:
                                        $$SessionExercisesTableReferences
                                            ._exerciseIdTable(db),
                                    referencedColumn:
                                        $$SessionExercisesTableReferences
                                            ._exerciseIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (setEntriesRefs)
                        await $_getPrefetchedData<
                          SessionExercise,
                          $SessionExercisesTable,
                          SetEntry
                        >(
                          currentTable: table,
                          referencedTable: $$SessionExercisesTableReferences
                              ._setEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SessionExercisesTableReferences(
                                db,
                                table,
                                p0,
                              ).setEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionExerciseId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SessionExercisesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionExercisesTable,
      SessionExercise,
      $$SessionExercisesTableFilterComposer,
      $$SessionExercisesTableOrderingComposer,
      $$SessionExercisesTableAnnotationComposer,
      $$SessionExercisesTableCreateCompanionBuilder,
      $$SessionExercisesTableUpdateCompanionBuilder,
      (SessionExercise, $$SessionExercisesTableReferences),
      SessionExercise,
      PrefetchHooks Function({
        bool sessionId,
        bool exerciseId,
        bool setEntriesRefs,
      })
    >;
typedef $$SetEntriesTableCreateCompanionBuilder =
    SetEntriesCompanion Function({
      Value<int> id,
      required int sessionExerciseId,
      required int setNumber,
      Value<int?> reps,
      Value<double?> weightValue,
      Value<WeightUnit?> unit,
      Value<WeightEntry> weightEntry,
      Value<int> sideCount,
      Value<LoadingMode> loadingMode,
      Value<double?> distanceMeters,
      Value<int?> durationSec,
      Value<bool> isWarmup,
      Value<double?> rpe,
      Value<String?> notes,
    });
typedef $$SetEntriesTableUpdateCompanionBuilder =
    SetEntriesCompanion Function({
      Value<int> id,
      Value<int> sessionExerciseId,
      Value<int> setNumber,
      Value<int?> reps,
      Value<double?> weightValue,
      Value<WeightUnit?> unit,
      Value<WeightEntry> weightEntry,
      Value<int> sideCount,
      Value<LoadingMode> loadingMode,
      Value<double?> distanceMeters,
      Value<int?> durationSec,
      Value<bool> isWarmup,
      Value<double?> rpe,
      Value<String?> notes,
    });

final class $$SetEntriesTableReferences
    extends BaseReferences<_$AppDatabase, $SetEntriesTable, SetEntry> {
  $$SetEntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SessionExercisesTable _sessionExerciseIdTable(_$AppDatabase db) => db
      .sessionExercises
      .createAlias('set_entries__session_exercise_id__session_exercises__id');

  $$SessionExercisesTableProcessedTableManager get sessionExerciseId {
    final $_column = $_itemColumn<int>('session_exercise_id')!;

    final manager = $$SessionExercisesTableTableManager(
      $_db,
      $_db.sessionExercises,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionExerciseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SetEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $SetEntriesTable> {
  $$SetEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get setNumber => $composableBuilder(
    column: $table.setNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightValue => $composableBuilder(
    column: $table.weightValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<WeightUnit?, WeightUnit, String> get unit =>
      $composableBuilder(
        column: $table.unit,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<WeightEntry, WeightEntry, String>
  get weightEntry => $composableBuilder(
    column: $table.weightEntry,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get sideCount => $composableBuilder(
    column: $table.sideCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<LoadingMode, LoadingMode, String>
  get loadingMode => $composableBuilder(
    column: $table.loadingMode,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<double> get distanceMeters => $composableBuilder(
    column: $table.distanceMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isWarmup => $composableBuilder(
    column: $table.isWarmup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rpe => $composableBuilder(
    column: $table.rpe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionExercisesTableFilterComposer get sessionExerciseId {
    final $$SessionExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionExerciseId,
      referencedTable: $db.sessionExercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionExercisesTableFilterComposer(
            $db: $db,
            $table: $db.sessionExercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SetEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SetEntriesTable> {
  $$SetEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get setNumber => $composableBuilder(
    column: $table.setNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightValue => $composableBuilder(
    column: $table.weightValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weightEntry => $composableBuilder(
    column: $table.weightEntry,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sideCount => $composableBuilder(
    column: $table.sideCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loadingMode => $composableBuilder(
    column: $table.loadingMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get distanceMeters => $composableBuilder(
    column: $table.distanceMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isWarmup => $composableBuilder(
    column: $table.isWarmup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rpe => $composableBuilder(
    column: $table.rpe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionExercisesTableOrderingComposer get sessionExerciseId {
    final $$SessionExercisesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionExerciseId,
      referencedTable: $db.sessionExercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionExercisesTableOrderingComposer(
            $db: $db,
            $table: $db.sessionExercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SetEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SetEntriesTable> {
  $$SetEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get setNumber =>
      $composableBuilder(column: $table.setNumber, builder: (column) => column);

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<double> get weightValue => $composableBuilder(
    column: $table.weightValue,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<WeightUnit?, String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumnWithTypeConverter<WeightEntry, String> get weightEntry =>
      $composableBuilder(
        column: $table.weightEntry,
        builder: (column) => column,
      );

  GeneratedColumn<int> get sideCount =>
      $composableBuilder(column: $table.sideCount, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LoadingMode, String> get loadingMode =>
      $composableBuilder(
        column: $table.loadingMode,
        builder: (column) => column,
      );

  GeneratedColumn<double> get distanceMeters => $composableBuilder(
    column: $table.distanceMeters,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isWarmup =>
      $composableBuilder(column: $table.isWarmup, builder: (column) => column);

  GeneratedColumn<double> get rpe =>
      $composableBuilder(column: $table.rpe, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$SessionExercisesTableAnnotationComposer get sessionExerciseId {
    final $$SessionExercisesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionExerciseId,
      referencedTable: $db.sessionExercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionExercisesTableAnnotationComposer(
            $db: $db,
            $table: $db.sessionExercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SetEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SetEntriesTable,
          SetEntry,
          $$SetEntriesTableFilterComposer,
          $$SetEntriesTableOrderingComposer,
          $$SetEntriesTableAnnotationComposer,
          $$SetEntriesTableCreateCompanionBuilder,
          $$SetEntriesTableUpdateCompanionBuilder,
          (SetEntry, $$SetEntriesTableReferences),
          SetEntry,
          PrefetchHooks Function({bool sessionExerciseId})
        > {
  $$SetEntriesTableTableManager(_$AppDatabase db, $SetEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SetEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SetEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SetEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> sessionExerciseId = const Value.absent(),
                Value<int> setNumber = const Value.absent(),
                Value<int?> reps = const Value.absent(),
                Value<double?> weightValue = const Value.absent(),
                Value<WeightUnit?> unit = const Value.absent(),
                Value<WeightEntry> weightEntry = const Value.absent(),
                Value<int> sideCount = const Value.absent(),
                Value<LoadingMode> loadingMode = const Value.absent(),
                Value<double?> distanceMeters = const Value.absent(),
                Value<int?> durationSec = const Value.absent(),
                Value<bool> isWarmup = const Value.absent(),
                Value<double?> rpe = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => SetEntriesCompanion(
                id: id,
                sessionExerciseId: sessionExerciseId,
                setNumber: setNumber,
                reps: reps,
                weightValue: weightValue,
                unit: unit,
                weightEntry: weightEntry,
                sideCount: sideCount,
                loadingMode: loadingMode,
                distanceMeters: distanceMeters,
                durationSec: durationSec,
                isWarmup: isWarmup,
                rpe: rpe,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sessionExerciseId,
                required int setNumber,
                Value<int?> reps = const Value.absent(),
                Value<double?> weightValue = const Value.absent(),
                Value<WeightUnit?> unit = const Value.absent(),
                Value<WeightEntry> weightEntry = const Value.absent(),
                Value<int> sideCount = const Value.absent(),
                Value<LoadingMode> loadingMode = const Value.absent(),
                Value<double?> distanceMeters = const Value.absent(),
                Value<int?> durationSec = const Value.absent(),
                Value<bool> isWarmup = const Value.absent(),
                Value<double?> rpe = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => SetEntriesCompanion.insert(
                id: id,
                sessionExerciseId: sessionExerciseId,
                setNumber: setNumber,
                reps: reps,
                weightValue: weightValue,
                unit: unit,
                weightEntry: weightEntry,
                sideCount: sideCount,
                loadingMode: loadingMode,
                distanceMeters: distanceMeters,
                durationSec: durationSec,
                isWarmup: isWarmup,
                rpe: rpe,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SetEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionExerciseId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionExerciseId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionExerciseId,
                                referencedTable: $$SetEntriesTableReferences
                                    ._sessionExerciseIdTable(db),
                                referencedColumn: $$SetEntriesTableReferences
                                    ._sessionExerciseIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SetEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SetEntriesTable,
      SetEntry,
      $$SetEntriesTableFilterComposer,
      $$SetEntriesTableOrderingComposer,
      $$SetEntriesTableAnnotationComposer,
      $$SetEntriesTableCreateCompanionBuilder,
      $$SetEntriesTableUpdateCompanionBuilder,
      (SetEntry, $$SetEntriesTableReferences),
      SetEntry,
      PrefetchHooks Function({bool sessionExerciseId})
    >;
typedef $$BodyweightEntriesTableCreateCompanionBuilder =
    BodyweightEntriesCompanion Function({
      Value<int> id,
      required DateTime date,
      required double value,
      required WeightUnit unit,
      Value<DateTime> createdAt,
    });
typedef $$BodyweightEntriesTableUpdateCompanionBuilder =
    BodyweightEntriesCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<double> value,
      Value<WeightUnit> unit,
      Value<DateTime> createdAt,
    });

class $$BodyweightEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $BodyweightEntriesTable> {
  $$BodyweightEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<WeightUnit, WeightUnit, String> get unit =>
      $composableBuilder(
        column: $table.unit,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BodyweightEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $BodyweightEntriesTable> {
  $$BodyweightEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BodyweightEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BodyweightEntriesTable> {
  $$BodyweightEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<double> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumnWithTypeConverter<WeightUnit, String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BodyweightEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BodyweightEntriesTable,
          BodyweightEntry,
          $$BodyweightEntriesTableFilterComposer,
          $$BodyweightEntriesTableOrderingComposer,
          $$BodyweightEntriesTableAnnotationComposer,
          $$BodyweightEntriesTableCreateCompanionBuilder,
          $$BodyweightEntriesTableUpdateCompanionBuilder,
          (
            BodyweightEntry,
            BaseReferences<
              _$AppDatabase,
              $BodyweightEntriesTable,
              BodyweightEntry
            >,
          ),
          BodyweightEntry,
          PrefetchHooks Function()
        > {
  $$BodyweightEntriesTableTableManager(
    _$AppDatabase db,
    $BodyweightEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BodyweightEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BodyweightEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BodyweightEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<double> value = const Value.absent(),
                Value<WeightUnit> unit = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => BodyweightEntriesCompanion(
                id: id,
                date: date,
                value: value,
                unit: unit,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime date,
                required double value,
                required WeightUnit unit,
                Value<DateTime> createdAt = const Value.absent(),
              }) => BodyweightEntriesCompanion.insert(
                id: id,
                date: date,
                value: value,
                unit: unit,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BodyweightEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BodyweightEntriesTable,
      BodyweightEntry,
      $$BodyweightEntriesTableFilterComposer,
      $$BodyweightEntriesTableOrderingComposer,
      $$BodyweightEntriesTableAnnotationComposer,
      $$BodyweightEntriesTableCreateCompanionBuilder,
      $$BodyweightEntriesTableUpdateCompanionBuilder,
      (
        BodyweightEntry,
        BaseReferences<_$AppDatabase, $BodyweightEntriesTable, BodyweightEntry>,
      ),
      BodyweightEntry,
      PrefetchHooks Function()
    >;
typedef $$RestDaysTableCreateCompanionBuilder =
    RestDaysCompanion Function({
      Value<int> id,
      required DateTime date,
      Value<String?> note,
    });
typedef $$RestDaysTableUpdateCompanionBuilder =
    RestDaysCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<String?> note,
    });

class $$RestDaysTableFilterComposer
    extends Composer<_$AppDatabase, $RestDaysTable> {
  $$RestDaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RestDaysTableOrderingComposer
    extends Composer<_$AppDatabase, $RestDaysTable> {
  $$RestDaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RestDaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $RestDaysTable> {
  $$RestDaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$RestDaysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RestDaysTable,
          RestDay,
          $$RestDaysTableFilterComposer,
          $$RestDaysTableOrderingComposer,
          $$RestDaysTableAnnotationComposer,
          $$RestDaysTableCreateCompanionBuilder,
          $$RestDaysTableUpdateCompanionBuilder,
          (RestDay, BaseReferences<_$AppDatabase, $RestDaysTable, RestDay>),
          RestDay,
          PrefetchHooks Function()
        > {
  $$RestDaysTableTableManager(_$AppDatabase db, $RestDaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RestDaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RestDaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RestDaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => RestDaysCompanion(id: id, date: date, note: note),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime date,
                Value<String?> note = const Value.absent(),
              }) => RestDaysCompanion.insert(id: id, date: date, note: note),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RestDaysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RestDaysTable,
      RestDay,
      $$RestDaysTableFilterComposer,
      $$RestDaysTableOrderingComposer,
      $$RestDaysTableAnnotationComposer,
      $$RestDaysTableCreateCompanionBuilder,
      $$RestDaysTableUpdateCompanionBuilder,
      (RestDay, BaseReferences<_$AppDatabase, $RestDaysTable, RestDay>),
      RestDay,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ExercisesTableTableManager get exercises =>
      $$ExercisesTableTableManager(_db, _db.exercises);
  $$TemplatesTableTableManager get templates =>
      $$TemplatesTableTableManager(_db, _db.templates);
  $$TemplateExercisesTableTableManager get templateExercises =>
      $$TemplateExercisesTableTableManager(_db, _db.templateExercises);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$SessionExercisesTableTableManager get sessionExercises =>
      $$SessionExercisesTableTableManager(_db, _db.sessionExercises);
  $$SetEntriesTableTableManager get setEntries =>
      $$SetEntriesTableTableManager(_db, _db.setEntries);
  $$BodyweightEntriesTableTableManager get bodyweightEntries =>
      $$BodyweightEntriesTableTableManager(_db, _db.bodyweightEntries);
  $$RestDaysTableTableManager get restDays =>
      $$RestDaysTableTableManager(_db, _db.restDays);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}
