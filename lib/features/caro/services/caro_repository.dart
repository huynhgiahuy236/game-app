import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/caro_models.dart';

class CaroRepository {
  static const _statsKey = 'caro.stats.v1';

  Future<CaroStats> loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_statsKey);
    if (raw == null) return CaroStats();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return CaroStats.fromJson(json);
    } catch (_) {
      return CaroStats();
    }
  }

  Future<void> saveStats(CaroStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(stats.toJson());
    await prefs.setString(_statsKey, raw);
  }
}
