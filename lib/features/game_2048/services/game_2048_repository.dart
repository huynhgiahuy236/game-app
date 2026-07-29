import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_2048_model.dart';

class Game2048Repository {
  static const _gameKey = 'game2048.active.v1';
  static const _bestKey = 'game2048.best.v1';
  static const _historyKey = 'game2048.history.v1';
  static const _maxHistory = 10;

  Future<Game2048Model?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_gameKey);
    if (raw == null) return null;
    final game = Game2048Model.decode(raw);
    if (game == null) await preferences.remove(_gameKey);
    return game;
  }

  Future<void> clearSave() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_gameKey);
  }

  Future<void> save(Game2048Model game) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_gameKey, game.encode());
    await preferences.setInt(_bestKey, game.bestScore);
  }

  Future<int> bestScore() async =>
      (await SharedPreferences.getInstance()).getInt(_bestKey) ?? 0;

  /// Lưu điểm cuối mỗi ván để hiển thị trong tab Thành tích.
  Future<void> recordFinalScore(int score) async {
    final preferences = await SharedPreferences.getInstance();
    final history =
        (preferences.getStringList(_historyKey) ?? <String>[])
            .map(int.tryParse)
            .whereType<int>()
            .toList();
    history.add(score);
    if (history.length > _maxHistory) {
      history.removeRange(0, history.length - _maxHistory);
    }
    await preferences.setStringList(
      _historyKey,
      history.map((s) => '$s').toList(),
    );
  }

  /// Lấy lịch sử điểm các ván gần nhất (mới nhất ở cuối).
  Future<List<int>> scoreHistory() async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList(_historyKey) ?? <String>[])
        .map(int.tryParse)
        .whereType<int>()
        .toList();
  }
}
