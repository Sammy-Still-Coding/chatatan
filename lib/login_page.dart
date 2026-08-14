import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chatatan_theme.dart';
import 'db_helper.dart';
import 'main_navigation.dart';
import 'password_recovery_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _dbHelper = DbHelper();

  bool _isLoading = false;
  bool _isRegister = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  late final AnimationController _authTabController;
  late Animation<double> _authTabAnimation;

  @override
  void initState() {
    super.initState();
    _authTabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _authTabAnimation = const AlwaysStoppedAnimation(0);
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final username = _usernameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Email dan password wajib diisi.', isError: true);
      return;
    }
    if (_isRegister && username.isEmpty) {
      _showMessage('Username wajib diisi.', isError: true);
      return;
    }
    if (_isRegister && !RegExp(r'^[a-zA-Z0-9_]{3,24}$').hasMatch(username)) {
      _showMessage(
        'Username harus 3–24 karakter dan hanya boleh huruf, angka, atau underscore.',
        isError: true,
      );
      return;
    }
    if (password.length < 6) {
      _showMessage('Password minimal 6 karakter.', isError: true);
      return;
    }
    if (_isRegister && password != confirmPassword) {
      _showMessage('Konfirmasi password belum sama.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isRegister) {
        final response = await _dbHelper.signUp(
          email: email,
          password: password,
          username: username,
        );
        if (!mounted) return;
        if (response.user != null) {
          _showMessage('Akun berhasil dibuat!');
          if (response.session != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MainNavigation()),
            );
          } else {
            final from = _authTabAnimation.value;
            setState(() => _isRegister = false);
            _authTabAnimation = Tween<double>(begin: from, end: 0).animate(
              CurvedAnimation(
                parent: _authTabController,
                curve: Curves.easeOutCubic,
              ),
            );
            _authTabController.forward(from: 0);
            _showMessage('Akun dibuat. Silakan cek email untuk verifikasi.');
          }
        }
      } else {
        final response = await _dbHelper.signIn(
          email: email,
          password: password,
        );
        if (!mounted) return;
        if (response.user != null) {
          _showMessage('Login berhasil!');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainNavigation()),
          );
        }
      }
    } on AuthException catch (error) {
      if (mounted) _showMessage(error.message, isError: true);
    } catch (error) {
      if (mounted) {
        _showMessage('Terjadi kesalahan: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _toggleMode() {
    final target = _isRegister ? 0.0 : 1.0;
    final from = _authTabAnimation.value;
    setState(() => _isRegister = !_isRegister);
    _authTabAnimation = Tween<double>(begin: from, end: target).animate(
      CurvedAnimation(parent: _authTabController, curve: Curves.easeOutCubic),
    );
    _authTabController.forward(from: 0);
  }

  @override
  void dispose() {
    _authTabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: ChatatanAmbientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    ChatatanGlass(
                      radius: 34,
                      opacity: .68,
                      blur: 28,
                      padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                      child: Column(
                        children: [
                          SizedBox(
                            width: 116,
                            height: 116,
                            child: Image.asset(
                              'assets/images/Logo ChaTatan Transparant.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'ChaTatan',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isRegister
                                ? 'Buat ruang belajar milikmu.'
                                : 'Catat, belajar, dan tumbuh bersama.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: ChatatanColors.muted,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    ChatatanGlass(
                      radius: 30,
                      opacity: .66,
                      blur: 26,
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildAuthSwitcher(),
                          const SizedBox(height: 21),
                          Text(
                            _isRegister
                                ? 'Buat akun baru'
                                : 'Selamat datang kembali',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _isRegister
                                ? 'Isi data berikut untuk bergabung.'
                                : 'Masuk untuk melanjutkan aktivitasmu.',
                            style: const TextStyle(
                              color: ChatatanColors.muted,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 19),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            child: Column(
                              children: [
                                if (_isRegister) ...[
                                  _authField(
                                    controller: _usernameController,
                                    label: 'Username',
                                    hint: 'Contoh: samuel',
                                    icon: Icons.person_outline_rounded,
                                  ),
                                  const SizedBox(height: 13),
                                ],
                                _authField(
                                  controller: _emailController,
                                  label: 'Email',
                                  hint: 'nama@email.com',
                                  icon: Icons.alternate_email_rounded,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 13),
                                _authField(
                                  controller: _passwordController,
                                  label: 'Password',
                                  hint: 'Minimal 6 karakter',
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: _obscurePassword,
                                  onSubmitted: _isRegister
                                      ? null
                                      : (_) => _submit(),
                                  suffix: IconButton(
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                if (_isRegister) ...[
                                  const SizedBox(height: 13),
                                  _authField(
                                    controller: _confirmPasswordController,
                                    label: 'Ulangi password',
                                    hint: 'Masukkan password yang sama',
                                    icon: Icons.verified_user_outlined,
                                    obscureText: _obscureConfirmPassword,
                                    onSubmitted: (_) => _submit(),
                                    suffix: IconButton(
                                      onPressed: () => setState(
                                        () => _obscureConfirmPassword =
                                            !_obscureConfirmPassword,
                                      ),
                                      icon: Icon(
                                        _obscureConfirmPassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (!_isRegister)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const PasswordRecoveryPage(),
                                  ),
                                ),
                                child: const Text('Lupa password?'),
                              ),
                            )
                          else
                            const SizedBox(height: 18),
                          SizedBox(
                            height: 54,
                            child: FilledButton(
                              onPressed: _isLoading ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: ChatatanColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 23,
                                      height: 23,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _isRegister ? 'Buat akun' : 'Masuk',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 13),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _isRegister
                                    ? 'Sudah punya akun?'
                                    : 'Belum punya akun?',
                                style: const TextStyle(
                                  color: ChatatanColors.muted,
                                ),
                              ),
                              TextButton(
                                onPressed: _isLoading ? null : _toggleMode,
                                child: Text(_isRegister ? 'Masuk' : 'Daftar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthSwitcher() => Container(
    height: 58,
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .34),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Colors.white.withValues(alpha: .84)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final segmentWidth = constraints.maxWidth / 2;
        const switcherHeight = 48.0;
        return Stack(
          children: [
            AnimatedBuilder(
              animation: _authTabController,
              builder: (context, _) {
                final t = _authTabController.value.clamp(0.0, 1.0);
                final stretch = math.sin(math.pi * t);
                final centerX = segmentWidth * (_authTabAnimation.value + .5);
                final bubbleWidth = segmentWidth * .94 + (22 * stretch);
                final bubbleHeight = switcherHeight * .86 - (8 * stretch);
                return Positioned(
                  left: centerX - bubbleWidth / 2,
                  top: (switcherHeight - bubbleHeight) / 2,
                  width: bubbleWidth,
                  height: bubbleHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(bubbleHeight / 2),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF7168F6).withValues(alpha: .76),
                          const Color(0xFF9D8AF5).withValues(alpha: .58),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .56),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ChatatanColors.primary.withValues(alpha: .18),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            Row(
              children: List.generate(2, (index) {
                final selected = (_isRegister ? 1 : 0) == index;
                final label = index == 0 ? 'Masuk' : 'Daftar';
                return Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: _isLoading || selected ? null : _toggleMode,
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 240),
                        style: TextStyle(
                          color: selected ? Colors.white : ChatatanColors.muted,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          fontSize: 14,
                        ),
                        child: Text(label),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      },
    ),
  );

  Widget _authField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
    ValueChanged<String>? onSubmitted,
  }) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    obscureText: obscureText,
    textInputAction: onSubmitted == null
        ? TextInputAction.next
        : TextInputAction.done,
    onSubmitted: onSubmitted,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      fillColor: Colors.white.withValues(alpha: .57),
    ),
  );
}
