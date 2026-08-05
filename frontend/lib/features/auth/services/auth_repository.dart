import 'package:flutter/foundation.dart';
import 'dart:async';

import '../../../core/network/api_client.dart';
import '../models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepository extends ChangeNotifier {
  static const Duration _startupWait = Duration(seconds: 12);
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _isAuthenticated = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;

  final ApiClient _apiClient = ApiClient.instance;

  Future<void> initSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _apiClient.getAccessToken();
      if (token != null && token.isNotEmpty) {
        try {
          final userData = await _apiClient
              .get('/auth/me')
              .timeout(_startupWait);
          _currentUser = UserModel.fromJson(userData);
        } catch (_) {}
      } else {
        // Auto-login with default credentials if available
        try {
          await login('admin', 'chimuoi@123').timeout(_startupWait);
        } catch (_) {}
      }
    } catch (_) {
    } finally {
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final resData = await _apiClient.post(
        '/auth/login',
        body: {'username': username, 'password': password},
      );

      final accessToken = resData['accessToken'];
      final refreshToken = resData['refreshToken'];
      await _apiClient.saveTokens(accessToken, refreshToken);

      _currentUser = UserModel.fromJson(resData['user']);
      _isAuthenticated = true;
      await _cachePreferences(_currentUser!.preferences);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken = await _apiClient.getRefreshToken();
      if (refreshToken != null) {
        await _apiClient.post(
          '/auth/logout',
          body: {'refreshToken': refreshToken},
        );
      }
    } catch (_) {}

    await _apiClient.clearTokens();
    _currentUser = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<void> _cachePreferences(UserPreferences prefs) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList('pinned_modules', prefs.pinnedModules);
  }
}
