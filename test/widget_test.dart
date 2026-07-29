import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameapp/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('hub renders game entry', (tester) async {
    SharedPreferences.setMockInitialValues({'sudoku.tutorial.v1': true});
    await tester.pumpWidget(const GameApp());
    await tester.pumpAndSettle();
    expect(find.text('Sudoku'), findsOneWidget);
    expect(find.text('2048'), findsOneWidget);
    expect(find.text('Trò chơi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('2048 opens without overflow on a small phone', (tester) async {
    SharedPreferences.setMockInitialValues({'sudoku.tutorial.v1': true});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const GameApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('2048'));
    await tester.pumpAndSettle();
    expect(find.text('Ghép số. Giữ nhịp. Tiến xa.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
