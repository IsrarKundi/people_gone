import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_motion.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/storage/local_store.dart';

/// The history grid, shared by Home's History section and the History
/// screen (Design Direction §5 sanctions this placement). Square photo
/// tiles with a saved-date caption — the date is the disambiguator,
/// never a title (FR-19).
class HistoryGrid extends StatefulWidget {
  const HistoryGrid({
    super.key,
    required this.entries,
    required this.onTap,
    this.deletingId,
    this.crossAxisCount = 3,
    this.shrinkWrap = false,
  });

  final List<HistoryEntry> entries;
  final void Function(HistoryEntry entry) onTap;
  final String? deletingId;
  final int crossAxisCount;

  /// True when embedded in Home's column (sizes to content, does not
  /// scroll itself); false on the History screen (fills + scrolls).
  final bool shrinkWrap;

  @override
  State<HistoryGrid> createState() => _HistoryGridState();
}

class _HistoryGridState extends State<HistoryGrid>
    with SingleTickerProviderStateMixin {
  AnimationController? _deleteController;
  int? _deletingIndex;

  @override
  void initState() {
    super.initState();
    _deleteController = AnimationController(
      vsync: this,
      duration: AppMotion.deleteScale,
    )..addListener(() {
        if (mounted) setState(() {});
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkDeleting(widget.deletingId);
    });
  }

  @override
  void didUpdateWidget(HistoryGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.deletingId != oldWidget.deletingId) {
      _checkDeleting(widget.deletingId);
    }
  }

  void _checkDeleting(String? id) {
    if (id == null) {
      _deletingIndex = null;
      _deleteController?.reset();
      return;
    }
    final idx = widget.entries.indexWhere((e) => e.id == id);
    if (idx != -1) {
      _deletingIndex = idx;
      final disable = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (disable) {
        _deleteController?.value = 1.0;
      } else {
        _deleteController?.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _deleteController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.sizes;
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = s.md;
        const childAspectRatio = 0.82;
        final totalSpacing = spacing * (widget.crossAxisCount - 1);
        final tileWidth =
            (constraints.maxWidth - totalSpacing) / widget.crossAxisCount;
        final tileHeight = tileWidth / childAspectRatio;
        final colWidth = tileWidth + spacing;
        final rowHeight = tileHeight + spacing;
        final t = _deleteController != null
            ? Curves.easeOutCubic.transform(_deleteController!.value)
            : 0.0;

        return GridView.builder(
          shrinkWrap: widget.shrinkWrap,
          physics:
              widget.shrinkWrap ? const NeverScrollableScrollPhysics() : null,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: widget.crossAxisCount,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: widget.entries.length,
          itemBuilder: (context, index) {
            final entry = widget.entries[index];
            Widget tile = _HistoryTile(
              entry: entry,
              onTap: () => widget.onTap(entry),
            );

            if (_deleteController != null &&
                _deletingIndex != null &&
                (_deleteController!.isAnimating ||
                    _deleteController!.value > 0.0)) {
              if (index == _deletingIndex) {
                final scale = (1.0 - t).clamp(0.0, 1.0);
                tile = Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: scale,
                    child: tile,
                  ),
                );
              } else if (index > _deletingIndex!) {
                final colCurrent = index % widget.crossAxisCount;
                final rowCurrent = index ~/ widget.crossAxisCount;
                final colPrev = (index - 1) % widget.crossAxisCount;
                final rowPrev = (index - 1) ~/ widget.crossAxisCount;
                final dx = (colPrev - colCurrent) * colWidth;
                final dy = (rowPrev - rowCurrent) * rowHeight;
                tile = Transform.translate(
                  offset: Offset(dx * t, dy * t),
                  child: tile,
                );
              }
            }
            return tile;
          },
        );
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
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final heroTag = disableAnimations ? null : 'history_photo_${entry.id}';

    Widget image = Image.file(
      File(entry.localPath),
      fit: BoxFit.cover,
      width: double.infinity,
      cacheWidth: 360,
      errorBuilder: (_, _, _) => Container(
        color: p.surfaceVariant,
        child: Icon(Icons.broken_image_outlined, color: p.border),
      ),
    );

    if (heroTag != null) {
      image = Hero(
        tag: heroTag,
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
        child: image,
      );
    }

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
                      image,
                      Positioned(
                        top: s.xs,
                        right: s.xs,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(s.radiusSm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.check_circle,
                                size: 12,
                                color: p.overlayKept,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                AppStrings.historyCleanedBadge.tr,
                                style: context.textStyles.labelMd.copyWith(
                                  color: Colors.white,
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
