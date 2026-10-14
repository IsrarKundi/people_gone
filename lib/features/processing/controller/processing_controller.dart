import 'dart:async';

import 'package:get/get.dart';

import '../../../core/diagnostics/diagnostics_log.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/result.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../services/processing/job_tracker.dart';
import '../../../services/processing/processing_api.dart';
import '../../../services/storage/local_store.dart';
import '../model/processing_args.dart';

enum ProcessingStage { uploading, working }

/// Processing (S3/S6): uploads the picked photo to our server and waits
/// for the clean. Progress is honest (Design Direction §1.5/§6): the
/// upload percentage is real bytes and appears only once bytes move
/// (Review 05 F1); the server stage is indeterminate — never a fake
/// percentage, and no stopwatch (Review 05 Supplement R5).
class ProcessingController extends GetxController {
  ProcessingController({required this.processingApi, required this.localStore});

  final ProcessingApi processingApi;
  final LocalStore localStore;

  late final ProcessingArgs args;

  final stage = ProcessingStage.uploading.obs;
  final uploadFraction = 0.0.obs;

  /// True once the first upload-progress callback reports bytes moved;
  /// before that the honest stage label is "connecting" (F1).
  final uploadMoved = false.obs;
  final errorMessage = RxnString();
  final isRunning = false.obs;

  bool _left = false;

  String get photoPath => args.photoPath;

  /// The working-stage line (design X15): a job whose confirmed
  /// proposal included distractions names them — "Removing 3 people
  /// and 2 distractions…" — derived from the confirmed counts in the
  /// args. Jobs without confirmed counts (or with none included)
  /// keep the generic people line; no count is ever invented.
  String get workingTitle {
    final distractions = args.distractionsIncluded ?? 0;
    if (distractions <= 0) return AppStrings.processingFindingRemoving.tr;
    final people = args.peopleToRemove ?? 0;
    final parts = <String>[
      if (people == 1)
        AppStrings.processingPartPersonOne.tr
      else if (people > 1)
        AppStrings.processingPartPeople.trParams(<String, String>{
          'count': '$people',
        }),
      if (distractions == 1)
        AppStrings.processingPartDistractionOne.tr
      else
        AppStrings.processingPartDistractions.trParams(<String, String>{
          'count': '$distractions',
        }),
    ];
    return AppStrings.processingRemovingCombo.trParams(<String, String>{
      'parts': parts.join(' and '),
    });
  }

  @override
  void onInit() {
    super.onInit();
    args = Get.arguments as ProcessingArgs;
    unawaited(start());
  }

  Future<void> start() async {
    if (isRunning.value) return;
    isRunning.value = true;
    errorMessage.value = null;
    stage.value = ProcessingStage.uploading;
    uploadFraction.value = 0;
    uploadMoved.value = false;

    JobTracker.instance.trackStarted(
      photoPath: args.photoPath,
      keepIds: args.keepIds,
      removeItemIds: args.removeItemIds,
      detachedBelongingIds: args.detachedBelongingIds,
    );

    diag(
      'processing',
      'start photo=${args.photoPath.split('/').last} keepIds=${args.keepIds} '
          'items=${args.removeItemIds} detached=${args.detachedBelongingIds}',
    );
    final result = await processingApi.processPhoto(
      localPath: args.photoPath,
      keepIds: args.keepIds,
      removeItemIds: args.removeItemIds,
      detachedBelongingIds: args.detachedBelongingIds,
      onUploadProgress: (fraction) {
        uploadFraction.value = fraction;
        if (fraction > 0) uploadMoved.value = true;
        if (fraction >= 1.0) stage.value = ProcessingStage.working;
      },
    );
    isRunning.value = false;

    switch (result) {
      case Success<ProcessedPhoto>(:final value):
        diag(
          'processing',
          'success: detected=${value.personsDetected} '
              'removed=${value.removedIds.length} engine=${value.engineUsed}',
        );
        await _deliver(value);
      case Failure<ProcessedPhoto>(:final failure):
        diag(
          'processing',
          'FAILED code=${failure.code} detail=${failure.detail ?? ''}',
        );
        if (failure.code == 'cancelled') {
          JobTracker.instance.clear();
          _goHome();
        } else {
          JobTracker.instance.trackFailed(failure.userMessageKey);
          if (!_left) {
            errorMessage.value = failure.userMessageKey;
          }
        }
    }
  }

  Future<void> _deliver(ProcessedPhoto photo) async {
    final written = await localStore.writeSessionResult(photo.resultBytes);
    switch (written) {
      case Success<String>(:final value):
        final outcome = ProcessingOutcome(
          originalPath: args.photoPath,
          resultPath: value,
          personsDetected: photo.personsDetected,
          keeperIds: photo.keeperIds,
          removedIds: photo.removedIds,
          totalSeconds: photo.totalSeconds,
          engineUsed: photo.engineUsed,
          persons: photo.persons,
          itemsRemoved: photo.itemsRemoved,
          distractionsRemoved: photo.distractionsRemoved,
          reflectionWarning: photo.reflectionWarning,
          reflectionRegions: photo.reflectionRegions,
        );
        JobTracker.instance.trackDone(outcome);
        if (_left) return;
        Get.offNamed<void>(Routes.result, arguments: outcome);
      case Failure<String>():
        JobTracker.instance.trackFailed(AppStrings.errorGeneric);
        if (_left) return;
        errorMessage.value = AppStrings.errorGeneric;
    }
  }

  /// User chooses to background the job and return to Home while processing
  /// continues server-side (Option 3 / backgrounding flow).
  void workInBackground() {
    diag('processing', 'user selected workInBackground');
    _left = true;
    Get.offAllNamed<void>(Routes.home);
  }

  /// Cancel (S6): the confirm dialog states the no-charge guarantee;
  /// cancelling consumes nothing (FR-07).
  Future<void> cancel() async {
    if (!isRunning.value) {
      JobTracker.instance.clear();
      _goHome();
      return;
    }
    final confirmed = await AppDialog.confirm(
      titleKey: AppStrings.processingCancelTitle,
      bodyKey: AppStrings.processingCancelBody,
      confirmLabelKey: AppStrings.processingCancelConfirm,
      cancelLabelKey: AppStrings.commonCancel,
    );
    if (confirmed) {
      JobTracker.instance.clear();
      processingApi.cancelOngoing();
    }
  }

  void _goHome() {
    if (_left) return;
    _left = true;
    Get.offAllNamed<void>(Routes.home);
  }
}
