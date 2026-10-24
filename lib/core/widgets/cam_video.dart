import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/theme_ext.dart';
import 'cam_art.dart';
import 'cam_frame.dart';

/// The animated asset for a mode. The owner approved exactly two
/// videos, and they cover every screen, so no screen still uses
/// the code puppet in production:
///
/// * Home circles (Home, small headers, Result) wave.
/// * Both work screens (Analyzing, Processing) scan — the
///   Analyzing art animated, with no monitor and no props.
///
/// Video has no transparency: the Home videos live inside the
/// code-drawn circle, so the frame edges never show; the work
/// videos are square and sit on the screen's surface. A
/// dark-background version of the work video is still open work
/// for dark theme — on dark screens the white video background
/// shows as a square for now.
String camVideoAsset(CamMode mode) => switch (mode) {
  CamMode.avatar || CamMode.avatarSmall || CamMode.resultsReady =>
    'assets/animations/cam_home_wave.mp4',
  CamMode.analyzing || CamMode.processing =>
    'assets/animations/cam_processing_scan.mp4',
};

/// Cam as a looping video.
///
/// While the video loads — or if it ever fails to load — the
/// neutral still artwork ([CamMascotArt]) shows in the same box,
/// so there is never a black flash or a hole. The video itself
/// carries all the motion; the only transforms applied here are
/// the one-shot nod and arrival pulse handed down by [CamMascot]
/// through [nod] and [pulse]. Reduced motion and tests never
/// reach this widget: [CamMascot] renders the still artwork
/// directly in those cases.
class CamMascotVideo extends StatefulWidget {
  const CamMascotVideo({
    super.key,
    required this.mode,
    this.nod = 0,
    this.pulse = 0,
  });

  final CamMode mode;

  /// Review's one-shot nod, in dp downward.
  final double nod;

  /// Result's one-shot arrival pulse, 0 to 1.
  final double pulse;

  @override
  State<CamMascotVideo> createState() => _CamMascotVideoState();
}

class _CamMascotVideoState extends State<CamMascotVideo> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(camVideoAsset(widget.mode));
    _controller.setLooping(true);
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _controller.play();
    }, onError: (_) {
      // Loading failed: the still artwork below stays in place.
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The circle for the header and result avatars: ring and
  /// surface are code, the video inside carries no ring.
  Widget _circle(BuildContext context, double size, double ringWidth) {
    final palette = context.palette;
    final Color ring = widget.mode == CamMode.resultsReady
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
        child: Center(child: _video(context, Size(size, size))),
      ),
    );
  }

  Widget _video(BuildContext context, Size size) {
    if (!_ready) {
      return CamMascotArt(
        frame: evaluateCamFrame(Duration.zero, widget.mode),
        mode: widget.mode,
      );
    }
    return SizedBox(
      width: size.width,
      height: size.height,
      child: VideoPlayer(_controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.sizes;

    final Widget video = switch (widget.mode) {
      CamMode.avatar => _circle(context, s.mascotAvatarSize, 3),
      CamMode.avatarSmall => _circle(context, s.mascotAvatarSmallSize, 2),
      CamMode.resultsReady => _circle(context, s.mascotAvatarSize, 3),
      CamMode.analyzing => _video(
        context,
        Size(s.mascotAnalyzingWidth, s.mascotAnalyzingWidth),
      ),
      CamMode.processing => _video(
        context,
        Size(s.mascotProcessingWidth, s.mascotProcessingWidth),
      ),
    };

    // One-shots only: a 2 dp dip for Review's nod, a 3 % scale
    // pulse and a small tilt for Result's arrival. The idle
    // motion lives inside the video itself and is not re-applied.
    final moved = Transform.translate(
      offset: Offset(0, widget.nod),
      child: Transform.rotate(
        angle: -0.02 * widget.pulse,
        alignment: Alignment.bottomCenter,
        child: Transform.scale(
          scale: 1 + 0.03 * widget.pulse,
          alignment: Alignment.bottomCenter,
          child: video,
        ),
      ),
    );

    return ExcludeSemantics(child: moved);
  }
}
