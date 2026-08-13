import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'db_helper.dart';
import 'main_navigation.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();

  final _dbHelper = DbHelper();

  bool _isLoading = false;
  bool _isRegister = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

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

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isRegister) {
        // ==========================
        // REGISTER
        // ==========================

        final response = await _dbHelper.signUp(
          email: email,
          password: password,
          username: username,
        );

        if (!mounted) return;

        if (response.user != null) {
          _showMessage('Akun berhasil dibuat!');

          // Kalau email confirmation aktif,
          // user belum tentu langsung login.
          if (response.session != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MainNavigation()),
            );
          } else {
            setState(() {
              _isRegister = false;
            });

            _showMessage('Akun dibuat. Silakan cek email untuk verifikasi.');
          }
        }
      } else {
        // ==========================
        // LOGIN
        // ==========================

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
    } on AuthException catch (e) {
      if (!mounted) return;

      _showMessage(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;

      _showMessage('Terjadi kesalahan: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
    setState(() {
      _isRegister = !_isRegister;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // LOGO
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),

                  const SizedBox(height: 28),

                  Text(
                    _isRegister ? 'Buat akun baru' : 'Selamat datang kembali!',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    _isRegister
                        ? 'Daftar untuk mulai menggunakan ChaTatan.'
                        : 'Masuk untuk melanjutkan ke ChaTatan.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                  ),

                  const SizedBox(height: 32),

                  // USERNAME
                  if (_isRegister) ...[
                    TextField(
                      controller: _usernameController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        hintText: 'Contoh: samuel',
                        prefixIcon: const Icon(Icons.person_outline),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],

                  // EMAIL
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'nama@email.com',
                      prefixIcon: const Icon(Icons.email_outlined),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // PASSWORD
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Minimal 6 karakter',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  if (_isRegister) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Ulangi password',
                        hintText: 'Masukkan password yang sama',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
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
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // BUTTON
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isRegister ? 'BUAT AKUN' : 'MASUK',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // SWITCH LOGIN / REGISTER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isRegister ? 'Sudah punya akun?' : 'Belum punya akun?',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),

                      TextButton(
                        onPressed: _isLoading ? null : _toggleMode,
                        child: Text(
                          _isRegister ? 'Masuk' : 'Daftar',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
