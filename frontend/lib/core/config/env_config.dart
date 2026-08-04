import 'package:flutter/foundation.dart';

class EnvConfig {
  static String get apiBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:4000/api/v1';
    }
    // Android emulator default host loopback is 10.0.2.2
    // For physical device, change to your computer's local Wi-Fi IP (e.g. http://192.168.1.5:4000/api/v1)
    return 'http://10.0.2.2:4000/api/v1';
  }
}
