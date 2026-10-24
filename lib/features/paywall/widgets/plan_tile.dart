import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_motion.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/pressable_scale.dart';

/// One subscription / purchase plan tile on S8 Paywall.
/// Styled according to tokens: when selected, uses `p.primaryContainer` and
/// border in `p.primary`.
class PlanTile extends StatelessWidget {
  const PlanTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String subtitle;
  final String price;
  final bool isSelected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$title, $price. $subtitle',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: PressableScale(
          child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.enterCurve,
          padding: EdgeInsets.symmetric(
            horizontal: s.md,
            vertical: s.sm + 2,
          ),
          decoration: BoxDecoration(
            color: isSelected ? p.primaryContainer : p.surface,
            borderRadius: BorderRadius.circular(s.radiusMd),
            border: Border.all(
              color: isSelected ? p.primary : p.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Selection indicator radio/check
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? p.primary : p.textTertiary,
                    width: 2,
                  ),
                  color: isSelected ? p.primary : Colors.transparent,
                ),
                child: isSelected
                    ? Icon(
                        AppIcons.check,
                        size: 14,
                        color: p.onPrimary,
                      )
                    : null,
              ),
              SizedBox(width: s.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          title,
                          style: context.textStyles.bodyLg.copyWith(
                            fontWeight: FontWeight.w700,
                            color: p.textPrimary,
                          ),
                        ),
                        if (badge != null) ...<Widget>[
                          SizedBox(width: s.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: p.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(s.radiusSm),
                            ),
                            child: Text(
                              badge!,
                              style: context.textStyles.caption.copyWith(
                                color: p.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: context.textStyles.caption.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (price.isNotEmpty) ...<Widget>[
                SizedBox(width: s.sm),
                Text(
                  price,
                  style: context.textStyles.titleMd.copyWith(
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
}
