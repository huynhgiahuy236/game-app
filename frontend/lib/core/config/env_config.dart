class EnvConfig {
  static String get apiBaseUrl {
    // Uses 127.0.0.1:4000 which works for:
    // 1. Real Android phone connected via USB (with ADB reverse port forwarding: `adb reverse tcp:4000 tcp:4000`)
    // 2. Windows Desktop / Web / macOS / Linux / iOS
    return 'http://127.0.0.1:4000/api/v1';
  }
}
