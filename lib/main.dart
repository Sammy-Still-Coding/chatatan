import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Supabase
  await Supabase.initialize(
    url: 'https://getipwvkqbhujoeqgxmz.supabase.co',
    anonKey: 'sb_publishable_2RhYu4hdkHZOYwdaOYmHdg_W_YGMq87',
  );

  runApp(const AplikasiTes());
}

// Instance global Supabase
final supabase = Supabase.instance.client;

class AplikasiTes extends StatelessWidget {
  const AplikasiTes ({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aplikasi Chatatan',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // Aplikasi akan langsung menampilkan LoginPage saat dibuka
      home: const LoginPage(),
    );
  }
}