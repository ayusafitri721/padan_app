import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../services/prediction_service.dart';

/// Halaman Detail Prediksi AI.
///
/// Mode live: berikan [menuId] untuk mengambil data prediksi dari backend
/// (`GET /api/v1/predictions/detail/{menu_id}`).
/// Mode fallback statis: berikan [menuName]/[porsi]/[alasan] (dipakai dari
/// kartu rekomendasi dashboard).
class DetailPrediksiScreen extends StatefulWidget {
  const DetailPrediksiScreen({
    super.key,
    this.menuId,
    this.menuName,
    this.porsi,
    this.alasan,
  }) : assert(menuId != null || (menuName != null && porsi != null));

  final int? menuId;
  final String? menuName;
  final String? porsi;
  final String? alasan;

  @override
  State<DetailPrediksiScreen> createState() => _DetailPrediksiScreenState();
}

class _DetailPrediksiScreenState extends State<DetailPrediksiScreen> {
  MenuPrediction? _prediction;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.menuId;
    if (id == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prediction = await PredictionService.fetchDetail(id);
      if (!mounted) return;
      setState(() {
        _prediction = prediction;
        _loading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0x26FFFFFF),
                borderRadius: BorderRadius.circular(9999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 13, color: Color(0xFFFFE082)),
                  SizedBox(width: 4),
                  Text(
                    'PADAN-AI Engine v2.4',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Bagikan',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fitur bagikan segera hadir.')),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_prediction == null) {
      if (widget.menuName != null) {
        // Mode fallback statis (dari dashboard).
        return _buildStaticBody();
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 40, color: AppColors.mutedText),
              const SizedBox(height: 12),
              Text(
                _error ?? 'Tidak dapat memuat prediksi.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }
    return _buildLiveBody(_prediction!);
  }

  Widget _buildStaticBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        _MenuHeader(
          menuName: widget.menuName!,
          category: 'Makanan Utama',
          akurasi: 94.8,
          targetLabel: 'Target Besok (Malam)',
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.outline, width: 1),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lightbulb_outline,
                          size: 18,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.alasan ?? '',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _MetaInfoCard(
          label: 'REKOMENDASI HARI INI',
          value: '${widget.porsi} porsi',
        ),
        const SizedBox(height: 12),
        _InfoNote(
          text: 'Rekomendasi dihasilkan dari model peramalan permintaan '
              '(Prophet/XGBoost). Detail parameter model akan tersedia di PADAN Pro.',
        ),
      ],
    );
  }

  Widget _buildLiveBody(MenuPrediction prediction) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        _MenuHeader(
          menuName: prediction.menuName,
          category: prediction.category,
          akurasi: prediction.accuracyScore,
          targetLabel:
              '${_formatTgl(prediction.predictionDate)} (${prediction.targetTime})',
          sku: prediction.sku,
        ),
        const SizedBox(height: 12),
        _RecipeCard(prediction: prediction),
        const SizedBox(height: 12),
        _FactorsCard(factors: prediction.factors),
        const SizedBox(height: 12),
        _IngredientsCard(ingredients: prediction.ingredients),
        const SizedBox(height: 12),
        _KalibrasiCard(
          menuId: prediction.menuId,
          planDate: prediction.predictionDate,
          recommended: prediction.safeSweet,
          low: prediction.safeLow,
          high: prediction.safeHigh,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  String _formatTgl(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    const bulan = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final day = int.tryParse(parts[2]);
    final mon = int.tryParse(parts[1]);
    if (day == null || mon == null || mon < 1 || mon > 12) return iso;
    return 'Target $day ${bulan[mon - 1]} ${parts[0]}';
  }
}

// ─── Header Menu & Target Waktu ─────────────────────────────
class _MenuHeader extends StatelessWidget {
  const _MenuHeader({
    required this.menuName,
    required this.category,
    required this.akurasi,
    required this.targetLabel,
    this.sku = '',
  });

