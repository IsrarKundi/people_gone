import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:people_gone/core/strings/app_strings.dart';
import 'package:people_gone/core/theme/app_theme.dart';
import 'package:people_gone/core/widgets/consent_sheet.dart';
import 'package:people_gone/core/widgets/primary_button.dart';

/// Review 02 F5/A4: ConsentSheet has exactly two variants — consent
/// (Continue + Cancel) and read-only (a single Close, no Cancel).
void main() {
  tearDown(Get.reset);

  Future<void> pumpSheet(
    WidgetTester tester, {
    required ConsentSheetVariant variant,
    required VoidCallback onContinue,
    VoidCallback? onCancel,
  }) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        theme: AppTheme.light(),
        home: Scaffold(
          body: ConsentSheet(
            titleKey: AppStrings.consentTitle,
            bodyKey: AppStrings.consentBody,
            bodyParams: const <String, String>{'provider': 'Test provider'},
            variant: variant,
            continueLabelKey: variant == ConsentSheetVariant.readOnly
                ? AppStrings.commonClose
                : AppStrings.consentContinue,
            onContinue: onContinue,
            onCancel: onCancel,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('consent variant shows Continue and Cancel', (tester) async {
    var cancelled = false;
    await pumpSheet(
      tester,
      variant: ConsentSheetVariant.consent,
      onContinue: () {},
      onCancel: () => cancelled = true,
    );
    expect(find.text('Continue and upload my photo'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    expect(cancelled, isTrue);
  });

  testWidgets('read-only variant shows a single Close and no Cancel', (
    tester,
  ) async {
    await pumpSheet(
      tester,
      variant: ConsentSheetVariant.readOnly,
      onContinue: () {},
    );
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    expect(find.byType(PrimaryButton), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });
}
