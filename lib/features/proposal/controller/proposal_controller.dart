import 'dart:math' as math;

import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../services/processing/processing_api.dart';
import '../../processing/model/processing_args.dart';
import '../model/proposal_args.dart';

/// Proposal (S4) Controller: manages keeper/removal selections,
/// live removal count, and overlap quality warnings (Requirements §4 S4).
class ProposalController extends GetxController {
  late final ProposalArgs args;

  final persons = <DetectedPerson>[].obs;

  String get photoPath => args.proposal.photoPath;

  @override
  void onInit() {
    super.onInit();
    args = Get.arguments as ProposalArgs;
    persons.assignAll(args.proposal.persons);
  }

  int get removeCount => persons.where((p) => !p.isKeeper).length;
  int get keeperCount => persons.where((p) => p.isKeeper).length;
  int get totalCount => persons.length;
  bool get nobodyToRemove => removeCount == 0;

  /// Checks if any person marked for removal bounding box overlaps with
  /// any keeper's bounding box. If so, a touch-up risk warning is shown (FR-04).
  bool get hasOverlapRisk {
    final keepers = persons.where((p) => p.isKeeper).toList();
    final removals = persons.where((p) => !p.isKeeper).toList();

    for (final rem in removals) {
      if (rem.box.length < 4) continue;
      for (final keep in keepers) {
        if (keep.box.length < 4) continue;
        final interX1 = math.max(rem.box[0], keep.box[0]);
        final interY1 = math.max(rem.box[1], keep.box[1]);
        final interX2 = math.min(rem.box[2], keep.box[2]);
        final interY2 = math.min(rem.box[3], keep.box[3]);

        if (interX1 < interX2 && interY1 < interY2) {
          return true;
        }
      }
    }
    return false;
  }

  /// Toggles a person's status between keeper and removal.
  void togglePerson(int id) {
    final index = persons.indexWhere((p) => p.id == id);
    if (index == -1) return;

    final person = persons[index];
    persons[index] = person.copyWith(isKeeper: !person.isKeeper);
  }

  /// User confirms the proposal and starts the clean (S6).
  void confirmProposal() {
    final keepIds = persons.where((p) => p.isKeeper).map((p) => p.id).toList();

    Get.offNamed<void>(
      Routes.processing,
      arguments: ProcessingArgs(photoPath: photoPath, keepIds: keepIds),
    );
  }

  void goHome() => Get.offAllNamed<void>(Routes.home);
}
