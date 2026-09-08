import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../widgets/corner_leaf_decoration.dart';
import 'register_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const int _totalPages = 2;

  final List<Map<String, String>> _pages = [
    {
      'title': 'Prediksi Permintaan Cerdas',
      'description':
          'AI kami menganalisis pola penjualan, data cuaca BMKG, dan event '
              'lokal untuk merekomendasikan stok bahan baku secara tepat.',
    },
    {
      'title': 'Cegah Stok Mubazir',
      'description':
          'Kurangi limbah makanan sejak awal dengan pendekatan preventif dan '
              'fitur Dynamic Pricing otomatis menjelang tutup toko.',
    },
  ];

  bool get _isLastPage => _currentPage == _totalPages - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
  }

  void _goToNextPage() {
    if (_isLastPage) {
      // Arahkan ke halaman register setelah onboarding selesai
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RegisterScreen()),
      );
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _skip() {
    _pageController.jumpToPage(_totalPages - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Decorative line-art leaves at screen corners
          const Positioned(
            top: 0,
            right: 0,
            child: CornerLeafDecoration(
              alignment: Alignment.topRight,
            ),
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            child: CornerLeafDecoration(
              alignment: Alignment.bottomLeft,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
            // Skip button (top right)
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _skip,
                  child: Text(
                    'Lewati',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
            // PageView slides
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _totalPages,
                itemBuilder: (_, index) {
                  final page = _pages[index];
                  return _OnboardingSlide(
                    imagePath: index == 0
                        ? 'assets/img/on_board_1.jpg'
                        : 'assets/img/on_board_2.jpg',
                    title: page['title']!,
                    description: page['description']!,
                  );
                },
              ),
            ),
            // Bottom controls: dots (left) + button (right)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Row(
                children: [
                  // Dot indicator
                  _DotsIndicator(
                    total: _totalPages,
                    currentPage: _currentPage,
                  ),
                  const Spacer(),
                  // Primary button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _goToNextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                      ),
                      child: Text(
                        _isLastPage ? 'Mulai Sekarang' : 'Lanjut',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
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

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({
    required this.imagePath,
    required this.title,
    required this.description,
  });

  final String? imagePath;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 445),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (imagePath != null)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: height * 0.40,
              ),
              child: Image.asset(
                imagePath!,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
            if (imagePath != null) const SizedBox(height: 28),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: AppColors.textPrimary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({required this.total, required this.currentPage});

  final int total;
  final int currentPage;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (index) {
        final isActive = index == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 26 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.primary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
