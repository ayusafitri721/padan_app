import 'dart:typed_data';

import 'api_service.dart';

class WasteChartPoint {
  const WasteChartPoint({required this.label, required this.monthYear, required this.wasteKg});
  final String label;
  final String monthYear;
  final double wasteKg;
  factory WasteChartPoint.fromJson(Map<String, dynamic> j) => WasteChartPoint(
        label: j['label'] as String? ?? '',
        monthYear: j['month_year'] as String? ?? '',
        wasteKg: (j['waste_kg'] as num? ?? 0).toDouble(),
      );
}

class WasteSummary {
  const WasteSummary({
    required this.hasData,
    required this.financialCumulativeIdr,
    required this.monthSavedPortions,
    required this.co2ReducedKg,
    required this.wasteReductionPercent,
    required this.chart,
    required this.insight,
    required this.levelLabel,
    required this.auditCount,
  });

  final bool hasData;

  final int financialCumulativeIdr;
  final int monthSavedPortions;
  final double co2ReducedKg;
  final int wasteReductionPercent;
  final List<WasteChartPoint> chart;
  final String insight;
  final String levelLabel;
  final int auditCount;

  factory WasteSummary.fromJson(Map<String, dynamic> j) => WasteSummary(
        hasData: j['has_data'] as bool? ?? false,        financialCumulativeIdr: (j['financial_cumulative_idr'] as num? ?? 0).toInt(),
        monthSavedPortions: (j['month_saved_portions'] as num? ?? 0).toInt(),
        co2ReducedKg: (j['co2_reduced_kg'] as num? ?? 0).toDouble(),
        wasteReductionPercent: (j['waste_reduction_percent'] as num? ?? 0).toInt(),
        chart: [
          for (final e in (j['chart'] as List<dynamic>? ?? []))
            WasteChartPoint.fromJson(e as Map<String, dynamic>),
        ],
        insight: j['insight'] as String? ?? '',
        levelLabel: j['level_label'] as String? ?? 'Bebas Mubazir',
        auditCount: (j['audit_count'] as num? ?? 0).toInt(),
      );
}

class WasteService {
  WasteService._();
  static Future<WasteSummary> fetchSummary() async {
    final data = await ApiService.get('/api/v1/waste/summary');
    return WasteSummary.fromJson(data);
  }

  static Future<Uint8List> downloadReport() async {
    return ApiService.getBytes('/api/v1/waste/download-report');
  }
}
