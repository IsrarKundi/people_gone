import 'package:flutter_test/flutter_test.dart';
import 'package:people_gone/core/diagnostics/diagnostics_log.dart';

void main() {
  group('DiagnosticsLog.sanitize', () {
    test('redacts Bearer tokens', () {
      expect(
        DiagnosticsLog.sanitize('Authorization: Bearer abc123XYZ.def'),
        isNot(contains('abc123XYZ')),
      );
    });

    test('redacts apikey and token assignments', () {
      final out = DiagnosticsLog.sanitize(
        'apikey=supersecret token: hunter2 ApiKey: abc',
      );
      expect(out, isNot(contains('supersecret')));
      expect(out, isNot(contains('hunter2')));
      expect(out, contains('<redacted>'));
    });

    test('strips signed-URL query strings', () {
      final out = DiagnosticsLog.sanitize(
        'GET https://x.supabase.co/storage/v1/object/sign/results/a.jpg'
        '?token=eyJhbGciOi rest',
      );
      expect(out, isNot(contains('eyJhbGciOi')));
      expect(out, contains('a.jpg?<redacted>'));
    });

    test('leaves ordinary step text untouched', () {
      const line = 'confirm -> job 1a2b3c4d keep=[0, 2] status=200';
      expect(DiagnosticsLog.sanitize(line), line);
    });
  });

  group('DiagnosticsLog buffer', () {
    test('export carries the header and entries in order', () {
      final log = DiagnosticsLog.instance;
      log.clear();
      log.add('auth', 'session established via signup (user 12345678)');
      log.add('gateway', 'confirm ok: job 1a2b3c4d');
      final out = log.export();
      expect(out, contains('PeopleGone diagnostics'));
      expect(out, contains('[auth] session established'));
      expect(
        out.indexOf('session established'),
        lessThan(out.indexOf('confirm ok')),
      );
      log.clear();
    });

    test('export of an empty log says so', () {
      final log = DiagnosticsLog.instance;
      log.clear();
      expect(log.export(), contains('(no entries yet)'));
    });
  });
}
