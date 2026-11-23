import 'package:flutter/material.dart';

/// PillPaatha design system — PillPaatha's OWN identity.
///
/// Guna's standing rule (23 Nov 2026): every project carries a unique
/// theme and colour pattern; design language is never reused across
/// projects. PillPaatha therefore deliberately does NOT use Kanakku's
/// palette (cream #F3F3F0 / deep green #1E6B4F / Fraunces+Manrope).
/// Only engineering patterns were reused, never visual identity.
///
/// PillPaatha's palette is a warm "care" palette, chosen for its
/// users — elderly patients and their family caregivers:
///  * background: soft peach  #FFF6EF
///  * primary:    deep violet #5B4B8A
///  * accent:     warm amber  #E8A33D
/// Type is large and friendly, tap targets are big, and contrast is
/// kept high for ageing eyes and bright daylight.
class PillTheme {
  static const primary = Color(0xFF5B4B8A); // deep violet
  static const primaryDark = Color(0xFF443763);
  static const accent = Color(0xFFE8A33D); // warm amber
  static const bg = Color(0xFFFFF6EF); // soft peach
  static const card = Colors.white;
  static const ink = Color(0xFF2B2440); // deep plum-ink, high contrast
  static const inkSoft = Color(0xFF6E6489);
  static const danger = Color(0xFFB3261E);
  static const cautionBg = Color(0xFFFFF0D2);
  static const sampleBg = Color(0xFFFBE3B8);

  static const cardRadius = 20.0;

  /// Tamil strings fall back to the platform's Noto Sans Tamil.
  static const tamilFallback = <String>['Noto Sans Tamil'];

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        surface: bg,
      ),
      scaffoldBackgroundColor: bg,
      fontFamilyFallback: tamilFallback,
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: ink,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          fontFamilyFallback: tamilFallback,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: Color(0xFFF0DFCE)),
        ),
      ),
      textTheme: base.textTheme.copyWith(
        // Elderly-first sizing: body text a step larger than default.
        bodyLarge: const TextStyle(fontSize: 18, color: ink, height: 1.35),
        bodyMedium: const TextStyle(fontSize: 16, color: ink, height: 1.35),
        titleLarge: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
        titleMedium: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 54),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryDark,
          minimumSize: const Size(48, 54),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: accent.withValues(alpha: 0.35),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// The safety line shown on every screen of the app (MVP item 5).
const String kSafetyLineEn = 'This app does not replace your doctor.';
const String kSafetyLineTa =
    'இந்த செயலி உங்கள் மருத்துவருக்கு மாற்றாகாது.';
