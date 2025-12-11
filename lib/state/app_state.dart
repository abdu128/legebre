import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/api_exception.dart';
import '../services/legebre_api.dart';

enum AppStatus { loading, unauthenticated, authenticated }

class AppState extends ChangeNotifier {
  AppState({LegebreApi? api}) : _api = api ?? LegebreApi();

  final LegebreApi _api;
  AppUser? _user;
  AppStatus _status = AppStatus.loading;
  bool _bootstrapped = false;

  AppUser? get user => _user;
  AppStatus get status => _status;
  bool get isAuthenticated => _status == AppStatus.authenticated;
  LegebreApi get api => _api;

  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    try {
      final profile = await _api.getProfile();
      _user = profile;
      _status = AppStatus.authenticated;
    } on ApiException {
      await _api.logout();
      _status = AppStatus.unauthenticated;
    } catch (_) {
      _status = AppStatus.unauthenticated;
    }
    notifyListeners();
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
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    if (!isAuthenticated) return;
    final profile = await _api.getProfile();
    _user = profile;
    notifyListeners();
  }

  Future<void> logout() async {
    await _api.logout();
    _user = null;
    _status = AppStatus.unauthenticated;
    notifyListeners();
  }
}


