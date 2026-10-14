import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/diagnostics/diagnostics_log.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/result.dart';
import '../../../services/processing/processing_api.dart';
import '../../brush/model/brush_args.dart';
import '../../processing/model/processing_args.dart';
import '../model/proposal_args.dart';

/// Proposal (S4) Controller: manages keeper/removal selections,
/// live removal count, and overlap quality warnings (Requirements §4 S4).
///
/// Entry (Review 04 F1): when only a photo path arrives, the controller
/// runs the analysing state itself — ProcessingApi.detectPersons fills
/// the proposal; on failure it falls back to the single-call processing
/// path so the user is never stranded on a dead screen.
class ProposalController extends GetxController {
  ProposalController({required this.processingApi});

  final ProcessingApi processingApi;

  late final ProposalArgs args;

  final persons = <DetectedPerson>[].obs;

  /// Belongings from the v3 proposal (attached + ambiguous).
  final belongings = <DetectedBelonging>[].obs;

  /// Attached belongings the user detached (X9): protected even when
  /// their person is removed. Detach state survives person toggles —
  /// it is a decision about the item, not about the person.
  final detachedBelongingIds = <int>{}.obs;

  /// Ambiguous belongings the user included for removal (X10: the
  /// default is Keep, so this set starts empty and only grows by an
  /// explicit user action).
  final includedItemIds = <int>{}.obs;

  /// True while detectPersons runs on entry (the analysing state).
  final isAnalyzing = false.obs;

  DetectionProposal? _detection;
  String _photoPath = '';

  String get photoPath => _detection?.photoPath ?? _photoPath;

  /// The detected photo's intrinsic size, from the proposal's
  /// inputDimensions — the coordinate space person boxes live in.
  /// Null until detection completes (or for a malformed proposal).
  Size? get imageSize {
    final dims = _detection?.inputDimensions;
    if (dims == null || dims.length < 2 || dims[0] <= 0 || dims[1] <= 0) {
      return null;
    }
    return Size(dims[0].toDouble(), dims[1].toDouble());
  }

  @override
  void onInit() {
    super.onInit();
    args = Get.arguments as ProposalArgs;
    final seeded = args.proposal;
    if (seeded != null) {
      _detection = seeded;
      _photoPath = seeded.photoPath;
      persons.assignAll(seeded.persons);
      belongings.assignAll(seeded.belongings);
    } else {
      _photoPath = args.photoPath ?? '';
      unawaited(_analyze());
    }
  }

  /// The analysing state (F1): detect, populate, or fall back to the
  /// old single-call processing route — never a dead end, never a
  /// fake proposal.
  Future<void> _analyze() async {
    isAnalyzing.value = true;
    final result = await processingApi.detectPersons(localPath: _photoPath);
    isAnalyzing.value = false;
    switch (result) {
      case Success<DetectionProposal>(:final value):
        diag(
          'proposal',
          'persons loaded: ${value.persons.length} '
          'belongings: ${value.belongings.length}',
        );
        _detection = value;
        persons.assignAll(value.persons);
        belongings.assignAll(value.belongings);
      case Failure<DetectionProposal>(:final failure):
        diag(
          'proposal',
          'detect FAILED code=${failure.code} detail=${failure.detail ?? ''} '
          '— falling back to single-call processing',
        );
        Get.offNamed<void>(
          Routes.processing,
          arguments: ProcessingArgs(photoPath: _photoPath),
        );
    }
  }

  int get removeCount => persons.where((p) => !p.isKeeper).length;
  int get keeperCount => persons.where((p) => p.isKeeper).length;
  int get totalCount => persons.length;
  bool get nobodyToRemove => removeCount == 0;

  /// Attached belongings of one person (chip "Includes:" line, X9).
  List<DetectedBelonging> attachedBelongingsFor(int personId) => belongings
      .where(
        (b) => b.tier == BelongingTier.attached && b.personId == personId,
      )
      .toList();

