import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/minesweeper_models.dart';

class MinesweeperRepository {
  static const _statsKey = 'minesweeper.stats.v1';

  Future<MinesweeperStats> loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_statsKey);
    if (raw == null) return MinesweeperStats();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return MinesweeperStats.fromJson(json);
    } catch (_) {
      return MinesweeperStats();
    }
  }

  Future<void> saveStats(MinesweeperStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(stats.toJson());
    await prefs.setString(_statsKey, raw);
  }
}
