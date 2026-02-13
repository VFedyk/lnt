import 'package:flutter/material.dart';

/// Semantic color extension for app-specific color roles.
///
/// Provides success, warning, and streak colors that adapt to light/dark theme,
/// complementing the Material 3 [ColorScheme] (which handles primary, secondary,
/// tertiary, and error roles).
///
/// Access via `context.appColors.success`, etc.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color streak;

  const AppColors({
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.streak,
  });

  static const light = AppColors(
    success: Color(0xFF2E7D32),
    onSuccess: Colors.white,
    warning: Color(0xFFF57C00),
    onWarning: Colors.white,
    streak: Color(0xFFEF6C00),
  );

  static const dark = AppColors(
    success: Color(0xFF81C784),
    onSuccess: Color(0xFF1B5E20),
    warning: Color(0xFFFFB74D),
    onWarning: Color(0xFF4E2600),
    streak: Color(0xFFFFB300),
  );

  @override
  AppColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? streak,
  }) {
    return AppColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      streak: streak ?? this.streak,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      streak: Color.lerp(streak, other.streak, t)!,
    );
  }
}

extension AppColorsExtension on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}

abstract class AppTheme {
  static const _primarySeed = Colors.blue;

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primarySeed,
        brightness: Brightness.light,
      ),
      extensions: const [AppColors.light],
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primarySeed,
        brightness: Brightness.dark,
      ),
      extensions: const [AppColors.dark],
    );
  }
}
