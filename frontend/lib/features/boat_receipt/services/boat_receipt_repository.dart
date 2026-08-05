import 'dart:io';
import 'package:uuid/uuid.dart';
import '../../../core/network/api_client.dart';
import '../models/boat_receipt_model.dart';
import '../models/statistics_model.dart';

class BoatReceiptRepository {
  final ApiClient _apiClient = ApiClient.instance;
  final Uuid _uuid = const Uuid();

  String generateClientId() {
    return _uuid.v4();
  }

  Future<BoatReceiptModel> createReceipt({
    required String clientId,
    required String receiptDate,
    required String boatNumber,
    required int weightKg,
    int pricePerKg = 0,
    String? note,
    File? imageFile,
    String? inputMethod,
    String? ocrRawText,
    String? ocrDate,
    String? ocrBoat,
    String? ocrWeight,
    bool wasEdited = false,
    List<String>? editedFields,
  }) async {
    final fields = <String, String>{
      'clientId': clientId,
      'receiptDate': receiptDate,
      'boatNumber': boatNumber,
      'weightKg': weightKg.toString(),
      'pricePerKg': pricePerKg.toString(),
      'note': note ?? '',
      'inputMethod': inputMethod ?? (imageFile != null ? 'camera' : 'manual'),
      'ocrRawText': ocrRawText ?? '',
      'ocrExtractedDate': ocrDate ?? '',
      'ocrExtractedBoatNumber': ocrBoat ?? '',
      'ocrExtractedWeight': ocrWeight ?? '',
      'wasEdited': wasEdited.toString(),
    };

    final resData = await _apiClient.multipartPost(
      '/receipts',
      fields: fields,
      imageFile: imageFile,
    );

    return BoatReceiptModel.fromJson(resData);
  }

  Future<List<BoatReceiptModel>> getReceipts({
    String? date,
    String? month,
    String? year,
    String? boatNumber,
    String? from,
    String? to,
    int page = 1,
    int limit = 20,
    String? sortBy,
  }) async {
    final queryParams = <String>[];
    if (date != null && date.isNotEmpty) queryParams.add('date=$date');
    if (month != null && month.isNotEmpty) queryParams.add('month=$month');
    if (year != null && year.isNotEmpty) queryParams.add('year=$year');
    if (boatNumber != null && boatNumber.isNotEmpty) {
      queryParams.add('boatNumber=${Uri.encodeComponent(boatNumber)}');
    }
    if (from != null && from.isNotEmpty) queryParams.add('from=$from');
    if (to != null && to.isNotEmpty) queryParams.add('to=$to');
    queryParams.add('page=$page');
    queryParams.add('limit=$limit');
    if (sortBy != null) queryParams.add('sortBy=$sortBy');

    final endpoint = '/receipts?${queryParams.join('&')}';
    final resData = await _apiClient.get(endpoint);

    final List list = resData as List;
    return list.map((item) => BoatReceiptModel.fromJson(item)).toList();
  }

  Future<List<BoatReceiptModel>> getAllReceipts({
    String? date,
    String? month,
    String? year,
    String? boatNumber,
    String? from,
    String? to,
  }) async {
    const pageSize = 100;
    final all = <BoatReceiptModel>[];
    var page = 1;
    while (true) {
      final batch = await getReceipts(
        date: date,
        month: month,
        year: year,
        boatNumber: boatNumber,
        from: from,
        to: to,
        page: page,
        limit: pageSize,
      );
      all.addAll(batch);
      if (batch.length < pageSize) break;
      page++;
    }
    return all;
  }

  Future<BoatReceiptModel> getReceiptById(String id) async {
    final resData = await _apiClient.get('/receipts/$id');
    return BoatReceiptModel.fromJson(resData);
  }

  Future<BoatReceiptModel> updateReceipt(
    String id, {
    String? receiptDate,
    String? boatNumber,
    int? weightKg,
    int? pricePerKg,
    String? note,
    File? imageFile,
  }) async {
    final fields = <String, String>{};
    if (receiptDate != null) fields['receiptDate'] = receiptDate;
    if (boatNumber != null) fields['boatNumber'] = boatNumber;
    if (weightKg != null) fields['weightKg'] = weightKg.toString();
    if (pricePerKg != null) fields['pricePerKg'] = pricePerKg.toString();
    if (note != null) fields['note'] = note;

    if (imageFile != null) {
      final resData = await _apiClient.multipartPost(
        '/receipts/$id',
        fields: fields,
        imageFile: imageFile,
      );
      return BoatReceiptModel.fromJson(resData);
    }

    final resData = await _apiClient.patch('/receipts/$id', body: fields);
    return BoatReceiptModel.fromJson(resData);
  }

