import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class IdentificationRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get speciesId => text()();
  TextColumn get turkishName => text()();
  TextColumn get scientificName => text()();
  TextColumn get confidence => text()();
  TextColumn get modelVersion => text()();
  TextColumn get imageUri => text().nullable()();
  TextColumn get thumbnailUri => text().nullable()();
  TextColumn get packageId => text().nullable()();
  TextColumn get speciesStatus => text().nullable()();
  RealColumn get modelConfidence => real().nullable()();
  IntColumn get repeatedHits => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime()();

  // --- Cinsiyet & Yaşam Evresi (schemaVersion 2) ---
  TextColumn get sexCategory => text().nullable()();
  RealColumn get sexConfidence => real().nullable()();
  TextColumn get ageCategory => text().nullable()();
  RealColumn get ageConfidence => real().nullable()();
  TextColumn get predictionMethod => text().nullable()();
  TextColumn get userCorrectedSex => text().nullable()();
  TextColumn get userCorrectedAge => text().nullable()();

  // --- Tür (schemaVersion 2) ---
  TextColumn get userCorrectedSpeciesId => text().nullable()();
  TextColumn get userCorrectedTurkishName => text().nullable()();
}

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}

class LiveDetectionEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId => text()();
  TextColumn get speciesId => text()();
  TextColumn get turkishName => text()();
  TextColumn get scientificName => text()();
  RealColumn get confidence => real()();
  IntColumn get startMs => integer()();
  IntColumn get endMs => integer()();
  TextColumn get regionalSupport => text().nullable()();
  TextColumn get temporalContext => text().nullable()();
  TextColumn get speciesStatus => text().nullable()();
  DateTimeColumn get detectedAt => dateTime().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

class InstalledPackages extends Table {
  TextColumn get packageId => text()();
  TextColumn get version => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  DateTimeColumn get installedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{packageId};
}

