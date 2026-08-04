import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/minesweeper_models.dart';
import '../services/minesweeper_engine.dart';
import '../services/minesweeper_repository.dart';

class MinesweeperViewModel extends ChangeNotifier {
  MinesweeperViewModel(this.repository) {
    board = MinesweeperEngine.createBoard(currentRows, currentCols);
  }

  final MinesweeperRepository repository;

  MinesweeperDifficulty difficulty = MinesweeperDifficulty.easy;
  int customRows = 10;
  int customCols = 10;
  int customMines = 15;

  MinesweeperStatus status = MinesweeperStatus.idle;
  bool flagMode = false;
  int elapsedSeconds = 0;
  Timer? _timer;

  late List<MineCell> board;
  bool firstClickDone = false;
  int? explodedMineIndex;

  MinesweeperSavedState? pendingSavedGame;
  MinesweeperStats stats = MinesweeperStats();
  bool soundMuted = false;

  int get currentRows => difficulty == MinesweeperDifficulty.custom ? customRows : difficulty.rows;
  int get currentCols => difficulty == MinesweeperDifficulty.custom ? customCols : difficulty.cols;
  int get currentMines => difficulty == MinesweeperDifficulty.custom ? customMines : difficulty.minesCount;
  int get totalCells => currentRows * currentCols;

  int get remainingFlags {
    final flaggedCount = board.where((c) => c.state == CellState.flagged).length;
    return currentMines - flaggedCount;
  }

  static Future<MinesweeperViewModel> create(MinesweeperRepository repository) async {
    final viewModel = MinesweeperViewModel(repository);
    viewModel.stats = await repository.loadStats();
    viewModel.soundMuted = await repository.loadSoundMuted();
    viewModel.difficulty = await repository.loadLastDifficulty();

    final saved = await repository.loadActiveGame();
    if (saved != null && saved.status == MinesweeperStatus.playing && saved.firstClickDone) {
      viewModel.pendingSavedGame = saved;
    }

    viewModel.resetGame();
    return viewModel;
  }

  void resetGame() {
    _timer?.cancel();
    elapsedSeconds = 0;
    status = MinesweeperStatus.idle;
    firstClickDone = false;
    explodedMineIndex = null;
    board = MinesweeperEngine.createBoard(currentRows, currentCols);
    notifyListeners();
  }

  Future<void> startNewGame({
    MinesweeperDifficulty? newDiff,
    int? rows,
    int? cols,
    int? mines,
  }) async {
    _timer?.cancel();
    if (newDiff != null) {
      difficulty = newDiff;
      await repository.saveLastDifficulty(difficulty);
    }
    if (rows != null && cols != null && mines != null) {
      customRows = rows;
      customCols = cols;
      customMines = mines;
    }

    resetGame();
    await repository.clearActiveGame();
  }

  Future<void> resumeSavedGame() async {
    final saved = pendingSavedGame;
    if (saved == null) return;

    difficulty = saved.difficulty;
    customRows = saved.rows;
    customCols = saved.cols;
    customMines = saved.minesCount;
    board = saved.board;
    status = saved.status;
    elapsedSeconds = saved.elapsedSeconds;
    firstClickDone = saved.firstClickDone;
    flagMode = saved.flagMode;
    explodedMineIndex = saved.explodedMineIndex;

    pendingSavedGame = null;

    if (status == MinesweeperStatus.playing) {
      _startTimer();
    }

    notifyListeners();
  }

  Future<void> clearSavedGame() async {
    pendingSavedGame = null;
    await repository.clearActiveGame();
    resetGame();
  }

  void toggleFlagMode() {
    flagMode = !flagMode;
    _saveActiveGame();
    notifyListeners();
  }

  void togglePause() {
    if (status != MinesweeperStatus.playing && status != MinesweeperStatus.paused) {
      return;
    }

    if (status == MinesweeperStatus.playing) {
      status = MinesweeperStatus.paused;
      _timer?.cancel();
    } else {
      status = MinesweeperStatus.playing;
      _startTimer();
    }
    _saveActiveGame();
    notifyListeners();
  }

  void handleCellTap(int index) {
    if (status == MinesweeperStatus.paused ||
        status == MinesweeperStatus.won ||
        status == MinesweeperStatus.lost) {
      return;
    }

    final cell = board[index];
    if (cell.state == CellState.revealed) {
      chordReveal(index);
      return;
    }

    if (flagMode) {
      toggleFlag(index);
    } else {
      revealCell(index);
    }
  }

