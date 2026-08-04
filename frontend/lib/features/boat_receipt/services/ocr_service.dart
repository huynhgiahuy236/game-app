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
      final List<String> lines = fullText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

      String? date;
      String? boatNumber;
      String? weight;

      // 1. DATE EXTRACTION
      // Search for date near "cân vào" or "giờ cân" first (handwritten date)
      final dateRegExp = RegExp(r'\b(0?[1-9]|[12][0-9]|3[01])\s*[\/\.-]\s*(0?[1-9]|1[0-2])\s*[\/\.-]\s*(20\d{2})\b');
      
      for (final line in lines) {
        final lower = line.toLowerCase();
        if (lower.contains('cân') || lower.contains('giờ')) {
          final m = dateRegExp.firstMatch(line);
          if (m != null) {
            final d = m.group(1)!.padLeft(2, '0');
            final month = m.group(2)!.padLeft(2, '0');
            final y = m.group(3);
            date = '$d/$month/$y';
            break;
          }
        }
      }

      // Fallback: any date match in fullText
      if (date == null) {
        final allDateMatches = dateRegExp.allMatches(fullText).toList();
        if (allDateMatches.isNotEmpty) {
          // If multiple dates found, pick the second one if available (often handwritten entry), else first
          final match = allDateMatches.length > 1 ? allDateMatches[1] : allDateMatches[0];
          final d = match.group(1)!.padLeft(2, '0');
          final month = match.group(2)!.padLeft(2, '0');
          final y = match.group(3);
          date = '$d/$month/$y';
        }
      }

      // 2. BOAT NUMBER EXTRACTION
      // Look for boat number near "số xe", "tên tàu", "ghe", or standard province prefixes (AG, BT, KG, ST, etc.)
      final boatRegExp = RegExp(r'\b(AG|BT|KG|ST|DT|CT|BL|CM|TG|LA|TV|VL|BD|TN|1G|16|IG)[\s\.-]?([0-9]{3,5})\b', caseSensitive: false);
      for (final line in lines) {
        final match = boatRegExp.firstMatch(line);
        if (match != null) {
          var prefix = match.group(1)!.toUpperCase();
          if (prefix == '1G' || prefix == '16' || prefix == 'IG') prefix = 'AG';
          final numStr = match.group(2);
          boatNumber = '$prefix $numStr';
          break;
        }
      }

      // Fallback boat match across fullText
      if (boatNumber == null) {
        final fallbackBoatRegExp = RegExp(r'\b([A-Z0-9]{2}[\s\-]?[0-9]{3,5})\b', caseSensitive: false);
        for (final match in fallbackBoatRegExp.allMatches(fullText)) {
          final str = match.group(0)?.toUpperCase();
          if (str != null &&
              !str.contains('KG') &&
              !str.contains('HG') &&
              !str.startsWith('HD') &&
              !str.startsWith('BM') &&
              !str.startsWith('WH') &&
              !str.startsWith('GF')) {
            boatNumber = str.replaceAll('-', ' ');
            if (boatNumber.startsWith('1G') || boatNumber.startsWith('16')) {
              boatNumber = boatNumber.replaceFirst(RegExp(r'^(1G|16)'), 'AG');
            }
            break;
          }
        }
      }

      // 3. WEIGHT EXTRACTION (in Kg)
      // First priority: look for 4-6 digit number near "KG", "vỏ trấu", "lúa", "số bao", "tịnh"
      final digitsRegExp = RegExp(r'\b([1-9][0-9]{3,5})\b');

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final lower = line.toLowerCase();

        // Skip document headers / supplier code lines
        if (lower.contains('ncc') ||
            lower.contains('mã') ||
            lower.contains('hợp đồng') ||
            lower.contains('bill') ||
            lower.contains('lading') ||
            lower.contains('100599') ||
            lower.contains('11000') ||
            lower.contains('43000')) {
          continue;
        }

        if (lower.contains('kg') || lower.contains('trấu') || lower.contains('lúa') || lower.contains('tịnh') || lower.contains('bao')) {
          final match = digitsRegExp.firstMatch(line);
          if (match != null) {
            final val = match.group(1);
            if (val != null && val != '2024' && val != '2025' && val != '2026' && !val.startsWith('1005') && !val.startsWith('0000')) {
              weight = val;
              break;
            }
          }
          // Check next line if table cell wrapped
          if (i + 1 < lines.length) {
            final nextMatch = digitsRegExp.firstMatch(lines[i + 1]);
            if (nextMatch != null) {
              final val = nextMatch.group(1);
              if (val != null && val != '2024' && val != '2025' && val != '2026' && !val.startsWith('1005') && !val.startsWith('0000')) {
                weight = val;
                break;
              }
            }
          }
        }
      }

      // Fallback weight match: search all matches excluding known code prefixes
      if (weight == null) {
        for (final match in digitsRegExp.allMatches(fullText)) {
          final str = match.group(1);
          if (str != null &&
              str != '2024' &&
              str != '2025' &&
              str != '2026' &&
              str != '2027' &&
              !str.startsWith('1005') &&
              !str.startsWith('1100') &&
              !str.startsWith('4300') &&
              !str.startsWith('0000')) {
            weight = str;
            break;
          }
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
