import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../services/prediction_service.dart';

/// Menampilkan detail prediksi untuk **semua** menu yang baru di-save.
/// Sebelumnya hanya topMenu yang ditampilkan sehingga es teh dll terasa hilang.
class DetailPrediksiListScreen extends StatefulWidget {
  const DetailPrediksiListScreen({super.key, required this.menuIds});

  final List<int> menuIds;

  @override
  State<DetailPrediksiListScreen> createState() => _DetailPrediksiListScreenState();
}

class _DetailPrediksiListScreenState extends State<DetailPrediksiListScreen> {
  late final PageController _pageController;
  int _page = 0;
  List<MenuPrediction?> _preds = [];
  List<String?> _errors = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _preds = List.filled(widget.menuIds.length, null);
    _errors = List.filled(widget.menuIds.length, null);
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final results = await Future.wait(
      widget.menuIds.map((id) async {
        try {
          final p = await PredictionService.fetchDetail(id);
          return p;
        } catch (e) {
          return e;
        }
      }),
    );
    if (!mounted) return;
    final preds = <MenuPrediction?>[];
    final errs = <String?>[];
    for (final r in results) {
      if (r is MenuPrediction) {
        preds.add(r);
        errs.add(null);
      } else {
        preds.add(null);
        errs.add(r.toString());
      }
    }
    setState(() {
      _preds = preds;
      _errors = errs;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.menuIds.length;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text(
          count > 1 ? 'Detail Prediksi ($count menu)' : 'Detail Prediksi',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          if (count > 1)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0x26FFFFFF), borderRadius: BorderRadius.circular(9999)),
                child: Text('${_page + 1}/$count', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                if (count > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: List.generate(count, (i) {
                                final selected = i == _page;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(
                                      _preds[i]?.menuName ?? 'Menu ${widget.menuIds[i]}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: selected ? Colors.white : AppColors.primary,
                                      ),
                                    ),
                                    selected: selected,
                                    selectedColor: AppColors.primary,
                                    backgroundColor: AppColors.tonalBadge,
                                    onSelected: (_) {
                                      _pageController.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                                    },
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: count,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, index) {
                      final pred = _preds[index];
                      final err = _errors[index];
                      if (pred == null) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.cloud_off_outlined, size: 36, color: AppColors.mutedText),
                              const SizedBox(height: 8),
                              Text(err ?? 'Gagal memuat menu ${widget.menuIds[index]}', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.mutedText)),
                              const SizedBox(height: 12),
                              OutlinedButton(onPressed: _loadAll, child: const Text('Coba Lagi')),
                            ]),
                          ),
                        );
                      }
                      // Reuse single-detail body by embedding a DetailPrediksiScreen in embedded mode.
                      // Untuk menghindari nested Scaffold, kita render langsung konten detail di sini.
                      return _SingleDetailBody(prediction: pred);
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

/// Body detail tanpa Scaffold – reuse dari DetailPrediksiScreen
class _SingleDetailBody extends StatelessWidget {
  const _SingleDetailBody({required this.prediction});
  final MenuPrediction prediction;

  String _formatTgl(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    const bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final d = int.tryParse(parts[2]);
    final m = int.tryParse(parts[1]);
    if (d == null || m == null || m < 1 || m > 12) return iso;
    return 'Target $d ${bulan[m - 1]} ${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header & Recipe etc – import dari detail_prediksi_screen via composition
        // Kita panggil DetailPrediksiScreen sebagai embedded widget melalui builder
        DetailPrediksiEmbedded(prediction: prediction, formatTgl: _formatTgl),
      ],
    );
  }
}

