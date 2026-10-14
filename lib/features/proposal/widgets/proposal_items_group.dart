import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../services/processing/processing_api.dart';
import 'distraction_card.dart';
import 'item_card.dart';

/// The Distractions group on S4 (design X1-X4): present only when at
/// least one showable item exists (X1). It carries ambiguous
/// belongings (X10) AND distractions (Phase B) as one list of chips
/// mirroring the person chips, all defaulting to Keep (X3). The
/// header's "Remove all / Keep all" (X4) is a convenience over the
/// per-item truth: it sets every chip in the group, both kinds.
class ProposalItemsGroup extends StatelessWidget {
  const ProposalItemsGroup({
    super.key,
    required this.items,
    required this.distractions,
    required this.photoPath,
    required this.includedItemIds,
    required this.includedDistractionIds,
    required this.onToggleItem,
    required this.onToggleDistraction,
    required this.onRemoveAll,
    required this.onKeepAll,
  });

  final List<DetectedBelonging> items;
  final List<DetectedDistraction> distractions;
  final String photoPath;
  final Set<int> includedItemIds;
  final Set<int> includedDistractionIds;
  final void Function(int itemId) onToggleItem;
  final void Function(int distractionId) onToggleDistraction;
  final VoidCallback onRemoveAll;
  final VoidCallback onKeepAll;

  int get totalCount => items.length + distractions.length;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              AppStrings.proposalItemsTitle.tr,
              style: context.textStyles.titleMd,
            ),
            SizedBox(width: s.xs),
            Text(
              AppStrings.proposalItemsCount.trParams(<String, String>{
                'count': '$totalCount',
              }),
              style: context.textStyles.bodySm.copyWith(color: p.textSecondary),
            ),
            const Spacer(),
            TextButton(
              onPressed: onRemoveAll,
              child: Text(
                AppStrings.proposalItemsRemoveAll.tr,
                style: context.textStyles.labelMd.copyWith(color: p.primary),
              ),
            ),
            TextButton(
              onPressed: onKeepAll,
              child: Text(
                AppStrings.proposalItemsKeepAll.tr,
                style: context.textStyles.labelMd.copyWith(
                  color: p.textSecondary,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: s.sm),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: totalCount,
            separatorBuilder: (_, _) => SizedBox(width: s.sm),
            itemBuilder: (context, index) {
              if (index < items.length) {
                final item = items[index];
                return ItemCard(
                  item: item,
                  imagePath: photoPath,
                  included: includedItemIds.contains(item.id),
                  onTap: () => onToggleItem(item.id),
                );
              }
              final distraction = distractions[index - items.length];
              return DistractionCard(
                distraction: distraction,
                imagePath: photoPath,
                included: includedDistractionIds.contains(distraction.id),
                onTap: () => onToggleDistraction(distraction.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The S4 confirm primary. People-only jobs keep the established
/// labels; when ambiguous items are included, the label counts both
/// halves (design X5): "Remove 3 people + 2 items", "Remove 1 item".
class ProposalConfirmButton extends StatelessWidget {
  const ProposalConfirmButton({
    super.key,
    required this.removes,
    required this.items,
    required this.onConfirm,
  });

  final int removes;
  final int items;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    if (items == 0) {
      return PrimaryButton(
        labelKey: removes > 1
            ? AppStrings.proposalRemoveCount
            : AppStrings.proposalRemoveOne,
        labelParams: <String, String>{'count': '$removes'},
        onPressed: onConfirm,
      );
    }
    final parts = <String>[
      if (removes == 1)
        AppStrings.proposalPartPersonOne.tr
      else if (removes > 1)
        AppStrings.proposalPartPeople.trParams(<String, String>{
          'count': '$removes',
        }),
      if (items == 1)
        AppStrings.proposalPartItemOne.tr
      else
        AppStrings.proposalPartItems.trParams(<String, String>{
          'count': '$items',
        }),
    ];
    return PrimaryButton(
      labelKey: AppStrings.proposalRemoveCombo,
      labelParams: <String, String>{'parts': parts.join(' + ')},
      onPressed: onConfirm,
    );
  }
}
