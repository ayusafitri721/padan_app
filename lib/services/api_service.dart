import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class ApiService {
  ApiService._();

  static const String baseUrl = 'http://127.0.0.1:8000';

  static Map<String, String> get _headers {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = AuthService.currentSession.value?.token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> get(String path) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
    );

    final data = _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }
    throw ApiException(
      data['detail'] ?? 'Terjadi kesalahan (HTTP ${response.statusCode})',
    );
  }

  static Future<List<dynamic>> getList(String path) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
    );

    final body = response.body.isEmpty ? '[]' : response.body;
    final data = jsonDecode(body);
    final statusOk = response.statusCode >= 200 && response.statusCode < 300;
    if (statusOk && data is List) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail != null) {
        throw ApiException(detail.toString());
      }
    }
    throw ApiException('Terjadi kesalahan (HTTP ${response.statusCode})');
  }

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );

    final data = _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }
    throw ApiException(
      data['detail'] ?? 'Terjadi kesalahan (HTTP ${response.statusCode})',
    );
  }

  static Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );

    final data = _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }
    throw ApiException(
      data['detail'] ?? 'Terjadi kesalahan (HTTP ${response.statusCode})',
    );
  }

  static Future<void> delete(String path) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    final data = _decode(response.body);
    throw ApiException(
      data['detail'] ?? 'Terjadi kesalahan (HTTP ${response.statusCode})',
    );
  }

  static Future<Uint8List> getBytes(String path) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    final data = _decode(response.body.isEmpty ? '{}' : response.body);
    throw ApiException(
      data['detail'] ?? 'Terjadi kesalahan (HTTP ${response.statusCode})',
    );
  }

  static Map<String, dynamic> _decode(String body) {
    if (body.isEmpty) return {};
    final decoded = jsonDecode(body);
    if (decoded == null) return {};
    return decoded as Map<String, dynamic>;
  }
}

class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}