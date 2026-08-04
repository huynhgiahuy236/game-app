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
    controller.select(3);
  });
  tearDown(() => controller.dispose());
  test('clues immutable, wrong value counts but is rejected', () {
    controller.select(0);
    controller.enter(9);
    expect(controller.game.values[0], 5);
    controller.select(3);
    controller.enter(9);
    expect(controller.game.values[3], 9);
    expect(controller.game.mistakes, 1);
    expect(controller.feedbackCell, 3);
  });
  test('notes toggle and undo restore action', () {
    controller.select(3);
    controller.toggleNotes();
    controller.enter(1);
    expect(controller.game.notes[3], contains(1));
    controller.undo();
    expect(controller.game.notes[3], isNull);
  });
  test('hint fills selected and is not undoable', () {
    controller.select(3);
    controller.hint();
    expect(controller.game.values[3], controller.game.solution[3]);
    expect(controller.game.hintsUsed, 1);
    expect(controller.game.history, isEmpty);
  });

  test('PuzzleBank returns unique puzzles for every supported difficulty', () {
    for (final d in Difficulty.values) {
      final puzzle = PuzzleBank.forDifficulty(d);
      expect(puzzle.difficulty, d);
      expect(puzzle.clues.length, 81);
      expect(puzzle.solution.length, 81);
    }
    final easyP = PuzzleBank.forDifficulty(Difficulty.easy);
    final hardP = PuzzleBank.forDifficulty(Difficulty.hard);
    expect(easyP.clues, isNot(equals(hardP.clues)));
  });

  test('hasProgress accurately detects player progress', () {
    expect(controller.game.hasProgress, false);
    controller.select(3);
    controller.toggleNotes();
    controller.enter(1);
    expect(controller.game.hasProgress, true);
  });

  test('encode and decode preserves game state including history', () {
    controller.select(3);
    controller.toggleNotes();
    controller.enter(1);
    final raw = controller.game.encode();
    final decoded = SudokuGame.decode(raw);
    expect(decoded, isNotNull);
    expect(decoded!.history.length, 1);
    expect(decoded.notes[3], contains(1));
    expect(decoded.difficulty, Difficulty.easy);
  });

  test('repository loads and saves last selected difficulty', () async {
    final repo = SudokuRepository();
    expect(await repo.loadLastDifficulty(), Difficulty.easy);
    await repo.saveLastDifficulty(Difficulty.hard);
    expect(await repo.loadLastDifficulty(), Difficulty.hard);
  });

  test('SudokuViewModel triggers toast messages for invalid actions', () {
    String? lastToast;
    controller.onToastMessage = (msg) => lastToast = msg;

    controller.undo();
    expect(lastToast, 'Không thể hoàn tác');

    controller.toggleNotes();
    expect(lastToast, 'Ghi chú đã bật');
  });
}
