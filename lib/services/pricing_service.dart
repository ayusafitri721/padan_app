import 'api_service.dart';

class PricingSchedule {
  const PricingSchedule({required this.time, required this.discount, required this.description});
  final String time;
  final int discount;
  final String description;
  factory PricingSchedule.fromJson(Map<String, dynamic> j) => PricingSchedule(
        time: j['time_interval'] as String? ?? '',
        discount: (j['discount_percentage'] as num? ?? 0).toInt(),
        description: j['description'] as String? ?? '',
      );
}

class PricingConfig {
  const PricingConfig({
    required this.isEnabled,
    required this.maxDiscount,
    required this.startTime,
    required this.broadcastWa,
    required this.schedules,
  });
  final bool isEnabled;
  final int maxDiscount;
  final String startTime; // "HH:MM"
  final bool broadcastWa;
  final List<PricingSchedule> schedules;
  factory PricingConfig.fromJson(Map<String, dynamic> j) => PricingConfig(
        isEnabled: j['is_enabled'] as bool? ?? true,
        maxDiscount: (j['max_discount_percentage'] as num? ?? 35).toInt(),
        startTime: j['start_intervention_time'] as String? ?? '20:30',
        broadcastWa: j['broadcast_whatsapp'] as bool? ?? true,
        schedules: [
          for (final e in (j['schedules'] as List<dynamic>? ?? []))
            PricingSchedule.fromJson(e as Map<String, dynamic>),
        ],
      );
}

class PricingPreview {
  const PricingPreview({
    required this.menuName,
    required this.originalPrice,
    required this.discountedPrice,
    required this.discount,
    required this.remaining,
    required this.isActive,
    required this.description,
  });
  final String menuName;
  final int originalPrice;
  final int discountedPrice;
  final int discount;
  final int remaining;
  final bool isActive;
  final String description;
  factory PricingPreview.fromJson(Map<String, dynamic> j) => PricingPreview(
        menuName: j['menu_name'] as String? ?? '',
        originalPrice: (j['original_price'] as num? ?? 0).toInt(),
        discountedPrice: (j['discounted_price'] as num? ?? 0).toInt(),
        discount: (j['discount_percentage'] as num? ?? 0).toInt(),
        remaining: (j['remaining_portions'] as num? ?? 0).toInt(),
        isActive: j['is_active'] as bool? ?? false,
        description: j['description'] as String? ?? '',
      );
}

class PricingService {
  PricingService._();
  static Future<PricingConfig> fetchConfig() async {
    final data = await ApiService.get('/api/v1/pricing/config');
    return PricingConfig.fromJson(data);
  }

  static Future<PricingConfig> saveConfig({
    required bool isEnabled,
    required int maxDiscount,
    required String startTime, // "HH:MM"
    required bool broadcastWa,
  }) async {
    final data = await ApiService.put('/api/v1/pricing/config', {
      'is_enabled': isEnabled,
      'max_discount_percentage': maxDiscount,
      'start_intervention_time': startTime.length == 5 ? '$startTime:00' : startTime,
      'broadcast_whatsapp': broadcastWa,
    });
    return PricingConfig.fromJson(data);
  }

  static Future<PricingPreview> fetchLivePreview() async {
    final data = await ApiService.get('/api/v1/pricing/live-preview');
    return PricingPreview.fromJson(data);
  }
}
