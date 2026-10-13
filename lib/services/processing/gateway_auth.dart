import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../config/app_config.dart';
import '../../core/strings/app_strings.dart';
import '../../core/utils/result.dart';

/// A persisted anonymous gateway session (Supabase GoTrue).
class StoredGatewaySession {
  const StoredGatewaySession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.expiryEpochSeconds,
  });

  final String accessToken;
  final String? refreshToken;
  final String userId;

  /// Seconds since epoch at which [accessToken] expires.
  final int expiryEpochSeconds;
}

/// Storage for a [StoredGatewaySession] — read / write / clear of the
/// access token, refresh token, user id and expiry epoch together.
abstract interface class GatewayTokenStore {
  Future<StoredGatewaySession?> read();
  Future<void> write(StoredGatewaySession session);
  Future<void> clear();
}

/// [GatewayTokenStore] backed by flutter_secure_storage. This file is a
/// service implementation, so it may import flutter_secure_storage
/// (Conventions §2/§8).
class SecureGatewayTokenStore implements GatewayTokenStore {
  SecureGatewayTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _accessKey = 'gateway_access_token';
  static const String _refreshKey = 'gateway_refresh_token';
  static const String _userKey = 'gateway_user_id';
  static const String _expiryKey = 'gateway_expiry_epoch';

  @override
  Future<StoredGatewaySession?> read() async {
    final access = await _storage.read(key: _accessKey);
    final userId = await _storage.read(key: _userKey);
    final expiryRaw = await _storage.read(key: _expiryKey);
    if (access == null || userId == null) return null;
    return StoredGatewaySession(
      accessToken: access,
      refreshToken: await _storage.read(key: _refreshKey),
      userId: userId,
      expiryEpochSeconds: int.tryParse(expiryRaw ?? '') ?? 0,
    );
  }

  @override
  Future<void> write(StoredGatewaySession session) async {
    await _storage.write(key: _accessKey, value: session.accessToken);
    if (session.refreshToken != null) {
      await _storage.write(key: _refreshKey, value: session.refreshToken);
    } else {
      await _storage.delete(key: _refreshKey);
    }
    await _storage.write(key: _userKey, value: session.userId);
    await _storage.write(
      key: _expiryKey,
      value: session.expiryEpochSeconds.toString(),
    );
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _userKey);
    await _storage.delete(key: _expiryKey);
  }
}

/// Anonymous Supabase auth for the gateway (§7.3). Ensures a valid
/// session exists: reuses a stored token, refreshes it, or signs up
/// anonymously. Never fabricates a session — every failure is a
/// [Failure] with code `gateway_auth`.
class GatewayAuth {
  GatewayAuth({
    required AppConfig config,
    GatewayTokenStore? tokenStore,
    Dio? dio,
    DateTime Function()? now,
  }) : _config = config,
       _store = tokenStore ?? SecureGatewayTokenStore(),
       _dio =
           dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 30))),
       _now = now ?? DateTime.now;

  final AppConfig _config;
  final GatewayTokenStore _store;
  final Dio _dio;
  final DateTime Function() _now;

  Dio get dio => _dio;

  Future<Result<({String accessToken, String userId})>> ensureSession() async {
    StoredGatewaySession? stored;
    try {
      stored = await _store.read();
    } catch (e) {
      return Failure<({String accessToken, String userId})>(
        AppFailure(
          code: 'gateway_auth',
          userMessageKey: AppStrings.errorGeneric,
          detail: e.toString(),
        ),
      );
    }
    final nowSeconds = _now().millisecondsSinceEpoch ~/ 1000;
    if (stored != null && stored.expiryEpochSeconds > nowSeconds + 60) {
      return Success<({String accessToken, String userId})>((
        accessToken: stored.accessToken,
        userId: stored.userId,
      ));
    }
    if (stored?.refreshToken != null) {
      return await _exchange(
        url: '${_config.supabaseUrl}/auth/v1/token',
        query: <String, dynamic>{'grant_type': 'refresh_token'},
        body: <String, dynamic>{'refresh_token': stored!.refreshToken},
      );
    }
    return await _exchange(
      url: '${_config.supabaseUrl}/auth/v1/signup',
      query: null,
      body: <String, dynamic>{},
    );
  }

  Future<Result<({String accessToken, String userId})>> _exchange({
    required String url,
    required Map<String, dynamic>? query,
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        url,
        data: body,
        queryParameters: query,
        options: Options(
          headers: <String, dynamic>{
            'apikey': _config.supabaseAnonKey,
            'Content-Type': 'application/json',
          },
        ),
      );
      final parsed = _parseSession(response.data);
      if (parsed == null) {
        return Failure<({String accessToken, String userId})>(
          AppFailure(
            code: 'gateway_auth',
            userMessageKey: AppStrings.errorGeneric,
            detail: 'HTTP ${response.statusCode}: auth response had no session',
          ),
        );
      }
      await _store.write(parsed);
      return Success<({String accessToken, String userId})>((
        accessToken: parsed.accessToken,
        userId: parsed.userId,
      ));
    } on DioException catch (e) {
      return _authFailure<({String accessToken, String userId})>(e);
    } catch (e) {
      return Failure<({String accessToken, String userId})>(
        AppFailure(
          code: 'gateway_auth',
          userMessageKey: AppStrings.errorGeneric,
          detail: e.toString(),
        ),
      );
    }
  }

  StoredGatewaySession? _parseSession(dynamic data) {
    if (data is! Map<String, dynamic>) return null;
    final access = data['access_token'] as String?;
    final user = data['user'] as Map<String, dynamic>?;
    final userId = user?['id'] as String?;
    if (access == null || userId == null) return null;
    final nowSeconds = _now().millisecondsSinceEpoch ~/ 1000;
    final expiresAt = (data['expires_at'] as num?)?.toInt();
    final expiresIn = (data['expires_in'] as num?)?.toInt();
    final expiry = expiresAt ?? (nowSeconds + (expiresIn ?? 3600));
    return StoredGatewaySession(
      accessToken: access,
      refreshToken: data['refresh_token'] as String?,
      userId: userId,
      expiryEpochSeconds: expiry,
    );
  }

  Failure<T> _authFailure<T>(DioException e) {
    final status = e.response?.statusCode;
    return Failure<T>(
      AppFailure(
        code: 'gateway_auth',
        userMessageKey: AppStrings.errorGeneric,
        detail: status != null
            ? 'HTTP $status'
            : 'auth request failed: ${e.type.name}',
      ),
    );
  }
}