@DriftDatabase(
  tables: <Type>[
    IdentificationRecords,
    LiveDetectionEvents,
    AppSettings,
    InstalledPackages,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.addColumn(
            identificationRecords,
            identificationRecords.userCorrectedSpeciesId,
          );
          await m.addColumn(
            identificationRecords,
            identificationRecords.userCorrectedTurkishName,
          );
        }
        if (from < 3) {
          // Live sessions before schema 3 only stored one aggregate row per
          // species and cannot recreate the real event timeline. Start the
          // unified player history with complete sessions only.
          await delete(identificationRecords).go();
          await m.createTable(liveDetectionEvents);
        }
        if (from >= 3 && from < 4) {
          await m.addColumn(
            liveDetectionEvents,
            liveDetectionEvents.temporalContext,
          );
        }
        if (from < 5) {
          await m.addColumn(
            liveDetectionEvents,
            liveDetectionEvents.detectedAt,
          );
          await m.addColumn(liveDetectionEvents, liveDetectionEvents.latitude);
          await m.addColumn(liveDetectionEvents, liveDetectionEvents.longitude);
        }
        if (from < 6) {
          await m.addColumn(
            identificationRecords,
            identificationRecords.speciesStatus,
          );
          await m.addColumn(
            liveDetectionEvents,
            liveDetectionEvents.speciesStatus,
          );
        }
        if (from < 7) {
          await m.addColumn(
            identificationRecords,
            identificationRecords.modelConfidence,
          );
          await m.addColumn(
            identificationRecords,
            identificationRecords.repeatedHits,
          );
        }
      },
    );
  }

  Stream<List<IdentificationRecord>> watchHistory() {
    return (select(identificationRecords)
          ..orderBy(<OrderingTerm Function(IdentificationRecords)>[
            (IdentificationRecords table) => OrderingTerm.desc(table.createdAt),
          ]))
        .watch();
  }

  Future<int> addIdentification({
    required String speciesId,
    required String turkishName,
    required String scientificName,
    required String confidence,
    required String modelVersion,
    String? imageUri,
    String? thumbnailUri,
    String? packageId,
    String? speciesStatus,
    double? modelConfidence,
    int repeatedHits = 1,
    String? sexCategory,
    double? sexConfidence,
    String? ageCategory,
    double? ageConfidence,
    String? predictionMethod,
  }) {
    return into(identificationRecords).insert(
      IdentificationRecordsCompanion.insert(
        speciesId: speciesId,
        turkishName: turkishName,
        scientificName: scientificName,
        confidence: confidence,
        modelVersion: modelVersion,
        imageUri: Value<String?>(imageUri),
        thumbnailUri: Value<String?>(thumbnailUri),
        packageId: Value<String?>(packageId),
        speciesStatus: Value<String?>(speciesStatus),
        modelConfidence: Value<double?>(modelConfidence),
        repeatedHits: Value<int>(repeatedHits),
        createdAt: DateTime.now(),
        sexCategory: Value<String?>(sexCategory),
        sexConfidence: Value<double?>(sexConfidence),
        ageCategory: Value<String?>(ageCategory),
        ageConfidence: Value<double?>(ageConfidence),
        predictionMethod: Value<String?>(predictionMethod),
      ),
    );
  }

  Future<void> deleteIdentification(int id) {
    return (delete(
      identificationRecords,
    )..where((IdentificationRecords table) => table.id.equals(id))).go();
  }

  Future<void> deleteLiveSession(String sessionId) {
    return transaction(() async {
      await (delete(identificationRecords)..where(
            (IdentificationRecords table) => table.packageId.equals(sessionId),
          ))
          .go();
      await (delete(liveDetectionEvents)..where(
            (LiveDetectionEvents table) => table.sessionId.equals(sessionId),
          ))
          .go();
    });
  }

  Future<int> addLiveDetectionEvent({
    required String sessionId,
    required String speciesId,
    required String turkishName,
    required String scientificName,
    required double confidence,
    required int startMs,
    required int endMs,
    required DateTime detectedAt,
    String? regionalSupport,
    String? temporalContext,
    String? speciesStatus,
    double? latitude,
    double? longitude,
  }) {
    return into(liveDetectionEvents).insert(
      LiveDetectionEventsCompanion.insert(
        sessionId: sessionId,
        speciesId: speciesId,
        turkishName: turkishName,
        scientificName: scientificName,
        confidence: confidence,
        startMs: startMs,
        endMs: endMs,
        regionalSupport: Value<String?>(regionalSupport),
        temporalContext: Value<String?>(temporalContext),
        speciesStatus: Value<String?>(speciesStatus),
        detectedAt: Value<DateTime?>(detectedAt),
        latitude: Value<double?>(latitude),
        longitude: Value<double?>(longitude),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<List<LiveDetectionEvent>> eventsForLiveSession(String sessionId) {
    return (select(liveDetectionEvents)
          ..where(
            (LiveDetectionEvents table) => table.sessionId.equals(sessionId),
          )
          ..orderBy(<OrderingTerm Function(LiveDetectionEvents)>[
            (LiveDetectionEvents table) => OrderingTerm.asc(table.startMs),
          ]))
        .get();
  }

  /// Kullanıcı tahmini onayladıktan veya düzelttikten sonra ilgili alanları günceller.
  ///
  /// [approved] true → kullanıcı modelin tahminini doğru buldu (userApproved).
  /// [approved] false → kullanıcı düzeltti (userValidated).
  Future<void> updateCorrection(
    int id, {
    String? correctedSex,
    String? correctedAge,
    String? correctedSpeciesId,
    String? correctedTurkishName,
    required bool approved,
  }) {
    final String method = approved ? 'userApproved' : 'userValidated';
    return (update(
      identificationRecords,
    )..where((IdentificationRecords table) => table.id.equals(id))).write(
      IdentificationRecordsCompanion(
        userCorrectedSex: Value<String?>(correctedSex),
        userCorrectedAge: Value<String?>(correctedAge),
        userCorrectedSpeciesId: Value<String?>(correctedSpeciesId),
        userCorrectedTurkishName: Value<String?>(correctedTurkishName),
        predictionMethod: Value<String?>(method),
      ),
    );
  }

  Future<void> clearHistory() {
    return transaction(() async {
      await delete(identificationRecords).go();
      await delete(liveDetectionEvents).go();
    });
  }

  Future<bool> isHistoryEnabled() async {
    return _boolSetting('historyEnabled', defaultValue: true);
  }

  Future<void> setHistoryEnabled(bool enabled) =>
      _setBoolSetting('historyEnabled', enabled);

  Future<bool> _boolSetting(String key, {required bool defaultValue}) async {
    final AppSetting? setting = await (select(
      appSettings,
    )..where((AppSettings table) => table.key.equals(key))).getSingleOrNull();
    if (setting == null) return defaultValue;
    return setting.value == 'true';
  }

  Future<void> _setBoolSetting(String key, bool enabled) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: key, value: enabled.toString()),
    );
  }

  Future<double> candidateThreshold() async {
    final AppSetting? setting =
        await (select(appSettings)..where(
              (AppSettings table) => table.key.equals('candidateThreshold'),
            ))
            .getSingleOrNull();
    return double.tryParse(setting?.value ?? '') ?? 0.20;
  }

  Future<void> setCandidateThreshold(double threshold) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(
        key: 'candidateThreshold',
        value: threshold.toStringAsFixed(2),
      ),
    );
  }

  Future<double> liveDetectionMinScore() async {
    final AppSetting? setting =
        await (select(appSettings)..where(
              (AppSettings table) => table.key.equals('liveDetectionMinScore'),
            ))
            .getSingleOrNull();
    return double.tryParse(setting?.value ?? '') ?? 0.0;
  }

  Future<void> setLiveDetectionMinScore(double score) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(
        key: 'liveDetectionMinScore',
        value: score.toStringAsFixed(2),
      ),
    );
  }

  Future<int> observationContextRadiusKm() async {
    final AppSetting? setting =
        await (select(appSettings)..where(
              (AppSettings table) =>
                  table.key.equals('observationContextRadiusKm'),
            ))
            .getSingleOrNull();
    final int radius = int.tryParse(setting?.value ?? '') ?? 20;
    return radius.clamp(1, 50);
  }

  Future<void> setObservationContextRadiusKm(int radiusKm) {
    final int safeRadius = radiusKm.clamp(1, 50);
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(
        key: 'observationContextRadiusKm',
        value: safeRadius.toString(),
      ),
    );
  }

  Future<DateTime?> eBirdApiKeyLastVerifiedAt() async {
    final AppSetting? setting =
        await (select(appSettings)..where(
              (AppSettings table) =>
                  table.key.equals('eBirdApiKeyLastVerifiedAt'),
            ))
            .getSingleOrNull();
    return DateTime.tryParse(setting?.value ?? '');
  }

  Future<void> setEBirdApiKeyLastVerifiedAt(DateTime value) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(
        key: 'eBirdApiKeyLastVerifiedAt',
        value: value.toUtc().toIso8601String(),
      ),
    );
  }

  Future<void> clearEBirdApiKeyLastVerifiedAt() {
    return (delete(appSettings)..where(
          (AppSettings table) => table.key.equals('eBirdApiKeyLastVerifiedAt'),
        ))
        .go();
  }

  Future<String> cropMode() async {
    final AppSetting? setting =
        await (select(appSettings)
              ..where((AppSettings table) => table.key.equals('cropMode')))
            .getSingleOrNull();
    return setting?.value ?? 'auto'; // 'off', 'auto', 'manual'
  }

  Future<void> setCropMode(String mode) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: 'cropMode', value: mode),
    );
  }

  Future<String> themeMode() async {
    final AppSetting? setting =
        await (select(appSettings)
              ..where((AppSettings table) => table.key.equals('themeMode')))
            .getSingleOrNull();
    return setting?.value ?? 'system'; // 'light', 'dark', 'system'
  }

  Future<void> setThemeMode(String mode) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: 'themeMode', value: mode),
    );
  }

  Future<String?> activePackageId() async {
    final InstalledPackage? package =
        await (select(installedPackages)
              ..where((InstalledPackages table) => table.isActive.equals(true)))
            .getSingleOrNull();
    return package?.packageId;
  }

  Future<void> setActivePackage(String packageId, String version) {
    return transaction(() async {
      await update(
        installedPackages,
      ).write(const InstalledPackagesCompanion(isActive: Value<bool>(false)));
      await into(installedPackages).insertOnConflictUpdate(
        InstalledPackagesCompanion.insert(
          packageId: packageId,
          version: version,
          isActive: const Value<bool>(true),
          installedAt: DateTime.now(),
        ),
      );
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final File file = File(
      <String>[directory.path, 'firbird.sqlite'].join(Platform.pathSeparator),
    );
    return NativeDatabase.createInBackground(file);
  });
}

final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((
  Ref ref,
) {
  final AppDatabase database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});
