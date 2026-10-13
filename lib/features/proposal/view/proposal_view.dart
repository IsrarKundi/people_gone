import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/primary_button.dart';
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
      final removes = controller.removeCount;
      final overlap = controller.hasOverlapRisk;
      final persons = controller.persons;

      return Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(s.screenPadding, s.md, s.screenPadding, s.lg),
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
                    Icon(Icons.info_outline, size: 16, color: AppColors.crimson),
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
              Padding(
                padding: EdgeInsets.symmetric(vertical: s.md),
                child: Text(
                  AppStrings.proposalNoPeople.tr,
                  style: context.textStyles.bodyMd.copyWith(color: p.textSecondary),
                ),
              )
            else ...<Widget>[
              SizedBox(
                height: 118,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: persons.length,
                  separatorBuilder: (_, _) => SizedBox(width: s.sm),
                  itemBuilder: (context, index) {
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
            ],
            PrimaryButton(
              labelKey: removes > 1
                  ? AppStrings.proposalRemoveCount
                  : (removes == 1
                      ? AppStrings.proposalRemoveOne
                      : AppStrings.proposalKeepAll),
              labelParams: <String, String>{'count': '$removes'},
              onPressed: removes > 0 ? controller.confirmProposal : null,
            ),
          ],
        ),
      );
    });
  }
}
