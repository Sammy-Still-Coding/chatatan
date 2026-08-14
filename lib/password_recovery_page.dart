import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chatatan_theme.dart';

class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({super.key});

  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _auth = Supabase.instance.client.auth;

  int _step = 0;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _message(String value, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value),
        backgroundColor: error ? Colors.red.shade700 : ChatatanColors.success,
      ),
    );
  }

  Future<void> _sendOtp({bool resend = false}) async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      _message('Masukkan alamat email yang valid.', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await _auth.resetPasswordForEmail(email);
      if (!mounted) return;
      setState(() => _step = 1);
      _message(
        resend
            ? 'Kode OTP baru sudah dikirim.'
            : 'Kode OTP pemulihan dikirim ke email Anda.',
      );
    } on AuthException catch (error) {
      if (mounted) _message(error.message, error: true);
    } catch (error) {
      if (mounted) _message('Gagal mengirim OTP: $error', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 8) {
      _message('Kode OTP harus terdiri dari 8 angka.', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final response = await _auth.verifyOTP(
        email: _emailController.text.trim().toLowerCase(),
        token: otp,
        type: OtpType.recovery,
      );
      if (response.session == null) {
        throw const AuthException('Sesi pemulihan tidak dapat dibuat.');
      }
      if (!mounted) return;
      setState(() => _step = 2);
      _message('OTP benar. Silakan buat password baru.');
    } on AuthException catch (error) {
      if (mounted) _message(error.message, error: true);
    } catch (error) {
      if (mounted)
        _message('OTP tidak dapat diverifikasi: $error', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updatePassword() async {
    final password = _passwordController.text;
    final confirmation = _confirmPasswordController.text;
    if (password.length < 6) {
      _message('Password minimal 6 karakter.', error: true);
      return;
    }
    if (password != confirmation) {
      _message('Konfirmasi password belum sama.', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await _auth.updateUser(UserAttributes(password: password));
      await _auth.signOut();
      if (!mounted) return;
      _message('Password berhasil diubah. Silakan masuk kembali.');
      Navigator.pop(context);
    } on AuthException catch (error) {
      if (mounted) _message(error.message, error: true);
    } catch (error) {
      if (mounted) _message('Gagal mengubah password: $error', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: ChatatanAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 20, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Lupa password',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: ChatatanGlass(
                        radius: 32,
                        opacity: .70,
                        blur: 28,
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          switchInCurve: Curves.easeOutCubic,
                          child: Column(
                            key: ValueKey(_step),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _stepHeader(),
                              const SizedBox(height: 24),
                              if (_step == 0) _emailStep(),
                              if (_step == 1) _otpStep(),
                              if (_step == 2) _passwordStep(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepHeader() {
    const titles = ['Pulihkan akun', 'Masukkan kode OTP', 'Password baru'];
    const descriptions = [
      'Kami akan mengirim kode pemulihan ke email akun ChaTatan Anda.',
      'Masukkan kode 6 angka yang dikirim ke email berikut.',
      'Buat password baru yang aman dan mudah Anda ingat.',
    ];
    const icons = [
      Icons.mark_email_unread_outlined,
      Icons.password_rounded,
      Icons.lock_reset_rounded,
    ];
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ChatatanColors.primary.withValues(alpha: .12),
            border: Border.all(color: Colors.white.withValues(alpha: .9)),
          ),
          child: Icon(icons[_step], size: 34, color: ChatatanColors.primary),
        ),
        const SizedBox(height: 16),
        Text(
          titles[_step],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        Text(
          descriptions[_step],
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13.5,
            color: ChatatanColors.muted,
            height: 1.4,
          ),
        ),
        if (_step == 1) ...[
          const SizedBox(height: 7),
          Text(
            _emailController.text.trim(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ChatatanColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
        const SizedBox(height: 19),
        Row(
          children: List.generate(3, (index) {
            final active = index <= _step;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                height: 5,
                margin: EdgeInsets.only(right: index == 2 ? 0 : 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: active
                      ? ChatatanColors.primary
                      : ChatatanColors.muted.withValues(alpha: .18),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _emailStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _sendOtp(),
        decoration: const InputDecoration(
          labelText: 'Email akun',
          hintText: 'nama@email.com',
          prefixIcon: Icon(Icons.alternate_email_rounded),
        ),
      ),
      const SizedBox(height: 18),
      _primaryButton('Kirim kode OTP', Icons.send_rounded, _sendOtp),
    ],
  );

  Widget _otpStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: _otpController,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        textAlign: TextAlign.center,
        maxLength: 8,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onSubmitted: (_) => _verifyOtp(),
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          letterSpacing: 8,
        ),
        decoration: const InputDecoration(
          counterText: '',
          labelText: 'Kode OTP',
          hintText: '00000000',
        ),
      ),
      const SizedBox(height: 18),
      _primaryButton('Verifikasi OTP', Icons.verified_rounded, _verifyOtp),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _loading ? null : () => _sendOtp(resend: true),
        child: const Text('Kirim ulang kode'),
      ),
      TextButton(
        onPressed: _loading ? null : () => setState(() => _step = 0),
        child: const Text('Ganti alamat email'),
      ),
    ],
  );

  Widget _passwordStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _passwordField(
        controller: _passwordController,
        label: 'Password baru',
        obscure: _obscurePassword,
        toggle: () => setState(() => _obscurePassword = !_obscurePassword),
      ),
      const SizedBox(height: 13),
      _passwordField(
        controller: _confirmPasswordController,
        label: 'Ulangi password baru',
        obscure: _obscureConfirmPassword,
        toggle: () =>
            setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
        onSubmitted: (_) => _updatePassword(),
      ),
      const SizedBox(height: 18),
      _primaryButton(
        'Simpan password baru',
        Icons.check_circle_rounded,
        _updatePassword,
      ),
    ],
  );

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback toggle,
    ValueChanged<String>? onSubmitted,
  }) => TextField(
    controller: controller,
    obscureText: obscure,
    textInputAction: onSubmitted == null
        ? TextInputAction.next
        : TextInputAction.done,
    onSubmitted: onSubmitted,
    decoration: InputDecoration(
      labelText: label,
      hintText: 'Minimal 6 karakter',
      prefixIcon: const Icon(Icons.lock_outline_rounded),
      suffixIcon: IconButton(
        onPressed: toggle,
        icon: Icon(
          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    ),
  );

  Widget _primaryButton(
    String label,
    IconData icon,
    Future<void> Function() action,
  ) => SizedBox(
    height: 54,
    child: FilledButton.icon(
      onPressed: _loading ? null : action,
      icon: _loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.3,
                color: Colors.white,
              ),
            )
          : Icon(icon),
      label: Text(label, style: const TextStyle(fontSize: 15.5)),
    ),
  );
}
