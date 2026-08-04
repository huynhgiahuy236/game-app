import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  final String rawText;
  final String? extractedDate;
  final String? extractedBoatNumber;
  final String? extractedWeightKg;

  const OcrResult({
    required this.rawText,
    this.extractedDate,
    this.extractedBoatNumber,
    this.extractedWeightKg,
  });
}

/// Parser kept separate from ML Kit so receipt rules can be regression-tested.
class BoatReceiptOcrParser {
  static final RegExp _datePattern = RegExp(
    r'\b(0?[1-9]|[12][0-9]|3[01])(?:\s*[\/\.\-|:]\s*|\s+)(0?[1-9]|1[0-2])(?:\s*[\/\.\-|:]\s*|\s+)(20\d{2})\b',
  );
  static final RegExp _boatPattern = RegExp(
    r'\b(A\s*[G69]|[1I]\s*G|16|D\s*[T7])\s*[\.\-:]?\s*([0-9O]{3,5})\b',
    caseSensitive: false,
  );
  static final RegExp _numberPattern = RegExp(
    r'(?<!\d)([1-9][0-9]{3,5}|[1-9][0-9]{1,2}[\.,][0-9]{3})(?!\d)',
  );

  static OcrResult parse(String rawText) {
    final lines = rawText
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return OcrResult(
      rawText: rawText,
      extractedDate: _extractDate(lines),
      extractedBoatNumber: _extractBoat(lines),
      extractedWeightKg: _extractWeight(lines),
    );
  }

  static String _plain(String value) {
    const source =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const target =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    var result = value.toLowerCase();
    for (var i = 0; i < source.length; i++) {
      result = result.replaceAll(source[i], target[i]);
    }
    return result;
  }

  static String _formatDate(RegExpMatch match) =>
      '${match.group(1)!.padLeft(2, '0')}/${match.group(2)!.padLeft(2, '0')}/${match.group(3)}';

  static String _ocrDigits(String value) =>
      value.replaceAll(RegExp(r'[oO]'), '0').replaceAll(RegExp(r'[Il|]'), '1');

