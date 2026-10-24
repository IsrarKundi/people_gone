import 'package:flutter/material.dart';

import '../theme/theme_ext.dart';
import 'cam_frame.dart';

/// Cam's art: the owner's approved V2 drawings themselves — never
/// a redrawn twin — brought to life as a puppet.
///
/// Two approved poses, and only two: the Home pose (waving) and
/// the Analyzing pose. Processing reuses the Analyzing pose
/// exactly — same art, same layers, no monitor, no keyboard, no
/// per-screen redraw — by the owner's order. The life comes from
/// layers in code, all driven by [CamFrame]:
///
/// 1. Pupils: the V2 pupils are painted out of the base assets
///    (`*_nopupil.webp`, eye whites only), and this widget draws
///    dark pupil discs with a white highlight over the whites.
///    The discs move with [CamFrame.gazeX]/[CamFrame.gazeY], so he
///    actually looks around. Pupils stay inside the measured eye
///    whites, so no gap ever opens at the edge.
/// 2. Blink: code eyelids, not an asset swap. For each eye, a
///    face-green lid grows down over the white ellipse as
///    [CamFrame.blink] rises, so the close is smooth.
/// 3. Mouth: the original smile is painted out of the base
///    assets (`*_nomouth.webp`), and this widget draws the
///    scene's mouth from [CamFrame.mouth] — open smile at Home
///    and on Result, curious while analyzing, small smile while
///    processing, frown when concerned.
/// 4. Moving parts: the Home arm rotates around its shoulder
///    ([CamFrame.waveAngle]) for the wave, and the Analyzing head
///    turns on its own while the body stays still, so the head
///    can scan without the whole picture moving.
///
/// Two rules from the owner are built into this widget, not left
/// to each screen:
///
/// 1. The circle is built in code, never baked into the mascot.
///    This widget draws the ring as a [BoxDecoration] border
///    around a [ClipOval] puppet, on the screen's surface colour.
/// 2. Analyzing and Processing are layered, never whole-picture
///    moved: their head turns on its own inside this widget, so
///    the body stays still. At rest the layers recompose the
///    original picture, which the golden test pins.
class CamMascotArt extends StatelessWidget {
  const CamMascotArt({super.key, required this.frame, required this.mode});

  final CamFrame frame;
  final CamMode mode;

  /// One eye: white-ellipse centre and size, pupil diameter, and
  /// pupil travel, all as fractions of the displayed image.
  /// Measured from the V2 art itself.
  ({double wx, double wy, double ww, double wh, double d, double maxDx,
      double maxDy}) _eye(
    double wx,
    double wy,
    double ww,
    double wh,
    double d,
    double maxDx,
    double maxDy,
  ) => (wx: wx, wy: wy, ww: ww, wh: wh, d: d, maxDx: maxDx, maxDy: maxDy);

  /// Eyes for the pose behind [mode]: Home pose for the circles,
  /// Analyzing pose for the two work screens.
  List<({double wx, double wy, double ww, double wh, double d, double maxDx,
      double maxDy})> get _eyes {
    switch (mode) {
      case CamMode.avatar:
      case CamMode.avatarSmall:
      case CamMode.resultsReady:
        return <({double wx, double wy, double ww, double wh, double d,
            double maxDx, double maxDy})>[
          // Home: pupils fill ~80% of the whites, so travel is
          // small by construction — the wave and mouth carry it.
          _eye(0.296, 0.301, 0.121, 0.129, 0.096, 0.016, 0.016),
          _eye(0.556, 0.311, 0.138, 0.135, 0.099, 0.019, 0.018),
        ];
      case CamMode.analyzing:
      case CamMode.processing:
        return <({double wx, double wy, double ww, double wh, double d,
            double maxDx, double maxDy})>[
          _eye(0.341, 0.335, 0.146, 0.141, 0.103, 0.021, 0.019),
          _eye(0.594, 0.280, 0.124, 0.124, 0.096, 0.014, 0.014),
        ];
    }
  }

