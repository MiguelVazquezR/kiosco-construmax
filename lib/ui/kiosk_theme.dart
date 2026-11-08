import 'package:flutter/material.dart';

/// Brand colours shared by the kiosk widgets (same orange as the web kiosk).
///
/// Every colour of the UI comes from this palette: orange is reserved for
/// actions and selection, green for success, red for errors and amber for
/// warnings. No widget should declare a colour of its own.
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
  static const Color dangerBorder = Color(0xFFF5C2BF);
  static const Color warningSoft = Color(0xFFFFF7E6);
  static const Color warningBorder = Color(0xFFF3D9A4);
  static const Color warningText = Color(0xFF8A6100);
  static const Color cameraWarning = Color(0xFFFFD166);
  static const Color success = Color(0xFF12805C);
  static const Color successSoft = Color(0xFFE6F5EF);
  static const Color cameraBackground = Color(0xFF11161C);
  static const Color successScrim = Color(0xE611161C);
  static const Color white = Color(0xFFFFFFFF);
}

/// Spacing scale: multiples of 4.
class KioskSpacing {
  const KioskSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;

  /// Outer padding of the main content: 24 px in landscape, 20 px in portrait.
  static const EdgeInsets pageLandscape = EdgeInsets.symmetric(
    horizontal: xl,
    vertical: lg,
  );
  static const EdgeInsets pagePortrait = EdgeInsets.all(lg);
}

/// Corner radii of the component family.
class KioskRadius {
  const KioskRadius._();

  static const double card = 20;
  static const double option = 16;
  static const double button = 14;
  static const double key = 12;
  static const double display = 14;
  static const double banner = 12;
  static const double overlay = 24;

  static BorderRadius get cardRadius => BorderRadius.circular(card);
  static BorderRadius get optionRadius => BorderRadius.circular(option);
  static BorderRadius get buttonRadius => BorderRadius.circular(button);
  static BorderRadius get keyRadius => BorderRadius.circular(key);
  static BorderRadius get displayRadius => BorderRadius.circular(display);
  static BorderRadius get bannerRadius => BorderRadius.circular(banner);
  static BorderRadius get overlayRadius => BorderRadius.circular(overlay);
}

/// Elevations: only a very subtle shadow separates surfaces.
class KioskShadows {
  const KioskShadows._();

  /// `0 2px 10px rgba(31, 41, 51, 0.04)`.
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0A1F2933), blurRadius: 10, offset: Offset(0, 2)),
  ];
}

/// Type scale of the kiosk. The project uses the platform font (Roboto on
/// Android), so sizes and weights live here to keep the hierarchy consistent.
class KioskText {
  const KioskText._();

  static const TextStyle clock = TextStyle(
    fontSize: 42,
    fontWeight: FontWeight.w700,
    height: 1.05,
    color: KioskColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const TextStyle clockCompact = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.05,
    color: KioskColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle deviceName = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: KioskColors.textPrimary,
  );
  static const TextStyle deviceNameCompact = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: KioskColors.textPrimary,
  );

  static const TextStyle screenTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: KioskColors.textPrimary,
  );
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.w700,
    color: KioskColors.textPrimary,
  );
  static const TextStyle optionTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: KioskColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: KioskColors.textPrimary,
  );
  static const TextStyle secondary = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: KioskColors.textMuted,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: KioskColors.textMuted,
  );
  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1,
    color: KioskColors.textMuted,
  );
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
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: KioskColors.brand,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: KioskColors.brand,
        foregroundColor: KioskColors.white,
        disabledBackgroundColor: const Color(0x59F26C17),
        disabledForegroundColor: KioskColors.white,
        minimumSize: const Size.fromHeight(60),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: KioskRadius.buttonRadius),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: KioskColors.surface,
        foregroundColor: KioskColors.textPrimary,
        side: const BorderSide(color: KioskColors.border),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: KioskRadius.buttonRadius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: KioskColors.brand,
        minimumSize: const Size(48, 44),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    textTheme: const TextTheme(
      headlineMedium: KioskText.screenTitle,
      titleMedium: KioskText.optionTitle,
      bodyMedium: KioskText.body,
      bodySmall: KioskText.caption,
    ),
  );
}
