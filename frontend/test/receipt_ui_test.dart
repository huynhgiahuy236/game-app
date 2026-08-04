import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameapp/features/boat_receipt/views/add_boat_receipt_screen.dart';

void main() {
  testWidgets('màn thêm phiếu không tràn ở 360px và chữ 130%', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi', 'VN'),
        supportedLocales: const [Locale('vi', 'VN')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: const AddBoatReceiptScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chụp bằng camera'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Chọn ảnh có sẵn'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Chọn ảnh có sẵn'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Nhập thủ công'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Nhập thủ công'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
