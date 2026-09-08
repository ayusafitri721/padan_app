import 'api_service.dart';

class PredictionFactor {
  const PredictionFactor({
    required this.key,
    required this.label,
    required this.description,
    required this.delta,
    required this.icon,
  });

  final String key;
  final String label;
  final String description;
  final int delta;
  final String icon;

  factory PredictionFactor.fromJson(Map<String, dynamic> json) =>
      PredictionFactor(
        key: (json['key'] ?? '') as String,
        label: (json['label'] ?? '') as String,
        description: (json['description'] ?? '') as String,
        delta: (json['delta'] ?? 0) as int,
        icon: (json['icon'] ?? '') as String,
      );
}

class Ingredient {
  const Ingredient({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.lowStock,
  });

  final String name;
  final double quantity;
  final String unit;
  final bool lowStock;

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
        name: (json['name'] ?? '') as String,
        quantity: ((json['quantity'] ?? 0) as num).toDouble(),
        unit: (json['unit'] ?? '') as String,
        lowStock: (json['low_stock'] ?? false) as bool,
      );
}

class MenuPrediction {
  const MenuPrediction({
    required this.menuId,
    required this.menuName,
    required this.sku,
    required this.category,
    required this.accuracyScore,
    required this.predictionDate,
    required this.targetTime,
    required this.recommendedPortions,
    required this.safeLow,
    required this.safeSweet,
    required this.safeHigh,
    required this.co2eSavedKg,
    required this.factors,
    required this.ingredients,
  });

  final int menuId;
  final String menuName;
  final String sku;
  final String category;
  final double accuracyScore;
  final String predictionDate;
  final String targetTime;
  final int recommendedPortions;
  final int safeLow;
  final int safeSweet;
  final int safeHigh;
  final double co2eSavedKg;
  final List<PredictionFactor> factors;
  final List<Ingredient> ingredients;

  factory MenuPrediction.fromJson(Map<String, dynamic> json) => MenuPrediction(
        menuId: (json['menu_id'] ?? 0) as int,
        menuName: (json['menu_name'] ?? '') as String,
        sku: (json['sku'] ?? '') as String,
        category: (json['category'] ?? '') as String,
        accuracyScore: ((json['accuracy_score'] ?? 0) as num).toDouble(),
        predictionDate: (json['prediction_date'] ?? '') as String,
        targetTime: (json['target_time'] ?? '') as String,
        recommendedPortions: (json['recommended_portions'] ?? 0) as int,
        safeLow: (json['safe_low'] ?? 0) as int,
        safeSweet: (json['safe_sweet'] ?? 0) as int,
        safeHigh: (json['safe_high'] ?? 0) as int,
        co2eSavedKg: ((json['co2e_saved_kg'] ?? 0) as num).toDouble(),
        factors: [
          for (final e in (json['factors'] as List<dynamic>? ?? []))
            PredictionFactor.fromJson(e as Map<String, dynamic>),
        ],
        ingredients: [
          for (final e in (json['ingredients'] as List<dynamic>? ?? []))
            Ingredient.fromJson(e as Map<String, dynamic>),
        ],
      );
}

class PredictionPlan {
  const PredictionPlan({
    required this.id,
    required this.menuId,
    required this.planDate,
    required this.recommendedPortions,
    required this.lockedPortions,
    required this.source,
  });

  final int id;
  final int menuId;
  final String planDate;
  final int recommendedPortions;
  final int lockedPortions;
  final String source;

  /// True bila target dikalibrasi manual oleh pemilik warung.
  bool get isManual => source == 'manual';

  factory PredictionPlan.fromJson(Map<String, dynamic> json) => PredictionPlan(
        id: (json['id'] ?? 0) as int,
        menuId: (json['menu_id'] ?? 0) as int,
        planDate: (json['plan_date'] ?? '') as String,
        recommendedPortions: (json['recommended_portions'] ?? 0) as int,
        lockedPortions: (json['locked_portions'] ?? 0) as int,
        source: (json['source'] ?? 'ai') as String,
      );
}

class PredictionService {
  PredictionService._();

  static Future<MenuPrediction> fetchDetail(int menuId) async {
    final data = await ApiService.get('/api/v1/predictions/detail/$menuId');
    return MenuPrediction.fromJson(data);
  }

  static Future<PredictionPlan?> fetchPlan(String planDate, int menuId) async {
    final data =
        await ApiService.get('/api/v1/predictions/plan/$planDate/$menuId');
    if (data.isEmpty) return null;
    return PredictionPlan.fromJson(data);
  }

  static Future<Map<String, dynamic>> lockPlan({
    required int menuId,
    required String planDate,
    required int recommendedPortions,
    required int lockedPortions,
  }) async {
    return ApiService.post('/api/v1/predictions/plan', {
      'menu_id': menuId,
      'plan_date': planDate,
      'recommended_portions': recommendedPortions,
      'locked_portions': lockedPortions,
      'source': 'manual',
    });
  }
}