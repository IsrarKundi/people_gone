import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../controller/proposal_controller.dart';
import '../widgets/person_card.dart';
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
            icon: Icon(Icons.close, color: p.textPrimary),
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
    final p = context.palette;
    final s = context.sizes;

    return Obx(() {
      if (controller.isAnalyzing.value) return _analyzingPanel(context);
      final removes = controller.removeCount;
      final overlap = controller.hasOverlapRisk;
      final persons = controller.persons;

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
                padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.sm),
                decoration: BoxDecoration(
                  color: AppColors.crimson.withAlpha(20),
                  borderRadius: BorderRadius.circular(s.radiusMd),
                  border: Border.all(color: AppColors.crimson.withAlpha(60)),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.crimson,
                    ),
                    SizedBox(width: s.xs),
                    Expanded(
                      child: Text(
                        AppStrings.proposalOverlapWarning.tr,
                        style: context.textStyles.caption.copyWith(
                          color: AppColors.crimson,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: s.sm),
            ],
            if (persons.isEmpty)
              _noPeopleActions(context)
            else ...<Widget>[
              _statusSentence(context),
              SizedBox(height: s.sm),
              SizedBox(
                height: 118,
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
                    );
                  },
                ),
              ),
              SizedBox(height: s.md),
              if (removes > 0)
                PrimaryButton(
                  labelKey: removes > 1
                      ? AppStrings.proposalRemoveCount
                      : AppStrings.proposalRemoveOne,
                  labelParams: <String, String>{'count': '$removes'},
                  onPressed: controller.confirmProposal,
                )
              else
                // Keep-all (Review 04 F3): completes locally with the
                // original photo — the label says exactly that.
                PrimaryButton(
                  labelKey: AppStrings.proposalKeepAllAction,
                  onPressed: controller.completeKeepAll,
                ),
            ],
          ],
        ),
      );
    });
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
      child: Row(
        children: <Widget>[
          SizedBox(
            width: s.iconSm,
            height: s.iconSm,
            child: CircularProgressIndicator(strokeWidth: 2, color: p.primary),
          ),
          SizedBox(width: s.md),
          Expanded(
            child: Text(
              AppStrings.proposalAnalyzing.tr,
              style: context.textStyles.bodyMd,
            ),
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
    final removedPart = removes == 1
        ? AppStrings.proposalStatusRemovedOne.tr
        : AppStrings.proposalStatusRemoved.trParams(<String, String>{
            'count': '$removes',
          });
    final protectedPart = keepers == 1
        ? AppStrings.proposalStatusProtectedOne.tr
        : AppStrings.proposalStatusProtected.trParams(<String, String>{
            'count': '$keepers',
          });
    return Semantics(
      liveRegion: true,
      child: Text(
        '$removedPart · $protectedPart',
        style: context.textStyles.bodyMd.copyWith(
          color: context.palette.textSecondary,
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
