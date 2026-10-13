import 'package:flutter_test/flutter_test.dart';
import 'package:people_gone/config/app_config.dart';
import 'package:people_gone/core/utils/result.dart';
import 'package:people_gone/services/processing/processing_api_impl.dart';

void main() {
  group('ProcessingApiImpl (Phase 1 scaffold)', () {
    final api = ProcessingApiImpl(config: AppConfig.fromEnvironment());

    test(
      'analysePhoto fails loudly as not_implemented until Phase 2',
      () async {
        final result = await api.analysePhoto('/tmp/does-not-matter.jpg');
        expect(result, isA<Failure<dynamic>>());
        final failure = (result as Failure<dynamic>).failure;
        expect(failure.code, 'not_implemented');
      },
    );

    test(
      'removePeople fails loudly as not_implemented until Phase 2',
      () async {
        final result = await api.removePeople('job-1', <int>[2, 3]);
        expect(result, isA<Failure<dynamic>>());
        expect((result as Failure<dynamic>).failure.code, 'not_implemented');
      },
    );
  });
}
