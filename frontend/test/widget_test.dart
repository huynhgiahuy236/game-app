import 'package:flutter_test/flutter_test.dart';
import 'package:gameapp/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app launches to login screen when unauthenticated', (tester) async {
    SharedPreferences.setMockInitialValues({'sudoku.tutorial.v1': true});
    await tester.pumpWidget(const GameApp());
    await tester.pumpAndSettle();

    expect(find.text('ĐĂNG NHẬP CHỊ MƯỜI'), findsOneWidget);
    expect(find.text('ĐĂNG NHẬP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
