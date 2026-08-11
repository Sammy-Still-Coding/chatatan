import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_page.dart';
import 'main_navigation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://getipwvkqbhujoeqgxmz.supabase.co',
    publishableKey: 'sb_publishable_2RhYu4hdkHZOYwdaOYmHdg_W_YGMq87',
  );

  runApp(const ChatatanApp());
}

class ChatatanApp extends StatelessWidget {
  const ChatatanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ChaTatan',

      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple),

      home: Supabase.instance.client.auth.currentSession != null
          ? const MainNavigation()
          : const LoginPage(),
    );
  }
}
