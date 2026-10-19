import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Accent colors and geometry shared by both themes.
abstract final class AppColors {
  // Paleta Macrobuddy (design tokens).
  static const Color background = Color(0xFF0A0A0A);
  static const Color surfaceCard = Color(0xFF141416);
  static const Color surfaceAlt = Color(0xFF1C1C1F);
  static const Color border = Color(0xFF262629);
  static const Color primaryCoral = Color(0xFFFF6B6B);
  static const Color secondaryCyan = Color(0xFF00E5FF);
  static const Color tertiaryPurple = Color(0xFFB388FF);
  static const Color warningAmber = Color(0xFFFFB300);
  static const Color successGreen = Color(0xFF00E676);
  static const Color iconMuted = Color(0xFF6E6E73);
  static const Color textSecondary = Color(0xFFA0A0A0);
  static const Color danger = Color(0xFFFF3B30);

  // Alias legacy: mantienen las referencias de pantallas que aún no usan
  // los nuevos tokens (Fase C las migra).
  static const Color accentOrange = primaryCoral;
  static const Color accentBlue = secondaryCyan;
  static const Color accentPurple = tertiaryPurple;
  static const Color accentTeal = successGreen;
  static const Color coral = primaryCoral;
  static const Color coralLight = Color(0xFFFF8E53);
  static const Color inkOnAccent = Color(0xFF121212);
  static const Gradient caloriesGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [coral, coralLight],
  );

  static const double radiusCard = 20;
  static const double radiusInput = 8;
  static const double radiusGlass = 99;
  static const double screenPadding = 16;
}

/// Semantic colors that adapt to the active brightness.
@immutable
class ThemeColors extends ThemeExtension<ThemeColors> {
  const ThemeColors({
    required this.scaffold,
    required this.card,
    required this.input,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.iconMuted,
    required this.glassFill,
    required this.glassBorder,
  });

  final Color scaffold;
  final Color card;
  final Color input;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color iconMuted;

  // Capa funcional de cristal: relleno translúcido + borde de 1px.
  final Color glassFill;
  final Color glassBorder;

  static const ThemeColors dark = ThemeColors(
    scaffold: AppColors.background,
    card: AppColors.surfaceCard,
    input: AppColors.surfaceAlt,
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: AppColors.textSecondary,
    border: AppColors.border,
    iconMuted: AppColors.iconMuted,
    glassFill: Color(0xEB141416), // #141416 al 92 %
    glassBorder: Color(0x14FFFFFF), // blanco al 8 %
  );

  static ThemeColors of(BuildContext context) =>
      Theme.of(context).extension<ThemeColors>() ?? ThemeColors.dark;

  @override
  ThemeColors copyWith({
    Color? scaffold,
    Color? card,
    Color? input,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? iconMuted,
    Color? glassFill,
    Color? glassBorder,
  }) {
    return ThemeColors(
      scaffold: scaffold ?? this.scaffold,
      card: card ?? this.card,
      input: input ?? this.input,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      iconMuted: iconMuted ?? this.iconMuted,
      glassFill: glassFill ?? this.glassFill,
      glassBorder: glassBorder ?? this.glassBorder,
    );
  }

  @override
  ThemeColors lerp(ThemeExtension<ThemeColors>? other, double t) {
    if (other is! ThemeColors) return this;
    return ThemeColors(
      scaffold: Color.lerp(scaffold, other.scaffold, t)!,
      card: Color.lerp(card, other.card, t)!,
      input: Color.lerp(input, other.input, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      iconMuted: Color.lerp(iconMuted, other.iconMuted, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
    );
  }
}

/// Tipografía para datos: números tabulares alinean macros y pesos en columnas.
abstract final class AppTypography {
  static final TextStyle numeric = GoogleFonts.jetBrainsMono().copyWith(
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

abstract final class AppTheme {
  static final ThemeData dark = _build();

  static ThemeData _build() {
    const colors = ThemeColors.dark;
    final colorScheme = ColorScheme.dark(
      primary: AppColors.primaryCoral,
      secondary: AppColors.secondaryCyan,
      tertiary: AppColors.tertiaryPurple,
      surface: colors.card,
      onSurface: colors.textPrimary,
      onSurfaceVariant: colors.textSecondary,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.scaffold,
      extensions: [colors],
      textTheme: GoogleFonts.interTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.scaffold,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: colors.textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.input,
        hintStyle: TextStyle(color: colors.textSecondary),
        labelStyle: TextStyle(color: colors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusInput),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusInput),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusInput),
          borderSide: const BorderSide(color: AppColors.primaryCoral),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusInput),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusInput),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryCoral,
          foregroundColor: AppColors.inkOnAccent,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusCard),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.textPrimary,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}
