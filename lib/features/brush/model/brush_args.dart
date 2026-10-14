/// Navigation payload for Brush (S5): the photo the user paints on.
/// Carries a file path only, never photo content.
class BrushArgs {
  const BrushArgs({required this.imagePath, this.suggestedRegion});

  /// The current result (or proposal) photo on this device, full
  /// resolution. A touch-up re-runs on THIS file (FR-09).
  final String imagePath;

  /// Phase D (X14): a probable reflection region ([x1, y1, x2, y2],
  /// image pixels) handed over from the Result screen's reflection
  /// warning. The canvas outlines it as a starting guide only —
  /// nothing is painted until the user paints.
  final List<int>? suggestedRegion;
}