  /// Ambiguous belongings — the Distractions group on S4 (X10).
  List<DetectedBelonging> get ambiguousItems => belongings
      .where((b) => b.tier == BelongingTier.ambiguous)
      .toList();

  bool isDetached(int itemId) => detachedBelongingIds.contains(itemId);
  bool isItemIncluded(int itemId) => includedItemIds.contains(itemId);
  int get includedCount => includedItemIds.length;

  /// The primary action exists whenever ANYTHING is being removed —
  /// people or included items (Review 04 F3: every reachable state
  /// keeps a working primary; keep-all-people + an included item is
  /// a real server job, never the local keep-all completion).
  bool get hasRemovals => removeCount > 0 || includedCount > 0;

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

  /// Detach / re-attach an attached belonging (X9). A detached
  /// belonging is protected; re-attaching restores following its
  /// person's state.
  void toggleDetach(int itemId) {
    if (detachedBelongingIds.contains(itemId)) {
      detachedBelongingIds.remove(itemId);
    } else {
      detachedBelongingIds.add(itemId);
    }
    detachedBelongingIds.refresh();
  }

  /// Include / exclude an ambiguous belonging (X3/X10: default Keep).
  void toggleItemIncluded(int itemId) {
    if (includedItemIds.contains(itemId)) {
      includedItemIds.remove(itemId);
    } else {
      includedItemIds.add(itemId);
    }
    includedItemIds.refresh();
  }

  /// Canvas tap on a belonging (tap priority is resolved by the
  /// canvas — people > belongings > distractions, X7): an attached
  /// belonging toggles its detach state, an ambiguous one toggles
  /// its inclusion.
  void toggleBelonging(int itemId) {
    final index = belongings.indexWhere((b) => b.id == itemId);
    if (index == -1) return;
    if (belongings[index].tier == BelongingTier.attached) {
      toggleDetach(itemId);
    } else {
      toggleItemIncluded(itemId);
    }
  }

  /// User confirms the proposal and starts the clean (S6), carrying
  /// the KEPT person ids as the keeper override plus the v3
  /// belongings decisions (included ambiguous items, detached
  /// attached items).
  void confirmProposal() {
    final keepIds = persons.where((p) => p.isKeeper).map((p) => p.id).toList();
    final removeItemIds = includedItemIds.toList()..sort();
    final detached = detachedBelongingIds.toList()..sort();
    diag(
      'proposal',
      'confirm tapped: keep=$keepIds items=$removeItemIds detached=$detached',
    );

    Get.offNamed<void>(
      Routes.processing,
      arguments: ProcessingArgs(
        photoPath: photoPath,
        keepIds: keepIds,
        removeItemIds: removeItemIds,
        detachedBelongingIds: detached,
      ),
    );
  }

  /// Keep-all state (Review 04 F3): every detected person is kept, so
  /// the job completes LOCALLY with the original photo as the result.
  /// No processPhoto call and no save credit — Result's nobodyRemoved
  /// handling renders it from there (§7.3).
  void completeKeepAll() {
    Get.offNamed<void>(
      Routes.result,
      arguments: ProcessingOutcome(
        originalPath: photoPath,
        resultPath: photoPath,
        personsDetected: persons.length,
        keeperIds: persons.map((p) => p.id).toList(),
        removedIds: const <int>[],
        totalSeconds: 0,
        engineUsed: '',
        persons: persons.toList(),
      ),
    );
  }

  /// No-people state (Review 04 F3): pick a different photo instead —
  /// the flow restarts from Home.
  void chooseDifferentPhoto() => Get.offAllNamed<void>(Routes.home);

  /// No-people state (FR-06): Brush mode is offered even when
  /// detection found nobody — the user paints what should go.
  void openBrush() {
    Get.toNamed<void>(Routes.brush, arguments: BrushArgs(imagePath: photoPath));
  }

  void goHome() => Get.offAllNamed<void>(Routes.home);
}
