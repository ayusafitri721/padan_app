import 'dart:convert';
import 'dart:typed_data';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';
import 'auth_service.dart';

class ProfileOutlet {
  const ProfileOutlet({required this.name, required this.address, required this.open, required this.close});
  final String name;
  final String address;
  final String open;
  final String close;
  factory ProfileOutlet.fromJson(Map<String, dynamic> j) => ProfileOutlet(
        name: j['outlet_name'] as String? ?? '',
        address: j['address'] as String? ?? '',
        open: j['opening_time'] as String? ?? '09:00',
        close: j['closing_time'] as String? ?? '22:00',
      );
}

class ProfileSubscription {
  const ProfileSubscription({required this.plan, required this.status, required this.expiresAt});
  final String plan;
  final String status;
  final DateTime expiresAt;
  factory ProfileSubscription.fromJson(Map<String, dynamic> j) => ProfileSubscription(
        plan: j['plan_name'] as String? ?? '',
        status: j['status'] as String? ?? '',
        expiresAt: DateTime.tryParse(j['expires_at'] as String? ?? '') ?? DateTime.now().add(const Duration(days: 365)),
      );
}

class ProfileAiPref {
  const ProfileAiPref({required this.mode, required this.maxDisc, required this.lastSync});
  final String mode; // MODERATE / AGGRESSIVE
  final int maxDisc;
  final DateTime? lastSync;
  factory ProfileAiPref.fromJson(Map<String, dynamic> j) => ProfileAiPref(
        mode: (j['weather_sensitivity_mode'] as String? ?? 'MODERATE').toUpperCase(),
        maxDisc: (j['max_critical_discount'] as num? ?? 35).toInt(),
        lastSync: j['last_offline_sync'] == null ? null : DateTime.tryParse(j['last_offline_sync'] as String),
      );
}

class ProfileStats {
  const ProfileStats({required this.days, required this.saved, required this.score});
  final int days;
  final int saved;
  final double score;
  factory ProfileStats.fromJson(Map<String, dynamic> j) => ProfileStats(
        days: (j['consistency_days'] as num? ?? 0).toInt(),
        saved: (j['saved_portions'] as num? ?? 0).toInt(),
        score: (j['kitchen_score'] as num? ?? 0).toDouble(),
      );
}

class ProfileDetails {
  const ProfileDetails({
    required this.userName,
    required this.userEmail,
    required this.businessType,
    required this.avatarUrl,
    required this.outlet,
    required this.sub,
    required this.ai,
    required this.stats,
    required this.cert,
  });
  final String userName;
  final String userEmail;
  final String businessType;
  final String? avatarUrl;
  final ProfileOutlet outlet;
  final ProfileSubscription sub;
  final ProfileAiPref ai;
  final ProfileStats stats;
  final Map<String, dynamic> cert;

  String? get avatarFullUrl {
    if (avatarUrl == null || avatarUrl!.isEmpty) return null;
    if (avatarUrl!.startsWith('http')) return avatarUrl;
    return '${ApiService.baseUrl}$avatarUrl';
  }

  factory ProfileDetails.fromJson(Map<String, dynamic> j) {
    final user = j['user'] as Map<String, dynamic>? ?? {};
    return ProfileDetails(
      userName: user['warung_name'] as String? ?? '',
      userEmail: user['phone_or_email'] as String? ?? '',
      businessType: user['business_type'] as String? ?? '',
      avatarUrl: user['avatar_url'] as String?,
      outlet: ProfileOutlet.fromJson(j['outlet'] as Map<String, dynamic>? ?? {}),
      sub: ProfileSubscription.fromJson(j['subscription'] as Map<String, dynamic>? ?? {}),
      ai: ProfileAiPref.fromJson(j['ai_preference'] as Map<String, dynamic>? ?? {}),
      stats: ProfileStats.fromJson(j['stats'] as Map<String, dynamic>? ?? {}),
      cert: j['certification'] as Map<String, dynamic>? ?? {},
    );
  }
}

class ProfileService {
  ProfileService._();
  static Future<ProfileDetails> fetchDetails() async {
    final data = await ApiService.get('/api/v1/profile/details');
    return ProfileDetails.fromJson(data);
  }

  static Future<ProfileAiPref> updateAi({required String mode, required int maxDisc}) async {
    final data = await ApiService.put('/api/v1/profile/ai-preferences', {
      'weather_sensitivity_mode': mode,
      'max_critical_discount': maxDisc,
    });
    return ProfileAiPref.fromJson(data);
  }

  static Future<DateTime> syncOffline() async {
    final data = await ApiService.post('/api/v1/profile/sync-offline', {});
    final s = data['last_offline_sync'] as String? ?? '';
    return DateTime.tryParse(s) ?? DateTime.now();
  }

  static Future<Uint8List> downloadCert() async {
    return ApiService.getBytes('/api/v1/waste/download-report');
  }

  static Future<Map<String, dynamic>> updateUser({
    String? warungName,
    String? phoneOrEmail,
    String? businessType,
  }) async {
    final body = <String, dynamic>{};
    if (warungName != null) body['warung_name'] = warungName;
    if (phoneOrEmail != null) body['phone_or_email'] = phoneOrEmail;
    if (businessType != null) body['business_type'] = businessType;
    return ApiService.put('/api/v1/profile/user', body);
  }

  static Future<Map<String, dynamic>> updateOutlet({
    String? outletName,
    String? address,
    String? openingTime,
    String? closingTime,
  }) async {
    final body = <String, dynamic>{};
    if (outletName != null) body['outlet_name'] = outletName;
    if (address != null) body['address'] = address;
    if (openingTime != null) body['opening_time'] = openingTime;
    if (closingTime != null) body['closing_time'] = closingTime;
    return ApiService.put('/api/v1/profile/outlet', body);
  }

  static Future<String> uploadAvatar(XFile file) async {
    final uri = Uri.parse('${ApiService.baseUrl}/api/v1/profile/avatar');
    final req = http.MultipartRequest('POST', uri);
    final token = AuthService.currentSession.value?.token;
    if (token != null && token.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }
    final bytes = await file.readAsBytes();
    // Tentukan content-type agar backend lolos validasi image/*
    String mime = file.mimeType ?? '';
    if (mime.isEmpty) {
      final ext = file.name.split('.').last.toLowerCase();
      if (ext == 'png') {
        mime = 'image/png';
      } else if (ext == 'webp') {
        mime = 'image/webp';
      } else {
        mime = 'image/jpeg';
      }
    }
    final mediaType = MediaType.parse(mime);
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: file.name, contentType: mediaType));
    final resp = await req.send();
    final respBody = await resp.stream.bytesToString();
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = respBody.isEmpty ? <String, dynamic>{} : jsonDecode(respBody) as Map<String, dynamic>;
      return (data['avatar_url'] as String?) ?? '';
    }
    final data = respBody.isEmpty ? <String, dynamic>{} : jsonDecode(respBody) as Map<String, dynamic>;
    throw ApiException((data['detail'] ?? 'Gagal upload avatar (${resp.statusCode})').toString());
  }
}
