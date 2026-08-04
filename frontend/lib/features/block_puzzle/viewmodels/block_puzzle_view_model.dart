import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/block_puzzle_models.dart';
import '../services/block_puzzle_repository.dart';

class BlockPuzzleViewModel extends ChangeNotifier {
  BlockPuzzleViewModel._({required this.repository, required BlockPuzzleGame game})
      // ignore: prefer_initializing_formals
      : _game = game;

  final BlockPuzzleRepository repository;
  BlockPuzzleGame _game;

  BlockPuzzleGame get game => _game;

  // Drag state
  int? _draggingTrayIndex;
  int? get draggingTrayIndex => _draggingTrayIndex;

  // Last lines cleared for animation
  List<int> lastClearedRows = [];
  List<int> lastClearedCols = [];

  // Track piece IDs
  int _nextPieceId = 1000;

  // Cells that are "new" (just placed) for animation
  Set<(int, int)> newlyPlacedCells = {};

  static Future<BlockPuzzleViewModel> create(
      BlockPuzzleRepository repository) async {
    final saved = await repository.loadGame();
    if (saved != null && !saved.isGameOver) {
      final vm = BlockPuzzleViewModel._(repository: repository, game: saved);
      vm._refillTrayIfEmpty();
      return vm;
    }
    final vm = BlockPuzzleViewModel._(
      repository: repository,
      game: BlockPuzzleGame(bestScore: saved?.bestScore ?? 0),
    );
    vm._refillTray();
    return vm;
  }

  void startDrag(int trayIndex) {
    if (_game.tray[trayIndex] == null) return;
    if (_game.isGameOver) return;
    _draggingTrayIndex = trayIndex;
    notifyListeners();
  }

  void cancelDrag() {
    _draggingTrayIndex = null;
    notifyListeners();
  }

  bool tryPlace(int boardRow, int boardCol) {
    final trayIdx = _draggingTrayIndex;
    if (trayIdx == null) return false;
    final piece = _game.tray[trayIdx];
    if (piece == null) return false;
    if (!_game.canPlace(piece, boardRow, boardCol)) {
      _draggingTrayIndex = null;
      notifyListeners();
      return false;
    }

    // Place the piece
    final newBoard =
        _game.board.map((r) => List<int>.from(r)).toList();
    final placed = <(int, int)>{};
    for (final (dr, dc) in piece.cells) {
      newBoard[boardRow + dr][boardCol + dc] = piece.colorIndex;
      placed.add((boardRow + dr, boardCol + dc));
    }

    // Update tray
    final newTray = List<BlockPiece?>.from(_game.tray);
    newTray[trayIdx] = null;

    // Score: 1 point per cell placed
    int addedScore = piece.cells.length;

    // Clear completed rows and columns
    final clearedRows = <int>[];
    final clearedCols = <int>[];

    for (int r = 0; r < BlockPuzzleGame.boardSize; r++) {
      if (newBoard[r].every((c) => c != 0)) {
        clearedRows.add(r);
      }
    }
    for (int c = 0; c < BlockPuzzleGame.boardSize; c++) {
      if (newBoard.every((row) => row[c] != 0)) {
        clearedCols.add(c);
      }
    }

    final clearCount = clearedRows.length + clearedCols.length;
    int comboBonus = _game.combo;

    if (clearCount > 0) {
      comboBonus += clearCount;
      // Score: 10 per line cleared + combo multiplier
      addedScore += clearCount * 10 * max(1, _game.combo + 1);
      // Bonus for multi-line
      if (clearCount > 1) addedScore += clearCount * clearCount * 5;

      for (final r in clearedRows) {
        for (int c = 0; c < BlockPuzzleGame.boardSize; c++) {
          newBoard[r][c] = 0;
        }
      }
      for (final c in clearedCols) {
        for (int r = 0; r < BlockPuzzleGame.boardSize; r++) {
          newBoard[r][c] = 0;
        }
      }
    } else {
      comboBonus = 0;
    }

    final newScore = _game.score + addedScore;
    final newBest = max(newScore, _game.bestScore);
    final newTotalClears = _game.totalClears + clearCount;

    // Check if tray is empty → refill
    final shouldRefill = newTray.every((p) => p == null);
    List<BlockPiece?> finalTray = newTray;
    if (shouldRefill) {
      finalTray = _generateTray(newBest);
    }

    newlyPlacedCells = placed;
    lastClearedRows = clearedRows;
    lastClearedCols = clearedCols;

    _game = BlockPuzzleGame(
      board: newBoard,
      score: newScore,
      bestScore: newBest,
      combo: clearCount > 0 ? comboBonus : 0,
      totalClears: newTotalClears,
      tray: finalTray,
      isGameOver: false,
    );

    _draggingTrayIndex = null;

    // Check game over
    _checkGameOver();

    _save();
    notifyListeners();
    return true;
  }

  void _checkGameOver() {
    for (final piece in _game.tray) {
      if (piece == null) continue;
      for (int r = 0; r < BlockPuzzleGame.boardSize; r++) {
        for (int c = 0; c < BlockPuzzleGame.boardSize; c++) {
          if (_game.canPlace(piece, r, c)) return; // At least one piece can fit
        }
      }
    }
    // No piece from tray can be placed → game over
    _game = _game.copyWith(isGameOver: true);
  }

  void _refillTray() {
    _game = _game.copyWith(tray: _generateTray(_game.bestScore));
  }

  void _refillTrayIfEmpty() {
    if (_game.tray.every((p) => p == null)) {
      _refillTray();
    }
  }

  List<BlockPiece?> _generateTray(int best) {
    final rng = Random();
    final result = <BlockPiece?>[];
    for (int i = 0; i < 3; i++) {
      final defIdx = rng.nextInt(kAllPieceDefinitions.length);
      final def = kAllPieceDefinitions[defIdx];
      final colorIdx = rng.nextInt(8) + 1; // 1..8
      result.add(BlockPiece(
        id: _nextPieceId++,
        cells: def.cells,
        colorIndex: colorIdx,
      ));
    }
    return result;
  }

  Future<void> newGame() async {
    await repository.clearGame();
    final best = _game.bestScore;
    _game = BlockPuzzleGame(bestScore: best);
    newlyPlacedCells = {};
    lastClearedRows = [];
    lastClearedCols = [];
    _refillTray();
    notifyListeners();
  }

  void _save() {
    repository.saveGame(_game);
  }
}
