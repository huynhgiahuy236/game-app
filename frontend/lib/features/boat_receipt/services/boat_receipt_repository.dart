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

    final endpoint = '/receipts?${queryParams.join('&')}';
    final resData = await _apiClient.get(endpoint);

    final List list = resData as List;
    return list.map((item) => BoatReceiptModel.fromJson(item)).toList();
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
  }) async {
    final body = <String, dynamic>{};
    if (receiptDate != null) body['receiptDate'] = receiptDate;
    if (boatNumber != null) body['boatNumber'] = boatNumber;
    if (weightKg != null) body['weightKg'] = weightKg;
    if (pricePerKg != null) body['pricePerKg'] = pricePerKg;
    if (note != null) body['note'] = note;

    final resData = await _apiClient.patch('/receipts/$id', body: body);
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

  Future<Map<String, dynamic>> getMonthlyStats(String? month) async {
    final query = month != null ? '?month=$month' : '';
    return await _apiClient.get('/receipts/statistics/monthly$query');
  }

  Future<Map<String, dynamic>> getYearlyStats(String? year) async {
    final query = year != null ? '?year=$year' : '';
    return await _apiClient.get('/receipts/statistics/yearly$query');
  }

  Future<List<dynamic>> getByBoatStats(String? boatNumber) async {
    final query = boatNumber != null ? '?boatNumber=${Uri.encodeComponent(boatNumber)}' : '';
    return await _apiClient.get('/receipts/statistics/by-boat$query');
  }
}
