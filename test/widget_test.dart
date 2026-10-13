// App-shell smoke test: the scaffold builds and Home (S1) renders its
// wordmark + empty-state line in the default (light) theme.
import 'package:flutter_test/flutter_test.dart';
import 'package:people_gone/config/app_config.dart';
import 'package:people_gone/main.dart';

void main() {
  testWidgets('app shell renders Home with wordmark and empty line', (
    tester,
  ) async {
    await tester.pumpWidget(PeopleGoneApp(config: AppConfig.fromEnvironment()));
    await tester.pumpAndSettle();

    expect(find.text('PeopleGone'), findsWidgets);
    expect(
      find.text(
        'Remove background people from a photo. Your subject stays untouched.',
      ),
      findsOneWidget,
    );
  });
}
