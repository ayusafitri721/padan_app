import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/app_colors.dart';
import '../services/prediction_service.dart';
import '../services/sales_service.dart';
import 'detail_prediksi_screen.dart';

class StokScreen extends StatefulWidget {
  const StokScreen({super.key, this.onGoToAkun});

  final VoidCallback? onGoToAkun;

  @override
  State<StokScreen> createState() => _StokScreenState();
}

class _StokScreenState extends State<StokScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isHoliday = false;
  bool _loading = true;
  String? _error;
  List<MenuItem> _menus = [];
  final Map<int, int> _sold = {};
  final Map<int, PredictionPlan> _plans = {};

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  void _changeDate(int delta) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: delta)));
    _load();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'Pilih tanggal penjualan',
      cancelText: 'Batal',
      confirmText: 'Pilih',
      locale: const Locale('id', 'ID'),
    );
    if (picked != null && !_isSameDay(picked, _selectedDate)) {
      setState(() => _selectedDate = picked);
      await _load();
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final menusFuture = SalesService.fetchMenus();
      final dateStr = _dateOnly(_selectedDate);
      final recordFuture = SalesService.fetchByDate(dateStr);
      final menus = await menusFuture;
      final record = await recordFuture;
      final tomorrowStr = _dateOnly(_selectedDate.add(const Duration(days: 1)));
      final planResults = await Future.wait(
        menus.map((m) => PredictionService.fetchPlan(tomorrowStr, m.id)),
      );
      if (!mounted) return;
      setState(() {
        _menus = menus;
        _sold.clear();
        _plans.clear();
        for (final m in menus) {
          _sold[m.id] = record?.items[m.id] ?? 0;
        }
        for (int i = 0; i < menus.length; i++) {
          final plan = planResults[i];
          if (plan != null) _plans[menus[i].id] = plan;
        }
        _isHoliday = record?.isHolidayToggle ?? false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  int _targetTotal() =>
      _menus.fold(0, (sum, m) => sum + (m.targetPortions));

  int _soldTotal() =>
      _menus.fold(0, (sum, m) => sum + (_sold[m.id] ?? 0));

  double _efficiency() {
    final target = _targetTotal();
    if (target == 0) return 0;
    return _soldTotal() / target * 100;
  }

  String _remainingText(MenuItem menu) {
    final sisa = menu.targetPortions - (_sold[menu.id] ?? 0);
    if (sisa <= 0) return 'Habis';
    return '$sisa porsi';
  }

  String _topMenuText() {
    if (_menus.isEmpty) return 'Belum ada menu. Tambahkan menu untuk mulai mencatat.';
    MenuItem? top;
    var topSold = -1;
    for (final m in _menus) {
      final sold = _sold[m.id] ?? 0;
      if (sold > topSold) {
        topSold = sold;
        top = m;
      }
    }
    if (top == null || topSold <= 0) {
      return 'Belum ada penjualan tercatat. Isi porsi terjual tiap menu.';
    }
    return 'Menu Terlaris: ${top.name} ($topSold porsi)';
  }

  Future<void> _submit({required bool asDraft}) async {
    final items = _menus
        .where((m) => (_sold[m.id] ?? 0) > 0)
        .map((m) => {'menu_id': m.id, 'sold_portions': _sold[m.id] ?? 0})
        .toList();

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada porsi yang dicatat.')),
      );
      return;
    }

    final dateStr = _dateOnly(_selectedDate);
    final displayDate = _formattedDate();
    try {
      final summary = asDraft
          ? await SalesService.saveDraft(
              date: dateStr,
              isHolidayToggle: _isHoliday,
              items: items,
            )
          : await SalesService.saveDailyRecord(
              date: dateStr,
              isHolidayToggle: _isHoliday,
              items: items,
            );

      if (!mounted) return;
      if (asDraft) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Draf $displayDate tersimpan (${summary.totalSold}/${summary.totalTarget} porsi).',
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Data penjualan $displayDate tersimpan! Efisiensi ${summary.efficiencyPercent.toStringAsFixed(1)}%.',
          ),
        ),
      );

      final topMenu = _menus
          .where((m) => (_sold[m.id] ?? 0) > 0)
          .reduce((a, b) => (_sold[a.id] ?? 0) >= (_sold[b.id] ?? 0) ? a : b);

      await _load();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DetailPrediksiScreen(menuId: topMenu.id),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _openAddMenuDialog() async {
    final result = await showDialog<_MenuDraft>(
      context: context,
      builder: (_) => _MenuFormDialog(title: 'Tambah Menu'),
    );
    if (result == null || !mounted) return;

    try {
      final created = await SalesService.createMenu(
        MenuInput(
          name: result.name,
          category: result.category,
          targetPortions: result.targetPortions,
          price: result.price,
        ),
      );
      if (result.photoBytes != null && result.photoName != null) {
        await SalesService.uploadMenuPhoto(
          created.id,
          bytes: result.photoBytes!,
          filename: result.photoName!,
        );
      }
      if (!mounted) return;
      setState(() => _loading = true);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Menu berhasil ditambahkan.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _openEditMenuDialog(MenuItem menu) async {
    final result = await showDialog<_MenuDraft>(
      context: context,
      builder: (_) => _MenuFormDialog(
        title: 'Edit Menu',
        name: menu.name,
        category: menu.category,
        targetPortions: menu.targetPortions,
        price: menu.price,
        existingPhotoUrl: menu.photoUrl,
      ),
    );
    if (result == null || !mounted) return;

    try {
      await SalesService.updateMenu(
        menu.id,
        MenuInput(
          name: result.name,
          category: result.category,
          targetPortions: result.targetPortions,
          price: result.price,
        ),
      );
      if (result.photoBytes != null && result.photoName != null) {
        await SalesService.uploadMenuPhoto(
          menu.id,
          bytes: result.photoBytes!,
          filename: result.photoName!,
        );
      } else if (result.photoCleared && menu.photoUrl != null) {
        await SalesService.deleteMenuPhoto(menu.id);
      }
      if (!mounted) return;
      setState(() => _loading = true);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Menu berhasil diperbarui.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _confirmDeleteMenu(MenuItem menu) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Menu?'),
        content: Text(
          'Menu "${menu.name}" akan dihapus dari daftar aktif.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await SalesService.deleteMenu(menu.id);
      if (!mounted) return;
      setState(() => _loading = true);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Menu berhasil dihapus.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  String _formattedDate() {
    const idMonths = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return '${_selectedDate.day} ${idMonths[_selectedDate.month - 1]} ${_selectedDate.year}';
  }

  String _formattedBadgeDate() {
    if (_isToday) return 'Hari Ini, ${_formattedDate()}';
    const idDays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    // DateTime.weekday: Mon=1 .. Sun=7; map to Sen..Min
    final dayLabel = idDays[_selectedDate.weekday - 1];
    return '$dayLabel, ${_formattedDate()}';
  }

  void _showNotifications() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.tonalBadge,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.notifications_outlined,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Notifikasi',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close, size: 20, color: AppColors.mutedText),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.tonalBadge,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Stok hari ini belum dicatat — lengkapi sebelum tutup kasir.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Periksa sisa porsi indikator di daftar menu.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
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
        centerTitle: true,
        title: const Text(
          'Stok',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _showNotifications,
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifikasi',
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () {
                final go = widget.onGoToAkun;
                if (go != null) {
                  go();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Buka tab Akun')),
                  );
                }
              },
              customBorder: const CircleBorder(),
              child: const CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white24,
                child: Icon(Icons.person_outline, size: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    children: [
                      _RutinitasBadge(date: _formattedBadgeDate()),
                      const SizedBox(height: 12),
                      _DateFilter(
                        displayDate: _formattedBadgeDate(),
                        isToday: _isToday,
                        onPrev: () => _changeDate(-1),
                        onNext: () => _changeDate(1),
                        onPick: _pickDate,
                        onToday: () {
                          setState(() => _selectedDate = DateTime.now());
                          _load();
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isToday ? 'Input Penjualan Harian' : 'Penjualan — ${_formattedDate()}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isToday
                            ? 'Catat porsi terjual sebelum tutup kasir untuk menjaga akurasi prediksi stok esok hari.'
                            : 'Menampilkan data untuk ${_formattedBadgeDate()}. Geser tanggal untuk melihat riwayat atau rencanakan tahun depan.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppColors.mutedText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _HolidayToggle(
                        value: _isHoliday,
                        onChanged: (v) => setState(() => _isHoliday = v),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Daftar Menu & Porsi Terjual',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _openAddMenuDialog,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Tambah Menu'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 0,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      for (final menu in _menus) ...[
                        _MenuCard(
                          menu: menu,
                          sold: _sold[menu.id] ?? 0,
                          remainingText: _remainingText(menu),
                          plan: _plans[menu.id],
                          onChanged: (value) =>
                              setState(() => _sold[menu.id] = value),
                          onEdit: () => _openEditMenuDialog(menu),
                          onDelete: () => _confirmDeleteMenu(menu),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 8),
                      _AiSummaryCard(
                        totalSold: _soldTotal(),
                        totalTarget: _targetTotal(),
                        efficiency: _efficiency(),
                        isHoliday: _isHoliday,
                        topMenuLabel: _topMenuText(),
                      ),
                      const SizedBox(height: 20),
                      _SaveButtons(
                        saveLabel: _isToday
                            ? 'Simpan Data Penjualan Hari Ini'
                            : 'Simpan — ${_formattedDate()}',
                        onSave: () => _submit(asDraft: false),
                        onDraft: () => _submit(asDraft: true),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}

class _RutinitasBadge extends StatelessWidget {
  const _RutinitasBadge({required this.date});

  final String date;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.tonalBadge,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Text(
            'RUTINITAS TUTUP WARUNG',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.02,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          date,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.mutedText,
          ),
        ),
      ],
    );
  }
}

class _DateFilter extends StatelessWidget {
  const _DateFilter({
    required this.displayDate,
    required this.isToday,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
    required this.onToday,
  });

  final String displayDate;
  final bool isToday;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPick;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1E293B),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _DateArrow(icon: Icons.chevron_left, onTap: onPrev),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              onTap: onPick,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.tonalBadge,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        displayDate,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.expand_more, size: 16, color: AppColors.mutedText),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          _DateArrow(icon: Icons.chevron_right, onTap: onNext),
          if (!isToday) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onToday,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  'Hari Ini',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DateArrow extends StatelessWidget {
  const _DateArrow({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.outline, width: 1),
          color: AppColors.white,
        ),
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
    );
  }
}

class _HolidayToggle extends StatelessWidget {
  const _HolidayToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1E293B),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.tonalBadge,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_month_outlined,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Toko Libur / Tutup',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.tonalBadge,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        'Opsional',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Aktifkan jika warung libur agar AI tidak mencatat angka 0 sebagai penurunan tren peminat.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.secondary,
          ),
        ],
      ),
    );
  }
}

