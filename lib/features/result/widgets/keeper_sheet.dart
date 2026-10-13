import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/person_thumbnail.dart';

/// Keeper-correction sheet (S7): every detected person with its
/// protected/removed state in words and visual face thumbnail.
/// Choosing a removed person re-runs the clean keeping
/// only them; re-runs are always free (FR-11).
class KeeperSheet extends StatelessWidget {
  const KeeperSheet({
    super.key,
    required this.people,
    required this.onChoose,
    this.imagePath,
    this.personBoxes = const <int, List<int>>{},
  });

  final List<({int id, bool kept})> people;
  final void Function(int id) onChoose;
  final String? imagePath;
  final Map<int, List<int>> personBoxes;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(s.radiusSheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        s.screenPadding,
        s.xxl,
        s.screenPadding,
        s.xxl,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              AppStrings.resultChooseKeeperTitle.tr,
              style: context.textStyles.titleLg,
            ),
            SizedBox(height: s.md),
            for (final person in people)
              Container(
                margin: EdgeInsets.only(bottom: s.sm),
                padding: EdgeInsets.all(s.sm),
                decoration: BoxDecoration(
                  color: p.surfaceVariant.withAlpha(60),
                  borderRadius: BorderRadius.circular(s.radiusLg),
                  border: Border.all(
                    color: person.kept ? AppColors.emerald.withAlpha(100) : p.border,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    PersonThumbnail(
                      imagePath: imagePath ?? '',
                      box: personBoxes[person.id] ?? const <int>[],
                      isKeeper: person.kept,
                      size: 46,
                    ),
                    SizedBox(width: s.md),
                    Expanded(
                      child: Text(
                        (person.kept
                                ? AppStrings.resultPersonKept
                                : AppStrings.resultPersonRemoved)
                            .trParams(<String, String>{
                              'n': '${person.id + 1}',
                            }),
                        style: context.textStyles.bodyMd.copyWith(
                          fontWeight: person.kept ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (!person.kept)
                      TextButton(
                        onPressed: () => onChoose(person.id),
                        child: Text(
                          AppStrings.resultKeepThisPerson.tr,
                          style: context.textStyles.labelLg.copyWith(
                            color: p.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            SizedBox(height: s.sm),
            Text(
              AppStrings.resultRerunNote.tr,
              style: context.textStyles.bodySm.copyWith(color: p.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
