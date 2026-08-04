import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  final String rawText;
  final String? extractedDate;
  final String? extractedBoatNumber;
  final String? extractedWeightKg;

  OcrResult({
    required this.rawText,
    this.extractedDate,
    this.extractedBoatNumber,
    this.extractedWeightKg,
  });
}

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<OcrResult> processImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      final String fullText = recognizedText.text;

      String? date;
      String? boatNumber;
      String? weight;

      // Extract Date regex (e.g., 11/07/2025 or 03/07/2025)
      final dateRegExp = RegExp(r'\b(0[1-9]|[12][0-9]|3[01])/(0[1-9]|1[0-2])/(20\d{2})\b');
      final dateMatch = dateRegExp.firstMatch(fullText);
      if (dateMatch != null) {
        date = dateMatch.group(0);
      }

      // Extract Boat Number regex (e.g., AG 0204 or AG-0204 or AG0204 or BT 1234)
      final boatRegExp = RegExp(r'\b([A-Z]{2}[\s\-]?[0-9]{3,5})\b', caseSensitive: false);
      final boatMatches = boatRegExp.allMatches(fullText);
      for (final match in boatMatches) {
        final str = match.group(0)?.toUpperCase();
        if (str != null && !str.contains('KG') && !str.contains('HG')) {
          boatNumber = str.replaceAll('-', ' ');
          break;
        }
      }

      // Extract Weight regex (e.g., 80956 or 80.956)
      // Standard weight on boat receipts is usually 4-6 digits (e.g. 80956 kg)
      final weightRegExp = RegExp(r'\b([1-9][0-9]{3,6})\b');
      final weightMatches = weightRegExp.allMatches(fullText);
      for (final match in weightMatches) {
        final str = match.group(0);
        // Avoid matching year like 2024 or 2025
        if (str != null && str != '2024' && str != '2025' && str != '2026') {
          weight = str;
          break;
        }
      }

      return OcrResult(
        rawText: fullText,
        extractedDate: date,
        extractedBoatNumber: boatNumber,
        extractedWeightKg: weight,
      );
    } catch (e) {
      return OcrResult(rawText: '');
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}