  final String menuName;
  final String category;
  final double akurasi;
  final String targetLabel;
  final String sku;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            menuName,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Pill(label: sku.isEmpty ? 'SKU #--' : sku, medium: true),
              _Pill(label: category, medium: true),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.data_usage, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Akurasi Model ${akurasi.toStringAsFixed(1)}%',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.schedule, size: 16, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(
                targetLabel,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.mutedText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.medium = false});

  final String label;
  final bool medium;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: medium ? 10 : 12,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.tonalBadge,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// ─── Kartu Utama Target Rekomendasi Masak ───────────────────
class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.prediction});

  final MenuPrediction prediction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REKOMENDASI MASAK',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.8),
              letterSpacing: 0.02,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${prediction.recommendedPortions}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 52,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 56 / 52,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'porsi',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _RangeItem(
                label: 'Batas Bawah',
                value: prediction.safeLow,
                color: Colors.white.withValues(alpha: 0.92),
              ),
              Container(width: 1, height: 32, color: const Color(0x33FFFFFF)),
              _RangeItem(
                label: 'Titik Manis',
                value: prediction.safeSweet,
                color: const Color(0xFFFFE082),
                bold: true,
              ),
              Container(width: 1, height: 32, color: const Color(0x33FFFFFF)),
              _RangeItem(
                label: 'Batas Atas',
                value: prediction.safeHigh,
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x26FFFFFF),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.eco, size: 14, color: Color(0x8AFFE082)),
                const SizedBox(width: 4),
                Text(
                  '~ ${prediction.co2eSavedKg.toStringAsFixed(1)} kg CO2e terhindar',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeItem extends StatelessWidget {
  const _RangeItem({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  final String label;
  final int value;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: GoogleFonts.plusJakartaSans(
              fontSize: bold ? 22 : 18,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Faktor Analisis Multidimensi ───────────────────────────
class _FactorsCard extends StatelessWidget {
  const _FactorsCard({required this.factors});

  final List<PredictionFactor> factors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FAKTOR ANALISIS AI',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedText,
              letterSpacing: 0.02,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Mengapa angkanya segini?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < factors.length; i++) ...[
            _FactorRow(factor: factors[i]),
            if (i != factors.length - 1)
              const Divider(height: 20, color: AppColors.outline),
          ],
          if (factors.any((f) => f.key == 'event' && f.delta > 0)) ...[
            const SizedBox(height: 12),
            const _MicroMapCard(),
          ],
        ],
      ),
    );
  }
}