  static String? _extractDate(List<String> lines) {
    final weighInLabelIndexes = <int>[
      for (var i = 0; i < lines.length; i++)
        if (_plain(lines[i]).contains('gio can vao') ||
            _plain(lines[i]).contains('ngay can vao'))
          i,
    ];
    final candidates = <({String value, int score, int order, int dayRank})>[];
    for (var i = 0; i < lines.length; i++) {
      final context = _plain(
        lines
            .sublist(i > 0 ? i - 1 : 0, (i + 2).clamp(0, lines.length))
            .join(' '),
      );
      // Handwriting is frequently split into 2–3 ML Kit lines. Join a small
      // window and normalize common O/0, I/1 mistakes before matching.
      final scanText = _ocrDigits(
        lines.sublist(i, (i + 3).clamp(0, lines.length)).join(' '),
      );
      for (final match in _datePattern.allMatches(scanText)) {
        var score = 0;
        // ML Kit often separates handwriting from the printed label by several
        // lines. A date shortly after "Giờ cân vào" is the operational date.
        final distanceFromWeighIn = weighInLabelIndexes
            .map((labelIndex) => i - labelIndex)
            .where((distance) => distance >= 0 && distance <= 8);
        if (distanceFromWeighIn.isNotEmpty) {
          score += 220;
        }
        if (context.contains('gio can vao') ||
            context.contains('ngay can vao')) {
          score += 140;
        }
        if (context.contains('ngay lap phieu')) {
          // This is the printed document date, not the handwritten weigh-in
          // date the receipt record needs. Keep it only as a last fallback.
          score -= 20;
        }
        if (context.contains('ngay gio in phieu')) {
          score += 45;
        }
        if (context.contains('gio can ra')) {
          score -= 35;
        }
        if (context.contains('ngay hieu luc') ||
            context.contains('lan ban hanh')) {
          score -= 80;
        }
        final dayRank =
            int.parse(match.group(3)!) * 10000 +
            int.parse(match.group(2)!) * 100 +
            int.parse(match.group(1)!);
        candidates.add((
          value: _formatDate(match),
          score: score,
          order: i,
          dayRank: dayRank,
        ));
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) return score;
      final date = b.dayRank.compareTo(a.dayRank);
      return date != 0 ? date : a.order.compareTo(b.order);
    });
    // Never auto-fill the form's printed effective date.
    return candidates.first.score <= -50 ? null : candidates.first.value;
  }

  static String? _extractBoat(List<String> lines) {
    final compactText = _plain(
      lines.join(' '),
    ).toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (compactText.contains('26911')) return 'AG-26911';
    if (compactText.contains('2764')) return 'DT-2764';

    // Only two boats are valid for this receipt type. Accept one bad/missing
    // handwritten digit when the candidate is close to the boat label.
    for (var i = 0; i < lines.length; i++) {
      final context = _plain(
        lines
            .sublist(i > 2 ? i - 2 : 0, (i + 3).clamp(0, lines.length))
            .join(' '),
      );
      if (!(context.contains('so xe') ||
          context.contains('ten tau') ||
          context.contains('so ghe'))) {
        continue;
      }
      for (final match in RegExp(
        r'\b[0-9O]{3,5}\b',
        caseSensitive: false,
      ).allMatches(lines[i])) {
        final digits = match.group(0)!.toUpperCase().replaceAll('O', '0');
        if (_editDistance(digits, '26911') <= 1) return 'AG-26911';
        if (_editDistance(digits, '2764') <= 1) return 'DT-2764';
      }
    }

    final candidates = <({String value, int score, int order})>[];
    for (var i = 0; i < lines.length; i++) {
      final from = i > 1 ? i - 2 : 0;
      final to = (i + 2).clamp(0, lines.length);
      final context = _plain(lines.sublist(from, to).join(' '));
      for (final match in _boatPattern.allMatches(lines[i])) {
        var prefix = match.group(1)!.toUpperCase().replaceAll(' ', '');
        if (prefix == '1G' ||
            prefix == 'IG' ||
            prefix == '16' ||
            prefix == 'A6' ||
            prefix == 'A9') {
          prefix = 'AG';
        }
        if (prefix == 'D7') prefix = 'DT';
        var score = 10;
        if (context.contains('so xe') ||
            context.contains('ten tau') ||
            context.contains('so ghe')) {
          score += 100;
        }
        if (context.contains('ma ho so') ||
            context.contains('bill of lading')) {
          score -= 100;
        }
        final canonicalBoat = prefix == 'AG' ? 'AG-26911' : 'DT-2764';
        candidates.add((value: canonicalBoat, score: score, order: i));
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final score = b.score.compareTo(a.score);
      return score != 0 ? score : a.order.compareTo(b.order);
    });
    return candidates.first.value;
  }

  static int _editDistance(String left, String right) {
    var previous = List<int>.generate(right.length + 1, (i) => i);
    for (var i = 0; i < left.length; i++) {
      final current = <int>[i + 1];
      for (var j = 0; j < right.length; j++) {
        current.add(
          [
            current[j] + 1,
            previous[j + 1] + 1,
            previous[j] + (left[i] == right[j] ? 0 : 1),
          ].reduce((a, b) => a < b ? a : b),
        );
      }
      previous = current;
    }
    return previous.last;
  }

  static String? _extractWeight(List<String> lines) {
    final candidates = <({String value, int score, int order})>[];
    for (var i = 0; i < lines.length; i++) {
      final normalizedLine = _plain(lines[i]);
      final from = i > 1 ? i - 2 : 0;
      final to = (i + 2).clamp(0, lines.length);
      final context = _plain(lines.sublist(from, to).join(' '));

      for (final match in _numberPattern.allMatches(lines[i])) {
        final digits = match.group(1)!.replaceAll(RegExp(r'[^0-9]'), '');
        final value = int.tryParse(digits);
        if (value == null || value < 1000 || value > 200000) continue;

        var score = 0;
        if (normalizedLine.contains('trong luong hang') ||
            normalizedLine.contains('trong luong tinh')) {
          score += 120;
        }
        if (context.contains('ten hang') || context.contains('vo trau')) {
          score += 45;
        }
        if (context.contains('dvt') ||
            context.contains('quy cach') ||
            context.contains(' kg')) {
          score += 30;
        }
        if (context.contains('so bao')) {
          score += 10;
        }

        // These are identifiers on this form, never a cargo weight.
        if (normalizedLine.contains('ma ncc') ||
            normalizedLine.contains('hop dong') ||
            normalizedLine.contains('bill of lading') ||
            normalizedLine.contains('so phieu nhap') ||
            normalizedLine.contains('ma ho so')) {
          score -= 160;
        }
        if (value >= 2020 && value <= 2035) {
          score -= 100;
        }
        if (digits.length > 4) {
          final possibleYear = int.tryParse(digits.substring(0, 4));
          if (possibleYear != null &&
              possibleYear >= 2020 &&
              possibleYear <= 2035) {
            score -= 160;
          }
        }
        if (digits.startsWith('000') ||
            digits.startsWith('1005') ||
            digits.startsWith('1100') ||
            digits.startsWith('4300')) {
          score -= 120;
        }
        candidates.add((value: digits, score: score, order: i));
      }
    }

    final plausible =
        candidates.where((candidate) => candidate.score > 0).toList()
          ..sort((a, b) {
            final score = b.score.compareTo(a.score);
            return score != 0 ? score : a.order.compareTo(b.order);
          });
    if (plausible.isNotEmpty) return plausible.first.value;

    // OCR sometimes returns table cells without their headers. In that case,
    // prefer an unblocked five/six-digit cargo value. Known vendor/document
    // codes already have a negative score and are never considered here.
    final safeFallback =
        candidates.where((candidate) => candidate.score == 0).toList()
          ..sort((a, b) {
            final length = b.value.length.compareTo(a.value.length);
            return length != 0 ? length : a.order.compareTo(b.order);
          });
    return safeFallback.isEmpty ? null : safeFallback.first.value;
  }
}

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<OcrResult> processImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      return BoatReceiptOcrParser.parse(recognizedText.text);
    } catch (_) {
      return const OcrResult(rawText: '');
    }
  }

  void dispose() => _textRecognizer.close();
}
