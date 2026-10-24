import 'package:flutter_test/flutter_test.dart';
import 'package:people_gone/core/widgets/cam_frame.dart';
import 'package:people_gone/core/widgets/cam_video.dart';

/// Contract for Cam's videos: exactly two owner-approved assets
/// cover every mode — Home circles wave, both work screens scan.
/// A mode mapping to the wrong video would put the wave on the
/// work screens or the scan in the Home circle.
void main() {
  test('every mode maps to one of the two approved videos', () {
    expect(camVideoAsset(CamMode.avatar), 'assets/animations/cam_home_wave.mp4');
    expect(
      camVideoAsset(CamMode.avatarSmall),
      'assets/animations/cam_home_wave.mp4',
    );
    expect(
      camVideoAsset(CamMode.resultsReady),
      'assets/animations/cam_home_wave.mp4',
    );
    expect(
      camVideoAsset(CamMode.analyzing),
      'assets/animations/cam_processing_scan.mp4',
    );
    expect(
      camVideoAsset(CamMode.processing),
      'assets/animations/cam_processing_scan.mp4',
    );
  });
}
