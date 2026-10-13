import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/storage/local_store.dart';

/// The history grid, shared by Home's History section and the History
/// screen (Design Direction §5 sanctions this placement). Square photo
/// tiles with a saved-date caption — the date is the disambiguator,
/// never a title (FR-19).
class HistoryGrid extends StatelessWidget {
  const HistoryGrid({
    super.key,
    required this.entries,
    required this.onTap,
    this.crossAxisCount = 3,
    this.shrinkWrap = false,
  });

  final List<HistoryEntry> entries;
  final void Function(HistoryEntry entry) onTap;
  final int crossAxisCount;

  /// True when embedded in Home's column (sizes to content, does not
  /// scroll itself); false on the History screen (fills + scrolls).
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final s = context.sizes;
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: s.md,
        crossAxisSpacing: s.md,
        childAspectRatio: 0.82,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _HistoryTile(entry: entry, onTap: () => onTap(entry));
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry, required this.onTap});

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(s.radiusMd),
                  border: Border.all(color: p.border),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: p.scrim.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(s.radiusMd - 1),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Image.file(
                        File(entry.localPath),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, _, _) => Container(
                          color: p.surfaceVariant,
                          child: Icon(Icons.broken_image_outlined, color: p.border),
                        ),
                      ),
                      Positioned(
                        top: s.xs,
                        right: s.xs,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(s.radiusSm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(Icons.check_circle, size: 9, color: p.overlayKept),
                              const SizedBox(width: 2),
                              Text(
                                'Cleaned',
                                style: context.textStyles.labelMd.copyWith(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
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
              style: context.textStyles.bodySm.copyWith(
                color: p.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );

  }
}
