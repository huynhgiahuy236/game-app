import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameapp/features/game_2048/models/game_2048_model.dart';
import 'package:gameapp/features/game_2048/services/game_2048_repository.dart';
import 'package:gameapp/features/game_2048/viewmodels/game_2048_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('merges each pair once and adds score', () {
    final model = Game2048Model(
      board: [2, 2, 2, 2, ...List<int>.filled(12, 0)],
    );
    final viewModel = Game2048ViewModel(
      Game2048Repository(),
      model,
      random: Random(1),
    );
    expect(viewModel.move(MoveDirection.left), isTrue);
    expect(model.board.take(2), [4, 4]);
    expect(model.score, 8);
    expect(model.board.where((value) => value != 0).length, 3);
  });

  test('undo restores board, score and moves', () {
    final original = [2, 2, ...List<int>.filled(14, 0)];
    final model = Game2048Model(board: List<int>.from(original));
    final viewModel = Game2048ViewModel(
      Game2048Repository(),
      model,
      random: Random(2),
    );
    viewModel.move(MoveDirection.left);
    viewModel.undo();
    expect(model.board, original);
    expect(model.score, 0);
    expect(model.moves, 0);
  });

  test('model serialization validates board', () {
    final model = Game2048Model(board: List<int>.filled(16, 0), score: 42);
    expect(Game2048Model.decode(model.encode())?.score, 42);
    expect(Game2048Model.decode('invalid'), isNull);
  });

  test('supports dynamic board size 5x5 and 6x6', () async {
    final repository = Game2048Repository();
    final viewModel = await Game2048ViewModel.create(repository);
    expect(viewModel.game.size, 4);

    await viewModel.newGame(size: 5);
    expect(viewModel.game.size, 5);
    expect(viewModel.game.board.length, 25);

    await viewModel.newGame(size: 6);
    expect(viewModel.game.size, 6);
    expect(viewModel.game.board.length, 36);
  });
}
