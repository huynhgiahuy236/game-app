import 'package:flutter_test/flutter_test.dart';
import 'package:gameapp/core/utils/formatters.dart';
import 'package:gameapp/features/boat_receipt/models/boat_receipt_model.dart';

void main() {
  group('Sổ Ghe Utility & Model Tests', () {
    test('Kilogram to Ton conversion formatting (80956 kg -> 80,956 tấn)', () {
      expect(AppFormatters.formatKgToTons(80956), '80,956 tấn');
      expect(AppFormatters.formatKgToTons(1000), '1 tấn');
      expect(AppFormatters.formatKgToTons(500), '0,5 tấn');
      expect(AppFormatters.formatKg(80956), '80.956 kg');
    });

    test('BoatReceiptModel JSON parsing', () {
      final json = {
        '_id': '64f8a1234567890123456789',
        'clientId': 'test-client-id-uuid',
        'receiptDate': '2025-07-11T00:00:00.000Z',
        'boatNumber': 'AG 0204',
        'weightKg': 80956,
        'note': 'Lúa tươi ST25',
        'input': {'method': 'camera', 'hasImage': true},
        'verification': {'wasEdited': true, 'editedFields': ['boatNumber']},
        'createdAt': '2025-07-11T08:00:00.000Z',
      };

      final model = BoatReceiptModel.fromJson(json);

      expect(model.id, '64f8a1234567890123456789');
      expect(model.boatNumber, 'AG 0204');
      expect(model.weightKg, 80956);
      expect(model.weightTons, 80.956);
      expect(model.inputMethod, 'camera');
      expect(model.wasEdited, true);
    });
  });
}
