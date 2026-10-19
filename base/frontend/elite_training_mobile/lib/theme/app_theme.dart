import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Accent colors and geometry shared by both themes.
abstract final class AppColors {
  static const Color accentOrange = Color(0xFFFF9500);
  static const Color accentBlue = Color(0xFF0A84FF);
  static const Color accentPurple = Color(0xFFBF5AF2);
  static const Color accentTeal = Color(0xFF30D158);
  static const Color danger = Color(0xFFFF3B30);
  static const double radiusCard = 16;
  static const double radiusInput = 8;
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
  });

  final Color scaffold;
  final Color card;
  final Color input;
  final Color textPrimary;
  final Color textSecondary;

  static const ThemeColors dark = ThemeColors(
    scaffold: Color(0xFF121212),
    card: Color(0xFF1C1C1E),
    input: Color(0xFF2C2C2E),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF8E8E93),
  );

  static const ThemeColors light = ThemeColors(
    scaffold: Color(0xFFF2F2F7),
    card: Color(0xFFFFFFFF),
    input: Color(0xFFE5E5EA),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xFF6C6C70),
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
  }) {
    return ThemeColors(
      scaffold: scaffold ?? this.scaffold,
      card: card ?? this.card,
      input: input ?? this.input,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
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
    );
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void setDarkMode(bool dark) =>
      state = dark ? ThemeMode.dark : ThemeMode.light;

  void toggle() =>
      state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
}

abstract final class AppTheme {
  static final ThemeData dark = _build(ThemeColors.dark, Brightness.dark);
  static final ThemeData light = _build(ThemeColors.light, Brightness.light);

  static ThemeData _build(ThemeColors colors, Brightness brightness) {
    final colorScheme = brightness == Brightness.dark
        ? ColorScheme.dark(
            primary: AppColors.accentOrange,
            secondary: AppColors.accentBlue,
            surface: colors.card,
            onSurface: colors.textPrimary,
            onSurfaceVariant: colors.textSecondary,
            error: AppColors.danger,
          )
        : ColorScheme.light(
            primary: AppColors.accentOrange,
            secondary: AppColors.accentBlue,
            surface: colors.card,
            onSurface: colors.textPrimary,
            onSurfaceVariant: colors.textSecondary,
            error: AppColors.danger,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
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
