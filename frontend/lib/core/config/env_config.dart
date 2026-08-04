class EnvConfig {
  static String? _overrideUrl;

  static const String defaultLocalUrl = 'http://127.0.0.1:4000/api/v1';
  static const String defaultRenderUrl = 'https://game-app-8hx0.onrender.com/api/v1';

  static String get apiBaseUrl {
    if (_overrideUrl != null && _overrideUrl!.isNotEmpty) {
      return _overrideUrl!;
    }
    const envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    return defaultRenderUrl;
  }

  static void setOverrideUrl(String? url) {
    if (url != null && url.trim().isNotEmpty) {
      _overrideUrl = url.trim();
    } else {
      _overrideUrl = null;
    }
  }
}
