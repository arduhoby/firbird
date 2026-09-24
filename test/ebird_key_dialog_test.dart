import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:firbird/app/history_and_settings_screens.dart';
import 'package:firbird/data/app_database.dart';
import 'package:firbird/l10n/app_localizations.dart';
import 'package:firbird/observation_context/ebird_live_observation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('eBird key error and successful save close cleanly', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const MethodChannel secureStorage = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          secureStorage,
          (MethodCall call) async => null,
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorage, null),
    );
    final AppDatabase database = AppDatabase.forTesting(
      NativeDatabase.memory(),
    );
    addTearDown(database.close);
    final Dio dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest:
              (RequestOptions options, RequestInterceptorHandler handler) {
                handler.resolve(
                  Response<dynamic>(requestOptions: options, data: []),
                );
              },
        ),
      );
    addTearDown(dio.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(
            ebirdLiveService: EbirdLiveObservationService(dio: dio),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('eBird API anahtarı'), 300);
    await tester.tap(find.text('eBird API anahtarı'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test et ve kaydet'));
    await tester.pump();
    expect(find.text('Geçerli bir eBird API anahtarı girin.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '12345678');
    await tester.tap(find.text('Test et ve kaydet'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(await database.eBirdApiKeyLastVerifiedAt(), isNotNull);
  });
}
