import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF0F1F4);
  static const line = Color(0xFFE7E8EC);
  static const text = Color(0xFF16181D);
  static const textMuted = Color(0xFF5B6270);
  static const accent = Color(0xFF2563EB);
  static const accentSoft = Color(0xFFE8EFFF);
  static const accentInk = Color(0xFF1E3A8A);
  static const onAccent = Color(0xFFFFFFFF);
  static const danger = Color(0xFFBA1A1A);
  static const playerTop = Color(0xFF1D4ED8);
  static const playerMid = Color(0xFF1E1B8F);
  static const playerBottom = Color(0xFF0F1030);
  static const onPlayer = Color(0xFFFFFFFF);
  static const onPlayerMuted = Color(0xC7FFFFFF);
  static const onPlayerFaint = Color(0x47FFFFFF);
}

// Newsreader is not bundled; use the closest system serif.
String get serifFamily =>
    defaultTargetPlatform == TargetPlatform.iOS ? 'Georgia' : 'serif';

TextStyle displayStyle(double size, {Color color = AppColors.text}) =>
    TextStyle(
      fontFamily: serifFamily,
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: color,
    );

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    primary: AppColors.accent,
    surface: AppColors.bg,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: Typography.blackMountainView.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.bg,
      indicatorColor: Colors.transparent,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w700,
          color: states.contains(WidgetState.selected)
              ? AppColors.accent
              : AppColors.textMuted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? AppColors.accent
              : AppColors.textMuted,
        ),
      ),
    ),
  );
}
