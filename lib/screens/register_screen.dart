import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/corner_leaf_decoration.dart';
import 'main_shell.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _warungNameController = TextEditingController();
  final _contactController = TextEditingController();
  final _passwordController = TextEditingController();

  static const List<String> _businessTypes = [
    'Warung Makan',
    'Katering',
    'Restoran Non-Chain',
  ];

  String? _selectedBusinessType;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _warungNameController.dispose();
    _contactController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBusinessType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih jenis usaha terlebih dahulu')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await AuthService.register(
        warungName: _warungNameController.text.trim(),
        phoneOrEmail: _contactController.text.trim(),
        businessType: _selectedBusinessType!,
        password: _passwordController.text,
      );
      if (!mounted) return;
      showSuccessDialog(
        context,
        title: 'Registrasi Berhasil',
        desc: 'Selamat datang, ${result.user.warungName}! Akun Anda berhasil dibuat.',
        onOk: _goToHome,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        title: 'Registrasi Gagal',
        desc: e.message,
      );
    } on Exception {
      if (!mounted) return;
      showErrorDialog(
        context,
        title: 'Registrasi Gagal',
        desc: 'Tidak dapat terhubung ke server. Pastikan backend berjalan.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
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
            child: CornerLeafDecoration(alignment: Alignment.topRight),
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            child: CornerLeafDecoration(alignment: Alignment.bottomLeft),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    // Logo & header
                    const Icon(
                      Icons.restaurant,
                      size: 64,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'PADAN',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Daftar Akun UMKM',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mulai selaraskan pangan Anda dan cegah sisa bersama PADAN.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AppColors.textPrimary.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Nama Warung / Usaha
                    TextFormField(
                      controller: _warungNameController,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        label: 'Nama Warung / Usaha',
                        icon: Icons.storefront_outlined,
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),

                    // Nomor HP / Email
                    TextFormField(
                      controller: _contactController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        label: 'Nomor HP / Email',
                        icon: Icons.person_outline,
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),

                    // Jenis Usaha (Dropdown)
                    DropdownButtonFormField<String>(
                      initialValue: _selectedBusinessType,
                      isExpanded: true,
                      decoration: _inputDecoration(
                        label: 'Jenis Usaha',
                        icon: Icons.category_outlined,
                      ),
                      items: _businessTypes
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(
                                type,
                                style:
                                    const TextStyle(color: AppColors.textPrimary),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(
                        () => _selectedBusinessType = value,
                      ),
                      validator: (v) => (v == null) ? 'Pilih jenis usaha' : null,
                    ),
                    const SizedBox(height: 16),

                    // Kata Sandi
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: _inputDecoration(
                        label: 'Kata Sandi',
                        icon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 28),

                    // CTA Daftar
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text('Daftar'),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Footer navigation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Sudah punya akun? ',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          ),
                          child: const Text(
                            'Masuk di sini',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: AppColors.textPrimary),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}