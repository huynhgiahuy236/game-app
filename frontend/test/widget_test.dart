import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameapp/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app launches directly to main home screen', (tester) async {
    SharedPreferences.setMockInitialValues({'sudoku.tutorial.v1': true});
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const GameApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Sổ ghe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