/// Wrapper agar bisa reuse private widgets dari detail_prediksi_screen tanpa duplikasi
/// Kami buat ulang minimal: header, recipe, factors, ingredients, kalibrasi dengan memanggil DetailPrediksiScreen's UI
/// Untuk simpel, kita langsung pakai DetailPrediksiScreen dalam mode embedded (tanpa AppBar) via custom builder
class DetailPrediksiEmbedded extends StatelessWidget {
  const DetailPrediksiEmbedded({super.key, required this.prediction, required this.formatTgl});
  final MenuPrediction prediction;
  final String Function(String) formatTgl;
  @override
  Widget build(BuildContext context) {
    // Render full detail by composing a Column that mirrors DetailPrediksiScreen._buildLiveBody
    // Kita instansiasi widget publik dari file detail_prediksi_screen secara manual
    // Untuk menjaga single source of truth, kita buat DetailPrediksiScreen dengan menuId dan biarkan ia fetch,
    // tapi di sini kita sudah punya prediction jadi kita render langsung via helper.
    // Karena widget private tidak bisa diimport, kita duplikasi layout ringkas yang memanggil service lock.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.outline)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(prediction.menuName, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Wrap(spacing: 8, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppColors.tonalBadge, borderRadius: BorderRadius.circular(9999)), child: Text(prediction.sku, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppColors.tonalBadge, borderRadius: BorderRadius.circular(9999)), child: Text(prediction.category, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary))),
            ]),
            const SizedBox(height: 8),
            Row(children: [const Icon(Icons.data_usage, size: 14, color: AppColors.primary), const SizedBox(width: 6), Text('Akurasi ${prediction.accuracyScore.toStringAsFixed(1)}%', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary))]),
            const SizedBox(height: 4),
            Row(children: [const Icon(Icons.schedule, size: 14, color: AppColors.accent), const SizedBox(width: 6), Text('${formatTgl(prediction.predictionDate)} (${prediction.targetTime})', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.mutedText))]),
          ]),
        ),
        const SizedBox(height: 12),
        // Recipe
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('REKOMENDASI MASAK', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70, letterSpacing: 0.06)),
            const SizedBox(height: 6),
            Text('${prediction.recommendedPortions}', style: GoogleFonts.plusJakartaSans(fontSize: 40, fontWeight: FontWeight.w700, color: Colors.white, fontFeatures: const [FontFeature.tabularFigures()])),
            Text('porsi', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Column(children: [Text('${prediction.safeLow}', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)), Text('Batas Bawah', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.white70))])),
              Container(width: 1, height: 28, color: Colors.white24),
              Expanded(child: Column(children: [Text('${prediction.safeSweet}', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFFFFE082))), Text('Titik Manis', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.white70))])),
              Container(width: 1, height: 28, color: Colors.white24),
              Expanded(child: Column(children: [Text('${prediction.safeHigh}', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)), Text('Batas Atas', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.white70))])),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(9999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.eco, size: 12, color: Color(0xFFFFE082)), const SizedBox(width: 4), Text('~ ${prediction.co2eSavedKg.toStringAsFixed(1)} kg CO₂e terhindar', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white))]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        // Factors ringkas
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.outline)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('FAKTOR ANALISIS AI', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.mutedText)),
            const SizedBox(height: 8),
            for (final f in prediction.factors)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(width: 32, height: 32, decoration: BoxDecoration(color: AppColors.tonalBadge, borderRadius: BorderRadius.circular(8)), child: Icon(f.key == 'weather' ? Icons.wb_sunny_outlined : f.key == 'event' ? Icons.celebration_outlined : f.key == 'trend' ? Icons.show_chart : Icons.replay, size: 16, color: AppColors.primary)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(f.label, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)), Text(f.description, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.mutedText))])),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: f.delta > 0 ? AppColors.tonalBadge : f.delta < 0 ? AppColors.warningSoft : Colors.transparent, borderRadius: BorderRadius.circular(9999)), child: Text(f.delta == 0 ? '0' : (f.delta > 0 ? '+${f.delta}' : '${f.delta}'), style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: f.delta < 0 ? AppColors.accent : AppColors.primary))),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        // Bahan Baku ringkas
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.outline)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('KEBUTUHAN BAHAN BAKU', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.mutedText)),
            const SizedBox(height: 8),
            for (final ing in prediction.ingredients)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Icon(ing.lowStock ? Icons.priority_high : Icons.check, size: 14, color: ing.lowStock ? AppColors.accent : AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(ing.name, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textPrimary))),
                  Text('${ing.quantity.toStringAsFixed(ing.quantity.truncateToDouble() == ing.quantity ? 0 : 1)} ${ing.unit}', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: ing.lowStock ? AppColors.accent : AppColors.textPrimary)),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        // Kalibrasi – reuse logic lock via PredictionService
        _EmbeddedKalibrasi(menuId: prediction.menuId, planDate: prediction.predictionDate, recommended: prediction.safeSweet, low: prediction.safeLow, high: prediction.safeHigh),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _EmbeddedKalibrasi extends StatefulWidget {
  const _EmbeddedKalibrasi({required this.menuId, required this.planDate, required this.recommended, required this.low, required this.high});
  final int menuId;
  final String planDate;
  final int recommended;
  final int low;
  final int high;
  @override
  State<_EmbeddedKalibrasi> createState() => _EmbeddedKalibrasiState();
}

class _EmbeddedKalibrasiState extends State<_EmbeddedKalibrasi> {
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
      await PredictionService.lockPlan(menuId: widget.menuId, planDate: widget.planDate, recommendedPortions: widget.recommended, lockedPortions: _value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_value == widget.recommended ? 'Terkunci: $_value porsi (AI)' : 'Terkunci: $_value porsi (manual)')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.outline)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('KALIBRASI MANUAL', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.mutedText)),
        const SizedBox(height: 8),
        Row(children: [
          Container(
            height: 40,
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.outline)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              InkWell(onTap: () => setState(() => _value = (_value - 1).clamp(widget.low, widget.high)), child: const SizedBox(width: 40, height: 40, child: Icon(Icons.remove, size: 16, color: AppColors.mutedText))),
              Container(width: 1, height: 20, color: AppColors.outline),
              SizedBox(width: 44, child: Center(child: Text('$_value', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)))),
              Container(width: 1, height: 20, color: AppColors.outline),
              InkWell(onTap: () => setState(() => _value = (_value + 1).clamp(widget.low, widget.high)), child: const SizedBox(width: 40, height: 40, child: Icon(Icons.add, size: 16, color: AppColors.mutedText))),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('$_value porsi • rentang ${widget.low}–${widget.high}', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.mutedText))),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _lock,
            icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.lock_outline, size: 16),
            label: Text(_saving ? 'Menyimpan…' : 'Kunci & Terapkan Angka Ini'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999))),
          ),
        ),
      ]),
    );
  }
}
