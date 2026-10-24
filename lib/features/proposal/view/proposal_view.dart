import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_motion.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/cam_frame.dart';
import '../../../core/widgets/cam_mascot.dart';
import '../widgets/compact_crops_strip.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../controller/proposal_controller.dart';
import '../widgets/person_card.dart';
import '../widgets/proposal_items_group.dart';
import '../widgets/proposal_photo_canvas.dart';

/// Proposal (S4): reviews detected people with visual face chips,
/// indicates keepers (green) and removals (red), and offers live count removal.
class ProposalView extends GetView<ProposalController> {
  const ProposalView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _topBar(context),
            Expanded(
              child: Obx(
                () => ProposalPhotoCanvas(
                  photoPath: controller.photoPath,
                  persons: controller.persons.toList(),
                  imageSize: controller.imageSize,
                  onTogglePerson: controller.togglePerson,
                  belongings: controller.belongings.toList(),
                  detachedIds: controller.detachedBelongingIds.toSet(),
                  includedItemIds: controller.includedItemIds.toSet(),
                  onToggleBelonging: controller.toggleBelonging,
                  distractions: controller.distractions.toList(),
                  includedDistractionIds: controller.includedDistractionIds
                      .toSet(),
                  onToggleDistraction: controller.toggleDistractionIncluded,
                ),
              ),
            ),
            _bottomPanel(context),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.sm),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: Icon(AppIcons.close, color: p.textPrimary),
            onPressed: controller.goHome,
          ),
          SizedBox(width: s.xs),
          Expanded(
            child: Text(
              AppStrings.proposalTitle.tr,
              style: context.textStyles.titleMd,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomPanel(BuildContext context) {
    return Obx(() {
      final isAnalyzing = controller.isAnalyzing.value;
      final disableAnimations =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;

      return AnimatedSwitcher(
        duration: disableAnimations ? Duration.zero : AppMotion.standard,
        reverseDuration: Duration.zero,
        switchInCurve: AppMotion.enterCurve,
        layoutBuilder: (currentChild, previousChildren) =>
            currentChild ?? const SizedBox.shrink(),
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: KeyedSubtree(
          key: ValueKey<bool>(isAnalyzing),
          child: isAnalyzing
              ? _analyzingPanel(context)
              : _resultsPanel(context),
        ),
      );
    });
  }

  Widget _resultsPanel(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final overlap = controller.hasOverlapRisk;
    final persons = controller.persons;
    final items = controller.ambiguousItems;
    final distractions = controller.distractions;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        s.screenPadding,
        s.md,
        s.screenPadding,
        s.lg,
      ),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (overlap) ...<Widget>[
              Container(
                padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: p.error.withAlpha(20),
                  borderRadius: BorderRadius.circular(s.radiusPill),
                  border: Border.all(color: p.error.withAlpha(60)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      AppIcons.info,
                      size: 13,
                      color: p.error,
                    ),
                    SizedBox(width: s.xs),
                    Flexible(
                      child: Text(
                        AppStrings.proposalOverlapWarning.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyles.caption.copyWith(
                          color: p.error,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: s.xs),
            ],
            if (persons.isEmpty && items.isEmpty && distractions.isEmpty)
              _noPeopleActions(context)
            else ...<Widget>[
              if (persons.isNotEmpty) ...<Widget>[
                _statusSentence(context),
                SizedBox(height: s.xs),
                CompactCropsStrip(
                  persons: controller.persons,
                  photoPath: controller.photoPath,
                  onTogglePerson: controller.togglePerson,
                ),
                SizedBox(height: s.sm),
                SizedBox(
                  // Taller when any chip carries an "Includes:" line.
                  height:
                      persons.any(
                        (person) => controller
                            .attachedBelongingsFor(person.id)
                            .isNotEmpty,
                      )
                      ? 164
                      : 118,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: persons.length + 1,
                    separatorBuilder: (_, _) => SizedBox(width: s.sm),
                    itemBuilder: (context, index) {
                      if (index == persons.length) {
                        // End-of-tray cue (Review 04 F4): the total
                        // count, reached when the tray is scrolled out —
                        // it tells the user how many people exist in all.
                        return SizedBox(
                          width: 64,
                          child: Center(
                            child: Text(
                              AppStrings.proposalPeopleCount.trParams(
                                <String, String>{'count': '${persons.length}'},
                              ),
                              style: context.textStyles.bodySm.copyWith(
                                color: p.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      final person = persons[index];
                      return PersonCard(
                        person: person,
                        imagePath: controller.photoPath,
                        onTap: () => controller.togglePerson(person.id),
                        belongings: controller.attachedBelongingsFor(person.id),
                        detachedIds: controller.detachedBelongingIds.toSet(),
                        onToggleDetach: controller.toggleDetach,
                      );
                    },
                  ),
                ),
                SizedBox(height: s.md),
              ],
              if (items.isNotEmpty || distractions.isNotEmpty) ...<Widget>[
                ProposalItemsGroup(
                  items: items,
                  distractions: distractions,
                  photoPath: controller.photoPath,
                  includedItemIds: controller.includedItemIds.toSet(),
                  includedDistractionIds: controller.includedDistractionIds
                      .toSet(),
                  onToggleItem: controller.toggleItemIncluded,
                  onToggleDistraction: controller.toggleDistractionIncluded,
                  onRemoveAll: controller.includeAllGroupItems,
                  onKeepAll: controller.keepAllGroupItems,
                ),
                SizedBox(height: s.md),
              ],
              if (controller.hasRemovals)
                ProposalConfirmButton(
                  removes: controller.removeCount,
                  items: controller.includedCount,
                  onConfirm: controller.confirmProposal,
                )
              else if (persons.isNotEmpty)
                // Keep-all (Review 04 F3): completes locally with the
                // original photo — the label says exactly that.
                PrimaryButton(
                  labelKey: AppStrings.proposalKeepAllAction,
                  onPressed: controller.completeKeepAll,
                )
              else
                // No people, only unattached items, nothing included:
                // the plain no-people exits stay available below the
                // group (never a dead or disabled primary, F3).
                _noPeopleActions(context),
            ],
          ],
        ),
      );
  }

  /// Analysing state (Review 04 F1): the photo is already on screen
  /// above; this panel names the stage while detectPersons runs. No
  /// primary action exists yet — and none is faked.
  Widget _analyzingPanel(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        s.screenPadding,
        s.md,
        s.screenPadding,
        s.lg,
      ),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      // Cam, centred and whole (owner journey): the magnifier drawing
      // in the middle of the panel on its clean surface background —
      // never cropped, never a small header avatar, never over the
      // photo. Display only; the status text sits below him.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CamMascot(mode: CamMode.analyzing),
          SizedBox(height: s.md),
          Text(
            AppStrings.proposalAnalyzing.tr,
            style: context.textStyles.bodyMd,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Live status sentence (Review 04 F4, §11.2C format): states both
  /// halves of the proposal and updates on every toggle, because it is
  /// composed from the controller's live counts inside the Obx.
  Widget _statusSentence(BuildContext context) {
    final removes = controller.removeCount;
    final keepers = controller.keeperCount;
    final included = controller.includedCount;
    final removedPart = removes == 1
        ? AppStrings.proposalStatusRemovedOne.tr
        : AppStrings.proposalStatusRemoved.trParams(<String, String>{
            'count': '$removes',
          });
    // Included ambiguous items get their own clause (X5 pattern):
    // counts are stated only for what the user actually included.
    final itemsPart = included == 0
        ? null
        : included == 1
        ? AppStrings.proposalStatusRemovedItemOne.tr
        : AppStrings.proposalStatusRemovedItems.trParams(<String, String>{
            'count': '$included',
          });
    final protectedPart = keepers == 1
        ? AppStrings.proposalStatusProtectedOne.tr
        : AppStrings.proposalStatusProtected.trParams(<String, String>{
            'count': '$keepers',
          });
    final String statusText =
        <String>[removedPart, ?itemsPart, protectedPart].join(' · ');
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Semantics(
      liveRegion: true,
      child: AnimatedSwitcher(
        duration: disableAnimations ? Duration.zero : AppMotion.fast,
        reverseDuration: Duration.zero,
        switchInCurve: AppMotion.enterCurve,
        layoutBuilder: (currentChild, previousChildren) =>
            currentChild ?? const SizedBox.shrink(),
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: Text(
          statusText,
          key: ValueKey<String>(statusText),
          style: context.textStyles.bodyMd.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
      ),
    );
  }

  /// No-people state (Review 04 F3, FR-06): a plain statement, a
  /// primary that picks a different photo, the Brush offer, and a
  /// plain exit. No disabled primary, ever.
  Widget _noPeopleActions(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(vertical: s.md),
          child: Text(
            AppStrings.proposalNoPeople.tr,
            style: context.textStyles.bodyMd.copyWith(color: p.textSecondary),
          ),
        ),
        PrimaryButton(
          labelKey: AppStrings.proposalChooseDifferentPhoto,
          onPressed: controller.chooseDifferentPhoto,
        ),
        SizedBox(height: s.sm),
        SecondaryButton(
          labelKey: AppStrings.proposalOpenBrush,
          onPressed: controller.openBrush,
        ),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: controller.goHome,
            child: Text(
              AppStrings.commonClose.tr,
              style: context.textStyles.labelMd.copyWith(
                color: p.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
