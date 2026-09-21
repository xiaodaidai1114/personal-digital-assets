import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getwidget/getwidget.dart';
import 'package:personal_digital_assets/app.dart';
import 'package:personal_digital_assets/crypto/kdf.dart';
import 'package:personal_digital_assets/data/app_update.dart';
import 'package:personal_digital_assets/data/demo_data.dart';
import 'package:personal_digital_assets/data/memory_asset_repository.dart';
import 'package:personal_digital_assets/theme/app_theme.dart';
import 'package:personal_digital_assets/ui/asset_detail_screen.dart';
import 'package:personal_digital_assets/ui/calendar_screen.dart';
import 'package:personal_digital_assets/ui/palette/command_palette.dart';
import 'package:personal_digital_assets/vault/vault_controller.dart';

Future<void> unlockApp(
  WidgetTester tester, {
  AppUpdateChecker? updateChecker,
}) async {
  final controller = VaultController(deriver: Pbkdf2Deriver(iterations: 1000));
  await tester.pumpWidget(
    PersonalDigitalAssetsApp(
      controller: controller,
      updateChecker: updateChecker,
    ),
  );
  await tester.pump();
  await tester.enterText(find.byType(TextFormField).first, 'test-password-123');
  await tester.enterText(find.byType(TextFormField).last, 'test-password-123');
  await tester.tap(find.byType(GFButton));
  await tester.pump();
  await tester.pumpAndSettle();
}

class _FakeUpdateChecker implements AppUpdateChecker {
  const _FakeUpdateChecker(this.release);

  final AppReleaseInfo release;

  @override
  Future<AppReleaseInfo?> checkLatest() async => release;
}

