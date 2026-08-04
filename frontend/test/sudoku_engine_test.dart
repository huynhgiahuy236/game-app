import 'package:flutter_test/flutter_test.dart';
import 'package:gameapp/features/sudoku/models/sudoku_models.dart';
import 'package:gameapp/features/sudoku/services/sudoku_engine.dart';

void main() {
  group('Sudoku engine', () {
    test('all bank puzzles are valid and uniquely solvable', () {
      for (final difficulty in Difficulty.values) {
        final puzzle = PuzzleBank.forDifficulty(difficulty);
        expect(SudokuEngine.isValidGrid(puzzle.clues), isTrue);
        expect(
          SudokuEngine.isValidGrid(puzzle.solution, allowEmpty: false),
          isTrue,
        );
        expect(
          SudokuEngine.countSolutions(puzzle.clues),
          1,
          reason: difficulty.name,
        );
      }
    });
    test('rejects row, column and box conflicts', () {
      final grid = List<int>.filled(81, 0);
      grid[0] = grid[1] = 2;
      expect(SudokuEngine.isValidGrid(grid), isFalse);
      grid[1] = 0;
      grid[9] = 2;
      expect(SudokuEngine.isValidGrid(grid), isFalse);
      grid[9] = 0;
      grid[10] = 2;
      expect(SudokuEngine.isValidGrid(grid), isFalse);
    });
    test('serializes and rejects corrupted state', () {
      final p = PuzzleBank.forDifficulty(Difficulty.easy);
      final game = SudokuGame(
        gameId: 'g',
        puzzleId: p.id,
        difficulty: p.difficulty,
        clues: p.clues,
        values: List.from(p.clues),
        solution: p.solution,
        createdAt: DateTime(2026),
      );
      game.notes[2] = {1, 4};
      final restored = SudokuGame.decode(game.encode());
      expect(restored?.notes[2], {1, 4});
      expect(SudokuGame.decode('broken'), isNull);
    });
  });
}
