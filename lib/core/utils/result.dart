/// Result type returned by every service (FOLDER_STRUCTURE_AND_CONVENTIONS.md
/// §7 rule 6). Controllers convert [Failure] into UI state; exceptions never
/// cross the service boundary.
sealed class Result<T> {
  const Result();
}

/// Successful outcome carrying a [value].
final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

/// Failed outcome carrying an [AppFailure].
final class Failure<T> extends Result<T> {
  const Failure(this.failure);

  final AppFailure failure;
}

/// A user-presentable failure. [userMessageKey] is a key into
/// `core/strings/app_strings.dart` — never raw exception text.
class AppFailure {
  const AppFailure({
    required this.code,
    required this.userMessageKey,
    this.detail,
  });

  /// Machine-readable code, e.g. `network`, `not_implemented`, `no_people`.
  final String code;

  /// String key resolved by the view via GetX translations.
  final String userMessageKey;

  /// Optional diagnostic detail for logs. Never shown to the user and never
  /// contains photo content or URLs (AGENTS.md).
  final String? detail;

  @override
  String toString() => 'AppFailure(code: $code, detail: $detail)';
}
