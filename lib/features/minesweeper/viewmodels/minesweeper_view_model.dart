import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/minesweeper_models.dart';
import '../services/minesweeper_engine.dart';
import '../services/minesweeper_repository.dart';

class MinesweeperViewModel extends ChangeNotifier {
  MinesweeperViewModel(this.repository) {
    resetGame();
  }

  final MinesweeperRepository repository;

  MinesweeperSize size = MinesweeperSize.size64;
  MinesweeperStatus status = MinesweeperStatus.idle;
  bool flagMode = false;
  int elapsedSeconds = 0;
  Timer? _timer;

  late List<MineCell> board;
  bool firstClickDone = false;
  int? explodedMineIndex;

  int get remainingFlags {
    final flaggedCount = board.where((c) => c.state == CellState.flagged).length;
    return size.minesCount - flaggedCount;
  }

  void resetGame() {
    _timer?.cancel();
    elapsedSeconds = 0;
    status = MinesweeperStatus.idle;
    firstClickDone = false;
    explodedMineIndex = null;
    board = MinesweeperEngine.createBoard(size);
    notifyListeners();
  }

  void changeSize(MinesweeperSize newSize) {
    size = newSize;
    resetGame();
  }

  void toggleFlagMode() {
    flagMode = !flagMode;
    notifyListeners();
  }

  void handleCellTap(int index) {
    if (status == MinesweeperStatus.won || status == MinesweeperStatus.lost) {
      return;
    }
    if (flagMode) {
      toggleFlag(index);
    } else {
      revealCell(index);
    }
  }

  void toggleFlag(int index) {
    if (status == MinesweeperStatus.won || status == MinesweeperStatus.lost) {
      return;
    }
    final cell = board[index];
    if (cell.state == CellState.revealed) return;

    if (cell.state == CellState.flagged) {
      cell.state = CellState.hidden;
    } else {
      cell.state = CellState.flagged;
    }
    notifyListeners();
  }

  void revealCell(int index) {
    if (status == MinesweeperStatus.won || status == MinesweeperStatus.lost) {
      return;
    }
    final cell = board[index];
    if (cell.state == CellState.flagged || cell.state == CellState.revealed) {
      return;
    }

    // Plant mines on first click to guarantee safety
    if (!firstClickDone) {
      firstClickDone = true;
      MinesweeperEngine.plantMines(
        board: board,
        size: size,
        safeIndex: index,
      );
      _startTimer();
      status = MinesweeperStatus.playing;
    }

    // Hit a mine! Explosion!
    if (cell.isMine) {
      cell.exploded = true;
      explodedMineIndex = index;
      status = MinesweeperStatus.lost;
      _timer?.cancel();
      _revealAllMines();
      _saveStatsOnEnd(won: false);
      notifyListeners();
      return;
    }

    // Reveal single or flood reveal empty area
    MinesweeperEngine.floodReveal(
      board: board,
      size: size,
      startIndex: index,
    );

    _checkWinCondition();
    notifyListeners();
  }

  void _checkWinCondition() {
    final totalNonMines = size.totalCells - size.minesCount;
    final revealedCount =
        board.where((c) => !c.isMine && c.state == CellState.revealed).length;

    if (revealedCount == totalNonMines) {
      status = MinesweeperStatus.won;
      _timer?.cancel();
      // Auto-flag all remaining mines
      for (final cell in board) {
        if (cell.isMine) cell.state = CellState.flagged;
      }
      _saveStatsOnEnd(won: true);
    }
  }

  void _revealAllMines() {
    for (final cell in board) {
      if (cell.isMine && cell.state == CellState.hidden) {
        cell.state = CellState.revealed;
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsedSeconds++;
      notifyListeners();
    });
  }

  Future<void> _saveStatsOnEnd({required bool won}) async {
    final stats = await repository.loadStats();
    stats.gamesPlayed++;
    if (won) {
      stats.gamesWon++;
      if (stats.bestTimeSeconds == 0 || elapsedSeconds < stats.bestTimeSeconds) {
        stats.bestTimeSeconds = elapsedSeconds;
      }
    }
    await repository.saveStats(stats);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
