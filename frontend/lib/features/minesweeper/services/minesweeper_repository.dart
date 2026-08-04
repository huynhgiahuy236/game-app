import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/minesweeper_models.dart';

class MinesweeperRepository {
  static const _statsKey = 'minesweeper.stats.v1';
  static const _savedGameKey = 'minesweeper.active_game.v1';
  static const _lastDifficultyKey = 'minesweeper.last_difficulty.v1';
  static const _soundMutedKey = 'minesweeper.sound_muted.v1';

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

  Future<MinesweeperSavedState?> loadActiveGame() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedGameKey);
    if (raw == null) return null;
    return MinesweeperSavedState.decode(raw);
  }

  Future<void> saveActiveGame(MinesweeperSavedState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedGameKey, state.encode());
  }

  Future<void> clearActiveGame() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedGameKey);
  }

  Future<MinesweeperDifficulty> loadLastDifficulty() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_lastDifficultyKey);
    if (idx != null && idx >= 0 && idx < MinesweeperDifficulty.values.length) {
      return MinesweeperDifficulty.values[idx];
    }
    return MinesweeperDifficulty.easy;
  }

  Future<void> saveLastDifficulty(MinesweeperDifficulty difficulty) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastDifficultyKey, difficulty.index);
  }

  Future<bool> loadSoundMuted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_soundMutedKey) ?? false;
  }

  Future<void> saveSoundMuted(bool muted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundMutedKey, muted);
  }
}
