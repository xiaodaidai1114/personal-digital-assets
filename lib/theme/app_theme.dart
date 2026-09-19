import 'package:flutter/material.dart';

import '../domain/asset.dart';

class AppColors {
  const AppColors._();

  static const dayBackground = Color(0xFFF3F4F9);
  static const daySurface = Color(0xFFFFFFFF);
  static const dayTextPrimary = Color(0xFF16181D);
  static const dayTextSecondary = Color(0xFF5A6072);
  static const dayOutline = Color(0xFFE3E6F0);
  static const primary = Color(0xFF6355E8);
  static const link = Color(0xFF5A4FD8);
  static const danger = Color(0xFFC93B3B);
  static const warning = Color(0xFFA56512);
  static const success = Color(0xFF1E7F5C);

  static const nightBackground = Color(0xFF101426);
  static const nightSurface = Color(0xFF1A2038);
  static const nightTextPrimary = Color(0xFFECEDF5);
  static const nightTextSecondary = Color(0xFFA7ADC4);
  static const graphNode = Color(0xFFF5F7FF);

  static Color typeDeep(AssetType type) => switch (type) {
        AssetType.email => const Color(0xFF0E7490),
        AssetType.subscription => const Color(0xFF5A4FD8),
        AssetType.apiKey => const Color(0xFF2D4ED8),
        AssetType.password => const Color(0xFF0C7A57),
        AssetType.device => const Color(0xFF9A5B00),
        AssetType.item => const Color(0xFF8A4B2A),
        AssetType.bill => const Color(0xFFC0245C),
        AssetType.bankCard => const Color(0xFF8A6D00),
        AssetType.other => const Color(0xFF555B6E),
      };

  static Color typeLight(AssetType type) => switch (type) {
        AssetType.email => const Color(0xFF7DD8F2),
        AssetType.subscription => const Color(0xFFB4A6FF),
        AssetType.apiKey => const Color(0xFF9DB2FF),
        AssetType.password => const Color(0xFF63D6AE),
        AssetType.device => const Color(0xFFF3B95F),
        AssetType.item => const Color(0xFFE0A87B),
        AssetType.bill => const Color(0xFFF287A9),
        AssetType.bankCard => const Color(0xFFE8CF6B),
        AssetType.other => const Color(0xFFB8BEDA),
      };
}

class AppGradients {
  const AppGradients._();

  static const light = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF82E2FF), Color(0xFFAED8FF), Color(0xFF9F86FF)],
  );

  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5A4FD8), Color(0xFF1F7FB8)],
  );

  static const nebula = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF101A3C), Color(0xFF2B1E52)],
  );
}

class AppTheme {
  const AppTheme._();

  static ThemeData day() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.daySurface,
      onSurface: AppColors.dayTextPrimary,
      secondaryContainer: AppColors.dayBackground,
      error: AppColors.danger,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.dayBackground,
      textTheme: _textTheme(base.textTheme, AppColors.dayTextPrimary),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.dayTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.dayTextPrimary,
          fontSize: 24,
          height: 1.34,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.daySurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.dayOutline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.daySurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.dayOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.dayOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary.withValues(alpha: .12),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.dayOutline),
    );
  }

  static ThemeData night() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary: AppColors.typeLight(AssetType.subscription),
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
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: .08)),
        ),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, Color color) => base
      .apply(
        bodyColor: color,
        displayColor: color,
        fontFamily: 'NotoSansSC',
      )
      .copyWith(
        displaySmall: const TextStyle(
          fontSize: 32,
          height: 1.25,
          fontWeight: FontWeight.w700,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        headlineMedium: const TextStyle(
          fontSize: 24,
          height: 1.34,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: const TextStyle(
          fontSize: 18,
          height: 1.45,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          height: 1.5,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: const TextStyle(fontSize: 14, height: 1.57),
        bodySmall: const TextStyle(fontSize: 12, height: 1.34),
      );
}
