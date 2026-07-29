import 'package:flutter/foundation.dart';
import '../models/caro_models.dart';
import '../services/caro_ai.dart';
import '../services/caro_repository.dart';

class CaroViewModel extends ChangeNotifier {
  CaroViewModel(this.repository) {
    resetBoard();
  }

  final CaroRepository repository;

  CaroBoardSize boardSize = CaroBoardSize.classic3x3;
  CaroMode mode = CaroMode.vsAi;
  CaroDifficulty difficulty = CaroDifficulty.medium;

  late List<CaroSymbol> board;
  CaroSymbol turn = CaroSymbol.x;
  CaroSymbol winner = CaroSymbol.none;
  List<int>? winningLine;
  bool isDraw = false;
  bool isAiThinking = false;

  final List<CaroMove> history = [];

  void resetBoard() {
    board = List<CaroSymbol>.filled(boardSize.totalCells, CaroSymbol.none);
    turn = CaroSymbol.x;
    winner = CaroSymbol.none;
    winningLine = null;
    isDraw = false;
    isAiThinking = false;
    history.clear();
    notifyListeners();
  }

  void configure({
    CaroBoardSize? newSize,
    CaroMode? newMode,
    CaroDifficulty? newDifficulty,
  }) {
    if (newSize != null) boardSize = newSize;
    if (newMode != null) mode = newMode;
    if (newDifficulty != null) difficulty = newDifficulty;
    resetBoard();
  }

  void playMove(int index) {
    if (winner != CaroSymbol.none || isDraw || isAiThinking) return;
    if (index < 0 || index >= board.length || board[index] != CaroSymbol.none) {
      return;
    }

    // Play human move
    _applyMove(index, turn);

    // Check if AI turn is needed
    if (winner == CaroSymbol.none &&
        !isDraw &&
        mode == CaroMode.vsAi &&
        turn == CaroSymbol.o) {
      _triggerAiMove();
    }
  }

  void _applyMove(int index, CaroSymbol symbol) {
    board[index] = symbol;
    history.add(CaroMove(index, symbol));

    // Check win condition
    final line = CaroAi.findWinningLine(board, boardSize);
    if (line != null) {
      winner = symbol;
      winningLine = line;
      _updateStatsOnEnd();
    } else if (!board.contains(CaroSymbol.none)) {
      isDraw = true;
      _updateStatsOnEnd();
    } else {
      turn = symbol.opposite;
    }
    notifyListeners();
  }

  void _triggerAiMove() async {
    isAiThinking = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 350));

    final aiMoveIdx = CaroAi.findBestMove(
      board: board,
      size: boardSize,
      aiSymbol: CaroSymbol.o,
      difficulty: difficulty,
    );

    isAiThinking = false;
    if (aiMoveIdx >= 0) {
      _applyMove(aiMoveIdx, CaroSymbol.o);
    }
  }

  void undo() {
    if (history.isEmpty || isAiThinking) return;
    if (mode == CaroMode.vsAi) {
      // Undo both AI move and Player move if AI went last
      if (history.last.symbol == CaroSymbol.o && history.length >= 2) {
        final aiMove = history.removeLast();
        final playerMove = history.removeLast();
        board[aiMove.index] = CaroSymbol.none;
        board[playerMove.index] = CaroSymbol.none;
      } else if (history.last.symbol == CaroSymbol.x) {
        final playerMove = history.removeLast();
        board[playerMove.index] = CaroSymbol.none;
      }
      turn = CaroSymbol.x;
    } else {
      final lastMove = history.removeLast();
      board[lastMove.index] = CaroSymbol.none;
      turn = lastMove.symbol;
    }
    winner = CaroSymbol.none;
    winningLine = null;
    isDraw = false;
    notifyListeners();
  }

  Future<void> _updateStatsOnEnd() async {
    final stats = await repository.loadStats();
    stats.totalGames++;

    if (isDraw) {
      stats.draws++;
    } else if (winner == CaroSymbol.x) {
      stats.xWins++;
      if (mode == CaroMode.vsAi) stats.playerWinsVsAi++;
    } else if (winner == CaroSymbol.o) {
      stats.oWins++;
      if (mode == CaroMode.vsAi) stats.aiWins++;
    }

    await repository.saveStats(stats);
  }
}
