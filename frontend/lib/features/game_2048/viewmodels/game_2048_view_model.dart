import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/game_2048_model.dart';
import '../services/game_2048_repository.dart';

class TileModel {
  const TileModel({
    required this.id,
    required this.value,
    required this.row,
    required this.col,
    this.previousRow,
    this.previousCol,
    this.mergedFrom,
    this.isNew = false,
  });

  final int id;
  final int value;
  final int row;
  final int col;
  final int? previousRow;
  final int? previousCol;
  final List<TileModel>? mergedFrom;
  final bool isNew;

  TileModel copyWith({
    int? id,
    int? value,
    int? row,
    int? col,
    int? previousRow,
    int? previousCol,
    List<TileModel>? mergedFrom,
    bool? isNew,
  }) {
    return TileModel(
      id: id ?? this.id,
      value: value ?? this.value,
      row: row ?? this.row,
      col: col ?? this.col,
      previousRow: previousRow ?? this.previousRow,
      previousCol: previousCol ?? this.previousCol,
      mergedFrom: mergedFrom ?? this.mergedFrom,
      isNew: isNew ?? this.isNew,
    );
  }
}

class Game2048ViewModel extends ChangeNotifier {
  Game2048ViewModel(this.repository, this.game, {Random? random})
      : _random = random ?? Random() {
    _syncTilesFromBoard();
  }

  final Game2048Repository repository;
  final Game2048Model game;
  final Random _random;
  Game2048Snapshot? _undo;

  List<TileModel> tiles = [];
  int _nextTileId = 1;
  bool isInvalidMove = false;
  bool isMovingLocked = false;
  int moveRevision = 0;
  int appearanceRevision = 0;

  bool get canUndo => _undo != null;

  Set<int> get lastMergedIndices {
    final indices = <int>{};
    for (final t in tiles) {
      if (t.mergedFrom != null) {
        indices.add(t.row * game.size + t.col);
      }
    }
    return indices;
  }

  static Future<Game2048ViewModel> create(
    Game2048Repository repository, {
    bool resume = true,
    Random? random,
  }) async {
    var saved = resume ? await repository.load() : null;
    if (saved != null && saved.board.every((v) => v == 0)) {
      saved = null;
      await repository.clearSave();
    }
    final game =
        saved ??
        Game2048Model(
          board: List<int>.filled(16, 0),
          size: 4,
          bestScore: await repository.bestScore(size: 4),
        );
    final viewModel = Game2048ViewModel(repository, game, random: random);
    final nonZeroTiles = game.board.where((v) => v > 0).length;
    if (nonZeroTiles < 2) {
      for (var i = 0; i < 2 - nonZeroTiles; i++) {
        viewModel._addTile();
      }
      viewModel._updateBoardFromTiles();
      await repository.save(game);
    }
    return viewModel;
  }

  Future<void> newGame({int? size}) async {
    if (game.moves > 0) {
      repository.recordFinalScore(game.score);
    }

    final newSize = size ?? game.size;
    game.size = newSize;
    game.board = List<int>.filled(newSize * newSize, 0);
    game.bestScore = await repository.bestScore(size: newSize);
    game.score = 0;
    game.moves = 0;
    game.won = false;
    game.gameOver = false;
    game.keepPlaying = false;
    _undo = null;
    tiles.clear();
    _nextTileId = 1;
    moveRevision++;
    appearanceRevision++;
    _addTile();
    _addTile();
    _updateBoardFromTiles();
    await repository.save(game);
    notifyListeners();
  }

