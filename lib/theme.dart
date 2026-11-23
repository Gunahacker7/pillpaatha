import 'package:flutter/material.dart';

/// PillPaatha V2 design system — Guna's reference boards (23 Nov
/// 2026, DESIGN-V2-SPEC.md). The Unique Theme/Colour Rule was
/// revoked for this app only, so PillPaatha V2 uses the boards'
/// teal/green health palette exactly:
///
///  * header / hero: deep teal gradient #0A5563 → #0F7A68
///  * primary action: green gradient #1DB56A → #12994E
///  * background: very light aqua-grey #EFF7F7
///  * cards: white, radius 20–24, soft teal-grey shadow
///  * text: deep navy-teal #123B4A, secondary #5E7A82
///  * taken #1FA055 / tint #E2F4E8 · missed #E5484D / tint #FDECEC
///    pending & snoozed amber #E8A33D / tint #FBF0DC
///
/// Type: Poppins (Latin) + Noto Sans Tamil, bundled so typography
/// is identical on every phone. Elderly-first sizes stay: body
/// 16–18px, primary buttons ≥54px tall.
class PillTheme {
  // Brand teal (headers, nav, brand marks).
  static const primary = Color(0xFF0F7A68);
  static const primaryDark = Color(0xFF0A5563);
  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A5563), Color(0xFF0F7A68)],
  );

  // Primary action green (buttons).
  static const action = Color(0xFF17A657);
  static const actionGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1DB56A), Color(0xFF12994E)],
  );

  static const accent = Color(0xFFE8A33D); // warm amber
  static const bg = Color(0xFFEFF7F7); // very light aqua-grey
  static const card = Colors.white;
  static const ink = Color(0xFF123B4A); // deep navy-teal
  static const inkSoft = Color(0xFF5E7A82);
  static const cardBorder = Color(0xFFDDEAE8);

  // Dose status colours + tints (boards).
  static const taken = Color(0xFF1FA055);
  static const takenTint = Color(0xFFE2F4E8);
  static const missed = Color(0xFFE5484D);
  static const missedTint = Color(0xFFFDECEC);
  static const pendingTint = Color(0xFFFBF0DC);
  static const neutralTint = Color(0xFFEAF1F2);
  static const danger = Color(0xFFE5484D);
  static const cautionBg = Color(0xFFFBF0DC);
  static const sampleBg = Color(0xFFFBF0DC);

  // Reminder hero (boards): deep teal + gold bell.
  static const bellGold = Color(0xFFF5B921);

  static const cardRadius = 22.0;

  static const cardShadow = [
    BoxShadow(
      color: Color(0x140A5563),
      blurRadius: 14,
      offset: Offset(0, 4),
    ),
  ];

  /// Bundled type (V2): Poppins for Latin, Noto Sans Tamil for
  /// Tamil — fetched by CI at build time (see the workflow file).
  static const fontLatin = 'PillSans';
  static const fontTamil = 'PillTamil';
  static const tamilFallback = <String>[fontTamil, 'Noto Sans Tamil'];

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        surface: bg,
      ),
      scaffoldBackgroundColor: bg,
      fontFamily: fontLatin,
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
        shadowColor: const Color(0x140A5563),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: cardBorder),
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
          backgroundColor: action,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 54),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryDark,
          minimumSize: const Size(48, 54),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: const BorderSide(color: Color(0xFFBFD9D4)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: takenTint,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? primaryDark : inkSoft,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? primaryDark : inkSoft,
          );
        }),
      ),
    );
  }
}

/// The safety line shown on every screen of the app (MVP item 5).
const String kSafetyLineEn = 'This app does not replace your doctor.';
const String kSafetyLineTa =
    'இந்த செயலி உங்கள் மருத்துவருக்கு மாற்றாகாது.';
