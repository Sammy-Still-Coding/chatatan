import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class ChatatanColors {
  static const background = Color(0xFFF0F5FF);
  static const ink = Color(0xFF111938);
  static const muted = Color(0xFF78839E);
  static const primary = Color(0xFF635BFF);
  static const secondary = Color(0xFF8D6BFF);
  static const accent = Color(0xFF69D2FF);
  static const success = Color(0xFF32CE8A);
}

class ChatatanGlass extends StatelessWidget {
  const ChatatanGlass({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = 24,
    this.opacity = .62,
    this.blur = 22,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double opacity;
  final double blur;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: opacity + .12),
                const Color(0xFFDDE7FF).withValues(alpha: opacity * .55),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: .88),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6678BE).withValues(alpha: .11),
                blurRadius: 24,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(radius),
                onTap: onTap,
                child: content,
              ),
            ),
    );
  }
}

Future<T?> showChatatanGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xFF111938).withValues(alpha: .20),
    elevation: 0,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: ChatatanGlass(
        radius: 30,
        opacity: .78,
        blur: 32,
        child: builder(sheetContext),
      ),
    ),
  );
}

class ChatatanSheetHandle extends StatelessWidget {
  const ChatatanSheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 42,
      height: 5,
      margin: const EdgeInsets.only(top: 10, bottom: 8),
      decoration: BoxDecoration(
        color: ChatatanColors.muted.withValues(alpha: .34),
        borderRadius: BorderRadius.circular(20),
      ),
    ),
  );
}

class ChatatanAmbientBackground extends StatelessWidget {
  const ChatatanAmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: ChatatanColors.background,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: -150,
          right: -120,
          child: _blob(const Color(0xFFB9B6FF).withValues(alpha: .30), 330),
        ),
        Positioned(
          top: 330,
          left: -170,
          child: _blob(const Color(0xFFBFE8FF).withValues(alpha: .28), 360),
        ),
        Positioned(
          bottom: -180,
          right: -150,
          child: _blob(const Color(0xFFE3C7FF).withValues(alpha: .23), 380),
        ),
        child,
      ],
    ),
  );

  static Widget _blob(Color color, double size) => IgnorePointer(
    child: ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 58, sigmaY: 58),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    ),
  );
}

ThemeData buildChatatanTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: ChatatanColors.primary,
    brightness: Brightness.light,
  );
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: ChatatanColors.background,
    fontFamily: 'Roboto',
    textTheme: ThemeData.light().textTheme.apply(
      bodyColor: ChatatanColors.ink,
      displayColor: ChatatanColors.ink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: ChatatanColors.ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      toolbarHeight: 76,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: ChatatanColors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      titleTextStyle: TextStyle(
        color: ChatatanColors.ink,
        fontSize: 21,
        fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white.withValues(alpha: .72),
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0xFF6678BE).withValues(alpha: .12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Colors.white.withValues(alpha: .88)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: .72),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: .9)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: .9)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: ChatatanColors.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ChatatanColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 50),
        shape: rounded,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ChatatanColors.primary,
        minimumSize: const Size(48, 50),
        side: BorderSide(color: Colors.white.withValues(alpha: .95)),
        backgroundColor: Colors.white.withValues(alpha: .55),
        shape: rounded,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ChatatanColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      foregroundColor: Colors.white,
      backgroundColor: ChatatanColors.primary,
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFFF8FAFF).withValues(alpha: .96),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFFF8FAFF),
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: Color(0xFFF8FAFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white.withValues(alpha: .65),
      selectedColor: const Color(0xFFDFDCFF),
      side: BorderSide(color: Colors.white.withValues(alpha: .9)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      labelStyle: const TextStyle(
        color: ChatatanColors.ink,
        fontWeight: FontWeight.w600,
      ),
    ),
    dividerColor: const Color(0xFFB9C5E4).withValues(alpha: .35),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ChatatanColors.ink.withValues(alpha: .94),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