  bool move(MoveDirection direction) {
    if (isMovingLocked || game.gameOver || (game.won && !game.keepPlaying)) {
      return false;
    }

    final beforeBoard = List<int>.from(game.board);
    final beforeScore = game.score;
    final beforeMoves = game.moves;

    final nextTiles = <TileModel>[];
    var gained = 0;
    var moved = false;

    for (var line = 0; line < game.size; line++) {
      final lineTiles = _getLineTiles(direction, line);
      var targetPos = 0;
      var i = 0;

      while (i < lineTiles.length) {
        final current = lineTiles[i];
        if (i + 1 < lineTiles.length && current.value == lineTiles[i + 1].value) {
          final next = lineTiles[i + 1];
          final newValue = current.value * 2;
          gained += newValue;
          moved = true;

          final targetRow = _getTargetRow(direction, line, targetPos);
          final targetCol = _getTargetCol(direction, line, targetPos);

          final source1 = current.copyWith(
            previousRow: current.row,
            previousCol: current.col,
            row: targetRow,
            col: targetCol,
            isNew: false,
          );
          final source2 = next.copyWith(
            previousRow: next.row,
            previousCol: next.col,
            row: targetRow,
            col: targetCol,
            isNew: false,
          );

          nextTiles.add(
            TileModel(
              id: _nextTileId++,
              value: newValue,
              row: targetRow,
              col: targetCol,
              previousRow: targetRow,
              previousCol: targetCol,
              mergedFrom: [source1, source2],
              isNew: false,
            ),
          );
          targetPos++;
          i += 2;
        } else {
          final targetRow = _getTargetRow(direction, line, targetPos);
          final targetCol = _getTargetCol(direction, line, targetPos);

          if (current.row != targetRow || current.col != targetCol) {
            moved = true;
          }

          nextTiles.add(
            current.copyWith(
              previousRow: current.row,
              previousCol: current.col,
              row: targetRow,
              col: targetCol,
              isNew: false,
            ),
          );
          targetPos++;
          i++;
        }
      }
    }

    if (!moved) {
      isInvalidMove = true;
      notifyListeners();
      Timer(const Duration(milliseconds: 250), () {
        isInvalidMove = false;
        notifyListeners();
      });
      return false;
    }

    isMovingLocked = true;
    Timer(const Duration(milliseconds: 140), () {
      isMovingLocked = false;
      notifyListeners();
    });

    moveRevision++;
    appearanceRevision++;

    _undo = Game2048Snapshot(beforeBoard, beforeScore, beforeMoves);
    tiles = nextTiles;
    _updateBoardFromTiles();

    game.score += gained;
    game.moves++;
    if (game.score > game.bestScore) {
      game.bestScore = game.score;
    }

    _addTile();
    _updateBoardFromTiles();

    game.won = game.board.any((v) => v >= 2048);
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
    _undo = null;
    moveRevision++;
    appearanceRevision++;
    _syncTilesFromBoard();
    repository.save(game);
    notifyListeners();
  }

  void continueAfterWin() {
    game.keepPlaying = true;
    repository.save(game);
    notifyListeners();
  }

  void _syncTilesFromBoard() {
    tiles.clear();
    final total = game.size * game.size;
    for (var i = 0; i < total; i++) {
      if (i < game.board.length && game.board[i] > 0) {
        tiles.add(
          TileModel(
            id: _nextTileId++,
            value: game.board[i],
            row: i ~/ game.size,
            col: i % game.size,
          ),
        );
      }
    }
  }

  void _updateBoardFromTiles() {
    final total = game.size * game.size;
    game.board = List<int>.filled(total, 0);
    for (final tile in tiles) {
      final index = tile.row * game.size + tile.col;
      if (index < total) {
        game.board[index] = tile.value;
      }
    }
  }

  List<TileModel> _getLineTiles(MoveDirection direction, int line) {
    final lineTiles = <TileModel>[];
    for (var pos = 0; pos < game.size; pos++) {
      final r = switch (direction) {
        MoveDirection.left || MoveDirection.right => line,
        MoveDirection.up => pos,
        MoveDirection.down => game.size - 1 - pos,
      };
      final c = switch (direction) {
        MoveDirection.up || MoveDirection.down => line,
        MoveDirection.left => pos,
        MoveDirection.right => game.size - 1 - pos,
      };
      final tile = _findTileAt(r, c);
      if (tile != null) lineTiles.add(tile);
    }
    return lineTiles;
  }

  int _getTargetRow(MoveDirection direction, int line, int targetPos) {
    return switch (direction) {
      MoveDirection.left || MoveDirection.right => line,
      MoveDirection.up => targetPos,
      MoveDirection.down => game.size - 1 - targetPos,
    };
  }

  int _getTargetCol(MoveDirection direction, int line, int targetPos) {
    return switch (direction) {
      MoveDirection.up || MoveDirection.down => line,
      MoveDirection.left => targetPos,
      MoveDirection.right => game.size - 1 - targetPos,
    };
  }

  TileModel? _findTileAt(int row, int col) {
    for (final t in tiles) {
      if (t.row == row && t.col == col) return t;
    }
    return null;
  }

  bool _isOccupied(int row, int col) {
    return tiles.any((t) => t.row == row && t.col == col);
  }

  void _addTile() {
    final emptyPositions = <int>[];
    for (var r = 0; r < game.size; r++) {
      for (var c = 0; c < game.size; c++) {
        if (!_isOccupied(r, c)) {
          emptyPositions.add(r * game.size + c);
        }
      }
    }
    if (emptyPositions.isEmpty) return;
    final pos = emptyPositions[_random.nextInt(emptyPositions.length)];
    final val = _pickRandomTile();
    tiles.add(
      TileModel(
        id: _nextTileId++,
        value: val,
        row: pos ~/ game.size,
        col: pos % game.size,
        isNew: true,
      ),
    );
  }

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
    for (var row = 0; row < game.size; row++) {
      for (var col = 0; col < game.size; col++) {
        final i = row * game.size + col;
        if (col < game.size - 1 && game.board[i] == game.board[i + 1]) return true;
        if (row < game.size - 1 && game.board[i] == game.board[i + game.size]) return true;
      }
    }
    return false;
  }
}
