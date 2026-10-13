import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CMP-01 / FR-01 guard: PeopleGone NEVER requests a media or storage
/// permission — photo access is the system picker only (Requirements
/// §6.7, §13.1). This checks the app module's source manifest; library
/// manifests are checked too where they are visible in the repo
/// (currently none declare permissions — gal 2.3.x ships an empty one).
void main() {
  test('app manifest declares no media/storage permissions', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml');
    expect(manifest.existsSync(), isTrue);
    final content = manifest.readAsStringSync();
    for (final forbidden in <String>[
      'READ_MEDIA_IMAGES',
      'READ_MEDIA_VIDEO',
      'READ_MEDIA_AUDIO',
      'READ_EXTERNAL_STORAGE',
      'WRITE_EXTERNAL_STORAGE',
      'MANAGE_EXTERNAL_STORAGE',
      'android.permission.CAMERA',
    ]) {
      expect(
        content.contains(forbidden),
        isFalse,
        reason: 'Manifest must never declare $forbidden',
      );
    }
  });

  test('pubspec pulls in no library-access photo package', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final forbidden in <String>['photo_manager', 'wechat_assets_picker']) {
      expect(pubspec.contains(forbidden), isFalse);
    }
  });
}
