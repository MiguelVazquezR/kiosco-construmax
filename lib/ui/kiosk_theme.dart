import 'package:flutter/material.dart';

/// Brand colours shared by the kiosk widgets (same orange as the web kiosk).
class KioskColors {
  const KioskColors._();

  static const Color brand = Color(0xFFF26C17);
  static const Color brandSoft = Color(0xFFFFF1E6);
  static const Color background = Color(0xFFF6F7F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1F2933);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);
  static const Color danger = Color(0xFFD92D20);
  static const Color dangerSoft = Color(0xFFFEECEB);
  static const Color warningSoft = Color(0xFFFFF7E6);
  static const Color success = Color(0xFF12805C);
}

ThemeData buildKioskTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: KioskColors.brand,
    primary: KioskColors.brand,
    surface: KioskColors.surface,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: KioskColors.background,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: KioskColors.brand,
        minimumSize: const Size.fromHeight(56),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        foregroundColor: KioskColors.textPrimary,
        side: const BorderSide(color: KioskColors.border),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: KioskColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: KioskColors.textPrimary,
      ),
      bodyMedium: TextStyle(fontSize: 15, color: KioskColors.textPrimary),
      bodySmall: TextStyle(fontSize: 13, color: KioskColors.textMuted),
    ),
  );
}
