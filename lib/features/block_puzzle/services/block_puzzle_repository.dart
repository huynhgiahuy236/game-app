import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/block_puzzle_models.dart';

class BlockPuzzleRepository {
  static const _keyBoard = 'block_puzzle_board';
  static const _keyScore = 'block_puzzle_score';
  static const _keyBest = 'block_puzzle_best';
  static const _keyCombo = 'block_puzzle_combo';
  static const _keyTotalClears = 'block_puzzle_total_clears';
  static const _keyTray = 'block_puzzle_tray';

  Future<BlockPuzzleGame?> loadGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final boardJson = prefs.getString(_keyBoard);
      if (boardJson == null) return null;

      final rawBoard = (jsonDecode(boardJson) as List)
          .map((row) => (row as List).map((c) => c as int).toList())
          .toList();

      final score = prefs.getInt(_keyScore) ?? 0;
      final best = prefs.getInt(_keyBest) ?? 0;
      final combo = prefs.getInt(_keyCombo) ?? 0;
      final totalClears = prefs.getInt(_keyTotalClears) ?? 0;

      final trayJson = prefs.getString(_keyTray);
      List<BlockPiece?> tray = [null, null, null];
      if (trayJson != null) {
        final rawTray = jsonDecode(trayJson) as List;
        tray = rawTray.map<BlockPiece?>((t) {
          if (t == null) return null;
          final cells = (t['cells'] as List)
              .map<(int, int)>((c) => (c[0] as int, c[1] as int))
              .toList();
          return BlockPiece(
            id: t['id'] as int,
            cells: cells,
            colorIndex: t['colorIndex'] as int,
          );
        }).toList();
      }

      return BlockPuzzleGame(
        board: rawBoard,
        score: score,
        bestScore: best,
        combo: combo,
        totalClears: totalClears,
        tray: tray,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveGame(BlockPuzzleGame game) async {
    final prefs = await SharedPreferences.getInstance();
    final boardJson =
        jsonEncode(game.board.map((r) => r.toList()).toList());
    await prefs.setString(_keyBoard, boardJson);
    await prefs.setInt(_keyScore, game.score);
    await prefs.setInt(_keyBest, game.bestScore);
    await prefs.setInt(_keyCombo, game.combo);
    await prefs.setInt(_keyTotalClears, game.totalClears);

    final trayJson = jsonEncode(game.tray.map((piece) {
      if (piece == null) return null;
      return {
        'id': piece.id,
        'colorIndex': piece.colorIndex,
        'cells': piece.cells.map((c) => [c.$1, c.$2]).toList(),
      };
    }).toList());
    await prefs.setString(_keyTray, trayJson);
  }

  Future<int> bestScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyBest) ?? 0;
  }

  Future<void> clearGame() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBoard);
    await prefs.remove(_keyScore);
    await prefs.remove(_keyCombo);
    await prefs.remove(_keyTotalClears);
    await prefs.remove(_keyTray);
    // Keep best score
  }
}
