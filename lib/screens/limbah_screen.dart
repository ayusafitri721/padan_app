import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../services/waste_service.dart';
import '../services/api_service.dart';
import '../utils/web_download.dart';

class LimbahScreen extends StatefulWidget {
  const LimbahScreen({super.key, this.onGoToAkun, this.onGoToStok});
  final VoidCallback? onGoToAkun;
  final VoidCallback? onGoToStok;

  @override
  State<LimbahScreen> createState() => _LimbahScreenState();
}

class _LimbahScreenState extends State<LimbahScreen> {
  WasteSummary? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _data == null;
      _error = null;
    });
    try {
      final s = await WasteService.fetchSummary();
      if (!mounted) return;
      setState(() {
        _data = s;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Gagal memuat data limbah.';
        _loading = false;
      });
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.tonalBadge, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.recycling_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('Limbah bulan ini turun — pertahankan!', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary))),
              ]),
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Tutup'))),
          ]),
        ),
      ),
    );
  }

  bool _downloading = false;

  Future<void> _downloadReport() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mengunduh laporan...')));
      final bytes = await WasteService.downloadReport();
      if (!mounted) return;
      if (kIsWeb) {
        await downloadBytes(bytes, 'padan-laporan-limbah.pdf');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Laporan terunduh (${bytes.length} bytes)')));
      } else {
        // Mobile: belum simpan ke storage — tampilkan ukuran, bisa dikembangkan pakai path_provider/share
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Laporan siap (${bytes.length} bytes) — simpan file diimplementasikan untuk mobile.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _showProPlanDetail() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.tonalBadge, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.workspace_premium, color: AppColors.primary, size: 20)),
              const SizedBox(width: 12),
              Text('PADAN Pro Plan', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close, size: 20, color: AppColors.mutedText)),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.tonalBadge, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Aktif s/d 31 Des 2026', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                const SizedBox(height: 4),
                Text('Fitur AI & Cuaca BMKG • Prediksi stok harian, audit limbah otomatis, dan laporan PDF.', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textPrimary, height: 1.4)),
              ]),
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Tutup'))),
          ]),
        ),
      ),
    );
  }

  void _showKonsultan() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.tonalBadge, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.support_agent, color: AppColors.primary, size: 20)),
              const SizedBox(width: 12),
              Text('Konsultan PADAN', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close, size: 20, color: AppColors.mutedText)),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.tonalBadge, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('Konsultasi sisa porsi & resep daur pangan via chat. Hubungi tim PADAN untuk rekomendasi pengolahan limbah menjadi menu baru.', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, height: 1.4))),
              ]),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Membuka chat konsultan — hubungi support@padan.id')));
                },
                icon: const Icon(Icons.chat_outlined, size: 18),
                label: const Text('Hubungi via Chat'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999))),
              ),
            ),
          ]),
        ),
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentSession.value?.user;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('Limbah', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  child: _data!.hasData
                      ? ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    children: [
                      // Top badges
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: AppColors.tonalBadge, borderRadius: BorderRadius.circular(9999)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text('AUDIT PANGAN BERKELANJUTAN', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.04, color: AppColors.primary)),
                            ]),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(9999), border: Border.all(color: const Color(0xFFA5D6A7))),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.eco_outlined, size: 14, color: Color(0xFF2E7D32)),
                                const SizedBox(width: 4),
                                Text(_data!.levelLabel, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Financial cumulative card (sage)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primary, Color(0xFF2A4530)]),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [BoxShadow(color: Color(0x333A5A40), blurRadius: 18, offset: Offset(0, 8))],
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: -8,
                              right: -8,
                              child: Container(width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08))),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('DAMPAK FINANSIAL KUMULATIF', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.06, color: Colors.white70)),
                                    const Spacer(),
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                                      child: const Icon(Icons.savings_outlined, color: Color(0xFFFFE082), size: 20),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(_idr(_data!.financialCumulativeIdr), style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white, fontFeatures: const [FontFeature.tabularFigures()])),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Text('Bulan Ini', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70)),
                                          const SizedBox(height: 4),
                                          Text('${_data!.monthSavedPortions} Porsi', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, fontFeatures: const [FontFeature.tabularFigures()])),
                                          Text('Makanan diselamatkan', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white70)),
                                        ]),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Text('Emisi Tercegah', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70)),
                                          const SizedBox(height: 4),
                                          Text('${_data!.co2ReducedKg.toStringAsFixed(_data!.co2ReducedKg.truncateToDouble() == _data!.co2ReducedKg ? 0 : 1)} kg CO₂e', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, fontFeatures: const [FontFeature.tabularFigures()])),
                                          Text('Jejak karbon', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white70)),
                                        ]),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Chart card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.outline), boxShadow: const [BoxShadow(color: Color(0x0A1E293B), blurRadius: 10, offset: Offset(0, 4))]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('Grafik Penurunan Limbah', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                    const SizedBox(height: 2),
                                    Text('Evaluasi berkala 4 bulan terakhir', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.mutedText)),
                                  ]),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(9999)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.trending_down, size: 14, color: Color(0xFF2E7D32)),
                                      const SizedBox(width: 4),
                                      Text('${_data!.wasteReductionPercent}% Limbah', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF2E7D32))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 140,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  for (final p in _data!.chart)
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            Text('${p.wasteKg.toStringAsFixed(p.wasteKg.truncateToDouble() == p.wasteKg ? 0 : 1)} kg', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontFeatures: const [FontFeature.tabularFigures()])),
                                            const SizedBox(height: 6),
                                            Builder(builder: (_) {
                                              final maxKg = (_data!.chart.map((e) => e.wasteKg).reduce((a, b) => a > b ? a : b));
                                              final h = maxKg > 0 ? (p.wasteKg / maxKg * 88).clamp(12, 88).toDouble() : 12.0;
                                              final isLast = p == _data!.chart.last;
                                              return Container(
                                                height: h,
                                                decoration: BoxDecoration(
                                                  color: isLast ? AppColors.primary : AppColors.tonalBadge,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                              );
                                            }),
                                            const SizedBox(height: 8),
                                            Text(p.label, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedText)),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.tonalBadge.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(14)),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.lightbulb_outline, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_data!.insight, style: GoogleFonts.plusJakartaSans(fontSize: 12, height: 1.4, color: AppColors.textPrimary))),
                        ]),
                      ),
                      const SizedBox(height: 14),
                      // UMKM profile + subscription + actions
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.outline), boxShadow: const [BoxShadow(color: Color(0x0A1E293B), blurRadius: 10, offset: Offset(0, 4))]),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppColors.tonalBadge,
                                  child: Text((user?.warungName ?? 'W').characters.first.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppColors.primary)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(user?.warungName ?? 'Warung Saya', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                    Text(user?.businessType ?? 'UMKM Kuliner', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.mutedText)),
                                  ]),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(9999)),
                                  child: Text('UMKM Mitra', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF2E7D32))),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            InkWell(
                              onTap: _showProPlanDetail,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: AppColors.tonalBadge, borderRadius: BorderRadius.circular(14)),
                                child: Row(children: [
                                  Container(width: 32, height: 32, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.workspace_premium_outlined, size: 18, color: Colors.white)),
                                  const SizedBox(width: 10),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('PADAN Pro Plan', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                    Text('Aktif s/d 31 Des 2026 • Fitur AI & Cuaca BMKG', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.mutedText)),
                                  ])),
                                  const Icon(Icons.chevron_right, size: 20, color: AppColors.mutedText),
                                ]),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1, color: AppColors.outline),
                            _ActionRow(icon: Icons.picture_as_pdf_outlined, title: 'Laporan Lengkap Food Waste', subtitle: 'Unduh rekap bulanan format PDF', trailing: Icons.download_outlined, onTap: _downloadReport),
                            _ActionRow(
                              icon: Icons.verified_outlined,
                              title: 'Riwayat Audit Pangan Hijau',
                              subtitle: '${_data!.auditCount} kali validasi dapur ramah lingkungan',
                              trailing: Icons.chevron_right,
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Riwayat audit: ${_data!.auditCount} validasi tercatat')));
                              },
                            ),
                            _ActionRow(icon: Icons.chat_bubble_outline, title: 'Hubungi Konsultan PADAN', subtitle: 'Konsultasi sisa porsi & resep daur pangan', trailing: Icons.chevron_right, onTap: _showKonsultan, isLast: true),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Download report button (functional)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _downloading ? null : _downloadReport,
                          icon: _downloading
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                          label: Text(_downloading ? 'Mengunduh...' : 'Unduh Laporan PDF'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sertifikat Bebas Mubazir dibagikan!')));
                          },
                          icon: const Icon(Icons.eco_outlined, size: 18),
                          label: const Text('Bagikan Sertifikat Bebas Mubazir'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.tonalBadge,
                            foregroundColor: AppColors.primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  )
                      : _buildEmptyState(),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.tonalBadge,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.recycling_outlined,
                size: 44,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Belum ada data limbah',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _data?.insight ??
                  'Catat penjualan harian di tab Stok agar ringkasan limbah terisi otomatis.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                height: 1.5,
                color: AppColors.mutedText,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: widget.onGoToStok,
                icon: const Icon(Icons.edit_note_outlined, size: 18),
                label: const Text('Catat Penjualan Sekarang'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.title, required this.subtitle, required this.trailing, this.onTap, this.isLast = false});
  final IconData icon;
  final String title;
  final String subtitle;
  final IconData trailing;
  final VoidCallback? onTap;
  final bool isLast;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title — segera hadir'))),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: isLast ? null : const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.outline, width: 1))),
        child: Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.tonalBadge, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: AppColors.primary)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.mutedText)),
          ])),
          Icon(trailing, size: 18, color: AppColors.mutedText),
        ]),
      ),
    );
  }
}
