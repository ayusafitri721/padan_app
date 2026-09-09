// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/api_service.dart';
import '../utils/file_saver.dart';
import '../utils/web_download.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProfileDetails? _data;
  bool _loading = true;
  String? _error;
  bool _savingAi = false;
  bool _syncing = false;
  late String _mode; // MODERATE / AGGRESSIVE
  late double _maxDisc;

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
      final d = await ProfileService.fetchDetails();
      if (!mounted) return;
      setState(() {
        _data = d;
        _mode = d.ai.mode;
        _maxDisc = d.ai.maxDisc.toDouble();
        _loading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Gagal memuat profil.';
        _loading = false;
      });
    }
  }

  Future<void> _saveAi() async {
    setState(() => _savingAi = true);
    try {
      final pref = await ProfileService.updateAi(mode: _mode, maxDisc: _maxDisc.round());
      if (!mounted) return;
      setState(() {
        _data = ProfileDetails(
          userName: _data!.userName,
          userEmail: _data!.userEmail,
          businessType: _data!.businessType,
          avatarUrl: _data!.avatarUrl,
          outlet: _data!.outlet,
          sub: _data!.sub,
          ai: pref,
          stats: _data!.stats,
          cert: _data!.cert,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preferensi AI tersimpan.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _savingAi = false);
    }
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    try {
      final t = await ProfileService.syncOffline();
      if (!mounted) return;
      setState(() {
        _data = ProfileDetails(
          userName: _data!.userName,
          userEmail: _data!.userEmail,
          businessType: _data!.businessType,
          avatarUrl: _data!.avatarUrl,
          outlet: _data!.outlet,
          sub: _data!.sub,
          ai: ProfileAiPref(mode: _data!.ai.mode, maxDisc: _data!.ai.maxDisc, lastSync: t),
          stats: _data!.stats,
          cert: _data!.cert,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sinkron: ${t.toLocal().toString().substring(0, 16)}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _downloadCert() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mengunduh sertifikat...')));
      final bytes = await ProfileService.downloadCert();
      if (!mounted) return;
      if (kIsWeb) {
        await downloadBytes(bytes, 'padan-sertifikat-bebas-mubazir.pdf');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sertifikat terunduh (${bytes.length} bytes)')));
      } else {
        final path = await saveBytesToFile(bytes, 'padan-sertifikat-bebas-mubazir.pdf');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sertifikat tersimpan di $path (${bytes.length} bytes)'), duration: const Duration(seconds: 4)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  bool _uploadingAvatar = false;

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 85);
      if (file == null) return;
      setState(() => _uploadingAvatar = true);
      await ProfileService.uploadAvatar(file);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto profil diperbarui.')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _editProfile() async {
    if (_data == null) return;
    final nameCtrl = TextEditingController(text: _data!.userName);
    final phoneCtrl = TextEditingController(text: _data!.userEmail);
    final bisnisCtrl = TextEditingController(text: _data!.businessType);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profil'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama Warung', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'HP / Email', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: bisnisCtrl, decoration: const InputDecoration(labelText: 'Jenis Usaha', border: OutlineInputBorder())),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Simpan')),
        ],
      ),
    );
    if (ok != true) return;
    final newName = nameCtrl.text.trim();
    final newPhone = phoneCtrl.text.trim();
    final newBisnis = bisnisCtrl.text.trim();
    if (newName.isEmpty || newPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama warung dan HP/Email wajib diisi.')));
      return;
    }
    try {
      await ProfileService.updateUser(
        warungName: newName,
        phoneOrEmail: newPhone,
        businessType: newBisnis,
      );
      AuthService.updateCurrentUser(warungName: newName, phoneOrEmail: newPhone, businessType: newBisnis);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil diperbarui.')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _editOutlet() async {
    if (_data == null) return;
    final outletCtrl = TextEditingController(text: _data!.outlet.name);
    final alamatCtrl = TextEditingController(text: _data!.outlet.address);
    final bukaCtrl = TextEditingController(text: _data!.outlet.open);
    final tutupCtrl = TextEditingController(text: _data!.outlet.close);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Outlet'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: outletCtrl, decoration: const InputDecoration(labelText: 'Nama Outlet', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: alamatCtrl, decoration: const InputDecoration(labelText: 'Alamat', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: bukaCtrl, decoration: const InputDecoration(labelText: 'Jam Buka (HH:MM)', hintText: '09:00', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: tutupCtrl, decoration: const InputDecoration(labelText: 'Jam Tutup (HH:MM)', hintText: '22:00', border: OutlineInputBorder())),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Simpan')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ProfileService.updateOutlet(
        outletName: outletCtrl.text.trim(),
        address: alamatCtrl.text.trim(),
        openingTime: bukaCtrl.text.trim(),
        closingTime: tutupCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Outlet diperbarui.')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _showNotif() {
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
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.tonalBadge, borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.verified_outlined, size: 18, color: AppColors.primary), const SizedBox(width: 8), Expanded(child: Text('Akun terverifikasi — Mitra Juara Nol-Mubazir.', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary)))])),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Tutup'))),
          ]),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
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
        title: const Text('Akun', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: _showNotif, icon: const Icon(Icons.notifications_outlined), tooltip: 'Notifikasi'),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: _pickAvatar,
              customBorder: const CircleBorder(),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white24,
                backgroundImage: _data?.avatarFullUrl != null ? NetworkImage(_data!.avatarFullUrl!) : null,
                child: _data?.avatarFullUrl != null
                    ? null
                    : Text(
                        (_data?.userName ?? AuthService.currentSession.value?.user.warungName ?? 'U').characters.first.toUpperCase(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
              ),
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
                      // Identitas
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.outline), boxShadow: const [BoxShadow(color: Color(0x0A1E293B), blurRadius: 10, offset: Offset(0, 4))]),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                InkWell(
                                  onTap: _pickAvatar,
                                  customBorder: const CircleBorder(),
                                  child: Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 40,
                                        backgroundColor: AppColors.tonalBadge,
                                        backgroundImage: _data!.avatarFullUrl != null ? NetworkImage(_data!.avatarFullUrl!) : null,
                                        child: _data!.avatarFullUrl != null
                                            ? null
                                            : Text(
                                                _data!.userName.characters.first.toUpperCase(),
                                                style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.primary),
                                              ),
                                      ),
                                      if (_uploadingAvatar)
                                        Positioned.fill(
                                          child: Container(
                                            decoration: const BoxDecoration(color: Color(0x80000000), shape: BoxShape.circle),
                                            child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                                          ),
                                        ),
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 26,
                                          height: 26,
                                          decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                                          child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  right: 32,
                                  bottom: 0,
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(color: const Color(0xFF22C55E), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                                    child: const Icon(Icons.check, size: 12, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(child: Text(_data!.userName, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: _editProfile,
                                  customBorder: const CircleBorder(),
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(color: AppColors.tonalBadge, shape: BoxShape.circle),
                                    child: const Icon(Icons.edit_outlined, size: 14, color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('${_data!.outlet.name} • ${_data!.businessType.isEmpty ? 'Pemilik & Penanggung Jawab Pangan' : _data!.businessType}', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.mutedText)),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: _editProfile,
                              child: Text('${_data!.userEmail} • Tap untuk edit profil', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.primary, decoration: TextDecoration.underline)),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(9999)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.star, size: 14, color: Color(0xFFD97706)),
                                const SizedBox(width: 4),
                                Text('Mitra Juara Nol-Mubazir', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF92400E))),
                              ]),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                _StatBox(label: 'Konsistensi', value: '${_data!.stats.days}', sub: 'Hari Aktif Selaras'),
                                Container(width: 1, height: 40, color: AppColors.outline),
                                _StatBox(label: 'Pangan Terjaga', value: '${_data!.stats.saved}', sub: 'Porsi Berkah'),
                                Container(width: 1, height: 40, color: AppColors.outline),
                                _StatBox(label: 'Skor Dapur', value: '${_data!.stats.score.toStringAsFixed(_data!.stats.score.truncateToDouble() == _data!.stats.score ? 0 : 1)}/5', sub: 'Sangat Efisien'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Lisensi Pro Plan
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primary, Color(0xFF2A4530)]),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: const [BoxShadow(color: Color(0x333A5A40), blurRadius: 18, offset: Offset(0, 8))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.workspace_premium, size: 18, color: Color(0xFFFFE082))),
                                const SizedBox(width: 10),
                                Expanded(child: Text('PADAN Pro Plan', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9999)),
                                  child: Text('Aktif s/d ${_fmtDate(_data!.sub.expiresAt)}', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Lisensi Gerai Terpadu', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white70)),
                            const SizedBox(height: 12),
                            _ProFeature(icon: Icons.cloud_done_outlined, text: 'AI BMKG Weather Spoilage Sync (Otomatis)'),
                            const SizedBox(height: 6),
                            _ProFeature(icon: Icons.sell_outlined, text: 'Dynamic Markdown Pricing Kasir Otomatis'),
                            const SizedBox(height: 6),
                            _ProFeature(icon: Icons.chat_outlined, text: 'WhatsApp Broadcast Promo Warga Sekitar'),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 40,
                                    child: ElevatedButton(
                                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kelola langganan — segera hadir'))),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999))),
                                      child: const Text('Kelola Langganan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: SizedBox(
                                    height: 40,
                                    child: OutlinedButton(
                                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tambah staf — segera hadir'))),
                                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999))),
                                      child: const Text('Tambah Staf', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Sertifikasi
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.outline), boxShadow: const [BoxShadow(color: Color(0x0A1E293B), blurRadius: 10, offset: Offset(0, 4))]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(width: 32, height: 32, decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.verified, size: 18, color: Color(0xFFD97706))),
                                const SizedBox(width: 10),
                                Expanded(child: Text('Sertifikasi Bebas Mubazir Emas', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(9999)), child: Text('Emas', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF92400E)))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('${_data!.cert['issuer'] ?? ''} • Berlaku hingga ${_data!.cert['valid_until'] ?? '2026-12-31'}', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.mutedText)),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 40,
                              child: OutlinedButton.icon(
                                onPressed: _downloadCert,
                                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                                label: const Text('Unduh PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999))),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Operasional & Kasir
                      _SectionCard(
                        title: 'Operasional & Kasir Warung',
                        children: [
                          _OpRow(icon: Icons.storefront_outlined, title: 'Profil Outlet & Jam Layanan', subtitle: '${_data!.outlet.address} • Buka ${_data!.outlet.open} - ${_data!.outlet.close}', onTap: _editOutlet),
                          _OpRow(icon: Icons.point_of_sale_outlined, title: 'Akses Kasir & Shift', subtitle: '2 Aktif: Dini Shift Pagi, Rian Shift Sore • PIN Akses', onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kelola kasir — segera hadir')))),
                          _OpRow(icon: Icons.chat_outlined, title: 'Notifikasi Rekap WhatsApp', subtitle: 'Terhubung 0812-3456-7890', onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengaturan WA — segera hadir'))), isLast: true),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Preferensi AI
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.outline), boxShadow: const [BoxShadow(color: Color(0x0A1E293B), blurRadius: 10, offset: Offset(0, 4))]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Preferensi Mesin AI PADAN', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            const SizedBox(height: 12),
                            Text('Sensitivitas Cuaca BMKG', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _ChoicePill(label: 'Moderat', sub: 'Rekomendasi', selected: _mode == 'MODERATE', onTap: () => setState(() => _mode = 'MODERATE')),
                                const SizedBox(width: 8),
                                _ChoicePill(label: 'Agresif', sub: 'Musim Hujan', selected: _mode == 'AGGRESSIVE', onTap: () => setState(() => _mode = 'AGGRESSIVE')),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Taktik sambal & lauk basah saat radar hujan lebat di Tebet.', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.mutedText)),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Text('Batas Diskon Jam Kritis', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                const Spacer(),
                                Text('${_maxDisc.round()}%', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary, fontFeatures: const [FontFeature.tabularFigures()])),
                              ],
                            ),
                            Slider(
                              value: _maxDisc,
                              min: 15,
                              max: 60,
                              divisions: 9,
                              activeColor: AppColors.primary,
                              inactiveColor: AppColors.tonalBadge,
                              label: '${_maxDisc.round()}%',
                              onChanged: (v) => setState(() => _maxDisc = v),
                            ),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text('Hemat Modal 15%', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.mutedText)),
                              Text('Obral Habis 60%', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.mutedText)),
                            ]),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('Sinkronisasi Kasir Offline', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                    Text(
                                      _data!.ai.lastSync == null ? 'Belum pernah sinkron' : 'Terakhir: ${_data!.ai.lastSync!.toLocal().toString().substring(0, 16)}',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.mutedText),
                                    ),
                                  ]),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  height: 36,
                                  child: OutlinedButton(
                                    onPressed: _syncing ? null : _sync,
                                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999))),
                                    child: _syncing
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                        : const Text('Sinkron', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton(
                                onPressed: _savingAi ? null : _saveAi,
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999))),
                                child: _savingAi
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('Simpan Preferensi AI', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Bantuan & Edukasi
                      _SectionCard(
                        title: 'Pusat Bantuan & Edukasi',
                        children: [
                          _OpRow(icon: Icons.support_agent_outlined, title: 'Konsultasi Pangan PADAN', subtitle: 'Resep olahan sisa & kendala POS', onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hubungi konsultan — support@padan.id')))),
                          _OpRow(icon: Icons.menu_book_outlined, title: 'Panduan SOP Kasir & Sisa Bahan', subtitle: 'Standar cold-chain UMKM', onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buka panduan — segera hadir')))),
                          _OpRow(
                            icon: Icons.logout,
                            title: 'Keluar dari Sesi Kasir',
                            subtitle: 'Kunci terminal kasir sebelum pergantian shift',
                            isDestructive: true,
                            onTap: () {
                              AuthService.logout();
                              Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Footer status
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.outline)),
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(child: Text('Terminal POS Terenkripsi Lokal & Cloud', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                            Text('v2.4.2', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.mutedText)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value, required this.sub});
  final String label;
  final String value;
  final String sub;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.mutedText)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary, fontFeatures: const [FontFeature.tabularFigures()])),
          Text(sub, textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.mutedText)),
        ],
      ),
    );
  }
}

