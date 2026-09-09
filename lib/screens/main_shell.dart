import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';
import 'harga_screen.dart';
import 'limbah_screen.dart';
import 'login_screen.dart';
import 'stok_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _goToTab(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(
            onGoToStok: () => _goToTab(1),
            onGoToAkun: () => _goToTab(4),
          ),
          StokScreen(onGoToAkun: () => _goToTab(4)),
          LimbahScreen(
            onGoToAkun: () => _goToTab(4),
            onGoToStok: () => _goToTab(1),
          ),
          HargaScreen(onGoToAkun: () => _goToTab(4)),
          const _AkunScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.outline, width: 1)),
          boxShadow: [
            // Surface Level 3 — spatial isolation from scrolling content
            BoxShadow(
              color: Color(0x0F1E293B),
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 76,
            child: Row(
              children: [
                for (int i = 0; i < _destinations.length; i++)
                  Expanded(
                    child: _NavItem(
                      icon: _destinations[i].icon,
                      selectedIcon: _destinations[i].selectedIcon,
                      label: _destinations[i].label,
                      selected: _index == i,
                      onTap: () => setState(() => _index = i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? AppColors.tonalBadge : Colors.transparent,
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Icon(
              selected ? selectedIcon : icon,
              size: 24,
              color: selected ? AppColors.primary : AppColors.mutedText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: selected ? AppColors.primary : AppColors.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Holds the list of bottom destinations.
const List<_Destination> _destinations = [
  _Destination(
    Icons.home_outlined,
    Icons.home,
    'Beranda',
  ),
  _Destination(
    Icons.inventory_2_outlined,
    Icons.inventory_2,
    'Stok',
  ),
  _Destination(
    Icons.recycling_outlined,
    Icons.recycling,
    'Limbah',
  ),
  _Destination(
    Icons.sell_outlined,
    Icons.sell,
    'Harga',
  ),
  _Destination(
    Icons.account_circle_outlined,
    Icons.account_circle,
    'Akun',
  ),
];

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fitur ini akan segera tersedia.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AkunScreen extends StatelessWidget {
  const _AkunScreen();

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentSession.value?.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Akun',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primary,
              child: Text(
                (user?.warungName ?? 'U').characters.first.toUpperCase(),
                style: const TextStyle(
                  fontSize: 36,
                  color: AppColors.cream,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user?.warungName ?? 'UMKM',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user?.businessType ?? '',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () {
                AuthService.logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout),
              label: const Text('Keluar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFC62828),
                side: const BorderSide(color: Color(0xFFC62828)),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}