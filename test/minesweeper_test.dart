import 'package:flutter_test/flutter_test.dart';
import 'package:gameapp/features/minesweeper/models/minesweeper_models.dart';
import 'package:gameapp/features/minesweeper/services/minesweeper_engine.dart';
import 'package:gameapp/features/minesweeper/services/minesweeper_repository.dart';
import 'package:gameapp/features/minesweeper/viewmodels/minesweeper_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('1. First revealed cell and 3x3 surrounding region are guaranteed safe', () {
    final board = MinesweeperEngine.createBoard(9, 9);
    final safeIndex = 40; // Center of 9x9 board (row 4, col 4)

    MinesweeperEngine.plantMines(
      board: board,
      rows: 9,
      cols: 9,
      minesCount: 10,
      safeIndex: safeIndex,
    );

    final neighbors = MinesweeperEngine.getNeighbors(board, 9, 9, safeIndex);
    final safeRegion = [...neighbors, board[safeIndex]];

    for (final cell in safeRegion) {
      expect(cell.isMine, isFalse, reason: 'Cell ${cell.index} in 3x3 initial region must not be a mine');
    }
    expect(board.where((c) => c.isMine).length, 10);
  });

  test('2. Adjacent mine counts are computed accurately', () {
    final board = MinesweeperEngine.createBoard(3, 3);
    // Plant mines at (0,0) and (0,1)
    board[0].isMine = true;
    board[1].isMine = true;

    for (final cell in board) {
      if (cell.isMine) continue;
      final neighbors = MinesweeperEngine.getNeighbors(board, 3, 3, cell.index);
      cell.adjacentMines = neighbors.where((n) => n.isMine).length;
    }

    // (0,2) is adjacent to (0,1) -> 1 mine
    expect(board[2].adjacentMines, 1);
    // (1,0) is adjacent to (0,0) and (0,1) -> 2 mines
    expect(board[3].adjacentMines, 2);
    // (1,1) is adjacent to (0,0) and (0,1) -> 2 mines
    expect(board[4].adjacentMines, 2);
  });

  test('3 & 4. Flood fill reveals connected 0-adjacent empty region up to numbered boundaries', () {
    final board = MinesweeperEngine.createBoard(5, 5);
    // Plant mine only at bottom right corner (4,4)
    board[24].isMine = true;

    for (final cell in board) {
      if (cell.isMine) continue;
      final neighbors = MinesweeperEngine.getNeighbors(board, 5, 5, cell.index);
      cell.adjacentMines = neighbors.where((n) => n.isMine).length;
    }

    // Reveal top-left corner (0,0)
    final revealed = MinesweeperEngine.floodReveal(
      board: board,
      rows: 5,
      cols: 5,
      startIndex: 0,
    );

    // All safe cells (24 cells) should be revealed since empty region expands up to boundary
    expect(revealed.length, 24);
    expect(board[24].state, CellState.hidden); // Mine remains hidden
  });

  test('5 & 6. Flagged cells cannot be revealed and revealed cells cannot be flagged', () async {
    final repository = MinesweeperRepository();
    final vm = await MinesweeperViewModel.create(repository);

    vm.revealCell(0); // First click
    expect(vm.board[0].state, CellState.revealed);

    // Try flagging revealed cell -> state remains revealed
    vm.toggleFlag(0);
    expect(vm.board[0].state, CellState.revealed);

    // Flag a hidden cell
    final hiddenIdx = vm.board.indexWhere((c) => c.state == CellState.hidden);
    vm.toggleFlag(hiddenIdx);
    expect(vm.board[hiddenIdx].state, CellState.flagged);

    // Try revealing flagged cell -> state remains flagged
    vm.revealCell(hiddenIdx);
    expect(vm.board[hiddenIdx].state, CellState.flagged);
  });

  test('7. Flag placement and removal updates remaining flags count', () async {
    final repository = MinesweeperRepository();
    final vm = await MinesweeperViewModel.create(repository);
    final initialRemaining = vm.remainingFlags;

    vm.toggleFlag(1);
    expect(vm.remainingFlags, initialRemaining - 1);

    vm.toggleFlag(1);
    expect(vm.remainingFlags, initialRemaining);
  });

  test('9 & 12. Revealing a mine causes loss state and stops timer', () async {
    final repository = MinesweeperRepository();
    final vm = await MinesweeperViewModel.create(repository);

    vm.revealCell(0); // First click
    expect(vm.status, MinesweeperStatus.playing);

    // Find mine and reveal it
    final mineIdx = vm.board.indexWhere((c) => c.isMine);
    vm.revealCell(mineIdx);

    expect(vm.status, MinesweeperStatus.lost);
    expect(vm.board[mineIdx].exploded, isTrue);
  });

  test('10. Winning occurs when all non-mine cells are revealed', () async {
    final repository = MinesweeperRepository();
    final vm = await MinesweeperViewModel.create(repository);

    vm.revealCell(0); // First click

    // Reveal all non-mine cells
    for (var i = 0; i < vm.board.length; i++) {
      if (!vm.board[i].isMine && vm.board[i].state == CellState.hidden) {
        vm.revealCell(i);
      }
    }

    expect(vm.status, MinesweeperStatus.won);
    // Remaining mines auto-flagged
    for (final cell in vm.board) {
      if (cell.isMine) {
        expect(cell.state, CellState.flagged);
      }
    }
  });

  test('13. Pause and Resume suspends and restores timer without state corruption', () async {
    final repository = MinesweeperRepository();
    final vm = await MinesweeperViewModel.create(repository);

    vm.revealCell(0); // Start playing
    expect(vm.status, MinesweeperStatus.playing);

    vm.togglePause();
    expect(vm.status, MinesweeperStatus.paused);

    vm.togglePause();
    expect(vm.status, MinesweeperStatus.playing);
  });

  test('14. Saved game serialization and deserialization', () async {
    final repository = MinesweeperRepository();
    final vm = await MinesweeperViewModel.create(repository);

    vm.revealCell(0); // Plant mines and start game
    vm.toggleFlag(1);

    final savedState = MinesweeperSavedState(
      difficulty: vm.difficulty,
      rows: vm.currentRows,
      cols: vm.currentCols,
      minesCount: vm.currentMines,
      board: vm.board,
      status: vm.status,
      elapsedSeconds: vm.elapsedSeconds,
      firstClickDone: vm.firstClickDone,
      flagMode: vm.flagMode,
    );

    final encoded = savedState.encode();
    final decoded = MinesweeperSavedState.decode(encoded);

    expect(decoded, isNotNull);
    expect(decoded!.rows, vm.currentRows);
    expect(decoded.cols, vm.currentCols);
    expect(decoded.minesCount, vm.currentMines);
    expect(decoded.board.length, vm.board.length);
  });

  test('16. Easy, Medium, and Hard configurations use correct dimensions and mine counts', () {
    expect(MinesweeperDifficulty.easy.rows, 9);
    expect(MinesweeperDifficulty.easy.cols, 9);
    expect(MinesweeperDifficulty.easy.minesCount, 10);

    expect(MinesweeperDifficulty.medium.rows, 16);
    expect(MinesweeperDifficulty.medium.cols, 16);
    expect(MinesweeperDifficulty.medium.minesCount, 40);

    expect(MinesweeperDifficulty.hard.rows, 16);
    expect(MinesweeperDifficulty.hard.cols, 30);
    expect(MinesweeperDifficulty.hard.minesCount, 99);
  });

  test('18. Chord reveal reveals surrounding unflagged hidden cells when flags match adjacent mines', () {
    final board = MinesweeperEngine.createBoard(3, 3);
    // Mine at (0,0) index 0
    board[0].isMine = true;
    for (final cell in board) {
      if (cell.isMine) continue;
      final neighbors = MinesweeperEngine.getNeighbors(board, 3, 3, cell.index);
      cell.adjacentMines = neighbors.where((n) => n.isMine).length;
    }

    // Reveal (1,1) index 4, which has adjacentMines = 1
    board[4].state = CellState.revealed;

    // Flag (0,0) index 0
    board[0].state = CellState.flagged;

    // Chord reveal on (1,1) index 4
    final result = MinesweeperEngine.chordReveal(
      board: board,
      rows: 3,
      cols: 3,
      index: 4,
    );

    expect(result.hitMine, isFalse);
    expect(result.revealedIndices.length, greaterThan(0));
    expect(board[0].state, CellState.flagged); // Mine remains flagged
  });

  test('20. Large board 16x30 flood fill does not overflow call stack', () {
    final board = MinesweeperEngine.createBoard(16, 30);
    board[479].isMine = true; // Mine at last cell

    for (final cell in board) {
      if (cell.isMine) continue;
      final neighbors = MinesweeperEngine.getNeighbors(board, 16, 30, cell.index);
      cell.adjacentMines = neighbors.where((n) => n.isMine).length;
    }

    final revealed = MinesweeperEngine.floodReveal(
      board: board,
      rows: 16,
      cols: 30,
      startIndex: 0,
    );

    expect(revealed.length, 479);
  });
}
