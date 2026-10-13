import 'package:flutter_test/flutter_test.dart';
import 'package:people_gone/core/utils/result.dart';

void main() {
  group('Result', () {
    test('Success carries its value', () {
      const result = Success<int>(42);
      expect(result.value, 42);
    });

    test('Failure carries code and message key, never raw text', () {
      const failure = AppFailure(
        code: 'network',
        userMessageKey: 'error_offline',
      );
      const result = Failure<int>(failure);
      expect(result.failure.code, 'network');
      expect(result.failure.userMessageKey, 'error_offline');
      expect(result.failure.detail, isNull);
    });

    test('switch over Result is exhaustive', () {
      const Result<int> result = Success<int>(1);
      final label = switch (result) {
        Success<int>(:final value) => 'ok $value',
        Failure<int>() => 'failed',
      };
      expect(label, 'ok 1');
    });
  });
}
