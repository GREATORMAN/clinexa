import 'package:flutter/material.dart';


/// Clinexa V9 visual language.
///
/// The palette deliberately stays calm and clinical while giving the evaluator a
/// clearly differentiated, premium product surface. It is used by every shared
/// component so screens feel like one application instead of separate demos.
class ClinexaTheme {
  static const Color primary = Color(0xFFB779B0);
  static const Color primaryBright = Color(0xFFF0B4DA);
  static const Color accent = Color(0xFFA89AEF);
  static const Color accentSoft = Color(0xFFEFF1FF);
  static const Color navy = Color(0xFF17372C);
  static const Color ink = Color(0xFF233C33);
  static const Color muted = Color(0xFF6C7D74);
  static const Color canvas = Color(0xFFF4F5F0);
  static const Color canvasWarm = Color(0xFFFAFBFD);
  static const Color surfaceSoft = Color(0xFFF8F9F5);
  static const Color surfaceRaised = Color(0xFFFFFFFF);
  static const Color line = Color(0xFFE2E7DF);
  static const Color lineStrong = Color(0xFFD8E0EA);
  static const Color mint = Color(0xFFEAF3E9);
  static const Color sky = Color(0xFFEBF4FF);
  static const Color violet = Color(0xFFF1EEFF);
  static const Color amber = Color(0xFFFFF4D9);
  static const Color rose = Color(0xFFFFECEF);
  static const Color success = Color(0xFF18845F);
  static const Color warning = Color(0xFFB36A06);
  static const Color emergency = Color(0xFFC83E50);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF482441), Color(0xFF6B4279), Color(0xFFC084BA)],
    stops: [0, .54, 1],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC087B8), Color(0xFF8D79C9)],
  );

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      surface: surfaceRaised,
    ).copyWith(
      primary: const Color(0xFF82436F),
      onPrimary: Colors.white,
      secondary: const Color(0xFF675397),
      tertiary: primaryBright,
      error: emergency,
      surface: surfaceRaised,
      surfaceContainerLowest: surfaceRaised,
      surfaceContainerLow: surfaceSoft,
      surfaceContainer: const Color(0xFFF1F4F8),
      surfaceContainerHigh: const Color(0xFFE9EEF5),
      outline: lineStrong,
      outlineVariant: line,
      onSurface: ink,
      onSurfaceVariant: muted,
    );

    final inter = ThemeData.light().textTheme;
    final textTheme = inter.copyWith(
      displaySmall: inter.displaySmall?.copyWith(
        color: navy,
        fontWeight: FontWeight.w800,
        height: 1.02,
        letterSpacing: -1.35,
      ),
      headlineLarge: inter.headlineLarge?.copyWith(
        color: navy,
        fontWeight: FontWeight.w800,
        height: 1.06,
        letterSpacing: -1.15,
      ),
      headlineMedium: inter.headlineMedium?.copyWith(
        color: navy,
        fontWeight: FontWeight.w800,
        height: 1.08,
        letterSpacing: -.85,
      ),
      headlineSmall: inter.headlineSmall?.copyWith(
        color: navy,
        fontWeight: FontWeight.w800,
        height: 1.12,
        letterSpacing: -.55,
      ),
      titleLarge: inter.titleLarge?.copyWith(
        color: ink,
        fontWeight: FontWeight.w800,
        letterSpacing: -.35,
      ),
      titleMedium: inter.titleMedium?.copyWith(
        color: ink,
        fontWeight: FontWeight.w700,
        letterSpacing: -.15,
      ),
      titleSmall: inter.titleSmall?.copyWith(
        color: ink,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: inter.bodyLarge?.copyWith(color: ink, height: 1.5),
      bodyMedium: inter.bodyMedium?.copyWith(color: ink, height: 1.46),
      bodySmall: inter.bodySmall?.copyWith(color: muted, height: 1.42),
      labelLarge: inter.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      labelMedium: inter.labelMedium?.copyWith(fontWeight: FontWeight.w700),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
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
        color: surfaceRaised,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: line),
        ),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: const TextStyle(color: Color(0xFF98A4B5), fontWeight: FontWeight.w500),
        labelStyle: const TextStyle(color: muted, fontWeight: FontWeight.w600),
        prefixIconColor: const Color(0xFF7B8799),
        suffixIconColor: const Color(0xFF7B8799),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBright, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: emergency),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 18, vertical: 13)),
          textStyle: const WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.w700, letterSpacing: -.1)),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 17, vertical: 13)),
          textStyle: const WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.w700)),
          side: const WidgetStatePropertyAll(BorderSide(color: lineStrong)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          textStyle: const WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.w700)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
        labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: ink),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: navy,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primaryBright),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(color: Colors.white, fontSize: 11.5),
      ),
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark).copyWith(
      primary: const Color(0xFF955383), onPrimary: Colors.white,
      secondary: const Color(0xFFBCA5F4), onSecondary: const Color(0xFF151018),
      surface: const Color(0xFF211C25), onSurface: const Color(0xFFF6F0F6),
      onSurfaceVariant: const Color(0xFFBBAFBE),
      surfaceContainerLowest: const Color(0xFF101014), surfaceContainerLow: const Color(0xFF1B1820),
      surfaceContainer: const Color(0xFF28202D), outline: const Color(0xFF62536A), outlineVariant: const Color(0xFF3C303F),
      primaryContainer: const Color(0xFF39253B), secondaryContainer: const Color(0xFF2B253D),
    );
    final base = light;
    return base.copyWith(
      colorScheme: scheme, scaffoldBackgroundColor: const Color(0xFF101014),
      textTheme: base.textTheme.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
      appBarTheme: AppBarTheme(backgroundColor: scheme.surfaceContainerLowest, foregroundColor: scheme.onSurface, elevation: 0),
      cardTheme: CardThemeData(color: scheme.surface, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: scheme.outlineVariant))),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(fillColor: scheme.surfaceContainerLow, hintStyle: TextStyle(color: scheme.onSurfaceVariant), labelStyle: TextStyle(color: scheme.onSurfaceVariant), prefixIconColor: scheme.onSurfaceVariant),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: scheme.surface, showDragHandle: true),
      dialogTheme: DialogThemeData(backgroundColor: scheme.surface, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
      chipTheme: base.chipTheme.copyWith(backgroundColor: scheme.surfaceContainerLow, selectedColor: scheme.primaryContainer, labelStyle: TextStyle(color: scheme.onSurface), side: BorderSide(color: scheme.outlineVariant)),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    );
  }
}
