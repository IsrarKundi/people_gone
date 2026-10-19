/// Arguments passed into the Paywall screen (S8).
/// When opened from a cleaned photo (Result S7), [resultPath] and [originalPath]
/// are provided so the hero shows the user's own result.
/// When opened deliberately from Home (saves line at 0), photo paths are null.
class PaywallArgs {
  const PaywallArgs({
    this.originalPath,
    this.resultPath,
    this.arrivalReason,
  });

  final String? originalPath;
  final String? resultPath;
  final String? arrivalReason;

  bool get hasPhoto => resultPath != null && resultPath!.isNotEmpty;
}
