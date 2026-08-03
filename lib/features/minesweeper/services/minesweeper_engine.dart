import 'dart:math';
import '../models/minesweeper_models.dart';

class ChordRevealResult {
  ChordRevealResult({
    required this.revealedIndices,
    this.hitMine = false,
    this.explodedMineIndex,
  });

  final List<int> revealedIndices;
  final bool hitMine;
  final int? explodedMineIndex;
}

class MinesweeperEngine {
  static final _random = Random();

  /// Create fresh un-mined board cells for given rows and cols
  static List<MineCell> createBoard(int rows, int cols) {
    final list = <MineCell>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final idx = r * cols + c;
        list.add(MineCell(index: idx, row: r, col: c));
      }
    }
    return list;
  }

  /// Plant mines randomly while guaranteeing [safeIndex] and its 8 neighbors are mine-free
  static void plantMines({
    required List<MineCell> board,
    required int rows,
    required int cols,
    required int minesCount,
    required int safeIndex,
  }) {
    final safeNeighbors = getNeighbors(board, rows, cols, safeIndex)
        .map((c) => c.index)
        .toSet()
      ..add(safeIndex);

    var availableIndices = <int>[];
    for (var i = 0; i < board.length; i++) {
      if (!safeNeighbors.contains(i)) {
        availableIndices.add(i);
      }
    }

    // Fallback if safe 3x3 region leaves too few cells for mines
    if (availableIndices.length < minesCount) {
      availableIndices = [
        for (var i = 0; i < board.length; i++)
          if (i != safeIndex) i,
      ];
    }

    availableIndices.shuffle(_random);
    final countToPlant = min(minesCount, availableIndices.length);

    for (var i = 0; i < countToPlant; i++) {
      final idx = availableIndices[i];
      board[idx].isMine = true;
    }

    // Calculate adjacent mine counts for all cells
    for (final cell in board) {
      if (cell.isMine) continue;
      final neighbors = getNeighbors(board, rows, cols, cell.index);
      cell.adjacentMines = neighbors.where((n) => n.isMine).length;
    }
  }

  /// Get 8-directional neighbors of a cell
  static List<MineCell> getNeighbors(
    List<MineCell> board,
    int rows,
    int cols,
    int index,
  ) {
    final cell = board[index];
    final neighbors = <MineCell>[];

    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nr = cell.row + dr;
        final nc = cell.col + dc;
        if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
          neighbors.add(board[nr * cols + nc]);
        }
      }
    }
    return neighbors;
  }

  /// Flood-fill reveal connected 0-adjacent cells (BFS, stack-safe)
  static List<int> floodReveal({
    required List<MineCell> board,
    required int rows,
    required int cols,
    required int startIndex,
  }) {
    final revealedIndices = <int>[];
    final startCell = board[startIndex];

    if (startCell.state != CellState.hidden) return revealedIndices;

    final queue = <int>[startIndex];
    final visited = <int>{startIndex};

    while (queue.isNotEmpty) {
      final currentIdx = queue.removeAt(0);
      final cell = board[currentIdx];

      if (cell.state == CellState.flagged) continue;

      cell.state = CellState.revealed;
      revealedIndices.add(currentIdx);

      if (cell.adjacentMines == 0) {
        final neighbors = getNeighbors(board, rows, cols, currentIdx);
        for (final n in neighbors) {
          if (n.state == CellState.hidden && !visited.contains(n.index)) {
            visited.add(n.index);
            queue.add(n.index);
          }
        }
      }
    }

    return revealedIndices;
  }

  /// Chord reveal: reveal surrounding unflagged hidden cells if flags match adjacent mines
  static ChordRevealResult chordReveal({
    required List<MineCell> board,
    required int rows,
    required int cols,
    required int index,
  }) {
    final cell = board[index];
    if (cell.state != CellState.revealed || cell.adjacentMines == 0) {
      return ChordRevealResult(revealedIndices: []);
    }

    final neighbors = getNeighbors(board, rows, cols, index);
    final flaggedCount = neighbors.where((n) => n.state == CellState.flagged).length;

    if (flaggedCount != cell.adjacentMines) {
      return ChordRevealResult(revealedIndices: []);
    }

    final unflaggedHidden = neighbors.where((n) => n.state == CellState.hidden).toList();
    if (unflaggedHidden.isEmpty) {
      return ChordRevealResult(revealedIndices: []);
    }

    // Check if any unflagged hidden cell is a mine (incorrect flagging by user)
    final mineCell = unflaggedHidden.firstWhere(
      (n) => n.isMine,
      orElse: () => MineCell(index: -1, row: -1, col: -1),
    );

    if (mineCell.index != -1) {
      mineCell.exploded = true;
      return ChordRevealResult(
        revealedIndices: [],
        hitMine: true,
        explodedMineIndex: mineCell.index,
      );
    }

    // Safely reveal all surrounding unflagged hidden cells
    final revealed = <int>[];
    for (final target in unflaggedHidden) {
      final sub = floodReveal(
        board: board,
        rows: rows,
        cols: cols,
        startIndex: target.index,
      );
      revealed.addAll(sub);
    }

    return ChordRevealResult(revealedIndices: revealed);
  }
}
