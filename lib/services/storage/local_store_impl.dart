import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/strings/app_strings.dart';
import '../../core/utils/result.dart';
import 'local_store.dart';

/// [LocalStore] implementation — the only file that imports
/// `path_provider`, `flutter_secure_storage`, and `gal`
/// (Conventions §1.2/§8).
///
/// Layout under the app-documents directory:
///   peoplegone/history/  saved result files + index.json
///   peoplegone/session/  working result files (share/save source)
///   peoplegone/saves.json  {period: 'YYYY-MM' (UTC), used: n}
/// The consent record lives in secure storage.
class LocalStoreImpl implements LocalStore {
  LocalStoreImpl({
    Future<Directory> Function()? documentsDir,
    Future<String?> Function(String key)? secureRead,
    Future<void> Function(String key, String value)? secureWrite,
    DateTime Function()? nowUtc,
  }) : _documentsDir = documentsDir ?? getApplicationDocumentsDirectory,
       _secureRead = secureRead ?? _defaultSecureRead,
       _secureWrite = secureWrite ?? _defaultSecureWrite,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  static const FlutterSecureStorage _secure = FlutterSecureStorage();
  static const String _consentKey = 'consent_version';

  final Future<Directory> Function() _documentsDir;
  final Future<String?> Function(String key) _secureRead;
  final Future<void> Function(String key, String value) _secureWrite;
  final DateTime Function() _nowUtc;

  static Future<String?> _defaultSecureRead(String key) =>
      _secure.read(key: key);

  static Future<void> _defaultSecureWrite(String key, String value) =>
      _secure.write(key: key, value: value);

  Failure<T> _storageFailure<T>(Object error) => Failure<T>(
    AppFailure(
      code: 'storage',
      userMessageKey: AppStrings.errorGeneric,
      detail: error.toString(),
    ),
  );

  Future<Directory> _root() async {
    final docs = await _documentsDir();
    final root = Directory('${docs.path}/peoplegone');
    if (!await root.exists()) await root.create(recursive: true);
    return root;
  }

  Future<Directory> _historyDir() async {
    final dir = Directory('${(await _root()).path}/history');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _sessionDir() async {
    final dir = Directory('${(await _root()).path}/session');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // --- History ------------------------------------------------------------

  Future<File> _indexFile() async =>
      File('${(await _historyDir()).path}/index.json');

  Future<List<HistoryEntry>> _readIndex() async {
    final file = await _indexFile();
    if (!await file.exists()) return <HistoryEntry>[];
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return <HistoryEntry>[];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((dynamic e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeIndex(List<HistoryEntry> entries) async {
    final file = await _indexFile();
    await file.writeAsString(
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  @override
  Future<Result<List<HistoryEntry>>> history() async {
    try {
      final entries = await _readIndex();
      entries.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      return Success<List<HistoryEntry>>(entries);
    } catch (e) {
      return _storageFailure<List<HistoryEntry>>(e);
    }
  }

  @override
  Future<Result<void>> addHistory(HistoryEntry entry) async {
    try {
      final entries = await _readIndex();
      entries.removeWhere((e) => e.id == entry.id);
      entries.add(entry);
      await _writeIndex(entries);
      return const Success<void>(null);
    } catch (e) {
      return _storageFailure<void>(e);
    }
  }

  @override
  Future<Result<void>> deleteHistory(String id) async {
    try {
      final entries = await _readIndex();
      for (final entry in entries.where((e) => e.id == id)) {
        final file = File(entry.localPath);
        if (await file.exists()) await file.delete();
        if (entry.originalPath != null) {
          final orig = File(entry.originalPath!);
          if (await orig.exists()) await orig.delete();
        }
      }
      entries.removeWhere((e) => e.id == id);
      await _writeIndex(entries);
      return const Success<void>(null);
    } catch (e) {
      return _storageFailure<void>(e);
    }
  }

  @override
  Future<Result<String>> adoptIntoHistory(String sessionPath, String id) async {
    try {
      final dir = await _historyDir();
      final target = File('${dir.path}/$id.jpg');
      await File(sessionPath).copy(target.path);
      return Success<String>(target.path);
    } catch (e) {
      return _storageFailure<String>(e);
    }
  }

  @override
  Future<Result<String>> adoptOriginalIntoHistory(
    String originalPath,
    String id,
  ) async {
    try {
      final origFile = File(originalPath);
      if (!await origFile.exists()) {
        return Success<String>(originalPath);
      }
      final dir = await _historyDir();
      final target = File('${dir.path}/${id}_orig.jpg');
      await origFile.copy(target.path);
      return Success<String>(target.path);
    } catch (e) {
      return _storageFailure<String>(e);
    }
  }

  // --- Session results ------------------------------------------------------

  @override
  Future<Result<String>> writeSessionResult(Uint8List bytes) async {
    try {
      final dir = await _sessionDir();
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final file = File('${dir.path}/result_$stamp.jpg');
      await file.writeAsBytes(bytes, flush: true);
      return Success<String>(file.path);
    } catch (e) {
      return _storageFailure<String>(e);
    }
  }

  // --- Gallery --------------------------------------------------------------

  @override
  Future<Result<void>> saveToGallery(String localPath) async {
    try {
      await Gal.putImage(localPath);
      return const Success<void>(null);
    } catch (e) {
      return Failure<void>(
        AppFailure(
          code: 'gallery',
          userMessageKey: AppStrings.errorSaveFailed,
          detail: e.toString(),
        ),
      );
    }
  }

  // --- Free saves -----------------------------------------------------------

  String get _period {
    final now = _nowUtc();
    final month = now.month.toString().padLeft(2, '0');
    return '${now.year}-$month';
  }

  Future<File> _savesFile() async => File('${(await _root()).path}/saves.json');

  Future<int> _readUsed() async {
    final file = await _savesFile();
    if (!await file.exists()) return 0;
    final decoded =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (decoded['period'] != _period) return 0;
    return (decoded['used'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<Result<int>> freeSavesUsed() async {
    try {
      return Success<int>(await _readUsed());
    } catch (e) {
      return _storageFailure<int>(e);
    }
  }

  @override
  Future<Result<DateTime>> freeSavesResetDate() async {
    final now = _nowUtc();
    // DateTime.utc normalises month 13 into January of the next year.
    return Success<DateTime>(DateTime.utc(now.year, now.month + 1, 1));
  }

  @override
  Future<Result<void>> consumeFreeSave() async {
    try {
      final used = await _readUsed();
      final file = await _savesFile();
      await file.writeAsString(
        jsonEncode(<String, dynamic>{'period': _period, 'used': used + 1}),
      );
      return const Success<void>(null);
    } catch (e) {
      return _storageFailure<void>(e);
    }
  }

  // --- Consent --------------------------------------------------------------

  @override
  Future<Result<int?>> acceptedConsentVersion() async {
    try {
      final raw = await _secureRead(_consentKey);
      return Success<int?>(raw == null ? null : int.tryParse(raw));
    } catch (e) {
      return _storageFailure<int?>(e);
    }
  }

  @override
  Future<Result<void>> setAcceptedConsentVersion(int version) async {
    try {
      await _secureWrite(_consentKey, version.toString());
      return const Success<void>(null);
    } catch (e) {
      return _storageFailure<void>(e);
    }
  }
}
