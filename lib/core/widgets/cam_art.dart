import 'package:flutter/material.dart';

import '../theme/theme_ext.dart';
import 'cam_frame.dart';

/// Cam's art: the owner's approved sheet drawings themselves — never
/// a redrawn twin — brought to life as a puppet.
///
/// The sheet picture is the body. Life comes from two separate
/// layers on top of it, both driven by [CamFrame]:
///
/// 1. Pupils: the sheet pupils are painted out of the base assets
///    (`*_nopupil.webp`, eye whites only), and this widget draws
///    pupil discs over the whites. The discs move with
///    [CamFrame.gazeX]/[CamFrame.gazeY], so he actually looks
///    around — left and right while analyzing, at the computer
///    while processing, down at the photo on Result. Moving a
///    pupil inside a white eye leaves no gap, which is why this
///    layer is clean where cutting a hand or mouth out would not be.
/// 2. Blink: while the frame's blink value is high, the matching
///    blink asset (eyes painted closed) replaces the base, so the
///    pupils vanish for the blink and return after it.
///
/// Two rules from the owner are built into this widget, not left to
/// each screen:
///
/// 1. The circle is built in code, never baked into the mascot.
///    The avatar assets have their baked rings painted out; this
///    widget draws the ring as a [BoxDecoration] border around a
///    [ClipOval] puppet, on the screen's surface colour.
/// 2. Analyzing and Processing are never cropped or cut out.
///    Those assets are the full sheet panels with only the outer
///    white made transparent, and this widget renders them whole
///    with [BoxFit.contain] and no clip, no card, no container.
class CamMascotArt extends StatelessWidget {
  const CamMascotArt({super.key, required this.frame, required this.mode});

  final CamFrame frame;
  final CamMode mode;

  /// One eye in the sheet drawing: centre as fractions of the
  /// displayed image, and pupil diameter as a fraction of width.
  /// Measured from the sheet art itself (see the puppet proof).
  ({double fx, double fy, double d, double maxDx}) _eye(
    double fx,
    double fy,
    double d, {
    double maxDx = 0.028,
  }) => (fx: fx, fy: fy, d: d, maxDx: maxDx);

  List<({double fx, double fy, double d, double maxDx})> get _eyes {
    switch (mode) {
      case CamMode.avatar:
      case CamMode.avatarSmall:
        return <({double fx, double fy, double d, double maxDx})>[
          _eye(0.253, 0.524, 0.092, maxDx: 0.020),
          _eye(0.639, 0.466, 0.084, maxDx: 0.020),
        ];
      case CamMode.resultsReady:
        return <({double fx, double fy, double d, double maxDx})>[
          _eye(0.456, 0.312, 0.054),
          _eye(0.718, 0.279, 0.044),
        ];
      case CamMode.analyzing:
        return <({double fx, double fy, double d, double maxDx})>[
          _eye(0.389, 0.310, 0.052),
          _eye(0.624, 0.312, 0.066, maxDx: 0.015),
        ];
      case CamMode.processing:
        return <({double fx, double fy, double d, double maxDx})>[
          _eye(0.416, 0.395, 0.052),
          _eye(0.616, 0.362, 0.043),
        ];
    }
  }

