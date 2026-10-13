/// Route name constants (Conventions §3). Paths are kebab-case; navigation
/// goes through these names only (§7 rule 3).
abstract final class Routes {
  static const String home = '/';
  static const String processing = '/processing';
  static const String proposal = '/proposal';
  static const String brush = '/brush';
  static const String result = '/result';
  static const String paywall = '/paywall';
  static const String history = '/history';
  static const String historyDetail = '/history/detail';
  static const String settings = '/settings';
}