/// Thumbnail foto menu 52px — fallback ke ikon kategori bila belum ada foto
/// atau gagal dimuat.
/// Format rupiah ringkas: 15000 → Rp15.000
String _formatRp(int v) {
  final s = v.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final pos = s.length - i;
    buf.write(s[i]);
    if (pos > 1 && pos % 3 == 1) buf.write('.');
  }
  return 'Rp${buf.toString()}';
}

class _MenuPhoto extends StatelessWidget {  const _MenuPhoto({required this.menu, this.size = 52, this.iconSize = 26});

  final MenuItem menu;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final url = menu.photoUrl;
    if (url == null) {
      return Icon(menu.icon, size: iconSize, color: AppColors.primary);
    }
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          Icon(menu.icon, size: iconSize, color: AppColors.primary),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.menu,
    required this.sold,
    required this.remainingText,
    required this.onChanged,
    required this.onEdit,
    required this.onDelete,
    this.plan,
  });

  final MenuItem menu;
  final int sold;
  final String remainingText;
  final PredictionPlan? plan;
  final ValueChanged<int> onChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1E293B),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.tonalBadge,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                child: _MenuPhoto(menu: menu),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      menu.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Target: ${menu.targetPortions} porsi • Sisa: $remainingText',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.mutedText,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatRp(menu.price)}/porsi',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (plan != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            plan!.isManual
                                ? Icons.lock_outline
                                : Icons.auto_awesome,
                            size: 12,
                            color: plan!.isManual
                                ? AppColors.accent
                                : AppColors.secondary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Target Besok: ${plan!.lockedPortions} porsi '
                              '(${plan!.isManual ? 'Kalibrasi Manual' : 'Rekomendasi AI'})',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: plan!.isManual
                                    ? AppColors.accent
                                    : AppColors.secondary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.tonalBadge,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  '${menu.accuracy}%',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                icon: const Icon(
                  Icons.more_vert,
                  size: 18,
                  color: AppColors.mutedText,
                ),
                padding: EdgeInsets.zero,
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit Menu'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Hapus',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _QuickChip(
                label: 'Habis (${menu.targetPortions})',
                onTap: () => onChanged(menu.targetPortions),
              ),
              const SizedBox(width: 8),
              _QuickChip(
                label: '80%',
                onTap: () =>
                    onChanged((menu.targetPortions * 0.8).round()),
              ),
              const SizedBox(width: 8),
              _QuickChip(
                label: '50%',
                onTap: () =>
                    onChanged((menu.targetPortions * 0.5).round()),
              ),
              const Spacer(),
              _Stepper(
                value: sold,
                onChanged: onChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove,
            onTap: () => onChanged(value > 0 ? value - 1 : 0),
          ),
          Container(
            width: 1,
            height: 20,
            color: AppColors.outline,
          ),
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
          Container(
            width: 1,
            height: 20,
            color: AppColors.outline,
          ),
          _StepperButton(
            icon: Icons.add,
            onTap: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, size: 18, color: AppColors.mutedText),
      ),
    );
  }
}

