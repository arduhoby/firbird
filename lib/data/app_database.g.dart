// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $IdentificationRecordsTable extends IdentificationRecords
    with TableInfo<$IdentificationRecordsTable, IdentificationRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IdentificationRecordsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _speciesIdMeta = const VerificationMeta(
    'speciesId',
  );
  @override
  late final GeneratedColumn<String> speciesId = GeneratedColumn<String>(
    'species_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _turkishNameMeta = const VerificationMeta(
    'turkishName',
  );
  @override
  late final GeneratedColumn<String> turkishName = GeneratedColumn<String>(
    'turkish_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scientificNameMeta = const VerificationMeta(
    'scientificName',
  );
  @override
  late final GeneratedColumn<String> scientificName = GeneratedColumn<String>(
    'scientific_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<String> confidence = GeneratedColumn<String>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelVersionMeta = const VerificationMeta(
    'modelVersion',
  );
  @override
  late final GeneratedColumn<String> modelVersion = GeneratedColumn<String>(
    'model_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageUriMeta = const VerificationMeta(
    'imageUri',
  );
  @override
  late final GeneratedColumn<String> imageUri = GeneratedColumn<String>(
    'image_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbnailUriMeta = const VerificationMeta(
    'thumbnailUri',
  );
  @override
  late final GeneratedColumn<String> thumbnailUri = GeneratedColumn<String>(
    'thumbnail_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _packageIdMeta = const VerificationMeta(
    'packageId',
  );
  @override
  late final GeneratedColumn<String> packageId = GeneratedColumn<String>(
    'package_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sexCategoryMeta = const VerificationMeta(
    'sexCategory',
  );
  @override
  late final GeneratedColumn<String> sexCategory = GeneratedColumn<String>(
    'sex_category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sexConfidenceMeta = const VerificationMeta(
    'sexConfidence',
  );
  @override
  late final GeneratedColumn<double> sexConfidence = GeneratedColumn<double>(
    'sex_confidence',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ageCategoryMeta = const VerificationMeta(
    'ageCategory',
  );
  @override
  late final GeneratedColumn<String> ageCategory = GeneratedColumn<String>(
    'age_category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ageConfidenceMeta = const VerificationMeta(
    'ageConfidence',
  );
  @override
  late final GeneratedColumn<double> ageConfidence = GeneratedColumn<double>(
    'age_confidence',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _predictionMethodMeta = const VerificationMeta(
    'predictionMethod',
  );
  @override
  late final GeneratedColumn<String> predictionMethod = GeneratedColumn<String>(
    'prediction_method',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userCorrectedSexMeta = const VerificationMeta(
    'userCorrectedSex',
  );
  @override
  late final GeneratedColumn<String> userCorrectedSex = GeneratedColumn<String>(
    'user_corrected_sex',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userCorrectedAgeMeta = const VerificationMeta(
    'userCorrectedAge',
  );
  @override
  late final GeneratedColumn<String> userCorrectedAge = GeneratedColumn<String>(
    'user_corrected_age',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userCorrectedSpeciesIdMeta =
      const VerificationMeta('userCorrectedSpeciesId');
  @override
  late final GeneratedColumn<String> userCorrectedSpeciesId =
      GeneratedColumn<String>(
        'user_corrected_species_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _userCorrectedTurkishNameMeta =
      const VerificationMeta('userCorrectedTurkishName');
  @override
  late final GeneratedColumn<String> userCorrectedTurkishName =
      GeneratedColumn<String>(
        'user_corrected_turkish_name',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    speciesId,
    turkishName,
    scientificName,
    confidence,
    modelVersion,
    imageUri,
    thumbnailUri,
    packageId,
    createdAt,
    sexCategory,
    sexConfidence,
    ageCategory,
    ageConfidence,
    predictionMethod,
    userCorrectedSex,
    userCorrectedAge,
    userCorrectedSpeciesId,
    userCorrectedTurkishName,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'identification_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<IdentificationRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('species_id')) {
      context.handle(
        _speciesIdMeta,
        speciesId.isAcceptableOrUnknown(data['species_id']!, _speciesIdMeta),
      );
    } else if (isInserting) {
      context.missing(_speciesIdMeta);
    }
    if (data.containsKey('turkish_name')) {
      context.handle(
        _turkishNameMeta,
        turkishName.isAcceptableOrUnknown(
          data['turkish_name']!,
          _turkishNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_turkishNameMeta);
    }
    if (data.containsKey('scientific_name')) {
      context.handle(
        _scientificNameMeta,
        scientificName.isAcceptableOrUnknown(
          data['scientific_name']!,
          _scientificNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scientificNameMeta);
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    } else if (isInserting) {
      context.missing(_confidenceMeta);
    }
    if (data.containsKey('model_version')) {
      context.handle(
        _modelVersionMeta,
        modelVersion.isAcceptableOrUnknown(
          data['model_version']!,
          _modelVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_modelVersionMeta);
    }
    if (data.containsKey('image_uri')) {
      context.handle(
        _imageUriMeta,
        imageUri.isAcceptableOrUnknown(data['image_uri']!, _imageUriMeta),
      );
    }
    if (data.containsKey('thumbnail_uri')) {
      context.handle(
        _thumbnailUriMeta,
        thumbnailUri.isAcceptableOrUnknown(
          data['thumbnail_uri']!,
          _thumbnailUriMeta,
        ),
      );
    }
    if (data.containsKey('package_id')) {
      context.handle(
        _packageIdMeta,
        packageId.isAcceptableOrUnknown(data['package_id']!, _packageIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('sex_category')) {
      context.handle(
        _sexCategoryMeta,
        sexCategory.isAcceptableOrUnknown(
          data['sex_category']!,
          _sexCategoryMeta,
        ),
      );
    }
    if (data.containsKey('sex_confidence')) {
      context.handle(
        _sexConfidenceMeta,
        sexConfidence.isAcceptableOrUnknown(
          data['sex_confidence']!,
          _sexConfidenceMeta,
        ),
      );
    }
    if (data.containsKey('age_category')) {
      context.handle(
        _ageCategoryMeta,
        ageCategory.isAcceptableOrUnknown(
          data['age_category']!,
          _ageCategoryMeta,
        ),
      );
    }
    if (data.containsKey('age_confidence')) {
      context.handle(
        _ageConfidenceMeta,
        ageConfidence.isAcceptableOrUnknown(
          data['age_confidence']!,
          _ageConfidenceMeta,
        ),
      );
    }
    if (data.containsKey('prediction_method')) {
      context.handle(
        _predictionMethodMeta,
        predictionMethod.isAcceptableOrUnknown(
          data['prediction_method']!,
          _predictionMethodMeta,
        ),
      );
    }
    if (data.containsKey('user_corrected_sex')) {
      context.handle(
        _userCorrectedSexMeta,
        userCorrectedSex.isAcceptableOrUnknown(
          data['user_corrected_sex']!,
          _userCorrectedSexMeta,
        ),
      );
    }
    if (data.containsKey('user_corrected_age')) {
      context.handle(
        _userCorrectedAgeMeta,
        userCorrectedAge.isAcceptableOrUnknown(
          data['user_corrected_age']!,
          _userCorrectedAgeMeta,
        ),
      );
    }
    if (data.containsKey('user_corrected_species_id')) {
      context.handle(
        _userCorrectedSpeciesIdMeta,
        userCorrectedSpeciesId.isAcceptableOrUnknown(
          data['user_corrected_species_id']!,
          _userCorrectedSpeciesIdMeta,
        ),
      );
    }
    if (data.containsKey('user_corrected_turkish_name')) {
      context.handle(
        _userCorrectedTurkishNameMeta,
        userCorrectedTurkishName.isAcceptableOrUnknown(
          data['user_corrected_turkish_name']!,
          _userCorrectedTurkishNameMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  IdentificationRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IdentificationRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      speciesId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}species_id'],
      )!,
      turkishName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}turkish_name'],
      )!,
      scientificName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scientific_name'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}confidence'],
      )!,
      modelVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_version'],
      )!,
      imageUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_uri'],
      ),
      thumbnailUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_uri'],
      ),
      packageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}package_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      sexCategory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sex_category'],
      ),
      sexConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sex_confidence'],
      ),
      ageCategory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}age_category'],
      ),
      ageConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}age_confidence'],
      ),
      predictionMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prediction_method'],
      ),
      userCorrectedSex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_corrected_sex'],
      ),
      userCorrectedAge: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_corrected_age'],
      ),
      userCorrectedSpeciesId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_corrected_species_id'],
      ),
      userCorrectedTurkishName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_corrected_turkish_name'],
      ),
    );
  }

  @override
  $IdentificationRecordsTable createAlias(String alias) {
    return $IdentificationRecordsTable(attachedDatabase, alias);
  }
}

