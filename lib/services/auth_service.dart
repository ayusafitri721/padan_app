import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.warungName,
    required this.phoneOrEmail,
    required this.businessType,
  });

  final int id;
  final String warungName;
  final String phoneOrEmail;
  final String businessType;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as int,
        warungName: json['warung_name'] as String,
        phoneOrEmail: json['phone_or_email'] as String,
        businessType: json['business_type'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'warung_name': warungName,
        'phone_or_email': phoneOrEmail,
        'business_type': businessType,
      };
}

class AuthResult {
  const AuthResult({required this.token, required this.user});

  final String token;
  final AuthUser user;
}

class AuthService {
  AuthService._();

  static const _sessionKey = 'padan_session_v1';

  static final ValueNotifier<AuthResult?> currentSession = ValueNotifier(null);

  /// Dipanggil sekali saat app start (lihat main.dart) — mengembalikan
  /// sesi tersimpan bila ada sehingga user langsung masuk Beranda.
  /// Tidak pernah throw: gagal baca = dianggap belum login.
  static Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionKey);
      if (raw == null || raw.isEmpty) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final token = data['access_token'] as String?;
      final user = data['user'] as Map<String, dynamic>?;
      if (token == null || token.isEmpty || user == null) return;
      currentSession.value = AuthResult(
        token: token,
        user: AuthUser.fromJson(user),
      );
    } catch (_) {
      currentSession.value = null;
    }
  }

  static Future<void> _persist(AuthResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _sessionKey,
        jsonEncode({
          'access_token': result.token,
          'user': result.user.toJson(),
        }),
      );
    } catch (_) {
      // Penyimpanan lokal gagal — sesi memori tetap jalan.
    }
  }

  static Future<AuthResult> register({
    required String warungName,
    required String phoneOrEmail,
    required String businessType,
    required String password,
  }) async {
    final data = await ApiService.post('/api/v1/auth/register', {
      'warung_name': warungName,
      'phone_or_email': phoneOrEmail,
      'business_type': businessType,
      'password': password,
    });
    return _setSession(data);
  }

  static Future<AuthResult> login({
    required String phoneOrEmail,
    required String password,
  }) async {
    final data = await ApiService.post('/api/v1/auth/login', {
      'phone_or_email': phoneOrEmail,
      'password': password,
    });
    return _setSession(data);
  }

  static void logout() {
    currentSession.value = null;
    SharedPreferences.getInstance().then(
      (prefs) => prefs.remove(_sessionKey),
      onError: (_) {},
    );
  }

  static void updateCurrentUser({
    String? warungName,
    String? phoneOrEmail,
    String? businessType,
  }) {
    final cur = currentSession.value;
    if (cur == null) return;
    final updated = AuthResult(
      token: cur.token,
      user: AuthUser(
        id: cur.user.id,
        warungName: warungName ?? cur.user.warungName,
        phoneOrEmail: phoneOrEmail ?? cur.user.phoneOrEmail,
        businessType: businessType ?? cur.user.businessType,
      ),
    );
    currentSession.value = updated;
    // Sinkron ke storage agar tidak balik ke nama lama setelah restart.
    unawaited(_persist(updated));
  }

  static AuthResult _setSession(Map<String, dynamic> data) {
    final result = AuthResult(
      token: data['access_token'] as String,
      user: AuthUser.fromJson(data['user'] as Map<String, dynamic>),
    );
    currentSession.value = result;
    // Fire-and-forget: login tetap sukses walau penyimpanan gagal.
    unawaited(_persist(result));
    return result;
  }
}