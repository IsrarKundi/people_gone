import 'dart:io';

import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/utils/result.dart';

/// Opens the SYSTEM photo picker (FR-01) and validates the chosen file.
///
/// `image_picker` with [ImageSource.gallery] launches the Android Photo
/// Picker / iOS PHPicker — the app never requests a media permission and
/// never sees the rest of the library. The pick function is injectable
/// so the controller's states are unit-testable without a device.
class PickerController extends GetxController {
  PickerController({Future<XFile?> Function()? pickImage, int? maxBytes})
    : _pickImage = pickImage ?? _systemPick,
      _maxBytes = maxBytes ?? maxPhotoBytes;

  /// Input cap (Requirements §4.3): above this the app says so plainly —
  /// a photo is NEVER silently downscaled instead.
  static const int maxPhotoBytes = 60 * 1024 * 1024;

  final Future<XFile?> Function() _pickImage;
  final int _maxBytes;

  final isPicking = false.obs;
  final errorMessage = RxnString();

  static Future<XFile?> _systemPick() =>
      ImagePicker().pickImage(source: ImageSource.gallery);

  /// Returns the picked photo's path, or null when the user cancelled
  /// the system picker (a normal outcome, not an error).
  Future<Result<String?>> pickPhoto() async {
    if (isPicking.value) return const Success<String?>(null);
    isPicking.value = true;
    errorMessage.value = null;
    try {
      final picked = await _pickImage();
      if (picked == null) return const Success<String?>(null);
      final length = await File(picked.path).length();
      if (length > _maxBytes) {
        errorMessage.value = AppStrings.errorPhotoTooLarge;
        return const Failure<String?>(
          AppFailure(
            code: 'too_large',
            userMessageKey: AppStrings.errorPhotoTooLarge,
          ),
        );
      }
      return Success<String?>(picked.path);
    } catch (e) {
      errorMessage.value = AppStrings.errorGeneric;
      return Failure<String?>(
        AppFailure(
          code: 'picker_failed',
          userMessageKey: AppStrings.errorGeneric,
          detail: e.toString(),
        ),
      );
    } finally {
      isPicking.value = false;
    }
  }
}
