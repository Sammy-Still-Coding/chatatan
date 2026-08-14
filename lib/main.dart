import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'chatatan_theme.dart';
import 'login_page.dart';
import 'main_navigation.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await Supabase.initialize(
    url: 'https://getipwvkqbhujoeqgxmz.supabase.co',
    publishableKey: 'sb_publishable_2RhYu4hdkHZOYwdaOYmHdg_W_YGMq87',
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFFF0F5FF),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ChatatanApp());
}

class ChatatanApp extends StatelessWidget {
  const ChatatanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'ChaTatan',

      theme: buildChatatanTheme(),

      home: Supabase.instance.client.auth.currentSession != null
          ? const MainNavigation()
          : const LoginPage(),
    );
  }
}
