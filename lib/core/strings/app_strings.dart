import 'package:get/get.dart';

/// Every user-visible string (Conventions §6.5). Views reference the key
/// constants here — never a literal, never a bare key typed inline.
/// English ships in v1; Urdu entries join this same map later.
abstract final class AppStrings {
  static const String appName = 'app_name';

  // Common.
  static const String commonRetry = 'common_retry';
  static const String commonCancel = 'common_cancel';
  static const String commonContinue = 'common_continue';
  static const String commonClose = 'common_close';
  static const String commonDelete = 'common_delete';

  // Home (S1).
  static const String homeTitle = 'home_title';
  static const String homePickPhoto = 'home_pick_photo';
  static const String homeEmptyLine = 'home_empty_line';
  static const String homeSavesLeft = 'home_saves_left';
  static const String homeHistory = 'home_history';
  static const String homeSeeAll = 'home_see_all';

  // Consent (S2) — wording verbatim from Requirements §11.2A; the provider
  // display name is interpolated from AppConfig, never hard-coded.
  static const String consentTitle = 'consent_title';
  static const String consentBody = 'consent_body';
  static const String consentContinue = 'consent_continue';
  static const String consentPrivacyLink = 'consent_privacy_link';

  // Processing (S3/S6).
  static const String processingUploading = 'processing_uploading';
  static const String processingFindingRemoving = 'processing_finding_removing';
  static const String processingElapsed = 'processing_elapsed';
  static const String processingExpectation = 'processing_expectation';
  static const String processingCancelTitle = 'processing_cancel_title';
  static const String processingCancelBody = 'processing_cancel_body';
  static const String processingCancelConfirm = 'processing_cancel_confirm';

  // Proposal (S4).
  static const String proposalTitle = 'proposal_title';
  static const String proposalRemoveCount = 'proposal_remove_count';
  static const String proposalRemoveOne = 'proposal_remove_one';
  static const String proposalKeepAll = 'proposal_keep_all';
  static const String proposalNoPeople = 'proposal_no_people';
  static const String proposalOverlapWarning = 'proposal_overlap_warning';
  static const String proposalSubjectKept = 'proposal_subject_kept';
  static const String proposalPersonToRemove = 'proposal_person_to_remove';
  static const String proposalAnalyzing = 'proposal_analyzing';

  // Result (S7).
  static const String resultSummary = 'result_summary';
  static const String resultSave = 'result_save';
  static const String resultSaved = 'result_saved';
  static const String resultShare = 'result_share';
  static const String resultSavedSnackbar = 'result_saved_snackbar';
  static const String resultSaveUses = 'result_save_uses';
  static const String resultNoSaves = 'result_no_saves';
  static const String resultLocationNote = 'result_location_note';
  static const String resultDisclosure = 'result_disclosure';
  static const String resultReport = 'result_report';
  static const String resultWrongKeeper = 'result_wrong_keeper';
  static const String resultChooseKeeperTitle = 'result_choose_keeper_title';
  static const String resultPersonKept = 'result_person_kept';
  static const String resultPersonRemoved = 'result_person_removed';
  static const String resultKeepThisPerson = 'result_keep_this_person';
  static const String resultRerunNote = 'result_rerun_note';
  static const String resultPickAnother = 'result_pick_another';
  static const String resultBefore = 'result_before';
  static const String resultAfter = 'result_after';
  static const String resultOriginal = 'result_original';
  static const String reportTitle = 'report_title';
  static const String reportBody = 'report_body';
  static const String reportEmailAction = 'report_email_action';
  static const String savesOutTitle = 'saves_out_title';
  static const String savesOutBody = 'saves_out_body';

  // History (S9).
  static const String historyTitle = 'history_title';
  static const String historyOnDeviceLine = 'history_on_device_line';
  static const String historyEmptyLine = 'history_empty_line';
  static const String historyDeleteTitle = 'history_delete_title';
  static const String historyDeleteBody = 'history_delete_body';
  static const String historyDeletedSnackbar = 'history_deleted_snackbar';

  // Settings (S10).
  static const String settingsTitle = 'settings_title';
  static const String settingsYourPlan = 'settings_your_plan';
  static const String settingsSavesLeft = 'settings_saves_left';
  static const String settingsProcessingProvider =
      'settings_processing_provider';
  static const String settingsHowHandled = 'settings_how_handled';
  static const String settingsPrivacyPolicy = 'settings_privacy_policy';

  // Errors (§4.3: plain language + one recovery action).
  static const String errorGeneric = 'error_generic';
  static const String errorOffline = 'error_offline';
  static const String errorNotImplemented = 'error_not_implemented';
  static const String errorPhotoTooLarge = 'error_photo_too_large';
  static const String errorUploadFailed = 'error_upload_failed';
  static const String errorProcessingFailed = 'error_processing_failed';
  static const String errorTimeout = 'error_timeout';
  static const String errorNoPeople = 'error_no_people';
  static const String errorSaveFailed = 'error_save_failed';
  static const String errorPickAnother = 'error_pick_another';
}

