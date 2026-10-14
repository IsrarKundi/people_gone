import '../../../core/strings/app_strings.dart';

/// Maps a distraction's category (a label of record — every shipped
/// category passed the Phase B calibration gate on its own measured
/// precision, docs/architecture/phase-b-calibration.md) to the
/// display string key for its name on S4. Unknown or future
/// categories fall back to the generic "Item" — the UI never breaks
/// on a category it does not know.
String distractionCategoryLabelKey(String category) {
  return switch (category) {
    'car' => AppStrings.distractionClassCar,
    'bus' => AppStrings.distractionClassBus,
    'truck' => AppStrings.distractionClassTruck,
    'motorbike' => AppStrings.distractionClassMotorbike,
    'bicycle' => AppStrings.distractionClassBicycle,
    'traffic light' => AppStrings.distractionClassTrafficLight,
    'parking meter' => AppStrings.distractionClassParkingMeter,
    'bench' => AppStrings.distractionClassBench,
    'fire hydrant' => AppStrings.distractionClassFireHydrant,
    'trash bin' => AppStrings.distractionClassTrashBin,
    'stroller' => AppStrings.distractionClassStroller,
    _ => AppStrings.belongingClassOther,
  };
}
