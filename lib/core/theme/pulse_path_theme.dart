import 'package:flutter/material.dart';

abstract final class PulsePathColors {
  static const background = Color(0xFF070912);
  static const surface = Color(0xFF111521);
  static const surfaceBright = Color(0xFF181D2B);
  static const violet = Color(0xFF9B7BFF);
  static const blue = Color(0xFF5A8CFF);
  static const cyan = Color(0xFF42D9E8);
  static const textPrimary = Color(0xFFF5F7FF);
  static const textSecondary = Color(0xFF939BB0);
  static const divider = Color(0xFF252A3A);
}

abstract final class PulsePathSizes {
  static const heroCardRadius = 28.0;
  static const cardRadius = 22.0;
  static const compactCardRadius = 20.0;
  static const controlRadius = 16.0;
  static const controlHeight = 52.0;
}

abstract final class PulsePathTheme {
  static ThemeData get dark {
    const colorScheme = ColorScheme.dark(
      primary: PulsePathColors.violet,
      secondary: PulsePathColors.cyan,
      surface: PulsePathColors.surface,
      onSurface: PulsePathColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: PulsePathColors.background,
      colorScheme: colorScheme,
      fontFamily: 'sans-serif',
      textTheme:
          const TextTheme(
            displaySmall: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.1,
              height: 1.1,
            ),
            headlineSmall: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
            titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            bodyLarge: TextStyle(fontSize: 15, height: 1.5),
            bodyMedium: TextStyle(fontSize: 13, height: 1.45),
            labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ).apply(
            bodyColor: PulsePathColors.textPrimary,
            displayColor: PulsePathColors.textPrimary,
          ),
      cardTheme: CardThemeData(
        color: PulsePathColors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PulsePathSizes.cardRadius),
          side: const BorderSide(color: PulsePathColors.divider),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _primaryButtonStyle),
      filledButtonTheme: FilledButtonThemeData(style: _primaryButtonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(64, PulsePathSizes.controlHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          ),
          foregroundColor: const WidgetStatePropertyAll(
            PulsePathColors.textPrimary,
          ),
          textStyle: const WidgetStatePropertyAll(_buttonTextStyle),
          overlayColor: WidgetStatePropertyAll(
            PulsePathColors.violet.withValues(alpha: 0.08),
          ),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(
                color: PulsePathColors.divider.withValues(alpha: 0.55),
              );
            }
            return const BorderSide(color: PulsePathColors.divider);
          }),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PulsePathSizes.controlRadius),
            ),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PulsePathColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: const TextStyle(color: PulsePathColors.textSecondary),
        labelStyle: const TextStyle(color: PulsePathColors.textSecondary),
        floatingLabelStyle: const TextStyle(color: PulsePathColors.violet),
        border: _inputBorder(PulsePathColors.divider),
        enabledBorder: _inputBorder(PulsePathColors.divider),
        focusedBorder: _inputBorder(PulsePathColors.violet, width: 1.5),
        errorBorder: _inputBorder(colorScheme.error),
        focusedErrorBorder: _inputBorder(colorScheme.error, width: 1.5),
        disabledBorder: _inputBorder(
          PulsePathColors.divider.withValues(alpha: 0.55),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: PulsePathColors.divider,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: PulsePathColors.surface.withValues(alpha: 0.98),
        indicatorColor: PulsePathColors.violet.withValues(alpha: 0.16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? PulsePathColors.textPrimary
                : PulsePathColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          );
        }),
      ),
    );
  }

  static const _buttonTextStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
  );

  static ButtonStyle get _primaryButtonStyle {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(64, PulsePathSizes.controlHeight),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      ),
      backgroundColor: const WidgetStatePropertyAll(PulsePathColors.violet),
      foregroundColor: const WidgetStatePropertyAll(PulsePathColors.background),
      textStyle: const WidgetStatePropertyAll(_buttonTextStyle),
      elevation: const WidgetStatePropertyAll(0),
      overlayColor: WidgetStatePropertyAll(
        PulsePathColors.textPrimary.withValues(alpha: 0.12),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PulsePathSizes.controlRadius),
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(PulsePathSizes.controlRadius),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
