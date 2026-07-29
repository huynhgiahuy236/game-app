import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_2048_model.dart';

class Game2048Repository {
  static const _gameKey = 'game2048.active.v1';
  static const _bestKey = 'game2048.best.v1';

  Future<Game2048Model?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_gameKey);
    if (raw == null) return null;
    final game = Game2048Model.decode(raw);
    if (game == null) await preferences.remove(_gameKey);
    return game;
  }

  Future<void> save(Game2048Model game) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_gameKey, game.encode());
    await preferences.setInt(_bestKey, game.bestScore);
  }

  Future<int> bestScore() async =>
      (await SharedPreferences.getInstance()).getInt(_bestKey) ?? 0;
}
