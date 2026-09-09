import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'api_service.dart';

class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.category,
    required this.targetPortions,
    required this.accuracy,
    required this.soldToday,
    required this.remaining,
    this.imageUrl,
    this.price = 25000,
  });

  final int id;
  final String name;
  final String category;
  final int targetPortions;
  final int accuracy;
  final int soldToday;
  final int remaining;
  final String? imageUrl;
  final int price;

  /// URL absolut foto menu, null bila belum ada (pakai ikon kategori).
  String? get photoUrl =>
      imageUrl == null || imageUrl!.isEmpty ? null : '${ApiService.baseUrl}$imageUrl';

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
        id: (json['id'] ?? 0) as int,
        name: (json['name'] ?? '') as String,
        category: (json['category'] ?? 'Makanan Utama') as String,
        targetPortions: (json['target_portions'] ?? 0) as int,
        accuracy: (json['accuracy'] ?? 0) as int,
        soldToday: (json['sold_today'] ?? 0) as int,
        remaining: (json['remaining'] ?? 0) as int,
        imageUrl: json['image_url'] as String?,
        price: (json['price'] ?? 25000) as int,
      );

  IconData get icon => categoryToIcon(category);
}

const List<String> menuCategories = [
  'Makanan Utama',
  'Mie & Bakso',
  'Minuman',
  'Camilan',
  'Dessert',
  'Lainnya',
];

IconData categoryToIcon(String category) {
  switch (category) {
    case 'Mie & Bakso':
      return Icons.ramen_dining;
    case 'Minuman':
      return Icons.local_cafe;
    case 'Camilan':
      return Icons.fastfood;
    case 'Dessert':
      return Icons.cake;
    case 'Lainnya':
      return Icons.restaurant;
    default:
      return Icons.rice_bowl;
  }
}

class MenuInput {
  const MenuInput({
    required this.name,
    required this.category,
    required this.targetPortions,
    this.accuracy = 0,
    this.price = 25000,
  });

  final String name;
  final String category;
  final int targetPortions;
  final int accuracy;
  final int price;

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'target_portions': targetPortions,
        'accuracy': accuracy,
        'price': price,
      };
}

class SalesSummary {
  const SalesSummary({
    required this.id,
    required this.status,
    required this.totalSold,
    required this.totalTarget,
    required this.efficiencyPercent,
    required this.remainingTotal,
  });

  final int id;
  final String status;
  final int totalSold;
  final int totalTarget;
  final double efficiencyPercent;
  final int remainingTotal;

  factory SalesSummary.fromJson(Map<String, dynamic> json) => SalesSummary(
        id: (json['id'] ?? 0) as int,
        status: (json['status'] ?? '') as String,
        totalSold: (json['total_sold'] ?? 0) as int,
        totalTarget: (json['total_target'] ?? 0) as int,
        efficiencyPercent: ((json['efficiency_percent'] ?? 0) as num).toDouble(),
        remainingTotal: (json['remaining_total'] ?? 0) as int,
      );
}

class DailySalesRecord {
  const DailySalesRecord({
    required this.isHolidayToggle,
    required this.status,
    required this.items,
    required this.totalTarget,
    required this.totalSold,
  });

  final bool isHolidayToggle;
  final String status;
  final Map<int, int> items; // menu_id -> sold_portions
  final int totalTarget;
  final int totalSold;

  double get efficiency =>
      totalTarget == 0 ? 0 : totalSold / totalTarget * 100;

  int get remaining => (totalTarget - totalSold).clamp(0, 1 << 31);

  factory DailySalesRecord.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>? ?? []);
    int target = 0;
    int sold = 0;
    final map = <int, int>{};
    for (final e in rawItems) {
      final m = e as Map<String, dynamic>;
      map[(m['menu_id'] as int)] = ((m)['sold_portions'] as int? ?? 0);
      target += ((m)['target_portions'] as int? ?? 0);
      sold += ((m)['sold_portions'] as int? ?? 0);
    }
    return DailySalesRecord(
      isHolidayToggle: json['is_holiday_toggle'] as bool? ?? false,
      status: (json['status'] ?? '') as String,
      items: map,
      totalTarget: target,
      totalSold: sold,
    );
  }
}

class SalesService {
  SalesService._();

  static Future<List<MenuItem>> fetchMenus() async {
    final data = await ApiService.getList('/api/v1/sales/menus');
    return data
        .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<DailySalesRecord?> fetchToday() async {
    final data = await ApiService.get('/api/v1/sales/today');
    if (data.isEmpty) return null;
    return DailySalesRecord.fromJson(data);
  }

  static Future<DailySalesRecord?> fetchByDate(String date) async {
    final data = await ApiService.get('/api/v1/sales/by-date?date=$date');
    if (data.isEmpty) return null;
    return DailySalesRecord.fromJson(data);
  }

  static Future<MenuItem> createMenu(MenuInput input) async {
    final data = await ApiService.post('/api/v1/sales/menus', input.toJson());
    return MenuItem.fromJson(data);
  }

  static Future<MenuItem> updateMenu(int id, MenuInput input) async {
    final data = await ApiService.put(
      '/api/v1/sales/menus/$id',
      input.toJson(),
    );
    return MenuItem.fromJson(data);
  }

  static Future<void> deleteMenu(int id) async {
    await ApiService.delete('/api/v1/sales/menus/$id');
  }

  static Future<MenuItem> uploadMenuPhoto(
    int id, {
    required List<int> bytes,
    required String filename,
  }) async {
    final data = await ApiService.postMultipart(
      '/api/v1/sales/menus/$id/photo',
      fileBytes: Uint8List.fromList(bytes),
      filename: filename,
    );
    return MenuItem.fromJson(data);
  }

  static Future<MenuItem> deleteMenuPhoto(int id) async {
    final data = await ApiService.delete('/api/v1/sales/menus/$id/photo');
    return MenuItem.fromJson(data);
  }

  static Future<SalesSummary> saveDailyRecord({
    required String date,
    required bool isHolidayToggle,
    required List<Map<String, int>> items,
  }) async {
    final data = await ApiService.post('/api/v1/sales/daily-record', {
      'date': date,
      'is_holiday_toggle': isHolidayToggle,
      'items': items,
    });
    return SalesSummary.fromJson(data);
  }

  static Future<SalesSummary> saveDraft({
    required String date,
    required bool isHolidayToggle,
    required List<Map<String, int>> items,
  }) async {
    final data = await ApiService.post('/api/v1/sales/save-draft', {
      'date': date,
      'is_holiday_toggle': isHolidayToggle,
      'items': items,
    });
    return SalesSummary.fromJson(data);
  }
}