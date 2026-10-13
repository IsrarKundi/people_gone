/// Navigation payload for Brush (S5): the photo the user paints on.
/// Carries a file path only, never photo content.
class BrushArgs {
  const BrushArgs({required this.imagePath});

  /// The current result (or proposal) photo on this device, full
  /// resolution. A touch-up re-runs on THIS file (FR-09).
  final String imagePath;
}
