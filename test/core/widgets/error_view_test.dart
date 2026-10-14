import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:people_gone/core/strings/app_strings.dart';
import 'package:people_gone/core/theme/app_theme.dart';
import 'package:people_gone/core/widgets/error_view.dart';

void main() {
  Future<void> pump(WidgetTester tester, {VoidCallback? onShare}) {
    return tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        theme: AppTheme.light(),
        home: Scaffold(
          body: ErrorView(
            messageKey: AppStrings.errorProcessingFailed,
            onRetry: () {},
            onShareDiagnostics: onShare,
          ),
        ),
      ),
    );
  }

  testWidgets('share diagnostics action appears only when provided', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text(AppStrings.diagnosticsShare.tr), findsNothing);

    var shared = false;
    await pump(tester, onShare: () => shared = true);
    expect(find.text(AppStrings.diagnosticsShare.tr), findsOneWidget);
    await tester.tap(find.text(AppStrings.diagnosticsShare.tr));
    expect(shared, isTrue);
  });
}
