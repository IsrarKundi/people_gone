import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../services/processing/processing_api.dart';
import 'item_card.dart';

/// The Distractions group shell on S4 (design X1-X3): present only
/// when at least one ambiguous belonging exists; in Phase A it is
/// driven exclusively by ambiguous belongings (X10). Chips mirror
/// the person chips and default to Keep (X3).
class ProposalItemsGroup extends StatelessWidget {
  const ProposalItemsGroup({
    super.key,
    required this.items,
    required this.photoPath,
    required this.includedItemIds,
    required this.onToggleItem,
  });

  final List<DetectedBelonging> items;
  final String photoPath;
  final Set<int> includedItemIds;
  final void Function(int itemId) onToggleItem;

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
                'count': '${items.length}',
              }),
              style: context.textStyles.bodySm.copyWith(
                color: p.textSecondary,
              ),
            ),
          ],
        ),
        SizedBox(height: s.sm),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => SizedBox(width: s.sm),
            itemBuilder: (context, index) {
              final item = items[index];
              return ItemCard(
                item: item,
                imagePath: photoPath,
                included: includedItemIds.contains(item.id),
                onTap: () => onToggleItem(item.id),
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
