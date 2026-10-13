import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:people_gone/config/app_config.dart';
import 'package:people_gone/core/strings/app_strings.dart';
import 'package:people_gone/core/theme/app_theme.dart';
import 'package:people_gone/core/utils/result.dart';
import 'package:people_gone/features/settings/controller/settings_controller.dart';
import 'package:people_gone/features/settings/view/settings_view.dart';
import 'package:people_gone/services/storage/local_store.dart';

class FakeStore implements LocalStore {
  int used = 0;
  DateTime reset = DateTime.utc(2026, 11, 1);

  @override
  Future<Result<int>> freeSavesUsed() async => Success<int>(used);

  @override
  Future<Result<DateTime>> freeSavesResetDate() async =>
      Success<DateTime>(reset);

  @override
  Future<Result<List<HistoryEntry>>> history() async =>
      const Success<List<HistoryEntry>>(<HistoryEntry>[]);

  @override
  Future<Result<void>> addHistory(HistoryEntry entry) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> deleteHistory(String id) async =>
      const Success<void>(null);

  @override
  Future<Result<String>> adoptIntoHistory(
    String sessionPath,
    String id,
  ) async => Success<String>(sessionPath);

  @override
  Future<Result<String>> writeSessionResult(Uint8List bytes) async =>
      const Success<String>('/session/result.jpg');

  @override
  Future<Result<void>> saveToGallery(String localPath) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> consumeFreeSave() async => const Success<void>(null);

  @override
  Future<Result<int?>> acceptedConsentVersion() async =>
      const Success<int?>(null);

  @override
  Future<Result<void>> setAcceptedConsentVersion(int version) async =>
      const Success<void>(null);
}

void main() {
  tearDown(Get.reset);

  Future<void> pumpSettings(WidgetTester tester, FakeStore store) async {
    Get.put<SettingsController>(
      SettingsController(
        localStore: store,
        config: const AppConfig(
          apiBaseUrl: 'https://worker.test',
          providerDisplayName: "PeopleGone's processing servers",
          consentVersion: 1,
          supportEmail: 'support@example.com',
          privacyPolicyUrl: 'https://example.invalid/privacy',
        ),
        openLink: (_) async => true,
      ),
    );
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        theme: AppTheme.light(),
        home: const SettingsView(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('plan line shows the computed reset date (A6)', (tester) async {
    final store = FakeStore()..used = 1;
    await pumpSettings(tester, store);
    expect(find.text('9 of 10 free saves left — resets 1 Nov'), findsOneWidget);
  });

  testWidgets('provider label and value keep a minimum gap (F8)', (
    tester,
  ) async {
    await pumpSettings(tester, FakeStore());
    final label = tester.getRect(find.text('Processing provider'));
    final value = tester.getRect(find.text("PeopleGone's processing servers"));
    expect(value.left - label.right, greaterThanOrEqualTo(8));
  });
}
