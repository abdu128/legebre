import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_notification.dart';
import '../models/user.dart';
import '../services/api_exception.dart';
import '../services/device_token_manager.dart';
import '../services/legebre_api.dart';

enum AppStatus { loading, unauthenticated, authenticated }

class AppState extends ChangeNotifier {
  AppState({LegebreApi? api, DeviceTokenManager? deviceTokenManager})
    : _api = api ?? LegebreApi(),
      _deviceTokenManager = deviceTokenManager ?? DeviceTokenManager();

  final LegebreApi _api;
  final DeviceTokenManager _deviceTokenManager;
  AppUser? _user;
  AppStatus _status = AppStatus.loading;
  bool _bootstrapped = false;
  Locale? _locale;
  String? _lastRegisteredDeviceToken;
  Set<String> _lastSyncedTopics = <String>{};

  static const _localeKey = 'preferred_locale';

  AppUser? get user => _user;
  AppStatus get status => _status;
  bool get isAuthenticated => _status == AppStatus.authenticated;
  LegebreApi get api => _api;
  Locale get locale => _locale ?? const Locale('en');

  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    await _loadSavedLocale();
    notifyListeners();
    final hasToken = await _api.hasStoredToken();
    if (!hasToken) {
      _status = AppStatus.unauthenticated;
      notifyListeners();
      return;
    }
    _status = AppStatus.authenticated;
    notifyListeners();
    try {
      final profile = await _api.getProfile();
      _user = profile;
      _status = AppStatus.authenticated;
      await _registerDeviceTokenIfNeeded();
    } on ApiException catch (error) {
      final unauthorized = error.statusCode == 401 || error.statusCode == 403;
      if (unauthorized) {
        await _api.logout();
        _user = null;
        _status = AppStatus.unauthenticated;
      } else {
        debugPrint('Profile refresh failed: $error');
      }
    } catch (error) {
      debugPrint('Bootstrap failed: $error');
    }
    notifyListeners();
  }

  Future<void> _loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_localeKey);
      if (code != null && code.isNotEmpty) {
        _locale = Locale(code);
      }
    } catch (_) {
      // Ignore locale persistence failures.
    }
  }

  Future<void> _registerDeviceTokenIfNeeded() async {
    if (!isAuthenticated) return;
    try {
      final token = await _deviceTokenManager.fetchToken();
      if (token == null || token.isEmpty) return;
      if (_lastRegisteredDeviceToken != token) {
        await _api.registerDeviceToken(token);
        _lastRegisteredDeviceToken = token;
      }
      await _syncTopicsForUser();
    } catch (error) {
      debugPrint('Failed to register device token: $error');
    }
  }

  Future<void> _clearRemoteDeviceToken() async {
    try {
      await _deviceTokenManager.unsubscribeFromAllTopics();
      _lastSyncedTopics = <String>{};
    } catch (error) {
      debugPrint('Failed to unsubscribe from topics: $error');
    }

    try {
      if (isAuthenticated) {
        await _api.clearDeviceToken();
      }
    } catch (error) {
      debugPrint('Failed to clear remote device token: $error');
    } finally {
      _deviceTokenManager.invalidateCache();
      _lastRegisteredDeviceToken = null;
    }
  }

  Set<String> _topicsForUser(AppUser? user) {
    final topics = <String>{'global'};
    final role = user?.role.trim().toLowerCase();
    if (role != null && role.isNotEmpty) {
      topics.add(role);
      if (role.contains('buyer')) {
        topics.add('buyers');
      } else if (role.contains('seller')) {
        topics.add('sellers');
      } else if (role.contains('admin')) {
        topics.add('admins');
      }
    }
    return topics;
  }

  Future<void> _syncTopicsForUser() async {
    final desired = _topicsForUser(_user);
    if (setEquals(desired, _lastSyncedTopics)) return;
    try {
      await _deviceTokenManager.syncTopics(desired);
      _lastSyncedTopics = Set<String>.from(desired);
    } catch (error) {
      debugPrint('Failed to sync topic subscriptions: $error');
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, locale.languageCode);
    } catch (_) {
      // Ignore persistence failures.
    }
  }

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    final (user, _) = await _api.login(
      identifier: identifier,
      password: password,
    );
    _user = user;
    _status = AppStatus.authenticated;
    await _registerDeviceTokenIfNeeded();
    notifyListeners();
  }

  Future<void> register({
    required String name,
    required String password,
    String? email,
    String? phone,
    String? whatsapp,
    String role = 'BUYER',
  }) async {
    final (user, _) = await _api.register(
      name: name,
      password: password,
      email: email,
      phone: phone,
      whatsapp: whatsapp,
      role: role,
    );
    _user = user;
    _status = AppStatus.authenticated;
    await _registerDeviceTokenIfNeeded();
    notifyListeners();
  }

  Future<void> requestPasswordReset(String email) {
    return _api.requestPasswordReset(email: email);
  }

  Future<void> resetPassword({required String otp, required String password}) {
    return _api.resetPassword(otp: otp, password: password);
  }

  Future<void> refreshProfile() async {
    if (!isAuthenticated) return;
    final profile = await _api.getProfile();
    _user = profile;
    await _syncTopicsForUser();
    notifyListeners();
  }

  Future<void> refreshDeviceToken() async {
    _deviceTokenManager.invalidateCache();
    await _registerDeviceTokenIfNeeded();
  }

  Future<List<AppNotification>> fetchNotifications() async {
    return _api.getNotifications();
  }

  Future<AppNotification> markNotificationRead(int id) async {
    return _api.markNotificationRead(id);
  }

  Future<void> deleteNotification(int id) async {
    await _api.deleteNotification(id);
  }

  Future<void> logout() async {
    await _clearRemoteDeviceToken();
    await _api.logout();
    _user = null;
    _status = AppStatus.unauthenticated;
    notifyListeners();
  }
}
