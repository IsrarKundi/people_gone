import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';

/// Keeper-correction sheet (S7): every detected person with its
/// protected/removed state in words — never colour alone (Design
/// Direction R2). Choosing a removed person re-runs the clean keeping
/// only them; re-runs are always free (FR-11).
class KeeperSheet extends StatelessWidget {
  const KeeperSheet({super.key, required this.people, required this.onChoose});

  final List<({int id, bool kept})> people;
  final void Function(int id) onChoose;

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
              SizedBox(
                height: s.listRowMin,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        (person.kept
                                ? AppStrings.resultPersonKept
                                : AppStrings.resultPersonRemoved)
                            .trParams(<String, String>{
                              'n': '${person.id + 1}',
                            }),
                        style: context.textStyles.bodyMd,
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
