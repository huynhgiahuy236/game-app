import '../models/sudoku_models.dart';

abstract final class SudokuEngine {
  static bool isValidGrid(List<int> grid, {bool allowEmpty = true}) {
    if (grid.length != 81 || grid.any((v) => v < 0 || v > 9)) return false;
    for (var i = 0; i < 9; i++) {
      if (!_validUnit(List.generate(9, (j) => grid[i * 9 + j]), allowEmpty) ||
          !_validUnit(List.generate(9, (j) => grid[j * 9 + i]), allowEmpty)) {
        return false;
      }
      final br = (i ~/ 3) * 3, bc = (i % 3) * 3;
      if (!_validUnit(
        List.generate(9, (j) => grid[(br + j ~/ 3) * 9 + bc + j % 3]),
        allowEmpty,
      )) {
        return false;
      }
    }
    return true;
  }

  static bool _validUnit(List<int> unit, bool allowEmpty) {
    final values = unit.where((v) => v != 0).toList();
    return (allowEmpty || values.length == 9) &&
        values.toSet().length == values.length;
  }

  static int countSolutions(List<int> puzzle, {int limit = 2}) {
    final grid = List<int>.from(puzzle);
    var count = 0;
    void solve() {
      if (count >= limit) return;
      var target = -1;
      List<int>? candidates;
      for (var i = 0; i < 81; i++) {
        if (grid[i] != 0) continue;
        final c = candidatesFor(grid, i);
        if (c.isEmpty) return;
        if (candidates == null || c.length < candidates.length) {
          target = i;
          candidates = c;
        }
      }
      if (target == -1) {
        count++;
        return;
      }
      for (final value in candidates!) {
        grid[target] = value;
        solve();
        grid[target] = 0;
      }
    }

    if (isValidGrid(grid)) solve();
    return count;
  }

  static List<int> candidatesFor(List<int> grid, int index) {
    final used = <int>{};
    for (final peer in peers(index)) {
      if (grid[peer] != 0) used.add(grid[peer]);
    }
    return [
      for (var n = 1; n <= 9; n++)
        if (!used.contains(n)) n,
    ];
  }

  static Set<int> peers(int index) {
    final row = index ~/ 9, col = index % 9;
    return {
      for (var i = 0; i < 9; i++) row * 9 + i,
      for (var i = 0; i < 9; i++) i * 9 + col,
      for (var r = row ~/ 3 * 3; r < row ~/ 3 * 3 + 3; r++)
        for (var c = col ~/ 3 * 3; c < col ~/ 3 * 3 + 3; c++) r * 9 + c,
    }..remove(index);
  }
}

abstract final class PuzzleBank {
  static const _solution =
      '534678912672195348198342567859761423426853791713924856961537284287419635345286179';
  static const Map<Difficulty, String> _puzzles = {
    Difficulty.easy:
        '534070010600195000098000067800060003400853001700020006060000284000419005040080079',
    Difficulty.medium:
        '534070000600195000098000060800060003400853001700020006060000280000419005040080079',
    Difficulty.hard:
        '530070000600195000098000060800060003400803001700020006060000280000419005000080079',
    Difficulty.expert:
        '530070000600195008098000060800060003400803001700020006060000280000419005300080079',
  };

  static SudokuPuzzle forDifficulty(Difficulty difficulty) {
    List<int> parse(String s) => s.split('').map(int.parse).toList();
    return SudokuPuzzle(
      'classic-${difficulty.name}-01',
      difficulty,
      parse(_puzzles[difficulty]!),
      parse(_solution),
    );
  }
}
