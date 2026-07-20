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
  int get schemaVersion => 1;

  Stream<List<IdentificationRecord>> watchHistory() {
    return (select(identificationRecords)
          ..orderBy(<OrderingTerm Function(IdentificationRecords)>[
            (IdentificationRecords table) => OrderingTerm.desc(table.createdAt),
          ]))
        .watch();
  }

  Future<void> addIdentification({
    required String speciesId,
    required String turkishName,
    required String scientificName,
    required String confidence,
    required String modelVersion,
    String? imageUri,
    String? thumbnailUri,
    String? packageId,
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
      ),
    );
  }

  Future<void> deleteIdentification(int id) {
    return (delete(
      identificationRecords,
    )..where((IdentificationRecords table) => table.id.equals(id))).go();
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