  void toggleFlag(int index) {
    if (status == MinesweeperStatus.paused ||
        status == MinesweeperStatus.won ||
        status == MinesweeperStatus.lost) {
      return;
    }
    final cell = board[index];
    if (cell.state == CellState.revealed) return;

    if (cell.state == CellState.flagged) {
      cell.state = CellState.hidden;
    } else {
      cell.state = CellState.flagged;
    }

    _saveActiveGame();
    notifyListeners();
  }

  void revealCell(int index) {
    if (status == MinesweeperStatus.paused ||
        status == MinesweeperStatus.won ||
        status == MinesweeperStatus.lost) {
      return;
    }
    final cell = board[index];
    if (cell.state == CellState.flagged || cell.state == CellState.revealed) {
      return;
    }

    // Plant mines on first click to guarantee safe 3x3 region
    if (!firstClickDone) {
      firstClickDone = true;
      MinesweeperEngine.plantMines(
        board: board,
        rows: currentRows,
        cols: currentCols,
        minesCount: currentMines,
        safeIndex: index,
      );
      _startTimer();
      status = MinesweeperStatus.playing;
    }

    // Hit a mine! Loss state!
    if (cell.isMine) {
      cell.exploded = true;
      explodedMineIndex = index;
      _triggerLoss();
      return;
    }

    // Reveal single or flood reveal empty region
    MinesweeperEngine.floodReveal(
      board: board,
      rows: currentRows,
      cols: currentCols,
      startIndex: index,
    );

    _checkWinCondition();
    _saveActiveGame();
    notifyListeners();
  }

  void chordReveal(int index) {
    if (status != MinesweeperStatus.playing || !firstClickDone) return;

    final result = MinesweeperEngine.chordReveal(
      board: board,
      rows: currentRows,
      cols: currentCols,
      index: index,
    );

    if (result.hitMine && result.explodedMineIndex != null) {
      explodedMineIndex = result.explodedMineIndex;
      _triggerLoss();
      return;
    }

    if (result.revealedIndices.isNotEmpty) {
      _checkWinCondition();
      _saveActiveGame();
      notifyListeners();
    }
  }

  void _triggerLoss() {
    status = MinesweeperStatus.lost;
    _timer?.cancel();

    // Mark all incorrect flags and reveal all remaining unflagged mines
    for (final c in board) {
      if (c.state == CellState.flagged && !c.isMine) {
        c.isIncorrectFlag = true;
      } else if (c.isMine && c.state == CellState.hidden) {
        c.state = CellState.revealed;
      }
    }

    repository.clearActiveGame();
    _saveStatsOnEnd(won: false);
    notifyListeners();
  }

  void _checkWinCondition() {
    final totalNonMines = totalCells - currentMines;
    final revealedCount =
        board.where((c) => !c.isMine && c.state == CellState.revealed).length;

    if (revealedCount == totalNonMines) {
      status = MinesweeperStatus.won;
      _timer?.cancel();
      // Auto-flag all remaining mines
      for (final cell in board) {
        if (cell.isMine) cell.state = CellState.flagged;
      }
      repository.clearActiveGame();
      _saveStatsOnEnd(won: true);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsedSeconds++;
      _saveActiveGame();
      notifyListeners();
    });
  }

  Future<void> toggleSoundMuted() async {
    soundMuted = !soundMuted;
    await repository.saveSoundMuted(soundMuted);
    notifyListeners();
  }

  Future<void> _saveActiveGame() async {
    if (firstClickDone && status == MinesweeperStatus.playing) {
      final state = MinesweeperSavedState(
        difficulty: difficulty,
        rows: currentRows,
        cols: currentCols,
        minesCount: currentMines,
        board: board,
        status: status,
        elapsedSeconds: elapsedSeconds,
        firstClickDone: firstClickDone,
        flagMode: flagMode,
        explodedMineIndex: explodedMineIndex,
      );
      await repository.saveActiveGame(state);
    }
  }

  Future<void> _saveStatsOnEnd({required bool won}) async {
    stats.gamesPlayed++;
    if (won) {
      stats.gamesWon++;
      stats.updateBestTime(difficulty, elapsedSeconds);
    }
    await repository.saveStats(stats);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