class _AiSummaryCard extends StatelessWidget {
  const _AiSummaryCard({
    required this.totalSold,
    required this.totalTarget,
    required this.efficiency,
    required this.isHoliday,
    required this.topMenuLabel,
  });

  final int totalSold;
  final int totalTarget;
  final double efficiency;
  final bool isHoliday;
  final String topMenuLabel;

  @override
  Widget build(BuildContext context) {
    final percent = efficiency.clamp(0, 100).toDouble();
    final bestMenuLabel = isHoliday
        ? 'Warung ditandai libur hari ini.'
        : topMenuLabel;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1E293B),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Ringkasan AI Harian',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.tonalBadge,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  efficiency >= 90 ? 'Sangat Efisien' : 'Opsional',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$totalSold porsi terjual dari $totalTarget target',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${efficiency.toStringAsFixed(1)}% efisiensi',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppColors.mutedText,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 8,
              backgroundColor: AppColors.tonalBadge,
              valueColor: const AlwaysStoppedAnimation(AppColors.secondary),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.tonalBadge.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: AppColors.primary.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$bestMenuLabel Bahan sisa minimal! Hanya ${(totalTarget - totalSold).clamp(0, 1 << 31)} porsi total belum terserap hari ini.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textPrimary,
                    ),
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

class _SaveButtons extends StatelessWidget {
  const _SaveButtons({
    required this.onSave,
    required this.onDraft,
    this.saveLabel = 'Simpan Data Penjualan Hari Ini',
  });