class IdentificationRecord extends DataClass
    implements Insertable<IdentificationRecord> {
  final int id;
  final String speciesId;
  final String turkishName;
  final String scientificName;
  final String confidence;
  final String modelVersion;
  final String? imageUri;
  final String? thumbnailUri;
  final String? packageId;
  final DateTime createdAt;
  final String? sexCategory;
  final double? sexConfidence;
  final String? ageCategory;
  final double? ageConfidence;
  final String? predictionMethod;
  final String? userCorrectedSex;
  final String? userCorrectedAge;
  final String? userCorrectedSpeciesId;
  final String? userCorrectedTurkishName;
  const IdentificationRecord({
    required this.id,
    required this.speciesId,
    required this.turkishName,
    required this.scientificName,
    required this.confidence,
    required this.modelVersion,
    this.imageUri,
    this.thumbnailUri,
    this.packageId,
    required this.createdAt,
    this.sexCategory,
    this.sexConfidence,
    this.ageCategory,
    this.ageConfidence,
    this.predictionMethod,
    this.userCorrectedSex,
    this.userCorrectedAge,
    this.userCorrectedSpeciesId,
    this.userCorrectedTurkishName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['species_id'] = Variable<String>(speciesId);
    map['turkish_name'] = Variable<String>(turkishName);
    map['scientific_name'] = Variable<String>(scientificName);
    map['confidence'] = Variable<String>(confidence);
    map['model_version'] = Variable<String>(modelVersion);
    if (!nullToAbsent || imageUri != null) {
      map['image_uri'] = Variable<String>(imageUri);
    }
    if (!nullToAbsent || thumbnailUri != null) {
      map['thumbnail_uri'] = Variable<String>(thumbnailUri);
    }
    if (!nullToAbsent || packageId != null) {
      map['package_id'] = Variable<String>(packageId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || sexCategory != null) {
      map['sex_category'] = Variable<String>(sexCategory);
    }
    if (!nullToAbsent || sexConfidence != null) {
      map['sex_confidence'] = Variable<double>(sexConfidence);
    }
    if (!nullToAbsent || ageCategory != null) {
      map['age_category'] = Variable<String>(ageCategory);
    }
    if (!nullToAbsent || ageConfidence != null) {
      map['age_confidence'] = Variable<double>(ageConfidence);
    }
    if (!nullToAbsent || predictionMethod != null) {
      map['prediction_method'] = Variable<String>(predictionMethod);
    }
    if (!nullToAbsent || userCorrectedSex != null) {
      map['user_corrected_sex'] = Variable<String>(userCorrectedSex);
    }
    if (!nullToAbsent || userCorrectedAge != null) {
      map['user_corrected_age'] = Variable<String>(userCorrectedAge);
    }
    if (!nullToAbsent || userCorrectedSpeciesId != null) {
      map['user_corrected_species_id'] = Variable<String>(
        userCorrectedSpeciesId,
      );
    }
    if (!nullToAbsent || userCorrectedTurkishName != null) {
      map['user_corrected_turkish_name'] = Variable<String>(
        userCorrectedTurkishName,
      );
    }
    return map;
  }

  IdentificationRecordsCompanion toCompanion(bool nullToAbsent) {
    return IdentificationRecordsCompanion(
      id: Value(id),
      speciesId: Value(speciesId),
      turkishName: Value(turkishName),
      scientificName: Value(scientificName),
      confidence: Value(confidence),
      modelVersion: Value(modelVersion),
      imageUri: imageUri == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUri),
      thumbnailUri: thumbnailUri == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailUri),
      packageId: packageId == null && nullToAbsent
          ? const Value.absent()
          : Value(packageId),
      createdAt: Value(createdAt),
      sexCategory: sexCategory == null && nullToAbsent
          ? const Value.absent()
          : Value(sexCategory),
      sexConfidence: sexConfidence == null && nullToAbsent
          ? const Value.absent()
          : Value(sexConfidence),
      ageCategory: ageCategory == null && nullToAbsent
          ? const Value.absent()
          : Value(ageCategory),
      ageConfidence: ageConfidence == null && nullToAbsent
          ? const Value.absent()
          : Value(ageConfidence),
      predictionMethod: predictionMethod == null && nullToAbsent
          ? const Value.absent()
          : Value(predictionMethod),
      userCorrectedSex: userCorrectedSex == null && nullToAbsent
          ? const Value.absent()
          : Value(userCorrectedSex),
      userCorrectedAge: userCorrectedAge == null && nullToAbsent
          ? const Value.absent()
          : Value(userCorrectedAge),
      userCorrectedSpeciesId: userCorrectedSpeciesId == null && nullToAbsent
          ? const Value.absent()
          : Value(userCorrectedSpeciesId),
      userCorrectedTurkishName: userCorrectedTurkishName == null && nullToAbsent
          ? const Value.absent()
          : Value(userCorrectedTurkishName),
    );
  }

  factory IdentificationRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IdentificationRecord(
      id: serializer.fromJson<int>(json['id']),
      speciesId: serializer.fromJson<String>(json['speciesId']),
      turkishName: serializer.fromJson<String>(json['turkishName']),
      scientificName: serializer.fromJson<String>(json['scientificName']),
      confidence: serializer.fromJson<String>(json['confidence']),
      modelVersion: serializer.fromJson<String>(json['modelVersion']),
      imageUri: serializer.fromJson<String?>(json['imageUri']),
      thumbnailUri: serializer.fromJson<String?>(json['thumbnailUri']),
      packageId: serializer.fromJson<String?>(json['packageId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      sexCategory: serializer.fromJson<String?>(json['sexCategory']),
      sexConfidence: serializer.fromJson<double?>(json['sexConfidence']),
      ageCategory: serializer.fromJson<String?>(json['ageCategory']),
      ageConfidence: serializer.fromJson<double?>(json['ageConfidence']),
      predictionMethod: serializer.fromJson<String?>(json['predictionMethod']),
      userCorrectedSex: serializer.fromJson<String?>(json['userCorrectedSex']),
      userCorrectedAge: serializer.fromJson<String?>(json['userCorrectedAge']),
      userCorrectedSpeciesId: serializer.fromJson<String?>(
        json['userCorrectedSpeciesId'],
      ),
      userCorrectedTurkishName: serializer.fromJson<String?>(
        json['userCorrectedTurkishName'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'speciesId': serializer.toJson<String>(speciesId),
      'turkishName': serializer.toJson<String>(turkishName),
      'scientificName': serializer.toJson<String>(scientificName),
      'confidence': serializer.toJson<String>(confidence),
      'modelVersion': serializer.toJson<String>(modelVersion),
      'imageUri': serializer.toJson<String?>(imageUri),
      'thumbnailUri': serializer.toJson<String?>(thumbnailUri),
      'packageId': serializer.toJson<String?>(packageId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'sexCategory': serializer.toJson<String?>(sexCategory),
      'sexConfidence': serializer.toJson<double?>(sexConfidence),
      'ageCategory': serializer.toJson<String?>(ageCategory),
      'ageConfidence': serializer.toJson<double?>(ageConfidence),
      'predictionMethod': serializer.toJson<String?>(predictionMethod),
      'userCorrectedSex': serializer.toJson<String?>(userCorrectedSex),
      'userCorrectedAge': serializer.toJson<String?>(userCorrectedAge),
      'userCorrectedSpeciesId': serializer.toJson<String?>(
        userCorrectedSpeciesId,
      ),
      'userCorrectedTurkishName': serializer.toJson<String?>(
        userCorrectedTurkishName,
      ),
    };
  }

  IdentificationRecord copyWith({
    int? id,
    String? speciesId,
    String? turkishName,
    String? scientificName,
    String? confidence,
    String? modelVersion,
    Value<String?> imageUri = const Value.absent(),
    Value<String?> thumbnailUri = const Value.absent(),
    Value<String?> packageId = const Value.absent(),
    DateTime? createdAt,
    Value<String?> sexCategory = const Value.absent(),
    Value<double?> sexConfidence = const Value.absent(),
    Value<String?> ageCategory = const Value.absent(),
    Value<double?> ageConfidence = const Value.absent(),
    Value<String?> predictionMethod = const Value.absent(),
    Value<String?> userCorrectedSex = const Value.absent(),
    Value<String?> userCorrectedAge = const Value.absent(),
    Value<String?> userCorrectedSpeciesId = const Value.absent(),
    Value<String?> userCorrectedTurkishName = const Value.absent(),
  }) => IdentificationRecord(
    id: id ?? this.id,
    speciesId: speciesId ?? this.speciesId,
    turkishName: turkishName ?? this.turkishName,
    scientificName: scientificName ?? this.scientificName,
    confidence: confidence ?? this.confidence,
    modelVersion: modelVersion ?? this.modelVersion,
    imageUri: imageUri.present ? imageUri.value : this.imageUri,
    thumbnailUri: thumbnailUri.present ? thumbnailUri.value : this.thumbnailUri,
    packageId: packageId.present ? packageId.value : this.packageId,
    createdAt: createdAt ?? this.createdAt,
    sexCategory: sexCategory.present ? sexCategory.value : this.sexCategory,
    sexConfidence: sexConfidence.present
        ? sexConfidence.value
        : this.sexConfidence,
    ageCategory: ageCategory.present ? ageCategory.value : this.ageCategory,
    ageConfidence: ageConfidence.present
        ? ageConfidence.value
        : this.ageConfidence,
    predictionMethod: predictionMethod.present
        ? predictionMethod.value
        : this.predictionMethod,
    userCorrectedSex: userCorrectedSex.present
        ? userCorrectedSex.value
        : this.userCorrectedSex,
    userCorrectedAge: userCorrectedAge.present
        ? userCorrectedAge.value
        : this.userCorrectedAge,
    userCorrectedSpeciesId: userCorrectedSpeciesId.present
        ? userCorrectedSpeciesId.value
        : this.userCorrectedSpeciesId,
    userCorrectedTurkishName: userCorrectedTurkishName.present
        ? userCorrectedTurkishName.value
        : this.userCorrectedTurkishName,
  );
  IdentificationRecord copyWithCompanion(IdentificationRecordsCompanion data) {
    return IdentificationRecord(
      id: data.id.present ? data.id.value : this.id,
      speciesId: data.speciesId.present ? data.speciesId.value : this.speciesId,
      turkishName: data.turkishName.present
          ? data.turkishName.value
          : this.turkishName,
      scientificName: data.scientificName.present
          ? data.scientificName.value
          : this.scientificName,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      modelVersion: data.modelVersion.present
          ? data.modelVersion.value
          : this.modelVersion,
      imageUri: data.imageUri.present ? data.imageUri.value : this.imageUri,
      thumbnailUri: data.thumbnailUri.present
          ? data.thumbnailUri.value
          : this.thumbnailUri,
      packageId: data.packageId.present ? data.packageId.value : this.packageId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      sexCategory: data.sexCategory.present
          ? data.sexCategory.value
          : this.sexCategory,
      sexConfidence: data.sexConfidence.present
          ? data.sexConfidence.value
          : this.sexConfidence,
      ageCategory: data.ageCategory.present
          ? data.ageCategory.value
          : this.ageCategory,
      ageConfidence: data.ageConfidence.present
          ? data.ageConfidence.value
          : this.ageConfidence,
      predictionMethod: data.predictionMethod.present
          ? data.predictionMethod.value
          : this.predictionMethod,
      userCorrectedSex: data.userCorrectedSex.present
          ? data.userCorrectedSex.value
          : this.userCorrectedSex,
      userCorrectedAge: data.userCorrectedAge.present
          ? data.userCorrectedAge.value
          : this.userCorrectedAge,
      userCorrectedSpeciesId: data.userCorrectedSpeciesId.present
          ? data.userCorrectedSpeciesId.value
          : this.userCorrectedSpeciesId,
      userCorrectedTurkishName: data.userCorrectedTurkishName.present
          ? data.userCorrectedTurkishName.value
          : this.userCorrectedTurkishName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IdentificationRecord(')
          ..write('id: $id, ')
          ..write('speciesId: $speciesId, ')
          ..write('turkishName: $turkishName, ')
          ..write('scientificName: $scientificName, ')
          ..write('confidence: $confidence, ')
          ..write('modelVersion: $modelVersion, ')
          ..write('imageUri: $imageUri, ')
          ..write('thumbnailUri: $thumbnailUri, ')
          ..write('packageId: $packageId, ')
          ..write('createdAt: $createdAt, ')
          ..write('sexCategory: $sexCategory, ')
          ..write('sexConfidence: $sexConfidence, ')
          ..write('ageCategory: $ageCategory, ')
          ..write('ageConfidence: $ageConfidence, ')
          ..write('predictionMethod: $predictionMethod, ')
          ..write('userCorrectedSex: $userCorrectedSex, ')
          ..write('userCorrectedAge: $userCorrectedAge, ')
          ..write('userCorrectedSpeciesId: $userCorrectedSpeciesId, ')
          ..write('userCorrectedTurkishName: $userCorrectedTurkishName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    speciesId,
    turkishName,
    scientificName,
    confidence,
    modelVersion,
    imageUri,
    thumbnailUri,
    packageId,
    createdAt,
    sexCategory,
    sexConfidence,
    ageCategory,
    ageConfidence,
    predictionMethod,
    userCorrectedSex,
    userCorrectedAge,
    userCorrectedSpeciesId,
    userCorrectedTurkishName,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IdentificationRecord &&
          other.id == this.id &&
          other.speciesId == this.speciesId &&
          other.turkishName == this.turkishName &&
          other.scientificName == this.scientificName &&
          other.confidence == this.confidence &&
          other.modelVersion == this.modelVersion &&
          other.imageUri == this.imageUri &&
          other.thumbnailUri == this.thumbnailUri &&
          other.packageId == this.packageId &&
          other.createdAt == this.createdAt &&
          other.sexCategory == this.sexCategory &&
          other.sexConfidence == this.sexConfidence &&
          other.ageCategory == this.ageCategory &&
          other.ageConfidence == this.ageConfidence &&
          other.predictionMethod == this.predictionMethod &&
          other.userCorrectedSex == this.userCorrectedSex &&
          other.userCorrectedAge == this.userCorrectedAge &&
          other.userCorrectedSpeciesId == this.userCorrectedSpeciesId &&
          other.userCorrectedTurkishName == this.userCorrectedTurkishName);
}

class IdentificationRecordsCompanion
    extends UpdateCompanion<IdentificationRecord> {
  final Value<int> id;
  final Value<String> speciesId;
  final Value<String> turkishName;
  final Value<String> scientificName;
  final Value<String> confidence;
  final Value<String> modelVersion;
  final Value<String?> imageUri;
  final Value<String?> thumbnailUri;
  final Value<String?> packageId;
  final Value<DateTime> createdAt;
  final Value<String?> sexCategory;
  final Value<double?> sexConfidence;
  final Value<String?> ageCategory;
  final Value<double?> ageConfidence;
  final Value<String?> predictionMethod;
  final Value<String?> userCorrectedSex;
  final Value<String?> userCorrectedAge;
  final Value<String?> userCorrectedSpeciesId;
  final Value<String?> userCorrectedTurkishName;
  const IdentificationRecordsCompanion({
    this.id = const Value.absent(),
    this.speciesId = const Value.absent(),
    this.turkishName = const Value.absent(),
    this.scientificName = const Value.absent(),
    this.confidence = const Value.absent(),
    this.modelVersion = const Value.absent(),
    this.imageUri = const Value.absent(),
    this.thumbnailUri = const Value.absent(),
    this.packageId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.sexCategory = const Value.absent(),
    this.sexConfidence = const Value.absent(),
    this.ageCategory = const Value.absent(),
    this.ageConfidence = const Value.absent(),
    this.predictionMethod = const Value.absent(),
    this.userCorrectedSex = const Value.absent(),
    this.userCorrectedAge = const Value.absent(),
    this.userCorrectedSpeciesId = const Value.absent(),
    this.userCorrectedTurkishName = const Value.absent(),
  });
  IdentificationRecordsCompanion.insert({
    this.id = const Value.absent(),
    required String speciesId,
    required String turkishName,
    required String scientificName,
    required String confidence,
    required String modelVersion,
    this.imageUri = const Value.absent(),
    this.thumbnailUri = const Value.absent(),
    this.packageId = const Value.absent(),
    required DateTime createdAt,
    this.sexCategory = const Value.absent(),
    this.sexConfidence = const Value.absent(),
    this.ageCategory = const Value.absent(),
    this.ageConfidence = const Value.absent(),
    this.predictionMethod = const Value.absent(),
    this.userCorrectedSex = const Value.absent(),
    this.userCorrectedAge = const Value.absent(),
    this.userCorrectedSpeciesId = const Value.absent(),
    this.userCorrectedTurkishName = const Value.absent(),
  }) : speciesId = Value(speciesId),
       turkishName = Value(turkishName),
       scientificName = Value(scientificName),
       confidence = Value(confidence),
       modelVersion = Value(modelVersion),
       createdAt = Value(createdAt);
  static Insertable<IdentificationRecord> custom({
    Expression<int>? id,
    Expression<String>? speciesId,
    Expression<String>? turkishName,
    Expression<String>? scientificName,
    Expression<String>? confidence,
    Expression<String>? modelVersion,
    Expression<String>? imageUri,
    Expression<String>? thumbnailUri,
    Expression<String>? packageId,
    Expression<DateTime>? createdAt,
    Expression<String>? sexCategory,
    Expression<double>? sexConfidence,
    Expression<String>? ageCategory,
    Expression<double>? ageConfidence,
    Expression<String>? predictionMethod,
    Expression<String>? userCorrectedSex,
    Expression<String>? userCorrectedAge,
    Expression<String>? userCorrectedSpeciesId,
    Expression<String>? userCorrectedTurkishName,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (speciesId != null) 'species_id': speciesId,
      if (turkishName != null) 'turkish_name': turkishName,
      if (scientificName != null) 'scientific_name': scientificName,
      if (confidence != null) 'confidence': confidence,
      if (modelVersion != null) 'model_version': modelVersion,
      if (imageUri != null) 'image_uri': imageUri,
      if (thumbnailUri != null) 'thumbnail_uri': thumbnailUri,
      if (packageId != null) 'package_id': packageId,
      if (createdAt != null) 'created_at': createdAt,
      if (sexCategory != null) 'sex_category': sexCategory,
      if (sexConfidence != null) 'sex_confidence': sexConfidence,
      if (ageCategory != null) 'age_category': ageCategory,
      if (ageConfidence != null) 'age_confidence': ageConfidence,
      if (predictionMethod != null) 'prediction_method': predictionMethod,
      if (userCorrectedSex != null) 'user_corrected_sex': userCorrectedSex,
      if (userCorrectedAge != null) 'user_corrected_age': userCorrectedAge,
      if (userCorrectedSpeciesId != null)
        'user_corrected_species_id': userCorrectedSpeciesId,
      if (userCorrectedTurkishName != null)
        'user_corrected_turkish_name': userCorrectedTurkishName,
    });
  }

  IdentificationRecordsCompanion copyWith({
    Value<int>? id,
    Value<String>? speciesId,
    Value<String>? turkishName,
    Value<String>? scientificName,
    Value<String>? confidence,
    Value<String>? modelVersion,
    Value<String?>? imageUri,
    Value<String?>? thumbnailUri,
    Value<String?>? packageId,
    Value<DateTime>? createdAt,
    Value<String?>? sexCategory,
    Value<double?>? sexConfidence,
    Value<String?>? ageCategory,
    Value<double?>? ageConfidence,
    Value<String?>? predictionMethod,
    Value<String?>? userCorrectedSex,
    Value<String?>? userCorrectedAge,
    Value<String?>? userCorrectedSpeciesId,
    Value<String?>? userCorrectedTurkishName,
  }) {
    return IdentificationRecordsCompanion(
      id: id ?? this.id,
      speciesId: speciesId ?? this.speciesId,
      turkishName: turkishName ?? this.turkishName,
      scientificName: scientificName ?? this.scientificName,
      confidence: confidence ?? this.confidence,
      modelVersion: modelVersion ?? this.modelVersion,
      imageUri: imageUri ?? this.imageUri,
      thumbnailUri: thumbnailUri ?? this.thumbnailUri,
      packageId: packageId ?? this.packageId,
      createdAt: createdAt ?? this.createdAt,
      sexCategory: sexCategory ?? this.sexCategory,
      sexConfidence: sexConfidence ?? this.sexConfidence,
      ageCategory: ageCategory ?? this.ageCategory,
      ageConfidence: ageConfidence ?? this.ageConfidence,
      predictionMethod: predictionMethod ?? this.predictionMethod,
      userCorrectedSex: userCorrectedSex ?? this.userCorrectedSex,
      userCorrectedAge: userCorrectedAge ?? this.userCorrectedAge,
      userCorrectedSpeciesId:
          userCorrectedSpeciesId ?? this.userCorrectedSpeciesId,
      userCorrectedTurkishName:
          userCorrectedTurkishName ?? this.userCorrectedTurkishName,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (speciesId.present) {
      map['species_id'] = Variable<String>(speciesId.value);
    }
    if (turkishName.present) {
      map['turkish_name'] = Variable<String>(turkishName.value);
    }
    if (scientificName.present) {
      map['scientific_name'] = Variable<String>(scientificName.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<String>(confidence.value);
    }
    if (modelVersion.present) {
      map['model_version'] = Variable<String>(modelVersion.value);
    }
    if (imageUri.present) {
      map['image_uri'] = Variable<String>(imageUri.value);
    }
    if (thumbnailUri.present) {
      map['thumbnail_uri'] = Variable<String>(thumbnailUri.value);
    }
    if (packageId.present) {
      map['package_id'] = Variable<String>(packageId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (sexCategory.present) {
      map['sex_category'] = Variable<String>(sexCategory.value);
    }
    if (sexConfidence.present) {
      map['sex_confidence'] = Variable<double>(sexConfidence.value);
    }
    if (ageCategory.present) {
      map['age_category'] = Variable<String>(ageCategory.value);
    }
    if (ageConfidence.present) {
      map['age_confidence'] = Variable<double>(ageConfidence.value);
    }
    if (predictionMethod.present) {
      map['prediction_method'] = Variable<String>(predictionMethod.value);
    }
    if (userCorrectedSex.present) {
      map['user_corrected_sex'] = Variable<String>(userCorrectedSex.value);
    }
    if (userCorrectedAge.present) {
      map['user_corrected_age'] = Variable<String>(userCorrectedAge.value);
    }
    if (userCorrectedSpeciesId.present) {
      map['user_corrected_species_id'] = Variable<String>(
        userCorrectedSpeciesId.value,
      );
    }
    if (userCorrectedTurkishName.present) {
      map['user_corrected_turkish_name'] = Variable<String>(
        userCorrectedTurkishName.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IdentificationRecordsCompanion(')
          ..write('id: $id, ')
          ..write('speciesId: $speciesId, ')
          ..write('turkishName: $turkishName, ')
          ..write('scientificName: $scientificName, ')
          ..write('confidence: $confidence, ')
          ..write('modelVersion: $modelVersion, ')
          ..write('imageUri: $imageUri, ')
          ..write('thumbnailUri: $thumbnailUri, ')
          ..write('packageId: $packageId, ')
          ..write('createdAt: $createdAt, ')
          ..write('sexCategory: $sexCategory, ')
          ..write('sexConfidence: $sexConfidence, ')
          ..write('ageCategory: $ageCategory, ')
          ..write('ageConfidence: $ageConfidence, ')
          ..write('predictionMethod: $predictionMethod, ')
          ..write('userCorrectedSex: $userCorrectedSex, ')
          ..write('userCorrectedAge: $userCorrectedAge, ')
          ..write('userCorrectedSpeciesId: $userCorrectedSpeciesId, ')
          ..write('userCorrectedTurkishName: $userCorrectedTurkishName')
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

class $InstalledPackagesTable extends InstalledPackages
    with TableInfo<$InstalledPackagesTable, InstalledPackage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InstalledPackagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _packageIdMeta = const VerificationMeta(
    'packageId',
  );
  @override
  late final GeneratedColumn<String> packageId = GeneratedColumn<String>(
    'package_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _installedAtMeta = const VerificationMeta(
    'installedAt',
  );
  @override
  late final GeneratedColumn<DateTime> installedAt = GeneratedColumn<DateTime>(
    'installed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    packageId,
    version,
    isActive,
    installedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'installed_packages';
  @override
  VerificationContext validateIntegrity(
    Insertable<InstalledPackage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('package_id')) {
      context.handle(
        _packageIdMeta,
        packageId.isAcceptableOrUnknown(data['package_id']!, _packageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_packageIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('installed_at')) {
      context.handle(
        _installedAtMeta,
        installedAt.isAcceptableOrUnknown(
          data['installed_at']!,
          _installedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_installedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {packageId};
  @override
  InstalledPackage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InstalledPackage(
      packageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}package_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      installedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}installed_at'],
      )!,
    );
  }

  @override
  $InstalledPackagesTable createAlias(String alias) {
    return $InstalledPackagesTable(attachedDatabase, alias);
  }
}

class InstalledPackage extends DataClass
    implements Insertable<InstalledPackage> {
  final String packageId;
  final String version;
  final bool isActive;
  final DateTime installedAt;
  const InstalledPackage({
    required this.packageId,
    required this.version,
    required this.isActive,
    required this.installedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['package_id'] = Variable<String>(packageId);
    map['version'] = Variable<String>(version);
    map['is_active'] = Variable<bool>(isActive);
    map['installed_at'] = Variable<DateTime>(installedAt);
    return map;
  }

  InstalledPackagesCompanion toCompanion(bool nullToAbsent) {
    return InstalledPackagesCompanion(
      packageId: Value(packageId),
      version: Value(version),
      isActive: Value(isActive),
      installedAt: Value(installedAt),
    );
  }

  factory InstalledPackage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InstalledPackage(
      packageId: serializer.fromJson<String>(json['packageId']),
      version: serializer.fromJson<String>(json['version']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      installedAt: serializer.fromJson<DateTime>(json['installedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'packageId': serializer.toJson<String>(packageId),
      'version': serializer.toJson<String>(version),
      'isActive': serializer.toJson<bool>(isActive),
      'installedAt': serializer.toJson<DateTime>(installedAt),
    };
  }

  InstalledPackage copyWith({
    String? packageId,
    String? version,
    bool? isActive,
    DateTime? installedAt,
  }) => InstalledPackage(
    packageId: packageId ?? this.packageId,
    version: version ?? this.version,
    isActive: isActive ?? this.isActive,
    installedAt: installedAt ?? this.installedAt,
  );
  InstalledPackage copyWithCompanion(InstalledPackagesCompanion data) {
    return InstalledPackage(
      packageId: data.packageId.present ? data.packageId.value : this.packageId,
      version: data.version.present ? data.version.value : this.version,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      installedAt: data.installedAt.present
          ? data.installedAt.value
          : this.installedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InstalledPackage(')
          ..write('packageId: $packageId, ')
          ..write('version: $version, ')
          ..write('isActive: $isActive, ')
          ..write('installedAt: $installedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(packageId, version, isActive, installedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InstalledPackage &&
          other.packageId == this.packageId &&
          other.version == this.version &&
          other.isActive == this.isActive &&
          other.installedAt == this.installedAt);
}

class InstalledPackagesCompanion extends UpdateCompanion<InstalledPackage> {
  final Value<String> packageId;
  final Value<String> version;
  final Value<bool> isActive;
  final Value<DateTime> installedAt;
  final Value<int> rowid;
  const InstalledPackagesCompanion({
    this.packageId = const Value.absent(),
    this.version = const Value.absent(),
    this.isActive = const Value.absent(),
    this.installedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InstalledPackagesCompanion.insert({
    required String packageId,
    required String version,
    this.isActive = const Value.absent(),
    required DateTime installedAt,
    this.rowid = const Value.absent(),
  }) : packageId = Value(packageId),
       version = Value(version),
       installedAt = Value(installedAt);
  static Insertable<InstalledPackage> custom({
    Expression<String>? packageId,
    Expression<String>? version,
    Expression<bool>? isActive,
    Expression<DateTime>? installedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (packageId != null) 'package_id': packageId,
      if (version != null) 'version': version,
      if (isActive != null) 'is_active': isActive,
      if (installedAt != null) 'installed_at': installedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InstalledPackagesCompanion copyWith({
    Value<String>? packageId,
    Value<String>? version,
    Value<bool>? isActive,
    Value<DateTime>? installedAt,
    Value<int>? rowid,
  }) {
    return InstalledPackagesCompanion(
      packageId: packageId ?? this.packageId,
      version: version ?? this.version,
      isActive: isActive ?? this.isActive,
      installedAt: installedAt ?? this.installedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (packageId.present) {
      map['package_id'] = Variable<String>(packageId.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (installedAt.present) {
      map['installed_at'] = Variable<DateTime>(installedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InstalledPackagesCompanion(')
          ..write('packageId: $packageId, ')
          ..write('version: $version, ')
          ..write('isActive: $isActive, ')
          ..write('installedAt: $installedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $IdentificationRecordsTable identificationRecords =
      $IdentificationRecordsTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $InstalledPackagesTable installedPackages =
      $InstalledPackagesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    identificationRecords,
    appSettings,
    installedPackages,
  ];
}

typedef $$IdentificationRecordsTableCreateCompanionBuilder =
    IdentificationRecordsCompanion Function({
      Value<int> id,
      required String speciesId,
      required String turkishName,
      required String scientificName,
      required String confidence,
      required String modelVersion,
      Value<String?> imageUri,
      Value<String?> thumbnailUri,
      Value<String?> packageId,
      required DateTime createdAt,
      Value<String?> sexCategory,
      Value<double?> sexConfidence,
      Value<String?> ageCategory,
      Value<double?> ageConfidence,
      Value<String?> predictionMethod,
      Value<String?> userCorrectedSex,
      Value<String?> userCorrectedAge,
      Value<String?> userCorrectedSpeciesId,
      Value<String?> userCorrectedTurkishName,
    });
typedef $$IdentificationRecordsTableUpdateCompanionBuilder =
    IdentificationRecordsCompanion Function({
      Value<int> id,
      Value<String> speciesId,
      Value<String> turkishName,
      Value<String> scientificName,
      Value<String> confidence,
      Value<String> modelVersion,
      Value<String?> imageUri,
      Value<String?> thumbnailUri,
      Value<String?> packageId,
      Value<DateTime> createdAt,
      Value<String?> sexCategory,
      Value<double?> sexConfidence,
      Value<String?> ageCategory,
      Value<double?> ageConfidence,
      Value<String?> predictionMethod,
      Value<String?> userCorrectedSex,
      Value<String?> userCorrectedAge,
      Value<String?> userCorrectedSpeciesId,
      Value<String?> userCorrectedTurkishName,
    });

class $$IdentificationRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $IdentificationRecordsTable> {
  $$IdentificationRecordsTableFilterComposer({
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

  ColumnFilters<String> get speciesId => $composableBuilder(
    column: $table.speciesId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get turkishName => $composableBuilder(
    column: $table.turkishName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scientificName => $composableBuilder(
    column: $table.scientificName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelVersion => $composableBuilder(
    column: $table.modelVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUri => $composableBuilder(
    column: $table.imageUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailUri => $composableBuilder(
    column: $table.thumbnailUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sexCategory => $composableBuilder(
    column: $table.sexCategory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sexConfidence => $composableBuilder(
    column: $table.sexConfidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ageCategory => $composableBuilder(
    column: $table.ageCategory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ageConfidence => $composableBuilder(
    column: $table.ageConfidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get predictionMethod => $composableBuilder(
    column: $table.predictionMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userCorrectedSex => $composableBuilder(
    column: $table.userCorrectedSex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userCorrectedAge => $composableBuilder(
    column: $table.userCorrectedAge,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userCorrectedSpeciesId => $composableBuilder(
    column: $table.userCorrectedSpeciesId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userCorrectedTurkishName => $composableBuilder(
    column: $table.userCorrectedTurkishName,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IdentificationRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $IdentificationRecordsTable> {
  $$IdentificationRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get speciesId => $composableBuilder(
    column: $table.speciesId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get turkishName => $composableBuilder(
    column: $table.turkishName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scientificName => $composableBuilder(
    column: $table.scientificName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelVersion => $composableBuilder(
    column: $table.modelVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUri => $composableBuilder(
    column: $table.imageUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailUri => $composableBuilder(
    column: $table.thumbnailUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sexCategory => $composableBuilder(
    column: $table.sexCategory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sexConfidence => $composableBuilder(
    column: $table.sexConfidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ageCategory => $composableBuilder(
    column: $table.ageCategory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ageConfidence => $composableBuilder(
    column: $table.ageConfidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get predictionMethod => $composableBuilder(
    column: $table.predictionMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userCorrectedSex => $composableBuilder(
    column: $table.userCorrectedSex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userCorrectedAge => $composableBuilder(
    column: $table.userCorrectedAge,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userCorrectedSpeciesId => $composableBuilder(
    column: $table.userCorrectedSpeciesId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userCorrectedTurkishName => $composableBuilder(
    column: $table.userCorrectedTurkishName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IdentificationRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $IdentificationRecordsTable> {
  $$IdentificationRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get speciesId =>
      $composableBuilder(column: $table.speciesId, builder: (column) => column);

  GeneratedColumn<String> get turkishName => $composableBuilder(
    column: $table.turkishName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scientificName => $composableBuilder(
    column: $table.scientificName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get modelVersion => $composableBuilder(
    column: $table.modelVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageUri =>
      $composableBuilder(column: $table.imageUri, builder: (column) => column);

  GeneratedColumn<String> get thumbnailUri => $composableBuilder(
    column: $table.thumbnailUri,
    builder: (column) => column,
  );

  GeneratedColumn<String> get packageId =>
      $composableBuilder(column: $table.packageId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get sexCategory => $composableBuilder(
    column: $table.sexCategory,
    builder: (column) => column,
  );

  GeneratedColumn<double> get sexConfidence => $composableBuilder(
    column: $table.sexConfidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ageCategory => $composableBuilder(
    column: $table.ageCategory,
    builder: (column) => column,
  );

  GeneratedColumn<double> get ageConfidence => $composableBuilder(
    column: $table.ageConfidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get predictionMethod => $composableBuilder(
    column: $table.predictionMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userCorrectedSex => $composableBuilder(
    column: $table.userCorrectedSex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userCorrectedAge => $composableBuilder(
    column: $table.userCorrectedAge,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userCorrectedSpeciesId => $composableBuilder(
    column: $table.userCorrectedSpeciesId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userCorrectedTurkishName => $composableBuilder(
    column: $table.userCorrectedTurkishName,
    builder: (column) => column,
  );
}

class $$IdentificationRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $IdentificationRecordsTable,
          IdentificationRecord,
          $$IdentificationRecordsTableFilterComposer,
          $$IdentificationRecordsTableOrderingComposer,
          $$IdentificationRecordsTableAnnotationComposer,
          $$IdentificationRecordsTableCreateCompanionBuilder,
          $$IdentificationRecordsTableUpdateCompanionBuilder,
          (
            IdentificationRecord,
            BaseReferences<
              _$AppDatabase,
              $IdentificationRecordsTable,
              IdentificationRecord
            >,
          ),
          IdentificationRecord,
          PrefetchHooks Function()
        > {
  $$IdentificationRecordsTableTableManager(
    _$AppDatabase db,
    $IdentificationRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IdentificationRecordsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$IdentificationRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$IdentificationRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> speciesId = const Value.absent(),
                Value<String> turkishName = const Value.absent(),
                Value<String> scientificName = const Value.absent(),
                Value<String> confidence = const Value.absent(),
                Value<String> modelVersion = const Value.absent(),
                Value<String?> imageUri = const Value.absent(),
                Value<String?> thumbnailUri = const Value.absent(),
                Value<String?> packageId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> sexCategory = const Value.absent(),
                Value<double?> sexConfidence = const Value.absent(),
                Value<String?> ageCategory = const Value.absent(),
                Value<double?> ageConfidence = const Value.absent(),
                Value<String?> predictionMethod = const Value.absent(),
                Value<String?> userCorrectedSex = const Value.absent(),
                Value<String?> userCorrectedAge = const Value.absent(),
                Value<String?> userCorrectedSpeciesId = const Value.absent(),
                Value<String?> userCorrectedTurkishName = const Value.absent(),
              }) => IdentificationRecordsCompanion(
                id: id,
                speciesId: speciesId,
                turkishName: turkishName,
                scientificName: scientificName,
                confidence: confidence,
                modelVersion: modelVersion,
                imageUri: imageUri,
                thumbnailUri: thumbnailUri,
                packageId: packageId,
                createdAt: createdAt,
                sexCategory: sexCategory,
                sexConfidence: sexConfidence,
                ageCategory: ageCategory,
                ageConfidence: ageConfidence,
                predictionMethod: predictionMethod,
                userCorrectedSex: userCorrectedSex,
                userCorrectedAge: userCorrectedAge,
                userCorrectedSpeciesId: userCorrectedSpeciesId,
                userCorrectedTurkishName: userCorrectedTurkishName,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String speciesId,
                required String turkishName,
                required String scientificName,
                required String confidence,
                required String modelVersion,
                Value<String?> imageUri = const Value.absent(),
                Value<String?> thumbnailUri = const Value.absent(),
                Value<String?> packageId = const Value.absent(),
                required DateTime createdAt,
                Value<String?> sexCategory = const Value.absent(),
                Value<double?> sexConfidence = const Value.absent(),
                Value<String?> ageCategory = const Value.absent(),
                Value<double?> ageConfidence = const Value.absent(),
                Value<String?> predictionMethod = const Value.absent(),
                Value<String?> userCorrectedSex = const Value.absent(),
                Value<String?> userCorrectedAge = const Value.absent(),
                Value<String?> userCorrectedSpeciesId = const Value.absent(),
                Value<String?> userCorrectedTurkishName = const Value.absent(),
              }) => IdentificationRecordsCompanion.insert(
                id: id,
                speciesId: speciesId,
                turkishName: turkishName,
                scientificName: scientificName,
                confidence: confidence,
                modelVersion: modelVersion,
                imageUri: imageUri,
                thumbnailUri: thumbnailUri,
                packageId: packageId,
                createdAt: createdAt,
                sexCategory: sexCategory,
                sexConfidence: sexConfidence,
                ageCategory: ageCategory,
                ageConfidence: ageConfidence,
                predictionMethod: predictionMethod,
                userCorrectedSex: userCorrectedSex,
                userCorrectedAge: userCorrectedAge,
                userCorrectedSpeciesId: userCorrectedSpeciesId,
                userCorrectedTurkishName: userCorrectedTurkishName,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IdentificationRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $IdentificationRecordsTable,
      IdentificationRecord,
      $$IdentificationRecordsTableFilterComposer,
      $$IdentificationRecordsTableOrderingComposer,
      $$IdentificationRecordsTableAnnotationComposer,
      $$IdentificationRecordsTableCreateCompanionBuilder,
      $$IdentificationRecordsTableUpdateCompanionBuilder,
      (
        IdentificationRecord,
        BaseReferences<
          _$AppDatabase,
          $IdentificationRecordsTable,
          IdentificationRecord
        >,
      ),
      IdentificationRecord,
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
typedef $$InstalledPackagesTableCreateCompanionBuilder =
    InstalledPackagesCompanion Function({
      required String packageId,
      required String version,
      Value<bool> isActive,
      required DateTime installedAt,
      Value<int> rowid,
    });
typedef $$InstalledPackagesTableUpdateCompanionBuilder =
    InstalledPackagesCompanion Function({
      Value<String> packageId,
      Value<String> version,
      Value<bool> isActive,
      Value<DateTime> installedAt,
      Value<int> rowid,
    });

class $$InstalledPackagesTableFilterComposer
    extends Composer<_$AppDatabase, $InstalledPackagesTable> {
  $$InstalledPackagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InstalledPackagesTableOrderingComposer
    extends Composer<_$AppDatabase, $InstalledPackagesTable> {
  $$InstalledPackagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InstalledPackagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $InstalledPackagesTable> {
  $$InstalledPackagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get packageId =>
      $composableBuilder(column: $table.packageId, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => column,
  );
}

class $$InstalledPackagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InstalledPackagesTable,
          InstalledPackage,
          $$InstalledPackagesTableFilterComposer,
          $$InstalledPackagesTableOrderingComposer,
          $$InstalledPackagesTableAnnotationComposer,
          $$InstalledPackagesTableCreateCompanionBuilder,
          $$InstalledPackagesTableUpdateCompanionBuilder,
          (
            InstalledPackage,
            BaseReferences<
              _$AppDatabase,
              $InstalledPackagesTable,
              InstalledPackage
            >,
          ),
          InstalledPackage,
          PrefetchHooks Function()
        > {
  $$InstalledPackagesTableTableManager(
    _$AppDatabase db,
    $InstalledPackagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InstalledPackagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InstalledPackagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InstalledPackagesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> packageId = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> installedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InstalledPackagesCompanion(
                packageId: packageId,
                version: version,
                isActive: isActive,
                installedAt: installedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String packageId,
                required String version,
                Value<bool> isActive = const Value.absent(),
                required DateTime installedAt,
                Value<int> rowid = const Value.absent(),
              }) => InstalledPackagesCompanion.insert(
                packageId: packageId,
                version: version,
                isActive: isActive,
                installedAt: installedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InstalledPackagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InstalledPackagesTable,
      InstalledPackage,
      $$InstalledPackagesTableFilterComposer,
      $$InstalledPackagesTableOrderingComposer,
      $$InstalledPackagesTableAnnotationComposer,
      $$InstalledPackagesTableCreateCompanionBuilder,
      $$InstalledPackagesTableUpdateCompanionBuilder,
      (
        InstalledPackage,
        BaseReferences<
          _$AppDatabase,
          $InstalledPackagesTable,
          InstalledPackage
        >,
      ),
      InstalledPackage,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$IdentificationRecordsTableTableManager get identificationRecords =>
      $$IdentificationRecordsTableTableManager(_db, _db.identificationRecords);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$InstalledPackagesTableTableManager get installedPackages =>
      $$InstalledPackagesTableTableManager(_db, _db.installedPackages);
}
