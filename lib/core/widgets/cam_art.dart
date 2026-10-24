import 'package:flutter/material.dart';

import '../theme/theme_ext.dart';
import 'cam_frame.dart';

/// Cam's art: the owner's approved sheet drawings themselves — never
/// a redrawn twin.
///
/// Two rules from the owner are built into this widget, not left to
/// each screen:
///
/// 1. The circle is built in code, never baked into the mascot.
///    The avatar assets (`ic_cam_avatar.webp`, `ic_cam_results.webp`)
///    have their baked rings painted out; this widget draws the ring
///    as a [BoxDecoration] border around a [ClipOval] image, on the
///    screen's surface colour. Change the ring here and it changes
///    everywhere, identically.
///
/// 2. Analyzing and Processing are never cropped or cut out.
///    Those assets (`ic_cam_analyzing.webp`, `ic_cam_processing.webp`)
///    are the full sheet panels with only the outer white made
///    transparent, and this widget renders them whole with
///    [BoxFit.contain] and no clip, no card, no container — so on
///    screen they sit on the clean screen background, complete.
class CamMascotArt extends StatelessWidget {
  const CamMascotArt({super.key, required this.frame, required this.mode});

  final CamFrame frame;
  final CamMode mode;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final s = context.sizes;

    final Widget image = switch (mode) {
      // Code-drawn circle: ring + surface fill are code, the image
      // inside carries no ring of its own.
      CamMode.avatar => Container(
        width: s.mascotAvatarSize,
        height: s.mascotAvatarSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: palette.surface,
          border: Border.all(color: palette.mascotRing, width: 3),
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/icons/ic_cam_avatar.webp',
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
        ),
      ),
      CamMode.avatarSmall => Container(
        width: s.mascotAvatarSmallSize,
        height: s.mascotAvatarSmallSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: palette.surface,
          border: Border.all(color: palette.mascotRing, width: 2),
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/icons/ic_cam_avatar.webp',
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
        ),
      ),
      // Green ring, also code-drawn; the image inside has no ring.
      CamMode.resultsReady => Container(
        width: s.mascotAvatarSize,
        height: s.mascotAvatarSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: palette.surface,
          border: Border.all(color: palette.mascotRingReady, width: 3),
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/icons/ic_cam_results.webp',
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
        ),
      ),
      // Whole drawing, centred, uncropped, on a clean background:
      // no clip, no card, no container. The asset's own transparent
      // background lets the screen background show through. The box
      // is sized from the sheet art's own aspect ratio (analyzing
      // 569×670, processing 804×706) so the widget has its full size
      // from the first frame, before the image bytes decode.
      CamMode.analyzing => SizedBox(
        width: s.mascotAnalyzingWidth,
        height: s.mascotAnalyzingWidth * 670 / 569,
        child: Image.asset(
          'assets/icons/ic_cam_analyzing.webp',
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
      ),
      CamMode.processing => SizedBox(
        width: s.mascotProcessingWidth,
        height: s.mascotProcessingWidth * 706 / 804,
        child: Image.asset(
          'assets/icons/ic_cam_processing.webp',
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
      ),
    };

    // Calm alive motion only: the breathing scale from the frame,
    // around the ground line. No bounce, no sparkles, no overshoot.
    final moved = Transform.scale(
      scale: frame.breath,
      alignment: Alignment.bottomCenter,
      child: image,
    );

    return ExcludeSemantics(child: moved);
  }
}
