import 'package:flutter/material.dart';
import 'chatatan_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PrivacySecurityPage extends StatefulWidget {
  const PrivacySecurityPage({super.key});

  @override
  State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<PrivacySecurityPage> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _univController = TextEditingController();
  final _majorController = TextEditingController();
  final _semesterController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('users')
          .select('username, university, major, semester')
          .eq('id', user.id)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _usernameController.text = data['username'] ?? '';
          _univController.text = data['university'] ?? '';
          _majorController.text = data['major'] ?? '';
          _semesterController.text = data['semester']?.toString() ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memuat data: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User tidak ditemukan.');

      // 1. Update data profil ke Database
      await _supabase
          .from('users')
          .update({
            'username': _usernameController.text.trim(),
            'university': _univController.text.trim(),
            'major': _majorController.text.trim(),
            'semester': int.tryParse(_semesterController.text.trim()),
          })
          .eq('id', user.id);

      // 2. Update Password jika diisi
      if (_passwordController.text.isNotEmpty) {
        await _supabase.auth.updateUser(
          UserAttributes(password: _passwordController.text.trim()),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perubahan berhasil disimpan!')),
        );
        Navigator.pop(context, true); // Kembali & beri tanda bahwa data diubah
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _univController.dispose();
    _majorController.dispose();
    _semesterController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Privacy & Keamanan')),
      body: ChatatanAmbientBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ChatatanGlass(
                        radius: 25,
                        opacity: .70,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Informasi Profil & Akademik',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _usernameController,
                              decoration: const InputDecoration(
                                labelText: 'Username',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Username wajib diisi'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _univController,
                              decoration: const InputDecoration(
                                labelText: 'Universitas / Sekolah',
                                prefixIcon: Icon(Icons.school_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _majorController,
                              decoration: const InputDecoration(
                                labelText: 'Jurusan',
                                prefixIcon: Icon(Icons.book_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _semesterController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Semester',
                                prefixIcon: Icon(Icons.format_list_numbered),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ChatatanGlass(
                        radius: 25,
                        opacity: .70,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Keamanan Akun',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password Baru (opsional)',
                                helperText:
                                    'Kosongkan jika tidak ingin mengubah password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      ChatatanGlass(
                        radius: 20,
                        opacity: .78,
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            onPressed: _isSaving ? null : _saveChanges,
                            child: _isSaving
                                ? const SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Simpan Perubahan'),
                          ),
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