  /// The pupil discs for one displayed image of [size].
  List<Widget> _pupils(BuildContext context, Size size) {
    final palette = context.palette;
    final List<Widget> pupils = <Widget>[];
    for (final eye in _eyes) {
      final double d = eye.d * size.width;
      final double left =
          eye.fx * size.width - d / 2 + frame.gazeX * eye.maxDx * size.width;
      final double top =
          eye.fy * size.height - d / 2 + frame.gazeY * eye.maxDx * size.height;
      pupils.add(
        Positioned(
          left: left,
          top: top,
          width: d,
          height: d,
          child: Stack(
            children: <Widget>[
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.mascotPupilTeal,
                ),
              ),
              Center(
                child: Container(
                  width: d * 0.45,
                  height: d * 0.45,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.mascotPupil,
                  ),
                ),
              ),
              Positioned(
                left: d * 0.16,
                top: d * 0.16,
                width: d * 0.20,
                height: d * 0.20,
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return pupils;
  }

  /// The puppet for one displayed image: base image plus pupils,
  /// or the blink asset with no pupils while blinking.
  Widget _puppet(BuildContext context, String baseAsset, Size size) {
    final bool blinking = frame.blink > 0.3;
    if (blinking) {
      return Image.asset(
        baseAsset.replaceFirst('.webp', '_blink.webp'),
        width: size.width,
        height: size.height,
        fit: BoxFit.fill,
        excludeFromSemantics: true,
      );
    }
    return Stack(
      children: <Widget>[
        Image.asset(
          baseAsset.replaceFirst('.webp', '_nopupil.webp'),
          width: size.width,
          height: size.height,
          fit: BoxFit.fill,
          excludeFromSemantics: true,
        ),
        ..._pupils(context, size),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final s = context.sizes;

    final Widget image = switch (mode) {
      // Code-drawn circle: ring + surface fill are code, the
      // puppet inside carries no ring of its own. The displayed
      // image is slightly taller than the square (asset aspect),
      // centred in the circle, so pupil fractions map to it.
      CamMode.avatar => Container(
        width: s.mascotAvatarSize,
        height: s.mascotAvatarSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: palette.surface,
          border: Border.all(color: palette.mascotRing, width: 3),
        ),
        child: ClipOval(
          child: Center(
            child: _puppet(
              context,
              'assets/icons/ic_cam_avatar.webp',
              Size(s.mascotAvatarSize, s.mascotAvatarSize),
            ),
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
          child: Center(
            child: _puppet(
              context,
              'assets/icons/ic_cam_avatar.webp',
              Size(s.mascotAvatarSmallSize, s.mascotAvatarSmallSize),
            ),
          ),
        ),
      ),
      // Green ring, also code-drawn.
      CamMode.resultsReady => Container(
        width: s.mascotAvatarSize,
        height: s.mascotAvatarSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: palette.surface,
          border: Border.all(color: palette.mascotRingReady, width: 3),
        ),
        child: ClipOval(
          child: Center(
            child: _puppet(
              context,
              'assets/icons/ic_cam_results.webp',
              Size(s.mascotAvatarSize, s.mascotAvatarSize),
            ),
          ),
        ),
      ),
      // Whole drawing, centred, uncropped, on a clean background:
      // no clip, no card, no container. The box is sized from the
      // V1 art's own aspect ratio (analyzing square,
      // processing 1920×1280) so the widget has its full size from
      // the first frame, before the image bytes decode.
      CamMode.analyzing => SizedBox(
        width: s.mascotAnalyzingWidth,
        height: s.mascotAnalyzingWidth,
        child: _puppet(
          context,
          'assets/icons/ic_cam_analyzing.webp',
          Size(s.mascotAnalyzingWidth, s.mascotAnalyzingWidth),
        ),
      ),
      CamMode.processing => SizedBox(
        width: s.mascotProcessingWidth,
        height: s.mascotProcessingWidth * 1280 / 1920,
        child: _puppet(
          context,
          'assets/icons/ic_cam_processing.webp',
          Size(s.mascotProcessingWidth, s.mascotProcessingWidth * 1280 / 1920),
        ),
      ),
    };

    // Calm body motion only: breathing scale around the ground
    // line, a gentle lean, and the scene's shifts (sway, scan,
    // typing bob) — all from the frame, transform-only. The life
    // itself is the pupils above, not this motion. No bounce, no
    // sparkles, no overshoot.
    final moved = Transform.translate(
      offset: Offset(frame.shiftX, frame.shiftY),
      child: Transform.rotate(
        angle: frame.tilt,
        alignment: Alignment.bottomCenter,
        child: Transform.scale(
          scale: frame.breath,
          alignment: Alignment.bottomCenter,
          child: image,
        ),
      ),
    );

    return ExcludeSemantics(child: moved);
  }
}
