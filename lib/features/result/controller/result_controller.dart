import 'package:get/get.dart';

import '../../processing/model/processing_args.dart';

/// Result (S7) controller — scaffold for this milestone: exposes the
/// finished job's outcome. Save/share/compare land in the next step.
class ResultController extends GetxController {
  late final ProcessingOutcome outcome;

  @override
  void onInit() {
    super.onInit();
    outcome = Get.arguments as ProcessingOutcome;
  }

  bool get nobodyRemoved => outcome.nobodyRemoved;
  int get removedCount => outcome.removedIds.length;
  int get totalCount => outcome.personsDetected;
}
