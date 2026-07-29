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
    game.board[empty[_random.nextInt(empty.length)]] = _random.nextDouble() < .9
        ? 2
        : 4;
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