/// GetX translations map.
class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => <String, Map<String, String>>{
    'en_US': <String, String>{
      AppStrings.appName: 'PeopleGone',
      AppStrings.commonRetry: 'Retry',
      AppStrings.commonCancel: 'Cancel',
      AppStrings.commonContinue: 'Continue',
      AppStrings.commonClose: 'Close',
      AppStrings.commonDelete: 'Delete',
      AppStrings.homeTitle: 'PeopleGone',
      AppStrings.homePickPhoto: 'Pick a photo',
      AppStrings.homeEmptyLine:
          'Remove background people from a photo. Your subject stays untouched.',
      AppStrings.homeSavesLeft: '@count of 10 free saves left this month.',
      AppStrings.homeHistory: 'History',
      AppStrings.homeSeeAll: 'See all',
      AppStrings.consentTitle: 'Before your photo is uploaded',
      AppStrings.consentBody:
          'To remove people, PeopleGone sends the photo you choose to '
          '@provider over an encrypted connection. Only that one photo is '
          'sent — PeopleGone does not access the rest of your library.\n\n'
          'Your photo is used only to create your cleaned photo. It is '
          'never used to train AI models and is deleted from our servers '
          'when processing finishes, and in all cases within 24 hours.',
      AppStrings.consentContinue: 'Continue and upload my photo',
      AppStrings.consentPrivacyLink: 'Full details: Privacy Policy',
      AppStrings.processingUploading: 'Uploading your photo…',
      AppStrings.processingFindingRemoving: 'Finding people and removing them…',
      AppStrings.processingElapsed: 'Elapsed @time',
      AppStrings.processingExpectation:
          'This can take a few minutes. Keep the app open while we work.',
      AppStrings.processingCancelTitle: 'Cancel this clean?',
      AppStrings.processingCancelBody:
          'Nothing will be charged to your free saves.',
      AppStrings.processingCancelConfirm: 'Cancel clean',
      AppStrings.proposalTitle: 'Review people to remove',
      AppStrings.proposalRemoveCount: 'Remove @count people',
      AppStrings.proposalRemoveOne: 'Remove 1 person',
      AppStrings.proposalKeepAll: 'Keep all (nobody to remove)',
      AppStrings.proposalNoPeople: "There's nobody in the background to remove.",
      AppStrings.proposalOverlapWarning:
          'This person overlaps your subject — edges may need a touch-up.',
      AppStrings.proposalSubjectKept: 'Subject (keep)',
      AppStrings.proposalPersonToRemove: 'Remove',
      AppStrings.proposalAnalyzing: 'Analyzing photo…',
      AppStrings.resultSummary:
          '@removed of @total people removed. Your subject stays untouched.',
      AppStrings.resultSave: 'Save photo',
      AppStrings.resultSaved: 'Saved',
      AppStrings.resultShare: 'Share',
      AppStrings.resultSavedSnackbar: 'Saved to your photos',
      AppStrings.resultSaveUses:
          'Saving uses 1 free save · @count left after this one',
      AppStrings.resultNoSaves: "You've used this month's free saves.",
      AppStrings.resultLocationNote:
          'Location data is removed from saved photos.',
      AppStrings.resultDisclosure:
          'Processed securely · Original deleted from server',
      AppStrings.resultReport: 'Report this result',
      AppStrings.resultWrongKeeper: 'Kept the wrong person?',
      AppStrings.resultChooseKeeperTitle: 'Who should stay in the photo?',
      AppStrings.resultPersonKept: 'Person @n — protected',
      AppStrings.resultPersonRemoved: 'Person @n — will be removed',
      AppStrings.resultKeepThisPerson: 'Keep this person instead',
      AppStrings.resultRerunNote: 'Re-running is free — it never uses a save.',
      AppStrings.resultPickAnother: 'Pick another photo',
      AppStrings.resultBefore: 'Before',
      AppStrings.resultAfter: 'After',
      AppStrings.resultOriginal: 'Original',
      AppStrings.reportTitle: 'Report this result',
      AppStrings.reportBody:
          'Tell us what went wrong with this clean. Your photo is sent '
          'only if you attach it to the email yourself.',
      AppStrings.reportEmailAction: 'Email support',
      AppStrings.savesOutTitle: 'No free saves left',
      AppStrings.savesOutBody:
          "You've used this month's free saves, so this photo can't be "
          'saved yet. Free saves return on the 1st.',
      AppStrings.historyTitle: 'History',
      AppStrings.historyOnDeviceLine: 'History lives only on this phone.',
      AppStrings.historyEmptyLine: 'Photos you clean will live here.',
      AppStrings.historyDeleteTitle: 'Delete this photo from history?',
      AppStrings.historyDeleteBody: 'Your original photo is not affected.',
      AppStrings.historyDeletedSnackbar: 'Removed from history',
      AppStrings.settingsTitle: 'Settings',
      AppStrings.settingsYourPlan: 'Your plan',
      AppStrings.settingsSavesLeft:
          '@count of 10 free saves left — resets @date',
      AppStrings.settingsProcessingProvider: 'Processing provider',
      AppStrings.settingsHowHandled: 'How your photos are handled',
      AppStrings.settingsPrivacyPolicy: 'Privacy Policy',
      AppStrings.errorGeneric: 'Something went wrong. Please try again.',
      AppStrings.errorOffline:
          'You are offline. Your photo stays on this phone.',
      AppStrings.errorNotImplemented: 'This part is not ready yet.',
      AppStrings.errorPhotoTooLarge:
          'This photo is larger than PeopleGone can process.',
      AppStrings.errorUploadFailed:
          "The upload didn't finish. Check your connection and try again.",
      AppStrings.errorProcessingFailed:
          "We couldn't clean this photo. Please try again.",
      AppStrings.errorTimeout:
          'This is taking longer than usual. Please try again.',
      AppStrings.errorNoPeople: "There's nobody in the background to remove.",
      AppStrings.errorSaveFailed:
          "That photo couldn't be saved. Please try again.",
      AppStrings.errorPickAnother: 'Pick another photo',
    },
  };
}
