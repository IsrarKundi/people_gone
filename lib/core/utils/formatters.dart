import 'package:intl/intl.dart';

/// Pure formatting helpers (Conventions §1.2). No widgets, no state.
abstract final class Formatters {
  static final DateFormat _date = DateFormat.yMMMd();
  static final DateFormat _dateTime = DateFormat.yMMMd().add_jm();

  /// e.g. `Oct 13, 2026`.
  static String date(DateTime value) => _date.format(value);

  /// e.g. `Oct 13, 2026 5:33 PM`.
  static String dateTime(DateTime value) => _dateTime.format(value);

  /// Locale-aware integer, e.g. `1,200`.
  static String count(int value) => NumberFormat.decimalPattern().format(
        value,
      );
}
