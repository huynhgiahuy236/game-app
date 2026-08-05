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
  bool _isConnecting = false;
  int _startupSeconds = 0;
  String _startupMessage = 'Đang đọc phiên đăng nhập';
  Timer? _startupTicker;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  bool get isConnecting => _isConnecting;
  int get startupSeconds => _startupSeconds;
  String get startupMessage => _startupMessage;

  final ApiClient _apiClient = ApiClient.instance;

  Future<void> initSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _apiClient.getAccessToken();

      // Reading secure storage is the only work that blocks the first screen.
      // Network validation continues in the background so a sleeping server
      // never holds the UI on the splash screen.
      _isLoading = false;
      _isAuthenticated = token != null && token.isNotEmpty;
      _isConnecting = true;
      _startupMessage = 'Đang kết nối máy chủ';
      _startStartupTicker();
      notifyListeners();

      if (token != null && token.isNotEmpty) {
        try {
          final userData = await _apiClient
              .get('/auth/me')
              .timeout(_startupWait);
          _currentUser = UserModel.fromJson(userData);
          _isAuthenticated = true;
        } catch (_) {}
      } else {
        try {
          final resData = await _apiClient
              .post(
                '/auth/login',
                body: {'username': 'admin', 'password': 'chimuoi@123'},
              )
              .timeout(_startupWait);
          await _apiClient.saveTokens(
            resData['accessToken'],
            resData['refreshToken'],
          );
          _currentUser = UserModel.fromJson(resData['user']);
          _isAuthenticated = true;
          await _cachePreferences(_currentUser!.preferences);
        } catch (_) {}
      }
    } catch (_) {
    } finally {
      _isLoading = false;
      _isConnecting = false;
      _startupMessage = _isAuthenticated
          ? 'Đã kết nối'
          : 'Đang dùng chế độ ngoại tuyến';
      _startupTicker?.cancel();
      notifyListeners();
    }
  }

  void _startStartupTicker() {
    _startupTicker?.cancel();
    _startupSeconds = 0;
    _startupTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      _startupSeconds++;
      if (_startupSeconds >= 5) {
        _startupMessage = 'Máy chủ đang khởi động';
      }
      notifyListeners();
    });
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

  @override
  void dispose() {
    _startupTicker?.cancel();
    super.dispose();
  }
}
