import 'dart:io' show Platform;

/// In-memory diagnostics log (owner-requested, 2026-10-14): a ring
/// buffer of timestamped step entries from the processing flows, so a
/// failure on a real device can be SHARED with support instead of
/// dying behind a generic error message.
///
/// Privacy contract (AGENTS.md): entries never contain photos, file
/// contents, auth tokens, API keys, or signed URLs. [sanitize] strips
/// credential-shaped values and URL query strings from anything logged,
/// as a second line of defence behind careful call sites.
class DiagnosticsLog {
  DiagnosticsLog._();

  static final DiagnosticsLog instance = DiagnosticsLog._();

  static const int _capacity = 300;
  final List<String> _entries = <String>[];
  final DateTime Function() _now = DateTime.now;

  /// Appends one entry: `[time] [tag] message` (message sanitized).
  void add(String tag, String message) {
    final t = _now().toIso8601String();
    _entries.add('[$t] [$tag] ${sanitize(message)}');
    if (_entries.length > _capacity) {
      _entries.removeRange(0, _entries.length - _capacity);
    }
  }

  void clear() => _entries.clear();

  int get length => _entries.length;

  /// Plain-text export for the share sheet: a small header (mode lines
  /// are logged at app start) plus every buffered entry, oldest first.
  String export() {
    final header =
        'Framora diagnostics — exported ${_now().toIso8601String()}\n'
        'Platform: ${Platform.operatingSystem}\n'
        'Entries: ${_entries.length}\n'
        '----------------------------------------';
    if (_entries.isEmpty) return '$header\n(no entries yet)';
    return '$header\n${_entries.join('\n')}';
  }

  /// Strips credential-shaped material from a log line: `Bearer <x>`,
  /// `apikey: <x>` / `apikey=<x>`, `token: <x>` / `token=<x>`, and any
  /// URL query string (signed URLs carry their credential there).
  static String sanitize(String input) {
    var out = input;
    out = out.replaceAll(
      RegExp(r'Bearer\s+\S+', caseSensitive: false),
      'Bearer <redacted>',
    );
    out = out.replaceAllMapped(
      RegExp(r'(apikey|api_key|token|secret)\s*[:=]\s*\S+', caseSensitive: false),
      (m) => '${m[1]}=<redacted>',
    );
    out = out.replaceAllMapped(
      RegExp(r'(https?://[^\s?]+)\?[^\s]*'),
      (m) => '${m[1]}?<redacted>',
    );
    return out;
  }

  /// First 8 chars of an id for logs — safe on short ids (never throws,
  /// unlike a raw substring in a logging call inside a try block).
  static String shortId(String id) =>
      id.length <= 8 ? id : id.substring(0, 8);
}

/// Convenience for call sites: `diag('gateway', 'confirm ok job 1a2b')`.
void diag(String tag, String message) => DiagnosticsLog.instance.add(tag, message);
