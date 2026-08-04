import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameapp/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app launches to login screen when unauthenticated', (tester) async {
    SharedPreferences.setMockInitialValues({'sudoku.tutorial.v1': true});
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const GameApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('CHỊ MƯỜI APP'), findsOneWidget);
    expect(find.text('ĐĂNG NHẬP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
