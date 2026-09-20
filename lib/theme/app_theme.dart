import 'package:flutter/material.dart';

import '../domain/asset.dart';

class AppColors {
  const AppColors._();

  static const paper = Color(0xFFFFFFFF);
  static const paper2 = Color(0xFFF4F1EC);
  static const sheet = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1C1B17);
  static const ink2 = Color(0xFF57544C);
  static const ink3 = Color(0xFF6E6A60);
  static const rule = Color(0xFFE3E0D8);
  static const mark = Color(0xFF8A4A2B);
  static const ok = Color(0xFF3D5A45);

  static const dayBackground = paper;
  static const daySurface = sheet;
  static const dayTextPrimary = ink;
  static const dayTextSecondary = ink2;
  static const dayOutline = rule;
  static const primary = ink;
  static const link = mark;
  static const danger = Color(0xFF8B2E2E);
  static const warning = mark;
  static const success = ok;

  static const nightBackground = Color(0xFF1A1915);
  static const nightSurface = Color(0xFF24221C);
  static const nightTextPrimary = Color(0xFFEDE8DC);
  static const nightTextSecondary = Color(0xFFA39B8C);
  static const graphNode = Color(0xFFEDE8DC);

  static Color typeDeep(AssetType type) => ink;

  static Color typeLight(AssetType type) => graphNode;
}

class AppTheme {
  const AppTheme._();

  static const eveningMatrix = <double>[
    .98,
    0,
    0,
    0,
    0,
    0,
    .955,
    0,
    0,
    0,
    0,
    0,
    .925,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  static const eveningColorFilter = ColorFilter.matrix(eveningMatrix);

  static ThemeData day() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.ink,
      primary: AppColors.ink,
      onPrimary: AppColors.sheet,
      surface: AppColors.sheet,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.ink2,
      outline: AppColors.rule,
      outlineVariant: AppColors.rule,
      secondaryContainer: AppColors.paper2,
      onSecondaryContainer: AppColors.ink,
      error: AppColors.danger,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.paper,
      textTheme: _textTheme(base.textTheme, AppColors.ink),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 22,
          height: 28 / 22,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.sheet,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.rule),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.paper2,
        labelStyle: const TextStyle(color: AppColors.ink2),
        floatingLabelStyle: const TextStyle(color: AppColors.ink),
        hintStyle: const TextStyle(color: AppColors.ink3),
        helperStyle: const TextStyle(color: AppColors.ink2),
        prefixIconColor: AppColors.ink2,
        suffixIconColor: AppColors.ink2,
        border: _inputBorder(AppColors.rule),
        enabledBorder: _inputBorder(AppColors.rule),
        focusedBorder: _inputBorder(AppColors.mark, width: 2),
        errorBorder: _inputBorder(AppColors.danger),
        focusedErrorBorder: _inputBorder(AppColors.danger, width: 2),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              minimumSize: const Size(64, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ).copyWith(
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.disabled)
                    ? AppColors.paper2
                    : AppColors.ink,
              ),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.disabled)
                    ? AppColors.ink2
                    : AppColors.sheet,
              ),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              minimumSize: const Size(64, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ).copyWith(
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.disabled)
                    ? AppColors.ink2
                    : AppColors.ink,
              ),
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style:
            TextButton.styleFrom(
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ).copyWith(
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.disabled)
                    ? AppColors.ink2
                    : AppColors.mark,
              ),
            ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.sheet,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.paper2,
        elevation: 0,
        height: 64,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.ink2,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: AppColors.paper2,
        checkmarkColor: AppColors.ink,
        labelStyle: TextStyle(color: AppColors.ink, fontSize: 12),
        side: const BorderSide(color: AppColors.rule),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        showCheckmark: false,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.rule, thickness: 1),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.ink,
        selectionColor: AppColors.paper2,
        selectionHandleColor: AppColors.ink,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.sheet,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.sheet,
        elevation: 0,
        modalBackgroundColor: AppColors.sheet,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: TextStyle(color: AppColors.sheet),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData night() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.nightTextPrimary,
      brightness: Brightness.dark,
      primary: AppColors.nightTextPrimary,
      surface: AppColors.nightSurface,
      onSurface: AppColors.nightTextPrimary,
      error: const Color(0xFFFFB4B4),
    );
    final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.nightBackground,
      textTheme: _textTheme(base.textTheme, AppColors.nightTextPrimary),
      cardTheme: CardThemeData(
        color: AppColors.nightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: AppColors.nightTextPrimary.withValues(alpha: .12),
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.nightSurface,
        dragHandleColor: AppColors.nightTextSecondary,
        elevation: 0,
        modalBackgroundColor: AppColors.nightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color, width: width),
      );

  static TextTheme _textTheme(TextTheme base, Color color) => base
      .apply(bodyColor: color, displayColor: color, fontFamily: 'NotoSansSC')
      .copyWith(
        displaySmall: const TextStyle(
          fontSize: 28,
          height: 34 / 28,
          fontWeight: FontWeight.w600,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        headlineMedium: const TextStyle(
          fontSize: 22,
          height: 28 / 22,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: const TextStyle(
          fontSize: 16,
          height: 24 / 16,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: const TextStyle(
          fontSize: 14,
          height: 22 / 14,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: const TextStyle(
          fontSize: 14,
          height: 22 / 14,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: const TextStyle(fontSize: 14, height: 22 / 14),
        bodySmall: const TextStyle(
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w500,
        ),
      );
}
