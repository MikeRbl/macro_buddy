import 'package:flutter/material.dart';

/// Accent colors and geometry shared by both themes.
abstract final class AppColors {
  static const Color accentOrange = Color(0xFFFF9500);
  static const Color accentBlue = Color(0xFF0A84FF);
  static const Color accentPurple = Color(0xFFBF5AF2);
  static const Color accentTeal = Color(0xFF30D158);
  static const Color danger = Color(0xFFFF3B30);

  // Macrobuddy tokens: energía (calorías), fuerza (entrenos) y cuerpo.
  static const Color coral = Color(0xFFFF6B6B);
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
    required this.glassFill,
    required this.glassBorder,
  });

  final Color scaffold;
  final Color card;
  final Color input;
  final Color textPrimary;
  final Color textSecondary;

  // Capa funcional de cristal: relleno translúcido + borde de 1px.
  final Color glassFill;
  final Color glassBorder;

  static const ThemeColors dark = ThemeColors(
    scaffold: Color(0xFF121212),
    card: Color(0xFF1C1C1E),
    input: Color(0xFF2C2C2E),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA0A0A0),
    glassFill: Color(0x0FFFFFFF),
    glassBorder: Color(0x1FFFFFFF),
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
    Color? glassFill,
    Color? glassBorder,
  }) {
    return ThemeColors(
      scaffold: scaffold ?? this.scaffold,
      card: card ?? this.card,
      input: input ?? this.input,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
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
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
    );
  }
}

/// Tipografía para datos: números tabulares alinean macros y pesos en columnas.
abstract final class AppTypography {
  static final TextStyle numeric = const TextStyle().copyWith(
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

abstract final class AppTheme {
  static final ThemeData dark = _build();

  static ThemeData _build() {
    const colors = ThemeColors.dark;
    final colorScheme = ColorScheme.dark(
      primary: AppColors.accentOrange,
      secondary: AppColors.accentBlue,
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
          borderSide: const BorderSide(color: AppColors.accentOrange),
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
          backgroundColor: colors.textPrimary,
          foregroundColor: colors.scaffold,
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
        ),
      ),
    );
  }
}
