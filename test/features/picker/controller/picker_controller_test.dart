import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:people_gone/core/utils/result.dart';
import 'package:people_gone/features/picker/controller/picker_controller.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pg_picker_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<File> fileOfSize(int bytes) async {
    final file = File('${tempDir.path}/p$bytes.jpg');
    await file.writeAsBytes(List<int>.filled(bytes, 7));
    return file;
  }

  test('success: returns the picked path and clears picking state', () async {
    final file = await fileOfSize(100);
    final controller = PickerController(
      pickImage: () async => XFile(file.path),
      maxBytes: 1000,
    );
    final result = await controller.pickPhoto();
    expect(result, isA<Success<String?>>());
    expect((result as Success<String?>).value, file.path);
    expect(controller.isPicking.value, isFalse);
    expect(controller.errorMessage.value, isNull);
  });

  test('cancel: a null pick is a success with no path and no error', () async {
    final controller = PickerController(
      pickImage: () async => null,
      maxBytes: 1000,
    );
    final result = await controller.pickPhoto();
    expect(result, isA<Success<String?>>());
    expect((result as Success<String?>).value, isNull);
    expect(controller.errorMessage.value, isNull);
  });

  test('too large: fails with the plain-language size message', () async {
    final file = await fileOfSize(2000);
    final controller = PickerController(
      pickImage: () async => XFile(file.path),
      maxBytes: 1000,
    );
    final result = await controller.pickPhoto();
    expect(result, isA<Failure<String?>>());
    expect((result as Failure<String?>).failure.code, 'too_large');
    expect(controller.errorMessage.value, 'error_photo_too_large');
  });

  test('picker throwing surfaces a generic failure, state reset', () async {
    final controller = PickerController(
      pickImage: () async => throw StateError('platform gone'),
      maxBytes: 1000,
    );
    final result = await controller.pickPhoto();
    expect(result, isA<Failure<String?>>());
    expect((result as Failure<String?>).failure.code, 'picker_failed');
    expect(controller.isPicking.value, isFalse);
  });
}
