import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Menyimpan dan menerapkan preferensi tema untuk akun yang sedang aktif.
/// Preferensi diletakkan di auth user metadata agar mengikuti akun, bukan device.
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> loadForCurrentUser() async {
    final user = Supabase.instance.client.auth.currentUser;
    final value = user?.userMetadata?['dark_mode'];
    _apply(value == true || value?.toString() == 'true');
  }

  Future<void> setDarkMode(bool enabled) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _apply(false);
      return;
    }

    await Supabase.instance.client.auth.updateUser(
      UserAttributes(data: {'dark_mode': enabled}),
    );
    _apply(enabled);
  }

  void resetForLoggedOutUser() => _apply(false);

  void _apply(bool enabled) {
    if (_isDarkMode == enabled) {
      _updateSystemUi(enabled);
      return;
    }
    _isDarkMode = enabled;
    _updateSystemUi(enabled);
    notifyListeners();
  }

  void _updateSystemUi(bool dark) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: dark
            ? const Color(0xFF090E1D)
            : const Color(0xFFF0F5FF),
        systemNavigationBarIconBrightness: dark
            ? Brightness.light
            : Brightness.dark,
      ),
    );
  }
}
