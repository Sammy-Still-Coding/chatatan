import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'chatatan_theme.dart';
import 'login_page.dart';
import 'main_navigation.dart';
import 'theme_controller.dart';

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

  await ThemeController.instance.loadForCurrentUser();
  runApp(const ChatatanApp());
}

class ChatatanApp extends StatefulWidget {
  const ChatatanApp({super.key});

  @override
  State<ChatatanApp> createState() => _ChatatanAppState();
}

class _ChatatanAppState extends State<ChatatanApp> {
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      if (state.session == null) {
        ThemeController.instance.resetForLoggedOutUser();
      } else if (state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.initialSession) {
        ThemeController.instance.loadForCurrentUser();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) => MaterialApp(
        navigatorKey: appNavigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'ChaTatan',
        theme: buildChatatanTheme(),
        darkTheme: buildChatatanDarkTheme(),
        themeMode: Supabase.instance.client.auth.currentSession == null
            ? ThemeMode.light
            : ThemeController.instance.themeMode,
        home: Supabase.instance.client.auth.currentSession != null
            ? const MainNavigation()
            : const LoginPage(),
      ),
    );
  }
}
