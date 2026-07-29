import 'dart:math';
import '../models/minesweeper_models.dart';

class MinesweeperEngine {
  static final _random = Random();

  /// Create fresh un-mined board cells
  static List<MineCell> createBoard(MinesweeperSize size) {
    final list = <MineCell>[];
    for (var r = 0; r < size.rows; r++) {
      for (var c = 0; c < size.cols; c++) {
        final idx = r * size.cols + c;
        list.add(MineCell(index: idx, row: r, col: c));
      }
    }
    return list;
  }

  /// Plant mines randomly on board while guaranteeing [safeIndex] and its neighbors have 0 mines
  static void plantMines({
    required List<MineCell> board,
    required MinesweeperSize size,
    required int safeIndex,
  }) {
    final safeNeighbors = getNeighbors(board, size, safeIndex)
        .map((c) => c.index)
        .toSet()
      ..add(safeIndex);

    final availableIndices = <int>[];
    for (var i = 0; i < board.length; i++) {
      if (!safeNeighbors.contains(i)) {
        availableIndices.add(i);
      }
    }

    availableIndices.shuffle(_random);
    final countToPlant = min(size.minesCount, availableIndices.length);

    for (var i = 0; i < countToPlant; i++) {
      final idx = availableIndices[i];
      board[idx].isMine = true;
    }

    // Calculate adjacent mine counts for all cells
    for (final cell in board) {
      if (cell.isMine) continue;
      final neighbors = getNeighbors(board, size, cell.index);
      cell.adjacentMines = neighbors.where((n) => n.isMine).length;
    }
  }

  /// Get 8-directional neighbors of a cell
  static List<MineCell> getNeighbors(
    List<MineCell> board,
    MinesweeperSize size,
    int index,
  ) {
    final cell = board[index];
    final neighbors = <MineCell>[];

    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nr = cell.row + dr;
        final nc = cell.col + dc;
        if (nr >= 0 && nr < size.rows && nc >= 0 && nc < size.cols) {
          neighbors.add(board[nr * size.cols + nc]);
        }
      }
    }
    return neighbors;
  }

  /// Flood-fill reveal connected 0-adjacent cells
  static List<int> floodReveal({
    required List<MineCell> board,
    required MinesweeperSize size,
    required int startIndex,
  }) {
    final revealedIndices = <int>[];
    final queue = <int>[startIndex];

    while (queue.isNotEmpty) {
      final currentIdx = queue.removeAt(0);
      final cell = board[currentIdx];

      if (cell.state != CellState.hidden) continue;

      cell.state = CellState.revealed;
      revealedIndices.add(currentIdx);

      if (cell.adjacentMines == 0) {
        final neighbors = getNeighbors(board, size, currentIdx);
        for (final n in neighbors) {
          if (n.state == CellState.hidden && !n.isMine) {
            queue.add(n.index);
          }
        }
      }
    }

    return revealedIndices;
  }
}
