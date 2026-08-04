import 'dart:math';
import '../models/caro_models.dart';

class CaroAi {
  static final _random = Random();

  /// Finds the best move index for AI (playing as [aiSymbol])
  static int findBestMove({
    required List<CaroSymbol> board,
    required CaroBoardSize size,
    required CaroSymbol aiSymbol,
    required CaroDifficulty difficulty,
  }) {
    final available = <int>[];
    for (var i = 0; i < board.length; i++) {
      if (board[i] == CaroSymbol.none) available.add(i);
    }
    if (available.isEmpty) return -1;

    // Easy mode: 50% random, 50% smart
    if (difficulty == CaroDifficulty.easy && _random.nextDouble() < 0.5) {
      return available[_random.nextInt(available.length)];
    }

    final playerSymbol = aiSymbol.opposite;

    // 1. Check if AI can win in 1 move
    for (final idx in available) {
      board[idx] = aiSymbol;
      if (checkWinFrom(board, size, idx, aiSymbol)) {
        board[idx] = CaroSymbol.none;
        return idx;
      }
      board[idx] = CaroSymbol.none;
    }

    // 2. Check if AI needs to block Player from winning in 1 move
    for (final idx in available) {
      board[idx] = playerSymbol;
      if (checkWinFrom(board, size, idx, playerSymbol)) {
        board[idx] = CaroSymbol.none;
        return idx;
      }
      board[idx] = CaroSymbol.none;
    }

    // 3. For Medium/Hard, evaluate positional heuristics
    int bestScore = -999999;
    int bestIdx = available[_random.nextInt(available.length)];

    for (final idx in available) {
      final score = _evaluatePosition(board, size, idx, aiSymbol, playerSymbol);
      if (score > bestScore) {
        bestScore = score;
        bestIdx = idx;
      }
    }

    return bestIdx;
  }

  static int _evaluatePosition(
    List<CaroSymbol> board,
    CaroBoardSize size,
    int idx,
    CaroSymbol ai,
    CaroSymbol player,
  ) {
    int score = 0;
    final dim = size.dimension;
    final r = idx ~/ dim;
    final c = idx % dim;

    // Favor center positions
    final centerR = dim / 2;
    final centerC = dim / 2;
    final distFromCenter = (r - centerR).abs() + (c - centerC).abs();
    score += (dim - distFromCenter.toInt()) * 2;

    // Directions: (dr, dc)
    const dirs = [
      [0, 1],  // Horizontal
      [1, 0],  // Vertical
      [1, 1],  // Diagonal \
      [1, -1], // Diagonal /
    ];

    for (final d in dirs) {
      final dr = d[0];
      final dc = d[1];

      // Check potential for AI
      score += _countLinePotential(board, dim, r, c, dr, dc, ai) * 10;
      // Check blocking potential for Player
      score += _countLinePotential(board, dim, r, c, dr, dc, player) * 8;
    }

    return score;
  }

  static int _countLinePotential(
    List<CaroSymbol> board,
    int dim,
    int r,
    int c,
    int dr,
    int dc,
    CaroSymbol symbol,
  ) {
    int count = 0;
    for (var step = 1; step <= 3; step++) {
      final nr = r + dr * step;
      final nc = c + dc * step;
      if (nr >= 0 && nr < dim && nc >= 0 && nc < dim) {
        final cell = board[nr * dim + nc];
        if (cell == symbol) {
          count += 3;
        } else if (cell == CaroSymbol.none) {
          count += 1;
        } else {
          break;
        }
      }
    }
    for (var step = 1; step <= 3; step++) {
      final nr = r - dr * step;
      final nc = c - dc * step;
      if (nr >= 0 && nr < dim && nc >= 0 && nc < dim) {
        final cell = board[nr * dim + nc];
        if (cell == symbol) {
          count += 3;
        } else if (cell == CaroSymbol.none) {
          count += 1;
        } else {
          break;
        }
      }
    }
    return count;
  }

  static bool checkWinFrom(
    List<CaroSymbol> board,
    CaroBoardSize size,
    int idx,
    CaroSymbol symbol,
  ) {
    final dim = size.dimension;
    final winCount = size.winCount;
    final r = idx ~/ dim;
    final c = idx % dim;

    const dirs = [
      [0, 1],
      [1, 0],
      [1, 1],
      [1, -1],
    ];

    for (final d in dirs) {
      int count = 1;
      // Positive direction
      for (var step = 1; step < winCount; step++) {
        final nr = r + d[0] * step;
        final nc = c + d[1] * step;
        if (nr >= 0 && nr < dim && nc >= 0 && nc < dim && board[nr * dim + nc] == symbol) {
          count++;
        } else {
          break;
        }
      }
      // Negative direction
      for (var step = 1; step < winCount; step++) {
        final nr = r - d[0] * step;
        final nc = c - d[1] * step;
        if (nr >= 0 && nr < dim && nc >= 0 && nc < dim && board[nr * dim + nc] == symbol) {
          count++;
        } else {
          break;
        }
      }
      if (count >= winCount) return true;
    }
    return false;
  }

  /// Returns indices of winning line if [symbol] has won, or null
  static List<int>? findWinningLine(
    List<CaroSymbol> board,
    CaroBoardSize size,
  ) {
    final dim = size.dimension;
    final winCount = size.winCount;

    const dirs = [
      [0, 1],
      [1, 0],
      [1, 1],
      [1, -1],
    ];

    for (var r = 0; r < dim; r++) {
      for (var c = 0; c < dim; c++) {
        final idx = r * dim + c;
        final sym = board[idx];
        if (sym == CaroSymbol.none) continue;

        for (final d in dirs) {
          final line = <int>[idx];
          for (var step = 1; step < winCount; step++) {
            final nr = r + d[0] * step;
            final nc = c + d[1] * step;
            if (nr >= 0 && nr < dim && nc >= 0 && nc < dim) {
              final nIdx = nr * dim + nc;
              if (board[nIdx] == sym) {
                line.add(nIdx);
              } else {
                break;
              }
            } else {
              break;
            }
          }
          if (line.length >= winCount) {
            return line;
          }
        }
      }
    }
    return null;
  }
}
