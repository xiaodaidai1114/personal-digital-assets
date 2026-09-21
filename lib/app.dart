import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_services.dart';
import 'data/asset_repository.dart';
import 'data/demo_data.dart';
import 'data/memory_asset_repository.dart';
import 'data/backup/backup_file_store.dart';
import 'data/backup/backup_file_store_factory.dart';
import 'data/app_update.dart';
import 'data/reminders/noop_reminder_scheduler.dart';
import 'data/reminders/reminder_scheduler.dart';
import 'data/reminders/reminder_scheduler_factory.dart';
import 'data/repository_factory.dart';
import 'data/settings_store.dart';
import 'crypto/kdf.dart';
import 'theme/app_theme.dart';
import 'app_version.dart';
import 'ui/asset_list_screen.dart';
import 'ui/calendar_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/unlock_screen.dart';
import 'vault/auto_lock.dart';
import 'vault/biometric_gate_factory.dart';
import 'vault/vault_controller.dart';

class PersonalDigitalAssetsApp extends StatefulWidget {
  const PersonalDigitalAssetsApp({
    super.key,
    this.controller,
    this.repository,
    this.settingsStore,
    this.reminderScheduler,
    this.backupFileStore,
    this.updateChecker,
  });

  /// 测试时可注入低迭代次数的控制器与内存仓库。
  final VaultController? controller;
  final AssetRepository? repository;
  final SettingsStore? settingsStore;
  final ReminderScheduler? reminderScheduler;
  final BackupFileStore? backupFileStore;
  final AppUpdateChecker? updateChecker;

  @override
  State<PersonalDigitalAssetsApp> createState() =>
      _PersonalDigitalAssetsAppState();
}

class _PersonalDigitalAssetsAppState extends State<PersonalDigitalAssetsApp> {
  late final Future<AppServices> _servicesFuture;
  AppAppearance _appearance = AppAppearance.morning;

  @override
  void initState() {
    super.initState();
    _servicesFuture = _resolveServices();
  }

  Future<AppServices> _resolveServices() async {
    final injected = widget.controller;
    if (injected != null) {
      final repository = widget.repository ?? MemoryAssetRepository();
      if (widget.repository == null) {
        await seedDemoData(repository);
      }
      return _loadAppearance(
        AppServices(
          controller: injected,
          repository: repository,
          settingsStore: widget.settingsStore ?? MemorySettingsStore(),
          reminderScheduler:
              widget.reminderScheduler ?? NoopReminderScheduler(),
          backupFileStore: widget.backupFileStore ?? MemoryBackupFileStore(),
          updateChecker: widget.updateChecker ?? const NoopUpdateChecker(),
        ),
      );
    }
    final bundle = await createRepositoryBundle();
    final controller = VaultController(
      deriver: Pbkdf2Deriver(iterations: kIsWeb ? 1000 : 210000),
      stateStore: bundle.vaultStateStore,
      biometric: createBiometricGate(),
    );
    await controller.load();
    final services = AppServices(
      controller: controller,
      repository: bundle.repository,
      settingsStore: SharedPrefsSettingsStore(),
      reminderScheduler: createReminderScheduler(),
      backupFileStore: createBackupFileStore(),
      updateChecker: GitHubUpdateChecker(currentVersion: AppVersion.current),
    );
    await services.syncReminders();
    return _loadAppearance(services);
  }

  Future<AppServices> _loadAppearance(AppServices services) async {
    final appearance = await services.settingsStore.appearance();
    if (!mounted) {
      return services;
    }
    setState(() => _appearance = appearance);
    return services;
  }

  void _setAppearance(AppAppearance appearance) {
    if (_appearance != appearance) {
      setState(() => _appearance = appearance);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '个人数字资产',
    theme: AppTheme.day(),
    themeMode: ThemeMode.light,
    builder: (context, child) {
      final size = MediaQuery.sizeOf(context);
      final content = child == null
          ? null
          : _appearance == AppAppearance.evening
          ? ColorFiltered(
              colorFilter: AppTheme.eveningColorFilter,
              child: child,
            )
          : child;
      if (!kIsWeb || size.width < 1024 || content == null) {
        return content ?? const SizedBox.shrink();
      }
      return ColoredBox(
        color: AppColors.paper,
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.paper,
              border: Border.all(color: AppColors.rule),
            ),
            child: SizedBox(
              width: 430,
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(size: Size(430, size.height)),
                child: content,
              ),
            ),
          ),
        ),
      );
    },
    home: FutureBuilder<AppServices>(
      future: _servicesFuture,
      builder: (context, snapshot) {
        final services = snapshot.data;
        if (services == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return AppRoot(services: services, onAppearanceChanged: _setAppearance);
      },
    ),
  );
}

/// 根节点：监听解锁状态、驱动自动锁定与解锁开帘动效。
class AppRoot extends StatefulWidget {
  const AppRoot({
    super.key,
    required this.services,
    required this.onAppearanceChanged,
  });

  final AppServices services;
  final ValueChanged<AppAppearance> onAppearanceChanged;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late final AutoLockController _autoLock;
  late final VoidCallback _onControllerChanged;
  bool _openingCurtain = false;

  VaultController get _controller => widget.services.controller;

