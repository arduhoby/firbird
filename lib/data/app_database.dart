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

class InstalledPackages extends Table {
  TextColumn get packageId => text()();
  TextColumn get version => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  DateTimeColumn get installedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{packageId};
}

@DriftDatabase(
  tables: <Type>[IdentificationRecords, AppSettings, InstalledPackages],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

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
    return (delete(
      identificationRecords,
    )..where((IdentificationRecords table) => table.packageId.equals(sessionId))).go();
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
    return (update(identificationRecords)
          ..where((IdentificationRecords table) => table.id.equals(id)))
        .write(
          IdentificationRecordsCompanion(
            userCorrectedSex: Value<String?>(correctedSex),
            userCorrectedAge: Value<String?>(correctedAge),
            userCorrectedSpeciesId: Value<String?>(correctedSpeciesId),
            userCorrectedTurkishName: Value<String?>(correctedTurkishName),
            predictionMethod: Value<String?>(method),
          ),
        );
  }

  Future<void> clearHistory() => delete(identificationRecords).go();

  Future<bool> isHistoryEnabled() async {
    final AppSetting? setting =
        await (select(
              appSettings,
            )..where((AppSettings table) => table.key.equals('historyEnabled')))
            .getSingleOrNull();
    return setting?.value != 'false';
  }

  Future<void> setHistoryEnabled(bool enabled) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(
        key: 'historyEnabled',
        value: enabled.toString(),
      ),
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

  Future<String> cropMode() async {
    final AppSetting? setting =
        await (select(appSettings)..where(
              (AppSettings table) => table.key.equals('cropMode'),
            ))
            .getSingleOrNull();
    return setting?.value ?? 'auto'; // 'off', 'auto', 'manual'
  }

  Future<void> setCropMode(String mode) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(
        key: 'cropMode',
        value: mode,
      ),
    );
  }

  Future<String> themeMode() async {
    final AppSetting? setting =
        await (select(appSettings)..where(
              (AppSettings table) => table.key.equals('themeMode'),
            ))
            .getSingleOrNull();
    return setting?.value ?? 'system'; // 'light', 'dark', 'system'
  }

  Future<void> setThemeMode(String mode) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(
        key: 'themeMode',
        value: mode,
      ),
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
