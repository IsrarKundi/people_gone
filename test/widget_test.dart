// App-shell smoke test: Home (S1) renders per Design Review 01 — the
// wordmark appears EXACTLY once (app bar only), the saves line shows,
// the pick button is present, and the teaching line sits in flow.
// Storage is unimplemented on the test host, so the controller degrades
// to its defaults — which is itself part of what this test proves.
import 'package:flutter_test/flutter_test.dart';
import 'package:people_gone/config/app_config.dart';
import 'package:people_gone/main.dart';

void main() {
  testWidgets('app shell renders Home (Review 01 layout)', (tester) async {
    await tester.pumpWidget(PeopleGoneApp(config: AppConfig.fromEnvironment()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('PeopleGone'), findsOneWidget);
    expect(find.text('10 of 10 free saves left this month.'), findsOneWidget);
    expect(find.text('Pick a photo'), findsOneWidget);
    expect(
      find.text(
        'Remove background people from a photo. Your subject stays untouched.',
      ),
      findsOneWidget,
    );
  });
}
