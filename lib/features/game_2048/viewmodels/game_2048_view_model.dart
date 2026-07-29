import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/game_2048_model.dart';
import '../services/game_2048_repository.dart';

class Game2048ViewModel extends ChangeNotifier {
  Game2048ViewModel(this.repository, this.game, {Random? random})
    : _random = random ?? Random();

  final Game2048Repository repository;
  final Game2048Model game;
  final Random _random;
  Game2048Snapshot? _undo;
  Set<int> lastMergedIndices = const {};
  int moveRevision = 0;
  int appearanceRevision = 0;

  bool get canUndo => _undo != null;

  static Future<Game2048ViewModel> create(
    Game2048Repository repository, {
    bool resume = true,
    Random? random,
  }) async {
    final saved = resume ? await repository.load() : null;
    final game =
        saved ??
        Game2048Model(
          board: List<int>.filled(16, 0),
          bestScore: await repository.bestScore(),
        );
    final viewModel = Game2048ViewModel(repository, game, random: random);
    if (saved == null) {
      viewModel._addTile();
      viewModel._addTile();
      await repository.save(game);
    }
    return viewModel;
  }

  Future<void> newGame() async {
    if (game.moves > 0) {
      repository.recordFinalScore(game.score);
    }
    game.board.setAll(0, List<int>.filled(16, 0));
    game.score = 0;
    game.moves = 0;
    game.won = false;
    game.gameOver = false;
    game.keepPlaying = false;
    _undo = null;
    lastMergedIndices = const {};
    moveRevision++;
    appearanceRevision++;
    _addTile();
    _addTile();
    await repository.save(game);
    notifyListeners();
  }

  bool move(MoveDirection direction) {
    if (game.gameOver || (game.won && !game.keepPlaying)) return false;
    final before = List<int>.from(game.board);
    final beforeScore = game.score;
    final beforeMoves = game.moves;
    var gained = 0;
    final next = List<int>.filled(16, 0);
    final mergedTargets = <int>{};
    for (var line = 0; line < 4; line++) {
      final indices = _indices(direction, line);
      final values = [
        for (final i in indices)
          if (game.board[i] != 0) game.board[i],
      ];
      final merged = <int>[];
      for (var i = 0; i < values.length; i++) {
        if (i + 1 < values.length && values[i] == values[i + 1]) {
          final value = values[i] * 2;
          merged.add(value);
          gained += value;
          mergedTargets.add(indices[merged.length - 1]);
          i++;
        } else {
          merged.add(values[i]);
        }
      }
      for (var i = 0; i < merged.length; i++) {
        next[indices[i]] = merged[i];
      }
    }
    if (listEquals(before, next)) return false;
    _undo = Game2048Snapshot(before, beforeScore, beforeMoves);
    game.board.setAll(0, next);
    lastMergedIndices = mergedTargets;
    moveRevision++;
    appearanceRevision++;
    game.score += gained;
    game.moves++;
    if (game.score > game.bestScore) game.bestScore = game.score;
    _addTile();
    game.won = game.board.any((value) => value >= 2048);
    game.gameOver = !_hasMoves();
    if (game.gameOver) {
      repository.recordFinalScore(game.score);
    }
    repository.save(game);
    notifyListeners();
    return true;
  }

  void undo() {
    final snapshot = _undo;
    if (snapshot == null) return;
    game.board.setAll(0, snapshot.board);
    game.score = snapshot.score;
    game.moves = snapshot.moves;
    game.gameOver = false;
    game.won = game.board.any((value) => value >= 2048);
    lastMergedIndices = const {};
    moveRevision++;
    appearanceRevision++;
    _undo = null;
    repository.save(game);
    notifyListeners();
  }

  void continueAfterWin() {
    game.keepPlaying = true;
    repository.save(game);
    notifyListeners();
  }

  List<int> _indices(MoveDirection direction, int line) {
    return switch (direction) {
      MoveDirection.left => [for (var col = 0; col < 4; col++) line * 4 + col],
      MoveDirection.right => [
        for (var col = 3; col >= 0; col--) line * 4 + col,
      ],
      MoveDirection.up => [for (var row = 0; row < 4; row++) row * 4 + line],
      MoveDirection.down => [for (var row = 3; row >= 0; row--) row * 4 + line],
    };
  }

  void _addTile() {
    final empty = [
      for (var i = 0; i < 16; i++)
        if (game.board[i] == 0) i,
    ];
    if (empty.isEmpty) return;
    final tile = _pickRandomTile();
    game.board[empty[_random.nextInt(empty.length)]] = tile;
  }

  /// Sinh số ngẫu nhiên (2/4/8) tuỳ theo ngưỡng điểm & max tile hiện tại:
  /// - Dưới 256 điểm hoặc max < 64: 80% -> 2, 18% -> 4, 2% -> 8
  /// - 256..1023 điểm hoặc max 64..255: 60% -> 2, 32% -> 4, 8% -> 8
  /// - 1024..4095 điểm hoặc max 256..1023: 45% -> 2, 40% -> 4, 15% -> 8
  /// - Từ 4096 điểm hoặc max >= 1024: 30% -> 2, 45% -> 4, 25% -> 8
  int _pickRandomTile() {
    final maxTile = game.board.fold<int>(0, (m, v) => v > m ? v : m);
    final r = _random.nextDouble();
    if (game.score >= 4096 || maxTile >= 1024) {
      if (r < 0.30) return 2;
      if (r < 0.75) return 4;
      return 8;
    }
    if (game.score >= 1024 || maxTile >= 256) {
      if (r < 0.45) return 2;
      if (r < 0.85) return 4;
      return 8;
    }
    if (game.score >= 256 || maxTile >= 64) {
      if (r < 0.60) return 2;
      if (r < 0.92) return 4;
      return 8;
    }
    if (r < 0.80) return 2;
    if (r < 0.98) return 4;
    return 8;
  }

  bool _hasMoves() {
    if (game.board.contains(0)) return true;
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 4; col++) {
        final i = row * 4 + col;
        if (col < 3 && game.board[i] == game.board[i + 1]) return true;
        if (row < 3 && game.board[i] == game.board[i + 4]) return true;
      }
    }
    return false;
  }
}
