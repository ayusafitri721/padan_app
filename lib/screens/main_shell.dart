import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';
import 'harga_screen.dart';
import 'limbah_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
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
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _MorphingNavBar(
        index: _index,
        onTap: (i) => setState(() => _index = i),
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

class _MorphingNavBar extends StatefulWidget {
  const _MorphingNavBar({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  State<_MorphingNavBar> createState() => _MorphingNavBarState();
}

class _MorphingNavBarState extends State<_MorphingNavBar> {
  static const _barHeight = 68.0;
  static const _notchHeight = 18.0;
  static const _notchWidth = 88.0;
  static const _bubbleSize = 54.0;
  static const _topRadius = 20.0;
  static const _bubbleWrapWidth = 80.0; // fixed width for bubble+label to keep center aligned

  double _prevCenter = 0;
  double _targetCenter = 0;
  bool _firstFrame = true;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final totalHeight = _barHeight + _notchHeight + bottomPad;

    return Container(
      color: AppColors.background,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: totalHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final seg = w / _destinations.length;
              final targetCenter = seg * (widget.index + 0.5);

              // Initialize or detect index change — update prev/target for animation
              if (_firstFrame) {
                _prevCenter = targetCenter;
                _targetCenter = targetCenter;
                _firstFrame = false;
              } else if (_targetCenter != targetCenter) {
                _prevCenter = _targetCenter;
                _targetCenter = targetCenter;
              }

              final isFirst = _prevCenter == _targetCenter && _targetCenter == targetCenter && _prevCenter == targetCenter;
              // Use TweenAnimationBuilder for smooth morphing; on first frame no animation
              return TweenAnimationBuilder<double>(
                duration: isFirst ? Duration.zero : const Duration(milliseconds: 380),
                curve: Curves.easeInOutCubicEmphasized,
                tween: Tween<double>(begin: _prevCenter, end: _targetCenter),
                builder: (context, notchCenter, _) {
                  // Safe boundary for edge tabs (Beranda 0 & Akun 4):
                  // 20-24px margin from screen edge for bubble+notch, not too inward to crowd neighbor (Stok).
                  // notch needs topRadius(20)+halfWidth(44)=64, bubble needs 40+24=64 → same 64.
                  // This keeps dome fully symmetric, not cut at corner, and gap to neighbor ~44px (no overlap).
                  final safeInset = _notchWidth / 2 + _topRadius; // 44+20=64 → bubble margin 24px, notch left 20px
                  final clampedCenter = notchCenter.clamp(safeInset, w - safeInset);

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        top: _notchHeight,
                        child: CustomPaint(
                          painter: _NavBarPainter(
                            notchCenter: clampedCenter,
                            notchWidth: _notchWidth,
                            notchHeight: _notchHeight,
                            topRadius: _topRadius,
                          ),
                        ),
                      ),
                      // Inactive items — keep layout stable, active slot is spacer
                      Positioned.fill(
                        top: _notchHeight,
                        child: Row(
                          children: List.generate(_destinations.length, (i) {
                            final selected = i == widget.index;
                            return Expanded(
                              child: InkWell(
                                onTap: () => widget.onTap(i),
                                customBorder: const CircleBorder(),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(height: 6),
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 200),
                                      child: selected
                                          ? const SizedBox(height: 24, key: ValueKey('spacer'))
                                          : Icon(
                                              _destinations[i].icon,
                                              key: ValueKey('inactive_$i'),
                                              size: 24,
                                              color: AppColors.mutedText,
                                            ),
                                    ),
                                    const SizedBox(height: 3),
                                    AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 200),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: selected ? Colors.transparent : AppColors.mutedText,
                                      ),
                                      child: Text(_destinations[i].label),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      // Floating bubble — centered exactly at notchCenter via fixed-width wrapper
                      Positioned(
                        left: clampedCenter - _bubbleWrapWidth / 2,
                        top: 2,
                        width: _bubbleWrapWidth,
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey('bubble_${widget.index}'),
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 360),
                          curve: Curves.easeOutBack,
                          builder: (context, scale, child) {
                            return Transform.scale(
                              scale: 0.88 + scale * 0.12,
                              child: Opacity(opacity: scale.clamp(0, 1).toDouble(), child: child),
                            );
                          },
                          child: Center(
                            child: _ActiveBubble(
                              icon: _destinations[widget.index].selectedIcon,
                              label: _destinations[widget.index].label,
                              size: _bubbleSize,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ActiveBubble extends StatelessWidget {
  const _ActiveBubble({required this.icon, required this.label, required this.size});
  final IconData icon;
  final String label;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.outline.withValues(alpha: 0.0), width: 1),
            boxShadow: const [
              BoxShadow(color: Color(0x1A3A5A40), blurRadius: 12, offset: Offset(0, 6)),
              BoxShadow(color: Color(0x0F1E293B), blurRadius: 24, offset: Offset(0, -2)),
            ],
          ),
          child: Icon(icon, size: 26, color: AppColors.primary),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(9999),
            boxShadow: const [BoxShadow(color: Color(0x143A5A40), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}

class _NavBarPainter extends CustomPainter {
  _NavBarPainter({
    required this.notchCenter,
    required this.notchWidth,
    required this.notchHeight,
    required this.topRadius,
  });
  final double notchCenter;
  final double notchWidth;
  final double notchHeight;
  final double topRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final notchLeft = notchCenter - notchWidth / 2;
    final notchRight = notchCenter + notchWidth / 2;

    Path buildPath() {
      return Path()
        ..moveTo(0, topRadius)
        ..arcToPoint(Offset(topRadius, 0), radius: Radius.circular(topRadius))
        ..lineTo((notchLeft - 12).clamp(topRadius, w - topRadius), 0)
        ..cubicTo(
          (notchLeft - 2).clamp(topRadius, w - topRadius),
          0,
          (notchLeft + 10).clamp(topRadius, w - topRadius),
          notchHeight * 0.55,
          (notchCenter - notchWidth * 0.18).clamp(topRadius, w - topRadius),
          notchHeight * 0.95,
        )
        ..cubicTo(
          (notchCenter - notchWidth * 0.08).clamp(topRadius, w - topRadius),
          notchHeight + 6,
          (notchCenter + notchWidth * 0.08).clamp(topRadius, w - topRadius),
          notchHeight + 6,
          (notchCenter + notchWidth * 0.18).clamp(topRadius, w - topRadius),
          notchHeight * 0.95,
        )
        ..cubicTo(
          (notchRight - 10).clamp(topRadius, w - topRadius),
          notchHeight * 0.55,
          (notchRight + 2).clamp(topRadius, w - topRadius),
          0,
          (notchRight + 12).clamp(topRadius, w - topRadius),
          0,
        )
        ..lineTo(w - topRadius, 0)
        ..arcToPoint(Offset(w, topRadius), radius: Radius.circular(topRadius))
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
    }

    // Shadow under bar (soft, no patahan)
    final shadowPath = buildPath();
    final shadowPaint = Paint()
      ..color = const Color(0x0F1E293B)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawPath(shadowPath.shift(const Offset(0, -2)), shadowPaint);

    final path = buildPath();
    final paint = Paint()..color = AppColors.white..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    // hairline top border — follow same clamped dome for kubah mulus tanpa lancip
    final borderPaint = Paint()
      ..color = AppColors.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final borderPath = Path()
      ..moveTo(0, topRadius)
      ..arcToPoint(Offset(topRadius, 0), radius: Radius.circular(topRadius))
      ..lineTo((notchLeft - 12).clamp(topRadius, w - topRadius), 0)
      ..cubicTo(
        (notchLeft - 2).clamp(topRadius, w - topRadius),
        0,
        (notchLeft + 10).clamp(topRadius, w - topRadius),
        notchHeight * 0.55,
        (notchCenter - notchWidth * 0.18).clamp(topRadius, w - topRadius),
        notchHeight * 0.95,
      )
      ..cubicTo(
        (notchCenter - notchWidth * 0.08).clamp(topRadius, w - topRadius),
        notchHeight + 6,
        (notchCenter + notchWidth * 0.08).clamp(topRadius, w - topRadius),
        notchHeight + 6,
        (notchCenter + notchWidth * 0.18).clamp(topRadius, w - topRadius),
        notchHeight * 0.95,
      )
      ..cubicTo(
        (notchRight - 10).clamp(topRadius, w - topRadius),
        notchHeight * 0.55,
        (notchRight + 2).clamp(topRadius, w - topRadius),
        0,
        (notchRight + 12).clamp(topRadius, w - topRadius),
        0,
      )
      ..lineTo(w - topRadius, 0)
      ..arcToPoint(Offset(w, topRadius), radius: Radius.circular(topRadius));
    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _NavBarPainter old) => old.notchCenter != notchCenter;
}

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