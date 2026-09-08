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
  });

  final int id;
  final String name;
  final String category;
  final int targetPortions;
  final int accuracy;
  final int soldToday;
  final int remaining;

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
        id: (json['id'] ?? 0) as int,
        name: (json['name'] ?? '') as String,
        category: (json['category'] ?? 'Makanan Utama') as String,
        targetPortions: (json['target_portions'] ?? 0) as int,
        accuracy: (json['accuracy'] ?? 0) as int,
        soldToday: (json['sold_today'] ?? 0) as int,
        remaining: (json['remaining'] ?? 0) as int,
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
  });

  final String name;
  final String category;
  final int targetPortions;
  final int accuracy;

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'target_portions': targetPortions,
        'accuracy': accuracy,
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
  });

  final bool isHolidayToggle;
  final String status;
  final Map<int, int> items; // menu_id -> sold_portions

  factory DailySalesRecord.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>? ?? []);
    return DailySalesRecord(
      isHolidayToggle: json['is_holiday_toggle'] as bool? ?? false,
      status: (json['status'] ?? '') as String,
      items: {
        for (final e in rawItems)
          ((e as Map<String, dynamic>)['menu_id'] as int):
              ((e)['sold_portions'] as int? ?? 0),
      },
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