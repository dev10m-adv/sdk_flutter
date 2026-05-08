import 'dart:async';
import 'dart:convert';

import '../errors/uids_auth_exception.dart';
import '../models/auth_session.dart';
import '../network/auth_api_client.dart';
import '../storage/sdk_storage.dart';
import '../storage/storage_keys.dart';

/// Manages the lifecycle of an [AuthSession].
///
/// Responsibilities:
/// - Memory-first / secure-storage fallback reads.
/// - Token expiry checks with configurable buffer.
/// - A single scheduled auto-refresh timer (no polling).
/// - Manual refresh (e.g. after a 401).
/// - Broadcasting session changes via [sessionChanges].
final class SessionManager {
  SessionManager({
    required AuthApiClient apiClient,
    required SdkStorage storage,
    required Duration refreshBeforeExpiry,
    required bool autoRefresh,
  })  : _api = apiClient,
        _storage = storage,
        _refreshBeforeExpiry = refreshBeforeExpiry,
        _autoRefresh = autoRefresh;

  final AuthApiClient _api;
  final SdkStorage _storage;
  final Duration _refreshBeforeExpiry;
  final bool _autoRefresh;

  AuthSession? _memoryCache;
  Timer? _refreshTimer;

  final _sessionController = StreamController<AuthSession?>.broadcast();

  /// Stream of session changes.  Emits `null` on sign-out.
  Stream<AuthSession?> get sessionChanges => _sessionController.stream;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns the cached session (memory → secure storage), or `null`.
  Future<AuthSession?> currentSession() async {
    if (_memoryCache != null) return _memoryCache;
    return _loadFromStorage();
  }

  /// Returns a valid session, refreshing if expired or near expiry.
  Future<AuthSession> getValidSession() async {
    final session = await currentSession();
    if (session == null) throw const UidsSessionExpiredException();

    if (session.isExpiredWithBuffer(_refreshBeforeExpiry)) {
      return refreshSession();
    }
    return session;
  }

  /// Persists [session] in memory and secure storage, schedules auto-refresh.
  Future<void> saveSession(AuthSession session) async {
    _memoryCache = session;
    print('Saving session for user: ${session.user.email}');
    await _storage.write(StorageKeys.session, jsonEncode(session.toJson()));
    _sessionController.add(session);
    _scheduleAutoRefresh(session);
  }

  /// Forces a token refresh against the backend.
  ///
  /// On [UidsRefreshTokenExpiredException] the session is cleared and the
  /// exception is re-thrown.  Other network errors do NOT clear the session.
  Future<AuthSession> refreshSession() async {
    final session = await currentSession();
    if (session == null) throw const UidsSessionExpiredException();

    try {
      final refreshed = await _api.refreshToken(session.refreshToken);
      await saveSession(refreshed);
      return refreshed;
    } on UidsRefreshTokenExpiredException {
      await clearSession();
      rethrow;
    }
  }

  /// Clears memory cache and secure storage, cancels refresh timer.
  Future<void> clearSession() async {
    _memoryCache = null;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    await _storage.delete(StorageKeys.session);
    _sessionController.add(null);
  }

  /// Clears only the memory cache.  Secure storage is untouched.
  void clearMemoryCache() {
    _memoryCache = null;
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void dispose() {
    _refreshTimer?.cancel();
    _sessionController.close();
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  Future<AuthSession?> _loadFromStorage() async {
    final raw = await _storage.read(StorageKeys.session);
    print('Loaded session from storage: $raw');
    if (raw == null) return null;
    try {
      final session =
          AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      print('Parsed session from storage: $session');
      _memoryCache = session;
      return session;
    } catch (_) {
      print('Failed to parse session from storage, clearing corrupted data');
      // Corrupted storage — treat as missing.
      await _storage.delete(StorageKeys.session);
      return null;
    }
  }

  void _scheduleAutoRefresh(AuthSession session) {
    if (!_autoRefresh) return;
    _refreshTimer?.cancel();

    final delay = session.accessTokenExpiresAt
        .subtract(_refreshBeforeExpiry)
        .difference(DateTime.now());

    if (delay.isNegative) {
      // Already expired or within buffer — refresh immediately.
      _triggerRefresh();
      return;
    }

    _refreshTimer = Timer(delay, _triggerRefresh);
  }

  void _triggerRefresh() {
    refreshSession().ignore();
  }
}
