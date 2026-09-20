import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_digital_assets/app.dart';
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

  testWidgets('日常界面锁定浅色，不随系统深色切换', (tester) async {
    await tester.pumpWidget(const PersonalDigitalAssetsApp());

    final materialApp = tester.widget<MaterialApp>(
      find.byType(MaterialApp).first,
    );
    expect(materialApp.themeMode, ThemeMode.light);
    expect(materialApp.darkTheme, isNull);
  });
}
