import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameapp/features/boat_receipt/services/ocr_service.dart';
import 'package:gameapp/features/boat_receipt/views/receipt_confirmation_screen.dart';

void main() {
  testWidgets('hiển thị dữ liệu OCR rõ ràng trên màn hình nhỏ với chữ lớn', (
    tester,
  ) async {
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
        home: const ReceiptConfirmationScreen(
          ocrResult: OcrResult(
            rawText: 'sample',
            extractedDate: '11/07/2025',
            extractedBoatNumber: 'AG-26911',
            extractedWeightKg: '80956',
          ),
          inputMethod: 'camera',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ngày cân vào'), findsOneWidget);
    expect(find.text('Thứ Sáu, 11/07/2025'), findsOneWidget);
    expect(find.text('AG-26911'), findsWidgets);
    expect(find.text('80956'), findsOneWidget);
    expect(find.text('Xác nhận và lưu'), findsOneWidget);
    await tester.tap(find.text('Xác nhận và lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Xác nhận thông tin phiếu'), findsOneWidget);
    expect(find.text('Sửa lại'), findsOneWidget);
    await tester.tap(find.text('Sửa lại'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Thứ Sáu, 11/07/2025').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thứ Sáu, 11/07/2025').first);
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