  @override
  void initState() {
    super.initState();
    _autoLock = AutoLockController(
      vault: _controller,
      delayProvider: widget.services.settingsStore.autoLockDelay,
    );
    _onControllerChanged = () {
      if (_controller.isUnlocked && !_openingCurtain) {
        setState(() => _openingCurtain = true);
      } else {
        setState(() {});
      }
    };
    _controller.addListener(_onControllerChanged);
    _autoLock.start();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _autoLock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    // 日间系统栏兜底（DESIGN.md 纸底墨图标）：解锁页等没有 AppBar 的纸面
    // 也能确定图标方向，并保证离开星图夜色系统栏后恢复纸色；
    // 星图页内部更近的 AnnotatedRegion 会覆盖本值。
    value: SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: AppColors.paper,
      systemNavigationBarColor: AppColors.paper,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: Stack(
      children: [
        _controller.isUnlocked
            ? MainShell(
                services: widget.services,
                autoLock: _autoLock,
                onAppearanceChanged: widget.onAppearanceChanged,
              )
            : UnlockScreen(controller: _controller),
        if (_openingCurtain)
          _OpeningCurtain(
            onFinished: () => setState(() => _openingCurtain = false),
          ),
      ],
    ),
  );
}

/// 解锁转场：纸面淡出，主界面轻微上移进入。
class _OpeningCurtain extends StatefulWidget {
  const _OpeningCurtain({required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<_OpeningCurtain> createState() => _OpeningCurtainState();
}

class _OpeningCurtainState extends State<_OpeningCurtain>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 360),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            widget.onFinished();
          }
        });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, .72, curve: Curves.easeOut),
    );
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Opacity(
          opacity: 1 - fade.value,
          child: Transform.translate(
            offset: Offset(0, -8 * fade.value),
            child: child,
          ),
        ),
        child: Container(
          height: MediaQuery.sizeOf(context).height,
          color: AppColors.paper,
        ),
      ),
    );
  }
}

// 星图不再是底栏 tab（日常使用频率低），入口移至详情页「打开星图」。
const _desktopNavItems = <(int, String, IconData)>[
  (0, '找 · 保险库', Icons.inventory_2_outlined),
  (1, '办 · 哨所', Icons.visibility_outlined),
  (2, '设置', Icons.settings_outlined),
];

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.services,
    required this.autoLock,
    required this.onAppearanceChanged,
  });

  final AppServices services;
  final AutoLockController autoLock;
  final ValueChanged<AppAppearance> onAppearanceChanged;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  late final Future<AppReleaseInfo?> _updateFuture;
  bool _updateDismissed = false;

  @override
  void initState() {
    super.initState();
    _updateFuture = widget.services.updateChecker.checkLatest();
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    final pages = [
      AssetListScreen(
        controller: services.controller,
        repository: services.repository,
        onDataChanged: services.syncReminders,
      ),
      CalendarScreen(
        controller: services.controller,
        repository: services.repository,
        onDataChanged: services.syncReminders,
      ),
      SettingsScreen(
        services: services,
        onAppearanceChanged: widget.onAppearanceChanged,
      ),
    ];
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    final updateBanner = !_updateDismissed
        ? FutureBuilder<AppReleaseInfo?>(
            future: _updateFuture,
            builder: (context, snapshot) {
              final release = snapshot.data;
              if (release == null || !release.isUpdateAvailable) {
                return const SizedBox.shrink();
              }
              return _UpdateBanner(
                release: release,
                onDismissed: () => setState(() => _updateDismissed = true),
              );
            },
          )
        : null;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => widget.autoLock.notifyUserActive(),
      child: Scaffold(
        body: isDesktop
            ? Column(
                children: [
                  _DesktopNavigation(
                    selectedIndex: _selectedIndex,
                    onSelected: (index) =>
                        setState(() => _selectedIndex = index),
                  ),
                  Container(height: 1, color: AppColors.rule),
                  Expanded(
                    child: Column(
                      children: [
                        ?updateBanner,
                        Expanded(
                          child: IndexedStack(
                            index: _selectedIndex,
                            children: [
                              for (var i = 0; i < pages.length; i++)
                                TickerMode(
                                  enabled: i == _selectedIndex,
                                  child: pages[i],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  ?updateBanner,
                  Expanded(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: [
                        for (var i = 0; i < pages.length; i++)
                          TickerMode(
                            enabled: i == _selectedIndex,
                            child: pages[i],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: isDesktop
            ? null
            : NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) =>
                    setState(() => _selectedIndex = index),
                backgroundColor: AppColors.sheet,
                indicatorColor: AppColors.paper2,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
                elevation: 0,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.inventory_2_outlined),
                    selectedIcon: Icon(Icons.inventory_2_outlined),
                    label: '保险库',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.visibility_outlined),
                    selectedIcon: Icon(Icons.visibility_outlined),
                    label: '哨所',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: '设置',
                  ),
                ],
              ),
      ),
    );
  }
}

class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({required this.release, required this.onDismissed});

  final AppReleaseInfo release;
  final VoidCallback onDismissed;

  Future<void> _download(BuildContext context) async {
    final uri = release.apkUrl;
    if (uri == null) {
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('无法打开下载地址')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.sheet,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.rule)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.system_update_alt_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '发现新版本 v${release.version}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '可前往 GitHub Release 下载新版 APK',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _download(context),
                  child: const Text('下载'),
                ),
                IconButton(
                  tooltip: '稍后提醒',
                  onPressed: onDismissed,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const foreground = AppColors.ink;
    const secondary = AppColors.ink2;
    return Material(
      color: AppColors.sheet,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  '青穹资产云',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: foreground),
                ),
              ),
              const Spacer(),
              for (final item in _desktopNavItems)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onSelected(item.$1),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: selectedIndex == item.$1
                            ? AppColors.paper2
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(item.$3, size: 18, color: secondary),
                          const SizedBox(width: 8),
                          Text(
                            item.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: selectedIndex == item.$1
                                      ? foreground
                                      : secondary,
                                  fontWeight: selectedIndex == item.$1
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