  /// Mouth anchor for the pose behind [mode]: centre and width as
  /// fractions of the displayed image. The box is 0.06 tall,
  /// matching the patch the original smile was painted out of.
  ({double cx, double cy, double w}) get _mouth {
    switch (mode) {
      case CamMode.avatar:
      case CamMode.avatarSmall:
      case CamMode.resultsReady:
        return (cx: 0.46, cy: 0.425, w: 0.20);
      case CamMode.analyzing:
      case CamMode.processing:
        return (cx: 0.50, cy: 0.425, w: 0.20);
    }
  }

  /// Pupil discs plus eyelids for one displayed image of [size].
  /// Lids come after pupils so a blink covers them.
  List<Widget> _face(BuildContext context, Size size) {
    final palette = context.palette;
    final List<Widget> face = <Widget>[];
    for (final eye in _eyes) {
      final double d = eye.d * size.width;
      face.add(
        Positioned(
          left: eye.wx * size.width - d / 2 +
              frame.gazeX * eye.maxDx * size.width,
          top: eye.wy * size.height - d / 2 +
              frame.gazeY * eye.maxDy * size.height,
          width: d,
          height: d,
          child: Stack(
            children: <Widget>[
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.mascotPupil,
                ),
              ),
              Positioned(
                left: d * 0.18,
                top: d * 0.16,
                width: d * 0.22,
                height: d * 0.22,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.mascotEyeWhite,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      face.add(
        Positioned(
          left: (eye.wx - eye.ww / 2) * size.width,
          top: (eye.wy - eye.wh / 2) * size.height,
          width: eye.ww * size.width,
          height: eye.wh * size.height,
          child: ClipOval(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: frame.blink * eye.wh * size.height,
                color: palette.mascotV2Face,
              ),
            ),
          ),
        ),
      );
    }
    final mouth = _mouth;
    face.add(
      Positioned(
        left: (mouth.cx - mouth.w / 2) * size.width,
        top: (mouth.cy - 0.03) * size.height,
        width: mouth.w * size.width,
        height: 0.06 * size.height,
        child: CustomPaint(
          painter: _MouthPainter(frame.mouth, palette.mascotPupil),
        ),
      ),
    );
    return face;
  }

  /// Home pose: body, then the waving arm rotating around its
  /// shoulder (0.32, 0.55), then the face layers.
  Widget _homePose(BuildContext context, Size size) {
    return Stack(
      children: <Widget>[
        Image.asset(
          'assets/icons/ic_cam_v2_home_body.webp',
          width: size.width,
          height: size.height,
          fit: BoxFit.fill,
          excludeFromSemantics: true,
        ),
        Transform.rotate(
          angle: frame.waveAngle,
          alignment: const Alignment(-0.36, 0.10),
          child: Image.asset(
            'assets/icons/ic_cam_v2_home_arm.webp',
            width: size.width,
            height: size.height,
            fit: BoxFit.fill,
            excludeFromSemantics: true,
          ),
        ),
        ..._face(context, size),
      ],
    );
  }

  /// Analyzing pose, layered: the body stays still while the
  /// head turns on its own around the chin (0.47, 0.51). The
  /// face layers sit inside the head transform, so pupils, lids
  /// and mouth travel with the head. Processing uses this exact
  /// same widget — only its frame values differ.
  Widget _analyzingPose(BuildContext context, Size size) {
    return Stack(
      children: <Widget>[
        Image.asset(
          'assets/icons/ic_cam_v2_analyzing_body.webp',
          width: size.width,
          height: size.height,
          fit: BoxFit.fill,
          excludeFromSemantics: true,
        ),
        Transform.translate(
          offset: Offset(frame.shiftX * 0.7, 0),
          child: Transform.rotate(
            angle: frame.tilt * 2,
            alignment: const Alignment(-0.06, 0.02),
            child: Stack(
              children: <Widget>[
                Image.asset(
                  'assets/icons/ic_cam_v2_analyzing_head.webp',
                  width: size.width,
                  height: size.height,
                  fit: BoxFit.fill,
                  excludeFromSemantics: true,
                ),
                ..._face(context, size),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The circle for the header and result avatars: ring and
  /// surface are code, the Home puppet inside carries no ring.
  Widget _circle(BuildContext context, double size, double ringWidth) {
    final palette = context.palette;
    final Color ring = mode == CamMode.resultsReady
        ? palette.mascotRingReady
        : palette.mascotRing;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.surface,
        border: Border.all(color: ring, width: ringWidth),
      ),
      child: ClipOval(
        child: Center(
          child: _homePose(context, Size(size, size)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.sizes;

    final Widget image = switch (mode) {
      CamMode.avatar => _circle(context, s.mascotAvatarSize, 3),
      CamMode.avatarSmall => _circle(context, s.mascotAvatarSmallSize, 2),
      CamMode.resultsReady => _circle(context, s.mascotAvatarSize, 3),
      // Both work screens are square now: the V2 art is 1600×1600.
      CamMode.analyzing => SizedBox(
        width: s.mascotAnalyzingWidth,
        height: s.mascotAnalyzingWidth,
        child: _analyzingPose(
          context,
          Size(s.mascotAnalyzingWidth, s.mascotAnalyzingWidth),
        ),
      ),
      CamMode.processing => SizedBox(
        width: s.mascotProcessingWidth,
        height: s.mascotProcessingWidth,
        child: _analyzingPose(
          context,
          Size(s.mascotProcessingWidth, s.mascotProcessingWidth),
        ),
      ),
    };

    // Layered poses move their own head inside; only breathing
    // scales the whole picture, around the ground line.
    if (mode == CamMode.analyzing || mode == CamMode.processing) {
      return ExcludeSemantics(
        child: Transform.scale(
          scale: frame.breath,
          alignment: Alignment.bottomCenter,
          child: image,
        ),
      );
    }

    // Calm body motion only: breathing scale around the ground
    // line, a gentle lean, and the scene's shifts — all from the
    // frame, transform-only. The life itself is the pupils, lids,
    // mouth and wave above, not this motion. No bounce, no
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

/// The scene's mouth, drawn in code over the cleaned patch:
/// a stroked U for a smile, a filled round shape for an open
/// smile, a small filled oval for curious, a stroked inverted
/// U for a frown.
class _MouthPainter extends CustomPainter {
  const _MouthPainter(this.mouth, this.color);

  final CamMouth mouth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round;
    final double w = size.width;
    final double h = size.height;
    switch (mouth) {
      case CamMouth.smile:
        final Path path = Path()
          ..moveTo(0, h * 0.2)
          ..quadraticBezierTo(w * 0.5, h * 1.2, w, h * 0.2);
        canvas.drawPath(path, paint);
      case CamMouth.frown:
        final Path path = Path()
          ..moveTo(0, h * 0.8)
          ..quadraticBezierTo(w * 0.5, -h * 0.2, w, h * 0.8);
        canvas.drawPath(path, paint);
      case CamMouth.openSmile:
        final Path path = Path()
          ..moveTo(0, 0)
          ..lineTo(w, 0)
          ..quadraticBezierTo(w, h, w * 0.5, h)
          ..quadraticBezierTo(0, h, 0, 0)
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill,
        );
      case CamMouth.curious:
        canvas.drawOval(
          Rect.fromLTWH(w * 0.3, h * 0.2, w * 0.4, h * 0.6),
          Paint()
            ..color = color
            ..style = PaintingStyle.fill,
        );
    }
  }

  @override
  bool shouldRepaint(_MouthPainter old) =>
      old.mouth != mouth || old.color != color;
}