void main() {
  testWidgets('首次启动显示创建主密码界面', (tester) async {
    final controller = VaultController(
      deriver: Pbkdf2Deriver(iterations: 1000),
    );
    await tester.pumpWidget(PersonalDigitalAssetsApp(controller: controller));
    await tester.pump();
    expect(find.text('创建主密码'), findsOneWidget);

    // 无 AppBar 的纸面走 AppRoot 日间注解：纸底墨图标
    final overlay = tester
        .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
        )
        .value;
    expect(overlay.statusBarIconBrightness, Brightness.dark);
    expect(overlay.statusBarColor, AppSkin.light.canvas);
    expect(overlay.systemNavigationBarColor, AppSkin.light.canvas);
  });

  testWidgets('创建主密码后进入资产列表并显示演示数据', (tester) async {
    await unlockApp(tester);
    expect(find.text('青穹资产云'), findsOneWidget);
    expect(find.text('AI 助手订阅'), findsWidgets);
  });

  testWidgets('命令面板按类型检索并直达详情', (tester) async {
    await unlockApp(tester);
    await tester.tap(find.text('检索资产、字段、标签…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '检索资产、字段、标签…'), '邮箱');
    await tester.pump();
    final palette = find.byType(CommandPalette);
    // 「邮箱」同时命中标题与邮箱类型标签，非邮箱资产被面板排除
    expect(
      find.descendant(of: palette, matching: find.text('主邮箱')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: palette, matching: find.text('AI 助手订阅')),
      findsNothing,
    );
    await tester.tap(find.descendant(of: palette, matching: find.text('主邮箱')));
    await tester.pumpAndSettle();
    // 选中直达详情
    expect(find.byType(AssetDetailScreen), findsOneWidget);
  });

  testWidgets('命令面板支持字段检索、清空恢复与空态', (tester) async {
    await unlockApp(tester);
    await tester.tap(find.text('检索资产、字段、标签…'));
    await tester.pumpAndSettle();
    final palette = find.byType(CommandPalette);
    final paletteInput = find.descendant(
      of: palette,
      matching: find.byType(TextField),
    );
    // 字段值命中：标题不含 Android，靠 os 字段检索（暗数据不出暗区）
    await tester.enterText(paletteInput, 'Android');
    await tester.pump();
    expect(
      find.descendant(of: palette, matching: find.text('安卓手机')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: palette, matching: find.text('主邮箱')),
      findsNothing,
    );
    // 清空恢复全量
    await tester.enterText(paletteInput, '');
    await tester.pump();
    expect(
      find.descendant(of: palette, matching: find.text('主邮箱')),
      findsOneWidget,
    );
    // 无匹配显示空态并可关闭
    await tester.enterText(paletteInput, 'zzz不存在');
    await tester.pump();
    expect(
      find.descendant(of: palette, matching: find.text('无匹配资产')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('关闭面板'));
    await tester.pumpAndSettle();
    expect(find.byType(CommandPalette), findsNothing);
  });

  testWidgets('倾倒口粘贴 SSH 指令解析封缄入库并支持复制', (tester) async {
    // flutter_test 不内置剪贴板通道 mock：setData/getData 会永久挂起，这里手动接住
    var clipboardText = '';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            clipboardText = (call.arguments as Map?)?['text'] as String? ?? '';
          case 'Clipboard.getData':
            return <String, Object>{'text': clipboardText};
        }
        return null;
      },
    );
    await unlockApp(tester);
    await tester.enterText(
      find.widgetWithText(TextField, '粘贴倾倒：SSH 指令 / .env / JSON 凭证'),
      'ssh -p 2222 deploy@example.com',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('封缄入库'));
    await tester.pumpAndSettle();

    // 草稿核对 sheet：识别为服务器
    expect(find.textContaining('识别为「服务器」'), findsOneWidget);
    await tester.tap(find.text('封缄入库'));
    await tester.pump();
    expect(find.text('已封缄入库'), findsOneWidget);
    await tester.pumpAndSettle();

    // 列表出现新资产行，详情提供复制 SSH 上下文动作
    await tester.tap(find.text('deploy@example.com'));
    await tester.pumpAndSettle();
    expect(find.text('复制 SSH 指令'), findsOneWidget);
    await tester.tap(find.text('复制 SSH 指令'));
    await tester.pump();
    expect(clipboardText, 'ssh -p 2222 deploy@example.com');
  });

  testWidgets('详情显示上下游依赖并在删除时提示爆炸半径', (tester) async {
    await unlockApp(tester);
    for (
      var attempt = 0;
      attempt < 4 && find.text('AI 助手 API Key').evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -180));
      await tester.pump();
    }
    await tester.tap(find.text('AI 助手 API Key').last);
    await tester.pumpAndSettle();
    // 关联区改为上下游依赖列表（星图退役后的依赖视图），列表深处用 scrollUntilVisible
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('上下游依赖'),
      200,
      scrollable: scrollable,
    );
    await tester.pump();
    expect(find.text('上下游依赖'), findsOneWidget);
    expect(find.textContaining('属于：AI 助手订阅'), findsOneWidget);
    expect(find.textContaining('存储在：安卓手机'), findsOneWidget);
    // 滚到底部后 AppBar 被顶走，回滚一点再点删除
    await tester.drag(find.byType(ListView).first, const Offset(0, 160));
    await tester.pump();
    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();
    // 删除确认展示爆炸半径：受影响的关联资产清单
    expect(find.textContaining('爆炸半径'), findsOneWidget);
    expect(find.text('AI 助手订阅'), findsWidgets);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
  });

  testWidgets('到期清单独立页显示提醒区与月视图', (tester) async {
    // 哨所已转为后台提醒，到期清单页独立存在（入口藏于设置）
    final controller = VaultController(
      deriver: Pbkdf2Deriver(iterations: 1000),
    );
    final repository = MemoryAssetRepository();
    await seedDemoData(repository);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CalendarScreen(
          controller: controller,
          repository: repository,
          onDataChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('哨所'), findsWidgets);
    final scrollable = find.byType(Scrollable).first;
    expect(find.text('未来 30 天'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('10 月订阅账单'),
      160,
      scrollable: scrollable,
    );
    expect(find.text('10 月订阅账单'), findsWidgets);
  });

  testWidgets('宽屏保险库使用集合、列表和详情三栏', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);

    await unlockApp(tester);

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('集合'), findsOneWidget);
    expect(find.text('选择左侧资产查看详情'), findsOneWidget);

    await tester.ensureVisible(find.text('主邮箱').last);
    await tester.tap(find.text('主邮箱').last);
    await tester.pumpAndSettle();

    expect(find.byType(AssetDetailScreen), findsOneWidget);
    expect(find.text('邮箱地址'), findsOneWidget);
  });

  testWidgets('详情页可添加与删除备注', (tester) async {
    await unlockApp(tester);
    await tester.ensureVisible(find.text('主邮箱').last);
    await tester.tap(find.text('主邮箱').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('添加备注'));
    await tester.pump();
    await tester.tap(find.text('添加备注'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '已开启二次验证');
    // ensureVisible 会把按钮顶到 AppBar 下缘，下拉露出来再点
    await tester.ensureVisible(find.text('保存'));
    await tester.pump();
    await tester.drag(find.byType(ListView).first, const Offset(0, 160));
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('已开启二次验证'), findsOneWidget);

    // 新备注排在最前，删除第一条并确认
    await tester.ensureVisible(find.byTooltip('删除备注').first);
    await tester.pump();
    await tester.tap(find.byTooltip('删除备注').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('已开启二次验证'), findsNothing);
  });

  testWidgets('备注拒绝完整 Key 且不落库', (tester) async {
    await unlockApp(tester);
    await tester.ensureVisible(find.text('主邮箱').last);
    await tester.tap(find.text('主邮箱').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('添加备注'));
    await tester.pump();
    await tester.tap(find.text('添加备注'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'sk-abcdef1234567890');
    await tester.ensureVisible(find.text('保存'));
    await tester.pump();
    await tester.drag(find.byType(ListView).first, const Offset(0, 160));
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(find.textContaining('完整 Key'), findsOneWidget);
    // 保存失败时输入框保持展开（内容未写入时间线）
    expect(find.text('保存'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('详情页显示图片区与空态', (tester) async {
    await unlockApp(tester);
    await tester.ensureVisible(find.text('主邮箱').last);
    await tester.tap(find.text('主邮箱').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('添加图片'));
    await tester.pump();
    expect(find.text('图片'), findsOneWidget);
    expect(find.text('暂无图片'), findsOneWidget);
  });

  testWidgets('新增表单在普通字段中拒绝完整 Key', (tester) async {
    await unlockApp(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    final typeOption = find.byKey(const Key('asset-type-password'));
    await tester.ensureVisible(typeOption);
    await tester.pumpAndSettle();
    await tester.tap(typeOption);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '测试');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'sk-abcdef1234567890',
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -420));
    await tester.pump();
    await tester.ensureVisible(find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(find.textContaining('完整 Key'), findsOneWidget);
  });

  testWidgets('新增资产先选择类型并展示对应字段模板', (tester) async {
    await unlockApp(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('选择资产类型'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('asset-type-subscription')),
    );
    await tester.tap(find.byKey(const Key('asset-type-subscription')));
    await tester.pumpAndSettle();
    expect(find.text('订阅字段'), findsOneWidget);
    expect(find.text('套餐'), findsOneWidget);
  });

  testWidgets('资产支持长按多选并批量打标签', (tester) async {
    await unlockApp(tester);
    for (
      var attempt = 0;
      attempt < 4 && find.text('AI 助手 API Key').evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -180));
      await tester.pump();
    }
    await tester.longPress(find.text('AI 助手 API Key').last);
    await tester.pump();
    expect(find.text('已选 1 项'), findsOneWidget);
    await tester.tap(find.byTooltip('批量打标签'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '批量处理');
    await tester.tap(find.text('添加标签'));
    await tester.pumpAndSettle();
    expect(find.text('已选 1 项'), findsNothing);
    // 打上标签后，命令面板可按新标签检索到该资产
    await tester.tap(find.text('检索资产、字段、标签…'));
    await tester.pumpAndSettle();
    final palette = find.byType(CommandPalette);
    await tester.enterText(
      find.descendant(of: palette, matching: find.byType(TextField)),
      '批量处理',
    );
    await tester.pump();
    expect(
      find.descendant(of: palette, matching: find.text('AI 助手 API Key')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: palette, matching: find.text('主邮箱')),
      findsNothing,
    );
  });

  testWidgets('设置页显示安全与数据功能项', (tester) async {
    await unlockApp(tester);
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(find.text('界面模式'), findsOneWidget);
    expect(find.text('原生亮暗双主题，跟随系统时自动切换'), findsOneWidget);
    // 暗色为原生 Night Theme：切到暗色后 MaterialApp 走 darkTheme
    await tester.tap(find.text('暗色'));
    await tester.pumpAndSettle();
    final materialApp = tester.widget<MaterialApp>(
      find.byType(MaterialApp).first,
    );
    expect(materialApp.themeMode, ThemeMode.dark);
    await tester.tap(find.text('跟随系统'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp).first).themeMode,
      ThemeMode.system,
    );
    expect(find.text('立即锁定'), findsOneWidget);
    expect(find.text('自动锁定时长'), findsOneWidget);
    expect(find.text('生物识别解锁'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -220));
    await tester.pumpAndSettle();
    expect(find.text('导出加密备份'), findsOneWidget);
    expect(find.text('从备份恢复'), findsOneWidget);
  });

  testWidgets('发现新版本时显示提醒条并可稍后提醒', (tester) async {
    await unlockApp(
      tester,
      updateChecker: _FakeUpdateChecker(
        AppReleaseInfo(
          version: '1.3.0',
          releaseUrl: Uri.parse('https://example.com/release'),
          apkUrl: Uri.parse('https://example.com/app-release.apk'),
          publishedAt: null,
        ),
      ),
    );

    expect(find.text('发现新版本 v1.3.0'), findsOneWidget);
    expect(find.text('可前往 GitHub Release 下载新版 APK'), findsOneWidget);

    await tester.tap(find.byTooltip('稍后提醒'));
    await tester.pump();

    expect(find.text('发现新版本 v1.3.0'), findsNothing);
  });
}
