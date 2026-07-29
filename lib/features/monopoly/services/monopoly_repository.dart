import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/monopoly_models.dart';

class MonopolyRepository {
  static const _statsKey = 'monopoly.stats.v1';

  Future<MonopolyStats> loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_statsKey);
    if (raw == null) return MonopolyStats();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return MonopolyStats.fromJson(json);
    } catch (_) {
      return MonopolyStats();
    }
  }

  Future<void> saveStats(MonopolyStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(stats.toJson());
    await prefs.setString(_statsKey, raw);
  }
}