  final VoidCallback onSave;
  final VoidCallback onDraft;
  final String saveLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.description_outlined, size: 20),
            label: Text(saveLabel),
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
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: onDraft,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.tonalBadge,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9999),
              ),
            ),
            child: const Text(
              'Simpan sebagai Draf',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuDraft {
  const _MenuDraft({
    required this.name,
    required this.category,
    required this.targetPortions,
    required this.price,
    this.photoBytes,
    this.photoName,
    this.photoCleared = false,
  });

  final String name;
  final String category;
  final int targetPortions;
  final int price;

  /// Foto baru dari galeri (diupload setelah menu tersimpan).
  final Uint8List? photoBytes;
  final String? photoName;

  /// True bila foto lama dihapus tanpa pengganti.
  final bool photoCleared;
}

class _MenuFormDialog extends StatefulWidget {
  const _MenuFormDialog({
    required this.title,
    this.name = '',
    this.category = 'Makanan Utama',
    this.targetPortions = 0,
    this.price = 25000,
    this.existingPhotoUrl,
  });

  final String title;
  final String name;
  final String category;
  final int targetPortions;
  final int price;

  /// URL foto yang sudah tersimpan (mode edit), null bila belum ada.
  final String? existingPhotoUrl;

  @override
  State<_MenuFormDialog> createState() => _MenuFormDialogState();
}

class _MenuFormDialogState extends State<_MenuFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _targetController;
  late final TextEditingController _priceController;
  late String _category;
  Uint8List? _photoBytes;
  String? _photoName;
  bool _photoCleared = false;
  bool _pickingPhoto = false;

  String? get _previewUrl =>
      _photoCleared ? null : widget.existingPhotoUrl;

  Future<void> _pickPhoto() async {
    if (_pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 80,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photoBytes = bytes;
        _photoName = picked.name;
        _photoCleared = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih foto: $e')),
      );
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  void _clearPhoto() {
    setState(() {
      _photoBytes = null;
      _photoName = null;
      _photoCleared = true;
    });
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _category = menuCategories.contains(widget.category)
        ? widget.category
        : 'Makanan Utama';
    _targetController =
        TextEditingController(text: widget.targetPortions.toString());
    _priceController =
        TextEditingController(text: widget.price.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final target = int.tryParse(_targetController.text.trim()) ?? 0;
    final price = int.tryParse(_priceController.text.trim()) ?? 25000;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama menu wajib diisi.')),
      );
      return;
    }
    Navigator.of(context).pop(
      _MenuDraft(
        name: name,
        category: _category,
        targetPortions: target,
        price: price < 1000 ? 1000 : price,
        photoBytes: _photoBytes,
        photoName: _photoName,
        photoCleared: _photoCleared && _photoBytes == null,
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    IconData? prefix,
    String? suffix,
    String? helper,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      suffixText: suffix,
      prefixIcon: prefix == null
          ? null
          : Icon(prefix, size: 20, color: AppColors.primary),
      filled: true,
      fillColor: AppColors.tonalBadge.withValues(alpha: 0.45),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        color: AppColors.mutedText,
      ),
      floatingLabelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
      hintStyle: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        color: AppColors.mutedText.withValues(alpha: 0.7),
      ),
      helperStyle: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        color: AppColors.mutedText,
      ),
      suffixStyle: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
      enabledBorder: border(AppColors.outline),
      focusedBorder: border(AppColors.primary, 1.5),
      errorBorder: border(AppColors.error, 1.5),
      focusedErrorBorder: border(AppColors.error, 1.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      title: Text(
        widget.title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              decoration: _fieldDecoration(
                label: 'Nama Menu',
                hint: 'contoh: Nasi Goreng Spesial',
                prefix: Icons.restaurant_outlined,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _targetController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              decoration: _fieldDecoration(
                label: 'Target Porsi',
                prefix: Icons.inventory_2_outlined,
                suffix: 'porsi',
                helper: 'Acuan porsi masak harian menu ini.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              decoration: _fieldDecoration(
                label: 'Harga per Porsi (Rp)',
                prefix: Icons.payments_outlined,
                helper: 'Dipakai pratinjau dynamic pricing.',
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Foto Menu (opsional)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.tonalBadge,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  child: _photoBytes != null
                      ? Image.memory(
                          _photoBytes!,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        )
                      : _previewUrl != null
                          ? Image.network(
                              _previewUrl!,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.fastfood,
                                size: 30,
                                color: AppColors.primary,
                              ),
                            )
                          : const Icon(
                              Icons.add_a_photo_outlined,
                              size: 30,
                              color: AppColors.primary,
                            ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickingPhoto ? null : _pickPhoto,
                        icon: _pickingPhoto
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.photo_library_outlined, size: 18),
                        label: Text(
                          _photoBytes != null || _previewUrl != null
                              ? 'Ganti Foto'
                              : 'Pilih dari Galeri',
                        ),
                      ),
                      if (_photoBytes != null || _previewUrl != null)
                        TextButton.icon(
                          onPressed: _clearPhoto,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Hapus Foto'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.error,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Kategori',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in menuCategories)
                  GestureDetector(
                    onTap: () => setState(() => _category = category),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _category == category
                            ? AppColors.primary
                            : AppColors.tonalBadge,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            categoryToIcon(category),
                            size: 16,
                            color: _category == category
                                ? Colors.white
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            category,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _category == category
                                  ? Colors.white
                                  : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.mutedText),
          child: Text(
            'Batal',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9999),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text(
            'Simpan',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedText),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }
}