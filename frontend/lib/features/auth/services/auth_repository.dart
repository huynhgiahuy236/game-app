import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepository extends ChangeNotifier {
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
        final userData = await _apiClient.get('/auth/me');
        _currentUser = UserModel.fromJson(userData);
        _isAuthenticated = true;
        await _cachePreferences(_currentUser!.preferences);
      } else {
        _isAuthenticated = false;
        _currentUser = null;
      }
    } catch (e) {
      _isAuthenticated = false;
      _currentUser = null;
      await _apiClient.clearTokens();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final resData = await _apiClient.post('/auth/login', body: {
        'username': username,
        'password': password,
      });

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
        await _apiClient.post('/auth/logout', body: {'refreshToken': refreshToken});
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
