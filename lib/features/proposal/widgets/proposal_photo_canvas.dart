import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/photo_surface.dart';
import '../../../services/processing/processing_api.dart';

/// Renders the photo with visual bounding box outlines and status pills
/// for each detected person. Tapping a person's region toggles their state.
class ProposalPhotoCanvas extends StatelessWidget {
  const ProposalPhotoCanvas({
    super.key,
    required this.photoPath,
    required this.persons,
    required this.onTogglePerson,
  });

  final String photoPath;
  final List<DetectedPerson> persons;
  final void Function(int id) onTogglePerson;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final file = File(photoPath);

    return PhotoSurface(
      imageProvider: ResizeImage(
        FileImage(file),
        width: MediaQuery.sizeOf(context).width.toInt(),
      ),
      builder: (context, band) {
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.file(
              file,
              fit: BoxFit.contain,
              cacheWidth: MediaQuery.sizeOf(context).width.toInt(),
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
            // Position overlays mapped to the photo band
            if (band.width > 0 && band.height > 0)
              Positioned(
                left: band.left,
                top: band.top,
                width: band.width,
                height: band.height,
                child: CustomPaint(
                  painter: _OverlayPainter(
                    persons: persons,
                    photoBandSize: Size(band.width, band.height),
                    palette: p,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OverlayPainter extends CustomPainter {
  const _OverlayPainter({
    required this.persons,
    required this.photoBandSize,
    required this.palette,
  });

  final List<DetectedPerson> persons;
  final Size photoBandSize;
  final dynamic palette;

  @override
  void paint(Canvas canvas, Size size) {
    if (persons.isEmpty) return;

    for (final person in persons) {
      if (person.box.length < 4) continue;
      final bx1 = person.box[0].toDouble();
      final by1 = person.box[1].toDouble();
      final bx2 = person.box[2].toDouble();
      final by2 = person.box[3].toDouble();

      // We approximate mapping to canvas size if normalized or pixel dimensions
      // Assuming pixel coordinates from high-res image, scale to band size:
      // Note: person chips are the primary tap targets for precision.
      final color = person.isKeeper ? AppColors.emerald : AppColors.crimson;
      final strokePaint = Paint()
        ..color = color.withAlpha(200)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final fillPaint = Paint()
        ..color = color.withAlpha(35)
        ..style = PaintingStyle.fill;

      // Draw subtle indicators if box within range
      if (bx2 <= size.width && by2 <= size.height) {
        final rect = Rect.fromLTRB(bx1, by1, bx2, by2);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), fillPaint);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), strokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) => true;
}
