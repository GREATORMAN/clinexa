import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Clinexa V10 experience system.
///
/// Calm clinical neutrals, deep teal/indigo accents, restrained depth and
/// accessible contrast. Shared tokens live here so the product feels designed
/// as one system across patient, clinical and operations workspaces.
class ClinexaTheme {
  static const Color primary = Color(0xFF0E6F68);
  static const Color primaryBright = Color(0xFF2BB8AA);
  static const Color accent = Color(0xFF635BDF);
  static const Color accentSoft = Color(0xFFF0EFFF);
  static const Color navy = Color(0xFF12272C);
  static const Color ink = Color(0xFF1B2B31);
  static const Color muted = Color(0xFF66767D);
  static const Color canvas = Color(0xFFF5F7FA);
  static const Color canvasWarm = Color(0xFFFAFBFC);
  static const Color surfaceSoft = Color(0xFFF8FAFB);
  static const Color surfaceRaised = Color(0xFFFFFFFF);
  static const Color line = Color(0xFFE7EBEF);
  static const Color lineStrong = Color(0xFFD9E0E6);
  static const Color mint = Color(0xFFE8F7F3);
  static const Color sky = Color(0xFFECF4FF);
  static const Color violet = Color(0xFFF1EFFF);
  static const Color amber = Color(0xFFFFF5DD);
  static const Color rose = Color(0xFFFFECEF);
  static const Color success = Color(0xFF19845F);
  static const Color warning = Color(0xFFB66A08);
  static const Color emergency = Color(0xFFC63D50);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF102A2F), Color(0xFF17444A), Color(0xFF314E79)],
    stops: [0, .55, 1],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF159A8F), Color(0xFF635BDF)],
  );

  static const LinearGradient patientGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF123A3B), Color(0xFF245C64), Color(0xFF5860A8)],
  );

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      surface: surfaceRaised,
    ).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: mint,
      onPrimaryContainer: const Color(0xFF114C48),
      secondary: accent,
      onSecondary: Colors.white,
      secondaryContainer: accentSoft,
      onSecondaryContainer: const Color(0xFF37327C),
      tertiary: const Color(0xFF2B7895),
      error: emergency,
      surface: surfaceRaised,
      surfaceContainerLowest: surfaceRaised,
      surfaceContainerLow: surfaceSoft,
      surfaceContainer: const Color(0xFFF1F4F6),
      surfaceContainerHigh: const Color(0xFFEAF0F3),
      outline: lineStrong,
      outlineVariant: line,
      onSurface: ink,
      onSurfaceVariant: muted,
    );

    final base = ThemeData.light().textTheme;
    final textTheme = base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        color: navy,
        fontWeight: FontWeight.w800,
        height: 1.02,
        letterSpacing: -1.25,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        color: navy,
        fontWeight: FontWeight.w800,
        height: 1.04,
        letterSpacing: -1.15,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        color: navy,
        fontWeight: FontWeight.w800,
        height: 1.08,
        letterSpacing: -.9,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        color: navy,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -.6,
      ),
      titleLarge: base.titleLarge?.copyWith(
        color: ink,
        fontWeight: FontWeight.w800,
        letterSpacing: -.4,
      ),
      titleMedium: base.titleMedium?.copyWith(
        color: ink,
        fontWeight: FontWeight.w700,
        letterSpacing: -.2,
      ),
      titleSmall: base.titleSmall?.copyWith(
        color: ink,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: base.bodyLarge?.copyWith(color: ink, height: 1.48),
      bodyMedium: base.bodyMedium?.copyWith(color: ink, height: 1.46),
      bodySmall: base.bodySmall?.copyWith(color: muted, height: 1.42),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w700),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: surfaceRaised,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: line),
        ),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(color: Color(0xFF98A4AA), fontWeight: FontWeight.w500),
        labelStyle: const TextStyle(color: muted, fontWeight: FontWeight.w600),
        floatingLabelStyle: const TextStyle(color: primary, fontWeight: FontWeight.w700),
        prefixIconColor: const Color(0xFF74838A),
        suffixIconColor: const Color(0xFF74838A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: primaryBright, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: emergency),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: emergency, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 50)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 19, vertical: 14)),
          textStyle: const WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.w700, letterSpacing: -.1)),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 50)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
          textStyle: const WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.w700)),
          side: const WidgetStatePropertyAll(BorderSide(color: lineStrong)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
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
          minimumSize: const WidgetStatePropertyAll(Size(42, 42)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceSoft,
        selectedColor: mint,
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: const TextStyle(fontSize: 11.3, fontWeight: FontWeight.w700, color: ink),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: navy,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primaryBright),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(color: Colors.white, fontSize: 11.5),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(5),
        radius: const Radius.circular(10),
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.hovered) ? const Color(0xFFABB6BC) : const Color(0xFFC7D0D5)),
      ),
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(seedColor: primaryBright, brightness: Brightness.dark).copyWith(
      primary: const Color(0xFF5CD4C7),
      onPrimary: const Color(0xFF082D2A),
      primaryContainer: const Color(0xFF173F3D),
      onPrimaryContainer: const Color(0xFFB9F2EC),
      secondary: const Color(0xFFB8B3FF),
      onSecondary: const Color(0xFF22203B),
      secondaryContainer: const Color(0xFF34304E),
      onSecondaryContainer: const Color(0xFFEAE8FF),
      surface: const Color(0xFF182024),
      onSurface: const Color(0xFFF1F5F6),
      onSurfaceVariant: const Color(0xFFAFBBC0),
      surfaceContainerLowest: const Color(0xFF0F1518),
      surfaceContainerLow: const Color(0xFF161E22),
      surfaceContainer: const Color(0xFF1C272B),
      surfaceContainerHigh: const Color(0xFF263337),
      outline: const Color(0xFF516166),
      outlineVariant: const Color(0xFF2B383D),
      error: const Color(0xFFFF8393),
    );
    final base = light;
    return base.copyWith(
      colorScheme: scheme,
      canvasColor: scheme.surfaceContainerHigh,
      scaffoldBackgroundColor: const Color(0xFF0F1518),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      textTheme: base.textTheme.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: scheme.surfaceContainerLow,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: .72)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
