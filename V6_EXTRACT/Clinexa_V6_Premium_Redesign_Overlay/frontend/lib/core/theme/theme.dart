import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ClinexaTheme {
  static const Color primary = Color(0xFF006D68);
  static const Color primaryBright = Color(0xFF00A79D);
  static const Color navy = Color(0xFF0B1424);
  static const Color ink = Color(0xFF152033);
  static const Color muted = Color(0xFF6D7A8F);
  static const Color canvas = Color(0xFFF4F7FA);
  static const Color surfaceSoft = Color(0xFFF8FAFC);
  static const Color line = Color(0xFFE5EAF0);
  static const Color mint = Color(0xFFE7F7F4);
  static const Color sky = Color(0xFFEAF3FF);
  static const Color violet = Color(0xFFF1EDFF);
  static const Color amber = Color(0xFFFFF4DB);
  static const Color rose = Color(0xFFFFEDEF);
  static const Color success = Color(0xFF158A65);
  static const Color warning = Color(0xFFB46A00);
  static const Color emergency = Color(0xFFC93F4E);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      surface: Colors.white,
    ).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      secondary: primaryBright,
      tertiary: const Color(0xFF4567C6),
      error: emergency,
      surface: Colors.white,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: surfaceSoft,
      surfaceContainer: const Color(0xFFF0F4F7),
      surfaceContainerHigh: const Color(0xFFE9EEF3),
      outline: const Color(0xFFD8E0E8),
      outlineVariant: line,
      onSurface: ink,
      onSurfaceVariant: muted,
    );

    final base = GoogleFonts.manropeTextTheme();
    final textTheme = base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        color: navy,
        fontWeight: FontWeight.w800,
        height: 1.05,
        letterSpacing: -1.2,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        color: navy,
        fontWeight: FontWeight.w800,
        height: 1.08,
        letterSpacing: -1.0,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        color: navy,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -.7,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        color: navy,
        fontWeight: FontWeight.w800,
        height: 1.15,
        letterSpacing: -.4,
      ),
      titleLarge: base.titleLarge?.copyWith(
        color: ink,
        fontWeight: FontWeight.w800,
        letterSpacing: -.25,
      ),
      titleMedium: base.titleMedium?.copyWith(
        color: ink,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: base.titleSmall?.copyWith(
        color: ink,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: base.bodyLarge?.copyWith(color: ink, height: 1.48),
      bodyMedium: base.bodyMedium?.copyWith(color: ink, height: 1.45),
      bodySmall: base.bodySmall?.copyWith(color: muted, height: 1.4),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w800),
      labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w700),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: line),
        ),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSoft,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: const TextStyle(color: Color(0xFF97A3B4)),
        labelStyle: const TextStyle(color: muted, fontWeight: FontWeight.w600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryBright, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: emergency),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 50)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
          textStyle: const WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.w800)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 50)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
          textStyle: const WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.w800)),
          side: const WidgetStatePropertyAll(BorderSide(color: line)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          textStyle: const WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.w800)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceSoft,
        selectedColor: mint,
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ink),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 74,
        backgroundColor: Colors.white,
        indicatorColor: mint,
        shadowColor: const Color(0x160B1424),
        elevation: 10,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          fontSize: 10.5,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w700,
          color: states.contains(WidgetState.selected) ? primary : muted,
        )),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Colors.white,
        indicatorColor: mint,
        selectedIconTheme: IconThemeData(color: primary),
        unselectedIconTheme: IconThemeData(color: muted),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: navy,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primaryBright),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(seedColor: primaryBright, brightness: Brightness.dark);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF09101B),
      textTheme: GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme),
    );
  }
}
