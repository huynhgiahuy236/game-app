import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/env_config.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, [this.statusCode = 500]);

  @override
  String toString() => message;
}

class ApiClient {
  static final ApiClient instance = ApiClient._internal();
  ApiClient._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final http.Client _client = http.Client();

  static const String _keyAccessToken = 'jwt_access_token';
  static const String _keyRefreshToken = 'jwt_refresh_token';

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _keyAccessToken);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
  }

  Future<Map<String, String>> _getHeaders({bool isMultipart = false}) async {
    final token = await getAccessToken();
    final headers = <String, String>{};
    if (!isMultipart) {
      headers['Content-Type'] = 'application/json';
    }
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> get(String endpoint) async {
    return _sendRequest(() async {
      final headers = await _getHeaders();
      final url = Uri.parse('${EnvConfig.apiBaseUrl}$endpoint');
      return await _client.get(url, headers: headers);
    });
  }

  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    return _sendRequest(() async {
      final headers = await _getHeaders();
      final url = Uri.parse('${EnvConfig.apiBaseUrl}$endpoint');
      return await _client.post(
        url,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
    });
  }

  Future<dynamic> patch(String endpoint, {Map<String, dynamic>? body}) async {
    return _sendRequest(() async {
      final headers = await _getHeaders();
      final url = Uri.parse('${EnvConfig.apiBaseUrl}$endpoint');
      return await _client.patch(
        url,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
    });
  }

  Future<dynamic> delete(String endpoint) async {
    return _sendRequest(() async {
      final headers = await _getHeaders();
      final url = Uri.parse('${EnvConfig.apiBaseUrl}$endpoint');
      return await _client.delete(url, headers: headers);
    });
  }

  Future<dynamic> multipartPost(
    String endpoint, {
    required Map<String, String> fields,
    File? imageFile,
  }) async {
    return _sendRequest(() async {
      final url = Uri.parse('${EnvConfig.apiBaseUrl}$endpoint');
      final request = http.MultipartRequest('POST', url);

      final token = await getAccessToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields.addAll(fields);

      if (imageFile != null && await imageFile.exists()) {
        final multipartFile = await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: _imageMediaType(imageFile.path),
        );
        request.files.add(multipartFile);
      }

      final streamedResponse = await request.send();
      return await http.Response.fromStream(streamedResponse);
    });
  }

  MediaType _imageMediaType(String path) {
    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'jpe':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      case 'heic':
        return MediaType('image', 'heic');
      case 'heif':
        return MediaType('image', 'heif');
      default:
        // ImagePicker normally provides one of the formats above. JPEG is the
        // safest fallback for camera files whose temporary path has no suffix.
        return MediaType('image', 'jpeg');
    }
  }

  Future<dynamic> _sendRequest(
    Future<http.Response> Function() requestFn,
  ) async {
    try {
      var response = await requestFn();

      if (response.statusCode == 401) {
        final refreshed = await refreshTokens();
        if (refreshed) {
          response = await requestFn();
        }
      }

      return _processResponse(response);
    } on SocketException {
      throw ApiException(
        'Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng hoặc bật server.',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Đã xảy ra lỗi không xác định: $e');
    }
  }

  Future<bool> refreshTokens() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) return false;

      final url = Uri.parse('${EnvConfig.apiBaseUrl}/auth/refresh');
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final newAccessToken = data['data']['accessToken'];
          final newRefreshToken = data['data']['refreshToken'];
          await saveTokens(newAccessToken, newRefreshToken);
          return true;
        }
      }

      await clearTokens();
      return false;
    } catch (_) {
      await clearTokens();
      return false;
    }
  }

  dynamic _processResponse(http.Response response) {
    dynamic jsonBody;
    try {
      jsonBody = jsonDecode(response.body);
    } catch (_) {
      throw ApiException(
        'Dữ liệu từ máy chủ không đúng định dạng',
        response.statusCode,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonBody['data'];
    } else {
      final msg =
          jsonBody['message'] ?? 'Đã có lỗi xảy ra (${response.statusCode})';
      throw ApiException(msg, response.statusCode);
    }
  }
}
