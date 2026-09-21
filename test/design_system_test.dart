import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getwidget/getwidget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:personal_digital_assets/app.dart';
import 'package:personal_digital_assets/data/settings_store.dart';
import 'package:personal_digital_assets/theme/app_theme.dart';

void main() {
  testWidgets('亮色主题锁定 GF 色板、小圆角与无阴影', (tester) async {
    late ThemeData theme;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            theme = Theme.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(theme.brightness, Brightness.light);
    // GF 基底：F4F5F8 画布 + 白卡面 + 3880FF 主按钮
    expect(theme.scaffoldBackgroundColor, GFColors.BACKGROUND);
    expect(theme.scaffoldBackgroundColor, AppSkin.light.canvas);
    expect(theme.cardTheme.color, AppSkin.light.surface);
    expect(theme.cardTheme.elevation, 0);
    expect(theme.colorScheme.primary, GFColors.PRIMARY);
    expect(theme.colorScheme.error, GFColors.DANGER);
    expect(
      theme.filledButtonTheme.style?.backgroundColor?.resolve({}),
      GFColors.PRIMARY,
    );
    expect(
      theme.filledButtonTheme.style?.backgroundColor?.resolve({
        WidgetState.disabled,
      }),
      AppSkin.light.surfaceAlt,
    );
    expect(
      theme.filledButtonTheme.style?.foregroundColor?.resolve({
        WidgetState.disabled,
      }),
      AppSkin.light.disabled,
    );
    // 皮肤扩展随主题注册，context.skin 取到亮色实例
    expect(theme.extension<AppSkin>(), AppSkin.light);

    final cardShape = theme.cardTheme.shape as RoundedRectangleBorder;
    final cardRadius = cardShape.borderRadius as BorderRadius;
    expect(cardRadius.topLeft, const Radius.circular(8));

    final inputBorder =
        theme.inputDecorationTheme.enabledBorder as OutlineInputBorder;
    expect(inputBorder.borderRadius.topLeft, const Radius.circular(8));
  });

  testWidgets('暗色主题为原生 Night Theme 并注册暗色皮肤', (tester) async {
    late ThemeData theme;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        home: Builder(
          builder: (context) {
            theme = Theme.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AppSkin.dark.canvas);
    expect(theme.cardTheme.color, AppSkin.dark.surface);
    expect(theme.colorScheme.primary, GFColors.PRIMARY);
    expect(theme.colorScheme.error, GFColors.DANGER);
    expect(theme.extension<AppSkin>(), AppSkin.dark);
  });

  test('亮色正文对比度不低于 4.5:1（GF 派生色板）', () {
    final lightSurfaces = [
      AppSkin.light.canvas,
      AppSkin.light.surface,
      AppSkin.light.surfaceAlt,
    ];
    final lightTextColors = [
      AppSkin.light.textPrimary,
      AppSkin.light.textSecondary,
    ];

    for (final surface in lightSurfaces) {
      for (final textColor in lightTextColors) {
        expect(
          _relativeLuminance(textColor),
          lessThan(_relativeLuminance(surface)),
          reason: '${textColor.toARGB32()} must be dark text on light surface',
        );
        expect(
          _contrastRatio(textColor, surface),
          greaterThanOrEqualTo(4.5),
          reason: '${textColor.toARGB32()} on ${surface.toARGB32()}',
        );
      }
    }
  });

  test('暗色正文对比度不低于 4.5:1（GF 派生色板）', () {
    final darkSurfaces = [AppSkin.dark.canvas, AppSkin.dark.surface];
    final darkTextColors = [
      AppSkin.dark.textPrimary,
      AppSkin.dark.textSecondary,
    ];

    for (final surface in darkSurfaces) {
      for (final textColor in darkTextColors) {
        expect(
          _relativeLuminance(textColor),
          greaterThan(_relativeLuminance(surface)),
        );
        expect(_contrastRatio(textColor, surface), greaterThanOrEqualTo(4.5));
      }
    }
  });

  test('操作色在浅底上保持 UI 级对比（≥ 3:1）', () {
    final surfaces = [AppSkin.light.canvas, AppSkin.light.surface];
    final accents = [
      AppSkin.light.primary,
      AppSkin.light.danger,
      AppSkin.light.success,
    ];
    for (final surface in surfaces) {
      for (final accent in accents) {
        expect(
          _contrastRatio(accent, surface),
          greaterThanOrEqualTo(3),
          reason: '${accent.toARGB32()} on ${surface.toARGB32()}',
        );
      }
    }
  });

  test('外观模式默认亮色且支持暗色与跟随系统', () async {
    final store = MemorySettingsStore();
    expect(await store.themeMode(), AppThemeMode.light);
    await store.setThemeMode(AppThemeMode.dark);
    expect(await store.themeMode(), AppThemeMode.dark);
    await store.setThemeMode(AppThemeMode.system);
    expect(await store.themeMode(), AppThemeMode.system);
    expect(AppThemeMode.system.flutter, ThemeMode.system);
    expect(AppThemeMode.dark.flutter, ThemeMode.dark);
  });

  test('旧版 morning/evening 存量值迁移为亮色', () {
    expect(AppThemeMode.fromStorage('morning'), AppThemeMode.light);
    expect(AppThemeMode.fromStorage('evening'), AppThemeMode.light);
    expect(AppThemeMode.fromStorage(null), AppThemeMode.light);
    expect(AppThemeMode.fromStorage('dark'), AppThemeMode.dark);
    expect(AppThemeMode.fromStorage('system'), AppThemeMode.system);
  });

  test('外观偏好可持久化', () async {
    SharedPreferences.setMockInitialValues({
      'settings.appearance': AppThemeMode.dark.storageValue,
    });
    final store = SharedPrefsSettingsStore();
    expect(await store.themeMode(), AppThemeMode.dark);
    await store.setThemeMode(AppThemeMode.system);
    expect(await store.themeMode(), AppThemeMode.system);
  });

  testWidgets('应用默认亮色并提供原生暗色主题', (tester) async {
    await tester.pumpWidget(const PersonalDigitalAssetsApp());

    final materialApp = tester.widget<MaterialApp>(
      find.byType(MaterialApp).first,
    );
    expect(materialApp.themeMode, ThemeMode.light);
    expect(materialApp.darkTheme, isNotNull);
    expect(materialApp.darkTheme!.brightness, Brightness.dark);
  });
}

double _contrastRatio(Color foreground, Color background) {
  final first = _relativeLuminance(foreground);
  final second = _relativeLuminance(background);
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + .05) / (darker + .05);
}

double _relativeLuminance(Color color) {
  final argb = color.toARGB32();
  final red = ((argb >> 16) & 0xff) / 255;
  final green = ((argb >> 8) & 0xff) / 255;
  final blue = (argb & 0xff) / 255;
  double channel(double value) => value <= .03928
      ? value / 12.920
      : math.pow((value + .055) / 1.055, 2.4).toDouble();

  return .2126 * channel(red) + .7152 * channel(green) + .0722 * channel(blue);
}
