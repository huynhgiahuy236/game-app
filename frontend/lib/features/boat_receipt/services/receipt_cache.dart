import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/boat_receipt_model.dart';
import '../models/statistics_model.dart';

class ReceiptHomeCache {
  const ReceiptHomeCache({
    required this.summary,
    required this.weeklySummary,
    required this.recentReceipts,
    required this.savedAt,
  });

  final HomeSummaryModel summary;
  final Map<String, dynamic> weeklySummary;
  final List<BoatReceiptModel> recentReceipts;
  final DateTime savedAt;
}

class ReceiptCache {
  static const _homeKey = 'boat_receipt.home_cache.v1';
  static const _receiptsKey = 'boat_receipt.receipts_cache.v1';

  Future<void> saveHome({
    required HomeSummaryModel summary,
    required Map<String, dynamic> weeklySummary,
    required List<BoatReceiptModel> recentReceipts,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _homeKey,
      jsonEncode({
        'summary': summary.toJson(),
        'weeklySummary': weeklySummary,
        'recentReceipts': recentReceipts.map((item) => item.toJson()).toList(),
        'savedAt': DateTime.now().toIso8601String(),
      }),
    );
  }

  Future<ReceiptHomeCache?> loadHome() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_homeKey);
      if (raw == null) return null;
      final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return ReceiptHomeCache(
        summary: HomeSummaryModel.fromJson(
          Map<String, dynamic>.from(json['summary'] as Map),
        ),
        weeklySummary: Map<String, dynamic>.from(json['weeklySummary'] as Map),
        recentReceipts: (json['recentReceipts'] as List? ?? const [])
            .map(
              (item) => BoatReceiptModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
        savedAt: DateTime.tryParse('${json['savedAt']}') ?? DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveReceipts(List<BoatReceiptModel> receipts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _receiptsKey,
      jsonEncode({
        'items': receipts.map((item) => item.toJson()).toList(),
        'savedAt': DateTime.now().toIso8601String(),
      }),
    );
  }

  Future<(List<BoatReceiptModel>, DateTime)?> loadReceipts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_receiptsKey);
      if (raw == null) return null;
      final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final items = (json['items'] as List? ?? const [])
          .map(
            (item) => BoatReceiptModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
      return (items, DateTime.tryParse('${json['savedAt']}') ?? DateTime.now());
    } catch (_) {
      return null;
    }
  }
}
