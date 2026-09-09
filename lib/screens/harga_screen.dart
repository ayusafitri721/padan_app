import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../services/pricing_service.dart';
import '../services/api_service.dart';

class HargaScreen extends StatefulWidget {
  const HargaScreen({super.key, this.onGoToAkun});
  final VoidCallback? onGoToAkun;
  @override
  State<HargaScreen> createState() => _HargaScreenState();
}

class _HargaScreenState extends State<HargaScreen> {
  PricingConfig? _config;
  PricingPreview? _preview;
  bool _loading = true;
  String? _error;
  bool _saving = false;

  // editable state (mirrors config when loaded)
  bool _enabled = true;
  double _maxDisc = 35;
  TimeOfDay _closing = const TimeOfDay(hour: 22, minute: 0);
  bool _broadcast = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _config == null;
      _error = null;
    });
    try {
      final cfg = await PricingService.fetchConfig();
      PricingPreview? prev;
      try {
        prev = await PricingService.fetchLivePreview();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _config = cfg;
        _preview = prev;
        _enabled = cfg.isEnabled;
        _maxDisc = cfg.maxDiscount.toDouble();
        _closing = _parseTime(cfg.closingTime);
        _broadcast = cfg.broadcastWa;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Gagal memuat konfigurasi harga.';
        _loading = false;
      });
    }
  }

  TimeOfDay _parseTime(String s) {
    final parts = s.split(':');
    final h = int.tryParse(parts[0]) ?? 22;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }

  /// Jam mulai intervensi = tutup − 90 menit (cermin logika backend).
  String _interventionStr() {
    final total = (_closing.hour * 60 + _closing.minute - 90) % (24 * 60);
    final h = (total ~/ 60).toString().padLeft(2, '0');
    final m = (total % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _timeStr(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _idr(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final pos = s.length - i;
      buf.write(s[i]);
      if (pos > 1 && pos % 3 == 1) buf.write('.');
    }
    return 'Rp${buf.toString()}';
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _closing,
      helpText: 'Jam Tutup Warung',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked != null) setState(() => _closing = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final cfg = await PricingService.saveConfig(
        isEnabled: _enabled,
        maxDiscount: _maxDisc.round(),
        closingTime: _timeStr(_closing),
        broadcastWa: _broadcast,
      );
      PricingPreview? prev;
      try {
        prev = await PricingService.fetchLivePreview();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _config = cfg;
        _preview = prev;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Konfigurasi harga tersimpan.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showNotifications() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.tonalBadge, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.notifications_outlined, color: AppColors.primary, size: 20)),
              const SizedBox(width: 12),
              Text('Notifikasi', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close, size: 20, color: AppColors.mutedText)),
            ]),
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.tonalBadge, borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.sell_outlined, size: 18, color: AppColors.primary), const SizedBox(width: 8), Expanded(child: Text('Dynamic Pricing: diskon aktif saat sisa >3 porsi menjelang tutup.', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary)))])),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Tutup'))),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('Harga', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: _showNotifications, icon: const Icon(Icons.notifications_outlined), tooltip: 'Notifikasi'),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () {
                final go = widget.onGoToAkun;
                if (go != null) go();
              },
              customBorder: const CircleBorder(),
              child: const CircleAvatar(radius: 16, backgroundColor: Colors.white24, child: Icon(Icons.person_outline, size: 18, color: Colors.white)),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.mutedText)),
                      const SizedBox(height: 16),
                      OutlinedButton(onPressed: _load, child: const Text('Coba Lagi')),
                    ]),
                  ),
                )
              : SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    children: [
                      // Intro card Dynamic Pricing Engine
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.outline), boxShadow: const [BoxShadow(color: Color(0x0A1E293B), blurRadius: 10, offset: Offset(0, 4))]),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.tonalBadge, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.auto_graph, color: AppColors.primary, size: 20)),
                            const SizedBox(width: 10),
                            Expanded(child: Text('Dynamic Pricing Engine', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(9999), border: Border.all(color: const Color(0xFFA5D6A7))),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                Text('AI Auto-Markdown', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF2E7D32))),
                              ]),
                            ),
                          ]),
                          const SizedBox(height: 10),
                          Text('Pencegahan sisa pangan otomatis dengan diskon bertahap menjelang tutup warung.', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.mutedText, height: 1.4)),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      // Toggle card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.outline), boxShadow: const [BoxShadow(color: Color(0x0A1E293B), blurRadius: 10, offset: Offset(0, 4))]),
                        child: Column(children: [
                          Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Text('Dynamic Pricing Otomatis', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: _enabled ? const Color(0xFFE8F5E9) : AppColors.tonalBadge, borderRadius: BorderRadius.circular(9999)),
                                    child: Text(_enabled ? 'AKTIF' : 'NONAKTIF', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: _enabled ? const Color(0xFF2E7D32) : AppColors.mutedText)),
                                  ),
                                ]),
                                const SizedBox(height: 4),
                                Text('Berjalan otomatis berdasarkan waktu & sisa stok', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.mutedText)),
                              ]),
                            ),
                            Switch(value: _enabled, onChanged: (v) => setState(() => _enabled = v), activeThumbColor: AppColors.secondary),
                          ]),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: AppColors.tonalBadge.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(14)),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Icon(Icons.lightbulb_outline, size: 16, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(child: Text('Sistem akan secara otomatis menerapkan potongan harga pada menu yang masih tersisa > 3 porsi.', style: GoogleFonts.plusJakartaSans(fontSize: 12, height: 1.4, color: AppColors.textPrimary))),
                            ]),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      // Timeline
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.outline), boxShadow: const [BoxShadow(color: Color(0x0A1E293B), blurRadius: 10, offset: Offset(0, 4))]),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text('Jadwal Markdown Bertahap', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: AppColors.tonalBadge, borderRadius: BorderRadius.circular(9999)),
                              child: Text('15-30 Menit Loop', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                            ),
                          ]),
                          const SizedBox(height: 16),
                          ...() {
                            final schedules = _config!.schedules;
                            return [
                              for (int i = 0; i < schedules.length; i++)
                                _TimelineItem(
                                  time: schedules[i].time,
                                  discount: schedules[i].discount,
                                  desc: schedules[i].description,
                                  isLast: i == schedules.length - 1,
                                  isHighlighted: i == schedules.length - 2, // flash promo
                                ),
                            ];
                          }(),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      // Parameter konfigurasi
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.outline), boxShadow: const [BoxShadow(color: Color(0x0A1E293B), blurRadius: 10, offset: Offset(0, 4))]),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text('Parameter Konfigurasi', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            const Spacer(),
                            Container(width: 32, height: 32, decoration: BoxDecoration(color: AppColors.tonalBadge, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.settings_outlined, size: 18, color: AppColors.primary)),
                          ]),
                          const SizedBox(height: 16),
                          Text('Batas Maksimum Diskon', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedText)),
                          const SizedBox(height: 6),
                          Center(
                            child: Text('${_maxDisc.round()}%', style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.primary, fontFeatures: const [FontFeature.tabularFigures()])),
                          ),
                          Slider(
                            value: _maxDisc,
                            min: 10,
                            max: 60,
                            divisions: 10,
                            activeColor: AppColors.primary,
                            inactiveColor: AppColors.tonalBadge,
                            label: '${_maxDisc.round()}%',
                            onChanged: (v) => setState(() => _maxDisc = v),
                          ),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text('Min: 10%', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.mutedText)),
                            Text('Standar: 30-40%', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                            Text('Max: 60%', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.mutedText)),
                          ]),
                          const Divider(height: 24, color: AppColors.outline),
                          Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Jam Tutup Warung', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                const SizedBox(height: 4),
                                Text('${_timeStr(_closing)} WIB', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary, fontFeatures: const [FontFeature.tabularFigures()])),
                                const SizedBox(height: 2),
                                Text('Diskon mulai ${_interventionStr()} WIB', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.mutedText, fontFeatures: const [FontFeature.tabularFigures()])),
                              ]),
                            ),
                            OutlinedButton(
                              onPressed: _pickTime,
                              style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999))),
                              child: const Text('Ubah'),
                            ),
                          ]),
                          const Divider(height: 24, color: AppColors.outline),
                          InkWell(
                            onTap: () => setState(() => _broadcast = !_broadcast),
                            borderRadius: BorderRadius.circular(8),
                            child: Row(children: [
                              Checkbox(value: _broadcast, onChanged: (v) => setState(() => _broadcast = v ?? true), activeColor: AppColors.primary),
                              const SizedBox(width: 4),
                              Expanded(child: Text('Kirim notifikasi broadcast WhatsApp ke pelanggan setia terdekat saat promo anti-mubazir aktif.', style: GoogleFonts.plusJakartaSans(fontSize: 12, height: 1.4, color: AppColors.textPrimary))),
                            ]),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      // Live Preview
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.outline), boxShadow: const [BoxShadow(color: Color(0x0A1E293B), blurRadius: 10, offset: Offset(0, 4))]),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(width: 32, height: 32, decoration: BoxDecoration(color: AppColors.tonalBadge, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.primary)),
                            const SizedBox(width: 8),
                            Text('Pratinjau Katalog Konsumen', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: _preview != null && _preview!.isActive ? const Color(0xFFE8F5E9) : AppColors.tonalBadge, borderRadius: BorderRadius.circular(9999)),
                              child: Text(_preview != null && _preview!.isActive ? 'Live' : 'Pratinjau', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: _preview != null && _preview!.isActive ? const Color(0xFF2E7D32) : AppColors.mutedText)),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.outline)),
                            child: Row(children: [
                              Container(width: 52, height: 52, decoration: BoxDecoration(color: AppColors.tonalBadge, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.rice_bowl, size: 26, color: AppColors.primary)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(_preview?.menuName ?? 'Nasi Goreng Spesial', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                  const SizedBox(height: 2),
                                  Row(children: [
                                    if (_preview != null && _preview!.discount > 0) ...[
                                      Text(_idr(_preview!.originalPrice), style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.mutedText, decoration: TextDecoration.lineThrough, fontFeatures: const [FontFeature.tabularFigures()])),
                                      const SizedBox(width: 6),
                                      Text(_idr(_preview!.discountedPrice), style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF2E7D32), fontFeatures: const [FontFeature.tabularFigures()])),
                                    ] else ...[
                                      Text(_preview != null ? _idr(_preview!.originalPrice) : 'Rp25.000', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFeatures: const [FontFeature.tabularFigures()])),
                                    ],
                                  ]),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: AppColors.tonalBadge, borderRadius: BorderRadius.circular(9999)),
                                    child: Text('Sisa ${_preview?.remaining ?? 4} porsi', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary, fontFeatures: const [FontFeature.tabularFigures()])),
                                  ),
                                ]),
                              ),
                              if (_preview != null && _preview!.discount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: const Color(0xFFC62828), borderRadius: BorderRadius.circular(8)),
                                  child: Text('-${_preview!.discount}%', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white, fontFeatures: const [FontFeature.tabularFigures()])),
                                ),
                            ]),
                          ),
                          if (_preview != null) ...[
                            const SizedBox(height: 8),
                            Text(_preview!.description, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.mutedText)),
                          ],
                        ]),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save_outlined, size: 18),
                          label: Text(_saving ? 'Menyimpan...' : 'Simpan Konfigurasi Harga'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999))),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text("Algoritma PADAN akan mengkalibrasi harga sesuai sisa stok aktual di tab 'Stok'.", textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.mutedText, height: 1.3)),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.time, required this.discount, required this.desc, this.isLast = false, this.isHighlighted = false});
  final String time;
  final int discount;
  final String desc;
  final bool isLast;
  final bool isHighlighted;
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isHighlighted ? AppColors.primary : (isLast ? AppColors.mutedText.withValues(alpha: 0.3) : AppColors.tonalBadge),
                shape: BoxShape.circle,
                border: Border.all(color: isHighlighted ? AppColors.primary : AppColors.outline, width: 1),
              ),
              child: Icon(isLast ? Icons.storefront : Icons.schedule, size: 14, color: isHighlighted ? Colors.white : (isLast ? AppColors.mutedText : AppColors.primary)),
            ),
            if (!isLast) Container(width: 2, height: 32, color: AppColors.outline),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$time WIB', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFeatures: const [FontFeature.tabularFigures()])),
                    const SizedBox(height: 2),
                    Text(desc, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.mutedText)),
                  ]),
                ),
                if (!isLast)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: isHighlighted ? const Color(0xFFC62828) : AppColors.tonalBadge, borderRadius: BorderRadius.circular(9999)),
                    child: Text(discount > 0 ? 'Diskon $discount%' : 'Tutup', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: isHighlighted ? Colors.white : AppColors.primary)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.mutedText.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(9999)),
                    child: Text('Sisa 0 Porsi', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.mutedText)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
