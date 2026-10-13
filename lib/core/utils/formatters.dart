import 'package:intl/intl.dart';

/// Pure formatting helpers (Conventions §1.2). No widgets, no state.
abstract final class Formatters {
  static final DateFormat _date = DateFormat.yMMMd();
  static final DateFormat _dateTime = DateFormat.yMMMd().add_jm();

  /// e.g. `Oct 13, 2026`.
  static String date(DateTime value) => _date.format(value);

  static final DateFormat _dayMonth = DateFormat('d MMM');

  /// e.g. `1 Nov` — the compact day-month the Settings plan line uses
  /// for the free-saves reset date (Design Direction §4 S10).
  static String dayMonth(DateTime value) => _dayMonth.format(value);

  /// e.g. `Oct 13, 2026 5:33 PM`.
  static String dateTime(DateTime value) => _dateTime.format(value);

  /// Locale-aware integer, e.g. `1,200`.
  static String count(int value) => NumberFormat.decimalPattern().format(value);

  /// Elapsed time as `m:ss`, e.g. `0:42`, `2:05`. Used by the processing
  /// screen — an honest fact, never an estimate (Design Direction §6).
  static String elapsed(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds - minutes * 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
