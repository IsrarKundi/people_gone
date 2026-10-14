import '../../../core/strings/app_strings.dart';

/// Maps a belonging's detected class (a detector HINT — the classes
/// are confused with each other in measurement, investigation §5.5)
/// to the display string key for its name on S4. Unknown or future
/// classes fall back to the generic "Item" — the UI never states a
/// specific class the detector did not report, and never breaks on a
/// class it does not know.
String belongingClassLabelKey(String detectedClass) {
  return switch (detectedClass) {
    'backpack' => AppStrings.belongingClassBackpack,
    'handbag' => AppStrings.belongingClassHandbag,
    'suitcase' => AppStrings.belongingClassSuitcase,
    'umbrella' => AppStrings.belongingClassUmbrella,
    _ => AppStrings.belongingClassOther,
  };
}
