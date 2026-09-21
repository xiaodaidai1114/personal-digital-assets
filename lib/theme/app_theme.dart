import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';

/// 皮肤色对：以 GF（getwidget）默认色板为基底派生的亮/暗两套取值。
///
/// GF 组件不读 ThemeData，暗色场景必须显式传色；
/// Material 残件同样统一走 `context.skin.xxx`，亮暗双主题一处取色。
@immutable
class AppSkin extends ThemeExtension<AppSkin> {
  const AppSkin({
    required this.canvas,
    required this.surface,
    required this.surfaceAlt,
    required this.outline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.primary,
    required this.onPrimary,
    required this.danger,
    required this.success,
    required this.warning,
    required this.info,
    required this.disabled,
  });

  /// 页面画布。
  final Color canvas;

  /// 卡面与弹层。
  final Color surface;

  /// 输入填充与选中底。
  final Color surfaceAlt;

  /// 描边与分隔线。
  final Color outline;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// GF PRIMARY（3880FF）主操作色。
  final Color primary;
  final Color onPrimary;

  /// GF DANGER。
  final Color danger;

  /// 亮色用 GF SUCCESS swatch 700 保证白底对比度，暗色用 GF SUCCESS 原值。
  final Color success;
  final Color warning;
  final Color info;
  final Color disabled;

  /// GF 默认亮色：F4F5F8 画布 + 白卡面 + 3880FF 主色。
  static const AppSkin light = AppSkin(
    canvas: GFColors.BACKGROUND,
    surface: GFColors.WHITE,
    surfaceAlt: GFColors.BACKGROUND,
    outline: GFColors.LIGHT,
    textPrimary: GFColors.DARK,
    // 略深于 GF MUTED（757575）：F4F5F8 画布上才能守住 4.5:1 对比红线
    textSecondary: Color(0xFF616569),
    textTertiary: GFColors.NEUTRAL,
    primary: GFColors.PRIMARY,
    onPrimary: GFColors.WHITE,
    danger: GFColors.DANGER,
    success: Color(0xFF1A8257), // GF SUCCESS_SWATCH[700]
    warning: GFColors.WARNING,
    info: GFColors.INFO,
    disabled: GFColors.DISABLED,
  );

  /// 暗色：GF DARK（222428）卡面，画布再压暗一档，主色沿用 GF PRIMARY。
  static const AppSkin dark = AppSkin(
    canvas: Color(0xFF17181D),
    surface: GFColors.DARK,
    surfaceAlt: Color(0xFF2B2D34),
    outline: Color(0xFF3A3D45),
    textPrimary: Color(0xFFF4F5F8),
    textSecondary: Color(0xFFB3B8C4),
    textTertiary: GFColors.NEUTRAL,
    primary: GFColors.PRIMARY,
    onPrimary: GFColors.WHITE,
    danger: GFColors.DANGER,
    success: GFColors.SUCCESS,
    warning: GFColors.WARNING,
    info: GFColors.INFO,
    disabled: Color(0xFF6B6E76),
  );

  @override
  AppSkin copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceAlt,
    Color? outline,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? primary,
    Color? onPrimary,
    Color? danger,
    Color? success,
    Color? warning,
    Color? info,
    Color? disabled,
  }) => AppSkin(
    canvas: canvas ?? this.canvas,
    surface: surface ?? this.surface,
    surfaceAlt: surfaceAlt ?? this.surfaceAlt,
    outline: outline ?? this.outline,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textTertiary: textTertiary ?? this.textTertiary,
    primary: primary ?? this.primary,
    onPrimary: onPrimary ?? this.onPrimary,
    danger: danger ?? this.danger,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    info: info ?? this.info,
    disabled: disabled ?? this.disabled,
  );

  @override
  AppSkin lerp(AppSkin? other, double t) {
    if (other is! AppSkin) {
      return this;
    }
    return AppSkin(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
    );
  }
}

extension AppSkinContext on BuildContext {
  /// 当前亮暗主题对应的皮肤取值（AppTheme 已随主题注册，测试需自备）。
  AppSkin get skin => Theme.of(this).extension<AppSkin>()!;
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light, AppSkin.light);

  static ThemeData dark() => _build(Brightness.dark, AppSkin.dark);

  static ThemeData _build(Brightness brightness, AppSkin skin) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: skin.primary,
      onPrimary: skin.onPrimary,
      secondary: GFColors.SECONDARY,
      onSecondary: GFColors.WHITE,
      error: skin.danger,
      onError: GFColors.WHITE,
      surface: skin.surface,
      onSurface: skin.textPrimary,
      onSurfaceVariant: skin.textSecondary,
      outline: skin.outline,
      outlineVariant: skin.outline,
      surfaceContainerHighest: skin.surfaceAlt,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);
    return base.copyWith(
      scaffoldBackgroundColor: skin.canvas,
      textTheme: _textTheme(base.textTheme, skin.textPrimary),
      extensions: <ThemeExtension<dynamic>>[skin],
      appBarTheme: AppBarTheme(
        backgroundColor: skin.canvas,
        foregroundColor: skin.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: skin.textPrimary,
          fontSize: 22,
          height: 28 / 22,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: skin.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: skin.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: skin.surfaceAlt,
        labelStyle: TextStyle(color: skin.textSecondary),
        floatingLabelStyle: TextStyle(color: skin.textPrimary),
        hintStyle: TextStyle(color: skin.textTertiary),
        helperStyle: TextStyle(color: skin.textSecondary),
        prefixIconColor: skin.textSecondary,
        suffixIconColor: skin.textSecondary,
        border: _inputBorder(skin.outline),
        enabledBorder: _inputBorder(skin.outline),
        focusedBorder: _inputBorder(skin.primary, width: 2),
        errorBorder: _inputBorder(skin.danger),
        focusedErrorBorder: _inputBorder(skin.danger, width: 2),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? skin.surfaceAlt
                : skin.primary,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? skin.disabled
                : skin.onPrimary,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ).copyWith(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? skin.disabled
                : skin.primary,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ).copyWith(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? skin.disabled
                : skin.primary,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: skin.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: skin.surfaceAlt,
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: skin.textSecondary),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: skin.surfaceAlt,
        checkmarkColor: skin.textPrimary,
        labelStyle: TextStyle(color: skin.textPrimary, fontSize: 12),
        side: BorderSide(color: skin.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        showCheckmark: false,
      ),
      dividerTheme: DividerThemeData(color: skin.outline, thickness: 1),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: skin.primary,
        selectionColor: skin.surfaceAlt,
        selectionHandleColor: skin.primary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: skin.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: skin.surface,
        dragHandleColor: skin.textSecondary,
        elevation: 0,
        modalBackgroundColor: skin.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: skin.textPrimary,
        contentTextStyle: TextStyle(color: skin.surface),
        behavior: SnackBarBehavior.floating,
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