  Future<void> deleteReceipt(String id) async {
    await _apiClient.delete('/receipts/$id');
  }

  // Statistics
  Future<HomeSummaryModel> getHomeSummary() async {
    final resData = await _apiClient.get('/receipts/statistics/summary');
    return HomeSummaryModel.fromJson(resData);
  }

  Future<Map<String, dynamic>> getDailyStats(String? date) async {
    final query = date != null ? '?date=$date' : '';
    return await _apiClient.get('/receipts/statistics/daily$query');
  }

  Future<Map<String, dynamic>> getWeeklyStats(String? date) async {
    final query = date != null ? '?date=$date' : '';
    try {
      return await _apiClient.get('/receipts/statistics/weekly$query');
    } on ApiException catch (error) {
      // Máy chủ cũ chưa có API tuần. Ghép 7 kết quả ngày để ứng dụng vẫn
      // hoạt động trong thời gian backend đang được cập nhật.
      if (error.statusCode != 404) rethrow;
      return _buildWeekFromDaily(date);
    }
  }

  Future<Map<String, dynamic>> _buildWeekFromDaily(String? date) async {
    final anchor = DateTime.tryParse(date ?? '') ?? DateTime.now();
    final monday = DateTime(
      anchor.year,
      anchor.month,
      anchor.day - anchor.weekday + 1,
    );
    final days = await Future.wait(
      List.generate(7, (index) {
        final day = monday.add(Duration(days: index));
        final value =
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        return getDailyStats(value);
      }),
    );

    var trips = 0;
    var totalKg = 0;
    var totalAmount = 0;
    final boats = <String, Map<String, dynamic>>{};
    final dailyTotals = <Map<String, dynamic>>[];

    for (var index = 0; index < days.length; index++) {
      final day = days[index];
      final dayTrips = (day['trips'] as num?)?.toInt() ?? 0;
      final dayKg = (day['totalKg'] as num?)?.toInt() ?? 0;
      final dayAmount = (day['totalAmount'] as num?)?.toInt() ?? 0;
      trips += dayTrips;
      totalKg += dayKg;
      totalAmount += dayAmount;
      final dateValue = monday.add(Duration(days: index));
      dailyTotals.add({
        'date':
            '${dateValue.year}-${dateValue.month.toString().padLeft(2, '0')}-${dateValue.day.toString().padLeft(2, '0')}',
        'trips': dayTrips,
        'totalKg': dayKg,
        'totalAmount': dayAmount,
      });
      for (final rawBoat in (day['byBoat'] as List? ?? const [])) {
        final boat = Map<String, dynamic>.from(rawBoat as Map);
        final number = '${boat['boatNumber'] ?? 'Không rõ'}';
        final aggregate = boats.putIfAbsent(
          number,
          () => {
            'boatNumber': number,
            'trips': 0,
            'totalKg': 0,
            'totalAmount': 0,
          },
        );
        aggregate['trips'] =
            (aggregate['trips'] as int) +
            ((boat['trips'] as num?)?.toInt() ?? 0);
        aggregate['totalKg'] =
            (aggregate['totalKg'] as int) +
            ((boat['totalKg'] as num?)?.toInt() ?? 0);
        aggregate['totalAmount'] =
            (aggregate['totalAmount'] as int) +
            ((boat['totalAmount'] as num?)?.toInt() ?? 0);
      }
    }
    final byBoat = boats.values.toList()
      ..sort((a, b) => (b['totalKg'] as int).compareTo(a['totalKg'] as int));
    return {
      'trips': trips,
      'totalKg': totalKg,
      'totalAmount': totalAmount,
      'avgPricePerKg': totalKg > 0 ? (totalAmount / totalKg).round() : 0,
      'avgKgPerTrip': trips > 0 ? (totalKg / trips).round() : 0,
      'dailyTotals': dailyTotals,
      'byBoat': byBoat,
    };
  }

  Future<Map<String, dynamic>> getMonthlyStats(String? month) async {
    final query = month != null ? '?month=$month' : '';
    return await _apiClient.get('/receipts/statistics/monthly$query');
  }

  Future<Map<String, dynamic>> getYearlyStats(String? year) async {
    final query = year != null ? '?year=$year' : '';
    return await _apiClient.get('/receipts/statistics/yearly$query');
  }

  Future<List<dynamic>> getByBoatStats(String? boatNumber) async {
    final query = boatNumber != null
        ? '?boatNumber=${Uri.encodeComponent(boatNumber)}'
        : '';
    return await _apiClient.get('/receipts/statistics/by-boat$query');
  }
}
