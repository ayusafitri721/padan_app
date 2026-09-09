import 'dart:async';

import 'package:flutter/foundation.dart';

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
}

class AuthResult {
  const AuthResult({required this.token, required this.user});

  final String token;
  final AuthUser user;
}

class AuthService {
  AuthService._();

  static final ValueNotifier<AuthResult?> currentSession = ValueNotifier(null);

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
  }

  static void updateCurrentUser({
    String? warungName,
    String? phoneOrEmail,
    String? businessType,
  }) {
    final cur = currentSession.value;
    if (cur == null) return;
    currentSession.value = AuthResult(
      token: cur.token,
      user: AuthUser(
        id: cur.user.id,
        warungName: warungName ?? cur.user.warungName,
        phoneOrEmail: phoneOrEmail ?? cur.user.phoneOrEmail,
        businessType: businessType ?? cur.user.businessType,
      ),
    );
  }

  static AuthResult _setSession(Map<String, dynamic> data) {
    final result = AuthResult(
      token: data['access_token'] as String,
      user: AuthUser.fromJson(data['user'] as Map<String, dynamic>),
    );
    currentSession.value = result;
    return result;
  }
}