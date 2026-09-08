import 'package:flutter/material.dart';

import 'api_service.dart';

class WeatherData {
  const WeatherData({
    required this.lokasi,
    required this.provinsi,
    required this.condition,
    required this.temperature,
    required this.humidity,
    required this.windMs,
    required this.updatedAt,
    required this.insight,
  });

  final String lokasi;
  final String provinsi;
  final String condition;
  final int temperature;
  final int humidity;
  final double windMs;
  final String updatedAt;
  final String insight;

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      lokasi: (json['lokasi'] ?? '') as String,
      provinsi: (json['provinsi'] ?? '') as String,
      condition: (json['condition'] ?? '') as String,
      temperature: (json['temperature'] ?? 0) as int,
      humidity: (json['humidity'] ?? 0) as int,
      windMs: ((json['wind_ms'] ?? 0) as num).toDouble(),
      updatedAt: (json['updated_at'] ?? '') as String,
      insight: (json['insight'] ?? '') as String,
    );
  }

  IconData get icon {
    final d = condition.toLowerCase();
    if (d.contains('hujan')) return Icons.water_drop_outlined;
    if (d.contains('petir')) return Icons.flash_on;
    if (d.contains('berawan')) return Icons.wb_cloudy_outlined;
    if (d.contains('kabut') || d.contains('asap')) return Icons.blur_on;
    return Icons.wb_sunny_outlined;
  }
}

class WeatherService {
  WeatherService._();

  static const String defaultAdm4 = '31.71.03.1001';

  static Future<WeatherData> fetchWeather({
    String? adm4,
    double? latitude,
    double? longitude,
  }) async {
    final path = adm4 != null
        ? '/api/v1/weather?adm4=$adm4'
        : '/api/v1/weather?lat=$latitude&lon=$longitude';
    final data = await ApiService.get(path);
    return WeatherData.fromJson(data);
  }
}