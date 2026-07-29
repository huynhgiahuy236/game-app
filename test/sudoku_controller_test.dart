import 'package:flutter_test/flutter_test.dart';
import 'package:gameapp/features/sudoku/models/sudoku_models.dart';
import 'package:gameapp/features/sudoku/services/sudoku_engine.dart';
import 'package:gameapp/features/sudoku/services/sudoku_repository.dart';
import 'package:gameapp/features/sudoku/viewmodels/sudoku_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SudokuViewModel controller;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final p = PuzzleBank.forDifficulty(Difficulty.easy);
    controller = SudokuViewModel(
      SudokuRepository(),
      SudokuGame(
        gameId: 'test',
        puzzleId: p.id,
        difficulty: p.difficulty,
        clues: p.clues,
        values: List.from(p.clues),
        solution: p.solution,
        createdAt: DateTime(2026),
      ),
    );
    controller.select(2);
  });
  tearDown(() => controller.dispose());
  test('clues immutable, wrong value counts but is rejected', () {
    controller.select(0);
    controller.enter(9);
    expect(controller.game.values[0], 5);
    controller.select(2);
    controller.enter(9);
    expect(controller.game.values[2], 0);
    expect(controller.game.mistakes, 1);
  });
  test('notes toggle and undo restore action', () {
    controller.toggleNotes();
    controller.enter(1);
    expect(controller.game.notes[2], contains(1));
    controller.undo();
    expect(controller.game.notes[2], isNull);
  });
  test('hint fills selected and is not undoable', () {
    controller.hint();
    expect(controller.game.values[2], controller.game.solution[2]);
    expect(controller.game.hintsUsed, 1);
    expect(controller.game.history, isEmpty);
  });
}
