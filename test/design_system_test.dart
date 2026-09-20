import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:personal_digital_assets/app.dart';
import 'package:personal_digital_assets/data/settings_store.dart';
import 'package:personal_digital_assets/domain/asset.dart';
import 'package:personal_digital_assets/theme/app_theme.dart';

void main() {
  testWidgets('日常主题锁定纸墨、小圆角与无阴影', (tester) async {
    late ThemeData theme;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.day(),
        home: Builder(
          builder: (context) {
            theme = Theme.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(theme.scaffoldBackgroundColor, AppColors.paper);
    expect(theme.cardTheme.color, AppColors.sheet);
    expect(theme.cardTheme.elevation, 0);
    expect(
      theme.filledButtonTheme.style?.backgroundColor?.resolve({}),
      AppColors.ink,
    );
    expect(
      theme.filledButtonTheme.style?.backgroundColor?.resolve({
        WidgetState.disabled,
      }),
      AppColors.paper2,
    );
    expect(
      theme.filledButtonTheme.style?.foregroundColor?.resolve({
        WidgetState.disabled,
      }),
      AppColors.ink2,
    );

    final cardShape = theme.cardTheme.shape as RoundedRectangleBorder;
    final cardRadius = cardShape.borderRadius as BorderRadius;
    expect(cardRadius.topLeft, const Radius.circular(8));

    final inputBorder =
        theme.inputDecorationTheme.enabledBorder as OutlineInputBorder;
    expect(inputBorder.borderRadius.topLeft, const Radius.circular(8));
  });

  test('类型色默认关闭为墨色，星图使用夜墨', () {
    expect(AppColors.typeDeep(AssetType.bill), AppColors.ink);
    expect(AppColors.typeLight(AssetType.subscription), AppColors.graphNode);
  });

  test('浅色纸面上的文字对比度不低于 4.5:1', () {
    const daySurfaces = [AppColors.paper, AppColors.paper2, AppColors.sheet];
    const dayTextColors = [
      AppColors.ink,
      AppColors.ink2,
      AppColors.ink3,
      AppColors.mark,
      AppColors.danger,
    ];

    for (final surface in daySurfaces) {
      for (final textColor in dayTextColors) {
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

  test('早晨和晚上都保持浅色黑字', () async {
    final store = MemorySettingsStore();
    expect(await store.appearance(), AppAppearance.morning);
    await store.setAppearance(AppAppearance.evening);
    expect(await store.appearance(), AppAppearance.evening);

    for (var index = 0; index < 3; index++) {
      expect(AppTheme.eveningMatrix[index * 6], lessThanOrEqualTo(1));
      expect(AppTheme.eveningMatrix[index * 6], greaterThan(0));
    }
    expect(AppTheme.eveningMatrix[18], 1);
  });

  test('外观偏好可持久化', () async {
    SharedPreferences.setMockInitialValues({
      'settings.appearance': AppAppearance.evening.storageValue,
    });
    final store = SharedPrefsSettingsStore();
    expect(await store.appearance(), AppAppearance.evening);
    await store.setAppearance(AppAppearance.morning);
    expect(await store.appearance(), AppAppearance.morning);
  });

  test('夜墨表面才允许使用浅色文字', () {
    const nightSurfaces = [AppColors.nightBackground, AppColors.nightSurface];
    const nightTextColors = [
      AppColors.nightTextPrimary,
      AppColors.nightTextSecondary,
    ];

    for (final surface in nightSurfaces) {
      for (final textColor in nightTextColors) {
        expect(
          _relativeLuminance(textColor),
          greaterThan(_relativeLuminance(surface)),
        );
        expect(_contrastRatio(textColor, surface), greaterThanOrEqualTo(4.5));
      }
    }
  });

  testWidgets('日常界面锁定浅色，不随系统深色切换', (tester) async {
    await tester.pumpWidget(const PersonalDigitalAssetsApp());

    final materialApp = tester.widget<MaterialApp>(
      find.byType(MaterialApp).first,
    );
    expect(materialApp.themeMode, ThemeMode.light);
    expect(materialApp.darkTheme, isNull);
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