class _MicroMapCard extends StatelessWidget {
  const _MicroMapCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.tonalBadge.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, size: 15, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(
                'Peta Mikro-Lokasi',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Skema peta mikro sederhana (warung sebagai titik tengah, event berjarak).
          Row(
            children: [
              _MapPin(label: 'Warung', icon: Icons.storefront, color: AppColors.primary, active: true),
              const SizedBox(width: 6),
              const _RouteDot(),
              Transform.rotate(
                angle: -0.6,
                child: const Icon(Icons.near_me, size: 12, color: AppColors.mutedText),
              ),
              const SizedBox(width: 6),
              Expanded(child: Divider(color: AppColors.primary.withValues(alpha: 0.4))),
              const SizedBox(width: 6),
              _MapPin(label: 'Event', icon: Icons.celebration, color: AppColors.accent, active: true),
              const SizedBox(width: 6),
              const _RouteDot(),
              Transform.rotate(
                angle: -0.6,
                child: const Icon(Icons.near_me, size: 12, color: AppColors.mutedText),
              ),
              const SizedBox(width: 6),
              _MapPin(label: 'Lainnya', icon: Icons.place_outlined, color: AppColors.mutedText, active: false),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Event ±1,2 km dari lokasi warung — potensi kunjungan tambahan di sekitar area.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: AppColors.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({
    required this.label,
    required this.icon,
    required this.color,
    required this.active,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.12) : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: active ? 0.6 : 0.25), width: 1),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

class _RouteDot extends StatelessWidget {
  const _RouteDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: const BoxDecoration(
        color: AppColors.mutedText,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _FactorRow extends StatelessWidget {
  const _FactorRow({required this.factor});

  final PredictionFactor factor;

  IconData get _icon {
    switch (factor.icon) {
      case 'trending_up':
        return Icons.show_chart;
      case 'wb_sunny':
        return Icons.wb_sunny_outlined;
      case 'celebration':
        return Icons.celebration_outlined;
      case 'replay':
        return Icons.replay;
      default:
        return Icons.auto_awesome;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPositive = factor.delta > 0;
    final isNegative = factor.delta < 0;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.tonalBadge,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_icon, size: 19, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                factor.label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                factor.description,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.mutedText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isNegative
                ? AppColors.warningSoft
                : isPositive
                    ? AppColors.tonalBadge
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Text(
            factor.delta == 0
                ? '0'
                : (isPositive ? '+${factor.delta}' : '${factor.delta}'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isNegative
                  ? AppColors.accent
                  : isPositive
                      ? AppColors.primary
                      : AppColors.mutedText,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Kebutuhan Bahan Baku ───────────────────────────────────
class _IngredientsCard extends StatelessWidget {
  const _IngredientsCard({required this.ingredients});

  final List<Ingredient> ingredients;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KEBUTUHAN BAHAN BAKU',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedText,
              letterSpacing: 0.02,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Perkiraan kebutuhan hari target',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          for (final ingredient in ingredients)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: ingredient.lowStock
                          ? AppColors.warningSoft
                          : AppColors.tonalBadge,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      ingredient.lowStock
                          ? Icons.priority_high
                          : Icons.check,
                      size: 16,
                      color: ingredient.lowStock
                          ? AppColors.accent
                          : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ingredient.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_fmtQty(ingredient.quantity)} ${ingredient.unit}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ingredient.lowStock
                          ? AppColors.accent
                          : AppColors.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          if (ingredients.any((i) => i.lowStock))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Beberapa bahan mendekati batas stok. Segera top-up sebelum jam operasional.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _fmtQty(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toStringAsFixed(0);
    }
    return quantity.toStringAsFixed(1);
  }
}

// ─── Kalibrasi Manual & Kunci ───────────────────────────────
class _KalibrasiCard extends StatefulWidget {
  const _KalibrasiCard({
    required this.menuId,
    required this.planDate,
    required this.recommended,
    required this.low,
    required this.high,
  });

  final int menuId;
  final String planDate;
  final int recommended;
  final int low;
  final int high;

  @override
  State<_KalibrasiCard> createState() => _KalibrasiCardState();
}

class _KalibrasiCardState extends State<_KalibrasiCard> {
  late int _value;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _value = widget.recommended;
  }

  Future<void> _lock() async {
    setState(() => _saving = true);
    try {
      await PredictionService.lockPlan(
        menuId: widget.menuId,
        planDate: widget.planDate,
        recommendedPortions: widget.recommended,
        lockedPortions: _value,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _value == widget.recommended
                ? 'Terkunci: $_value porsi (rekomendasi AI). Target besok tersinkron ke dapur.'
                : 'Terkunci: $_value porsi. Kalibrasi manual diterapkan & tersinkron ke dapur.',
          ),
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
@override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KALIBRASI MANUAL',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedText,
              letterSpacing: 0.02,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sesuaikan untuk pesanan catering / permintaan khusus',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppColors.mutedText,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _CalibrateStepper(
                value: _value,
                onChanged: (v) => setState(() => _value = v.clamp(widget.low, widget.high)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_value porsi',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      'Rentang aman ${widget.low}–${widget.high}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.mutedText,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _lock,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.lock_outline, size: 18),
              label: Text(_saving
                  ? 'Menyimpan…'
                  : 'Kunci & Terapkan Angka Ini'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalibrateStepper extends StatelessWidget {
  const _CalibrateStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepBtn(icon: Icons.remove, onTap: () => onChanged(value - 1)),
          Container(width: 1, height: 22, color: AppColors.outline),
          SizedBox(
            width: 44,
            child: Center(
              child: Text(
                '$value',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          Container(width: 1, height: 22, color: AppColors.outline),
          _StepBtn(icon: Icons.add, onTap: () => onChanged(value + 1)),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 42,
        height: 44,
        child: Icon(icon, size: 18, color: AppColors.mutedText),
      ),
    );
  }
}

// ─── Kartu meta kecil (mode statis) ─────────────────────────
class _MetaInfoCard extends StatelessWidget {
  const _MetaInfoCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedText,
              letterSpacing: 0.02,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Catatan info (mode statis) ─────────────────────────────
class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.tonalBadge,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}