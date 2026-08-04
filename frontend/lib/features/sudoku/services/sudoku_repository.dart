import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sudoku_models.dart';

class SudokuRepository {
  static const _gameKey = 'sudoku.active.v1';
  static const _statsKey = 'sudoku.stats.v1';
  static const _tutorialKey = 'sudoku.tutorial.v1';
  static const _lastDifficultyKey = 'sudoku.last_difficulty.v1';

  Future<void> saveGame(SudokuGame game) async =>
      (await SharedPreferences.getInstance()).setString(
        _gameKey,
        game.encode(),
      );
  Future<SudokuGame?> loadGame() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_gameKey);
    if (raw == null) return null;
    final game = SudokuGame.decode(raw);
    if (game == null) await prefs.remove(_gameKey);
    return game;
  }

  Future<void> clearGame() async =>
      (await SharedPreferences.getInstance()).remove(_gameKey);
  Future<SudokuStats> loadStats() async => SudokuStats.fromJson(
    (await SharedPreferences.getInstance()).getString(_statsKey),
  );
  Future<void> saveStats(SudokuStats stats) async =>
      (await SharedPreferences.getInstance()).setString(
        _statsKey,
        jsonEncode(stats.toJson()),
      );
  Future<bool> tutorialSeen() async =>
      (await SharedPreferences.getInstance()).getBool(_tutorialKey) ?? false;
  Future<void> markTutorialSeen() async =>
      (await SharedPreferences.getInstance()).setBool(_tutorialKey, true);

  Future<Difficulty> loadLastDifficulty() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastDifficultyKey);
    if (raw != null) {
      try {
        return Difficulty.values.byName(raw);
      } catch (_) {}
    }
    return Difficulty.easy;
  }

  Future<void> saveLastDifficulty(Difficulty difficulty) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastDifficultyKey, difficulty.name);
  }
}
