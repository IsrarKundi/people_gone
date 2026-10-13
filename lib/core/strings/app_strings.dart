import 'package:get/get.dart';

/// Every user-visible string (Conventions §6.5). Views reference the key
/// constants here — never a literal, never a bare key typed inline.
/// English ships in v1; Urdu entries join this same map later.
abstract final class AppStrings {
  static const String appName = 'app_name';
  static const String homeTitle = 'home_title';
  static const String homePickPhoto = 'home_pick_photo';
  static const String homeEmptyLine = 'home_empty_line';
  static const String homeSavesLeft = 'home_saves_left';
  static const String commonRetry = 'common_retry';
  static const String commonCancel = 'common_cancel';
  static const String commonContinue = 'common_continue';
  static const String errorGeneric = 'error_generic';
  static const String errorOffline = 'error_offline';
  static const String errorNotImplemented = 'error_not_implemented';
}

/// GetX translations map.
class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => <String, Map<String, String>>{
        'en_US': <String, String>{
          AppStrings.appName: 'PeopleGone',
          AppStrings.homeTitle: 'PeopleGone',
          AppStrings.homePickPhoto: 'Pick a photo',
          AppStrings.homeEmptyLine:
              'Remove background people from a photo. Your subject stays untouched.',
          AppStrings.homeSavesLeft: '@count of 10 free saves left this month.',
          AppStrings.commonRetry: 'Retry',
          AppStrings.commonCancel: 'Cancel',
          AppStrings.commonContinue: 'Continue',
          AppStrings.errorGeneric: 'Something went wrong. Please try again.',
          AppStrings.errorOffline:
              'You are offline. Your photo stays on this phone.',
          AppStrings.errorNotImplemented: 'This part is not ready yet.',
        },
      };
}
