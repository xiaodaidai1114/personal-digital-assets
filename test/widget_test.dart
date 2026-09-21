import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_digital_assets/app.dart';
import 'package:personal_digital_assets/crypto/kdf.dart';
import 'package:personal_digital_assets/data/app_update.dart';
import 'package:personal_digital_assets/theme/app_theme.dart';
import 'package:personal_digital_assets/ui/asset_detail_screen.dart';
import 'package:personal_digital_assets/ui/graph/graph_palette.dart';
import 'package:personal_digital_assets/ui/graph/native_graph_view.dart';
import 'package:personal_digital_assets/ui/graph_screen.dart';
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
  await tester.tap(find.byType(FilledButton));
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
    final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
    ).value;
    expect(overlay.statusBarIconBrightness, Brightness.dark);
    expect(overlay.statusBarColor, AppSkin.light.canvas);
    expect(overlay.systemNavigationBarColor, AppSkin.light.canvas);
  });

  testWidgets('创建主密码后进入资产列表并显示演示数据', (tester) async {
    await unlockApp(tester);
    expect(find.text('保险库'), findsWidgets);
    expect(find.text('AI 助手订阅'), findsWidgets);
  });

  testWidgets('资产页可筛选类型', (tester) async {
    await unlockApp(tester);
    await tester.tap(find.text('筛选'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('邮箱 ·').last);
    await tester.pump();
    await tester.tap(find.text('应用筛选'));
    await tester.pumpAndSettle();
    expect(find.text('主邮箱'), findsWidgets);
    // 首页哨兵的临期提醒不受筛选影响（订阅临期仍提醒），
    // 但资产列表本身应只剩邮箱类资产
    final assetList = find.byType(ListView).first;
    expect(
      find.descendant(of: assetList, matching: find.text('AI 助手订阅')),
      findsNothing,
    );
  });

  testWidgets('资产页支持搜索与删除已选条件', (tester) async {
    await unlockApp(tester);
    await tester.enterText(
      find.widgetWithText(TextField, '搜索标题、标签、字段、关联'),
      'Android',
    );
    await tester.pump();
    expect(find.text('AI 助手 API Key'), findsNothing);
    await tester.tap(find.byTooltip('删除搜索条件'));
    await tester.pump();
    expect(find.text('AI 助手订阅'), findsWidgets);
  });

  testWidgets('哨所显示提醒区与月视图', (tester) async {
    await unlockApp(tester);
    await tester.tap(find.text('哨所').last);
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

  testWidgets('星图渲染节点并把系统栏切夜色（常驻动画，用定长 pump）', (tester) async {
    await unlockApp(tester);

    // 星图移出底栏后，导航栏恒为日间纸面（路由会遮蔽底栏，先在主壳断言）
    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBar.backgroundColor, AppSkin.light.surface);

    // 星图已移出底栏，入口在资产详情页「打开星图」
    await tester.ensureVisible(find.text('主邮箱').last);
    await tester.tap(find.text('主邮箱').last);
    await tester.pumpAndSettle();
    // 局部图位于长列表深处，元素按视口物化，需滚动直到其出现
    await tester.scrollUntilVisible(
      find.text('打开星图'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(find.text('打开星图'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('个节点 ·'), findsOneWidget);
    expect(find.text('清空'), findsOneWidget);

    // 星图夜墨画布：状态栏/导航栏同色，图标转浅色
    final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.descendant(
        of: find.byType(GraphScreen),
        matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      ),
    ).value;
    expect(overlay.statusBarIconBrightness, Brightness.light);
    expect(overlay.statusBarColor, kGraphBackground);
    expect(overlay.systemNavigationBarColor, kGraphSurface);
  });

  testWidgets('星图搜索聚焦一跳时保留全部节点', (tester) async {
    await unlockApp(tester);
    await tester.ensureVisible(find.text('主邮箱').last);
    await tester.tap(find.text('主邮箱').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('打开星图'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(find.text('打开星图'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 详情页局部图也在树中，限定星图页内的图谱视图
    final graphFinder = find.descendant(
      of: find.byType(GraphScreen),
      matching: find.byType(NativeGraphView),
    );
    final totalCount =
        tester.widget<NativeGraphView>(graphFinder).assets.length;

    await tester.enterText(
      find.widgetWithText(TextField, '搜索节点，自动保留一跳邻域'),
      'AI 助手订阅',
    );
    await tester.pump();

    final graph = tester.widget<NativeGraphView>(graphFinder);
    expect(graph.assets.length, totalCount);
    expect(graph.focusIds, isNotEmpty);
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

  testWidgets('图谱筛选抽屉保持夜墨文本', (tester) async {
    await unlockApp(tester);
    await tester.ensureVisible(find.text('主邮箱').last);
    await tester.tap(find.text('主邮箱').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('打开星图'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(find.text('打开星图'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('筛选'));
    await tester.pump(const Duration(milliseconds: 300));

    final titleContext = tester.element(find.text('图谱筛选'));
    expect(Theme.of(titleContext).brightness, Brightness.dark);
    expect(
      Theme.of(titleContext).scaffoldBackgroundColor,
      kGraphBackground,
    );
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
    await tester.enterText(
      find.widgetWithText(TextField, '搜索标题、标签、字段、关联'),
      '批量处理',
    );
    await tester.pump();
    expect(find.textContaining('当前 1 项'), findsOneWidget);
  });

  testWidgets('设置页显示安全与数据功能项', (tester) async {
    await unlockApp(tester);
    await tester.tap(find.text('设置'));
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
