import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';

import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/storage/local_store.dart';

/// Horizontal tray of earlier cleaned photos on Home (Option A).
/// Each item displays in natural aspect ratio with date caption and tap-to-view.
class EarlierCleansTray extends StatelessWidget {
  const EarlierCleansTray({
    super.key,
    required this.entries,
    required this.onTap,
  });

  final List<HistoryEntry> entries;
  final void Function(HistoryEntry entry) onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.sizes;
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: entries.length,
        separatorBuilder: (_, _) => SizedBox(width: s.md),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return _EarlierCleanTile(
            entry: entry,
            onTap: () => onTap(entry),
          );
        },
      ),
    );
  }
}

class _EarlierCleanTile extends StatelessWidget {
  const _EarlierCleanTile({required this.entry, required this.onTap});

  final HistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final dateLabel = Formatters.date(entry.savedAt);

    return Semantics(
      button: true,
      label: dateLabel,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 90,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(s.photoRadius),
                    border: Border.all(color: p.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(s.photoRadius - 1),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        Hero(
                          tag: MediaQuery.maybeOf(context)?.disableAnimations ?? false
                              ? 'disabled_${entry.id}'
                              : 'history_photo_${entry.id}',
                          flightShuttleBuilder: (
                            flightContext,
                            animation,
                            flightDirection,
                            fromHeroContext,
                            toHeroContext,
                          ) {
                            return Image.file(
                              File(entry.localPath),
                              fit: BoxFit.cover,
                              cacheWidth: MediaQuery.sizeOf(flightContext).width.toInt(),
                              errorBuilder: (_, _, _) => Container(color: p.surfaceVariant),
                            );
                          },
                          child: Image.file(
                            File(entry.localPath),
                            fit: BoxFit.cover,
                            cacheWidth: 180,
                            errorBuilder: (_, _, _) => Container(
                              color: p.surfaceVariant,
                              child: Icon(
                                AppIcons.brokenImage,
                                color: p.border,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: s.xs,
                          right: s.xs,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(s.radiusSm),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  AppIcons.checkCircleFill,
                                  size: 9,
                                  color: p.overlayKept,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  AppStrings.historyCleanedBadge.tr,
                                  style: context.textStyles.labelMd.copyWith(
                                    fontSize: 9,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: s.xs),
              Text(
                dateLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.caption.copyWith(
                  color: p.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
