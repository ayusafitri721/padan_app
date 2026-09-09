import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class ApiService {
  ApiService._();

  /// IP LAN untuk testing di HP fisik (milik partner, jangan dihapus).
  static const String _deviceBaseUrl = 'http://10.197.133.126:8000';

  /// Di web, backend hampir pasti satu host dengan halaman ini
  /// (mis. localhost:8080 → localhost:8000) sehingga tidak tergantung
  /// IP LAN yang bisa berubah tiap ganti WiFi. Di mobile pakai LAN IP.
  static String get baseUrl {
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.isNotEmpty) return 'http://$host:8000';
    }
    return _deviceBaseUrl;
  }

  /// Batas 15 detik untuk SEMUA request — tanpa ini request yang stall
  /// bikin UI muter selamanya. Timeout diubah jadi ApiException agar
  /// ditampilkan sebagai pesan error yang jelas.
  static Future<http.Response> _send(Future<http.Response> request) async {
    try {
      return await request.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw ApiException(
        'Server tidak merespons dalam 15 detik. Pastikan backend berjalan.',
      );
    }
  }

  static Map<String, String> get _headers {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = AuthService.currentSession.value?.token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> get(String path) async {
    final response = await _send(http.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
    ));

    final data = _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }
    throw ApiException(
      data['detail'] ?? 'Terjadi kesalahan (HTTP ${response.statusCode})',
    );
  }

  static Future<List<dynamic>> getList(String path) async {
    final response = await _send(http.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
    ));

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
    final response = await _send(http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    ));

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
    final response = await _send(http.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    ));

    final data = _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }
    throw ApiException(
      data['detail'] ?? 'Terjadi kesalahan (HTTP ${response.statusCode})',
    );
  }

  static Future<Map<String, dynamic>> delete(String path) async {
    final response = await _send(http.delete(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
    ));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _decode(response.body);
    }
    final data = _decode(response.body);
    throw ApiException(
      data['detail'] ?? 'Terjadi kesalahan (HTTP ${response.statusCode})',
    );
  }

  /// Upload satu file via multipart (mis. foto menu). [fileBytes] + [filename]
  /// dari image_picker sehingga jalan identik di web & mobile.
  static Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Uint8List fileBytes,
    required String filename,
    String field = 'photo',
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl$path'),
    )..headers.addAll(_headers);
    // MultipartRequest set content-type sendiri; jangan timpa dengan JSON.
    request.headers.remove('Content-Type');
    request.files.add(
      http.MultipartFile.fromBytes(field, fileBytes, filename: filename),
    );
    http.StreamedResponse streamed;
    try {
      streamed = await request.send().timeout(timeout);
    } on TimeoutException {
      throw ApiException(
        'Upload timeout. Periksa koneksi lalu coba lagi.',
      );
    }
    final body = await streamed.stream.bytesToString();
    final data = _decode(body);
    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      return data;
    }
    throw ApiException(
      data['detail'] ?? 'Upload gagal (HTTP ${streamed.statusCode})',
    );
  }

  static Future<Uint8List> getBytes(String path) async {    final response = await _send(http.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
    ));
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