class _ProFeature extends StatelessWidget {
  const _ProFeature({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white, height: 1.3))),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.outline), boxShadow: const [BoxShadow(color: Color(0x0A1E293B), blurRadius: 10, offset: Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _OpRow extends StatelessWidget {
  const _OpRow({required this.icon, required this.title, required this.subtitle, this.onTap, this.isLast = false, this.isDestructive = false});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isLast;
  final bool isDestructive;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: isLast ? null : const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.outline, width: 1))),
        child: Row(
          children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: isDestructive ? const Color(0xFFFEF2F2) : AppColors.tonalBadge, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: isDestructive ? const Color(0xFFDC2626) : AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: isDestructive ? const Color(0xFFDC2626) : AppColors.textPrimary)),
                Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.mutedText)),
              ]),
            ),
            Icon(isDestructive ? Icons.lock_outline : Icons.chevron_right, size: 18, color: isDestructive ? const Color(0xFFDC2626) : AppColors.mutedText),
          ],
        ),
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({required this.label, required this.sub, required this.selected, required this.onTap});
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.tonalBadge,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.primary : AppColors.outline),
          ),
          child: Column(
            children: [
              Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.primary)),
              Text(sub, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: selected ? Colors.white70 : AppColors.mutedText)),
            ],
          ),
        ),
      ),
    );
  }
}
