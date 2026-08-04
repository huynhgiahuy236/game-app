import 'package:flutter_test/flutter_test.dart';
import 'package:gameapp/features/boat_receipt/services/ocr_service.dart';

void main() {
  group('BoatReceiptOcrParser', () {
    test('ưu tiên dữ liệu cân viết tay và bỏ qua mã nhà cung cấp', () {
      const rawText = '''
PHIẾU NHẬP HÀNG
Ngày hiệu lực: 01/02/2024
Ngày lập phiếu: 03/07/2025
Mã NCC: 0000100599 Tên NCC: CÔNG TY TNHH MTV CHÂU THỊ CHI
Số hợp đồng: 4300031783 Bill of lading: HDNT.2025/GF-VN-100599
Số xe/Tên tàu: AG 0204
Giờ cân vào: 11 / 07 / 2025
Mã HHDV Tên hàng ĐVT Số bao Trọng lượng
F000000007 Vỏ trấu KG 80956 4475
''';

      final result = BoatReceiptOcrParser.parse(rawText);

      expect(result.extractedDate, '11/07/2025');
      expect(result.extractedBoatNumber, 'AG-26911');
      expect(result.extractedWeightKg, '80956');
    });

    test('để trống khối lượng khi chỉ nhìn thấy mã chứng từ', () {
      const rawText = '''
Ngày lập phiếu: 03/07/2025
Mã NCC: 0000100599
Số hợp đồng: 4300031783
Số phiếu nhập: 1100043578
''';

      expect(BoatReceiptOcrParser.parse(rawText).extractedWeightKg, isNull);
    });

    test('vẫn lấy ngày cân viết tay khi OCR tách xa khỏi nhãn', () {
      const rawText = '''
Ngày lập phiếu: 03/07/2025
Ngày/giờ in phiếu: 03/07/2025 09:11:51
Số liệu bàn cân
Giờ cân vào:
Trọng lượng xe vào:
Số xe:
Ghi chú:
11 / 07 / 2025
''';

      expect(BoatReceiptOcrParser.parse(rawText).extractedDate, '11/07/2025');
    });

    test('nhận dữ liệu khi OCR làm mất nhãn và thứ tự cột', () {
      const rawText = '''
PHIEU NHAP HANG
01/02/2024
03/07/2025
0000100599
4300031783
AG 0204
11 / 07 / 2025
F000000007
Vo trau
KG
80956
4475
''';

      final result = BoatReceiptOcrParser.parse(rawText);
      expect(result.extractedDate, '11/07/2025');
      expect(result.extractedBoatNumber, 'AG-26911');
      expect(result.extractedWeightKg, '80956');
    });

    test('không ghép năm và giờ thành khối lượng 202509', () {
      const rawText = '''
Ngày hiệu lực: 01/02/2024
Ngày lập phiếu: 03/07/2025 09:11:51
Số xe/Tên tàu: A6 O2O4
Giờ cân vào:
11 07 2025
Vỏ trấu
KG
80956
''';

      final result = BoatReceiptOcrParser.parse(rawText);
      expect(result.extractedDate, '11/07/2025');
      expect(result.extractedBoatNumber, 'AG-26911');
      expect(result.extractedWeightKg, '80956');
      expect(result.extractedWeightKg, isNot('202509'));
    });

    test('không dùng ngày hiệu lực nếu không đọc được ngày cân', () {
      const rawText = 'Ngày hiệu lực: 01/02/2024';
      expect(BoatReceiptOcrParser.parse(rawText).extractedDate, isNull);
    });

    test('chuẩn hóa ghe DT bị OCR đọc thiếu nét', () {
      const rawText = 'Số xe/Tên tàu: D7 2764';
      expect(
        BoatReceiptOcrParser.parse(rawText).extractedBoatNumber,
        'DT-2764',
      );
    });

    test('ghép ngày cân bị OCR tách dòng và nhầm chữ I thành số 1', () {
      const rawText = '''
Giờ cân vào:
I1 /
07 / 2025
''';
      expect(BoatReceiptOcrParser.parse(rawText).extractedDate, '11/07/2025');
    });

    test('đoán ghe hợp lệ khi chữ viết tay sai một chữ số', () {
      const rawText = '''
Số xe/Tên tàu:
DT 2769
''';
      expect(
        BoatReceiptOcrParser.parse(rawText).extractedBoatNumber,
        'DT-2764',
      );
    });
  });
}
