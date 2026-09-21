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
  AppThemeMode _themeMode = AppThemeMode.light;

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
      return _loadThemeMode(
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
    return _loadThemeMode(services);
  }

  Future<AppServices> _loadThemeMode(AppServices services) async {
    final mode = await services.settingsStore.themeMode();
    if (!mounted) {
      return services;
    }
    setState(() => _themeMode = mode);
    return services;
  }

  void _setThemeMode(AppThemeMode mode) {
    if (_themeMode != mode) {
      setState(() => _themeMode = mode);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '个人数字资产',
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: _themeMode.flutter,
    builder: (context, child) {
      final skin = context.skin;
      final size = MediaQuery.sizeOf(context);
      if (!kIsWeb || size.width < 1024 || child == null) {
        return child ?? const SizedBox.shrink();
      }
      return ColoredBox(
        color: skin.canvas,
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: skin.canvas,
              border: Border.all(color: skin.outline),
            ),
            child: SizedBox(
              width: 430,
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(size: Size(430, size.height)),
                child: child,
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
        return AppRoot(services: services, onThemeModeChanged: _setThemeMode);
      },
    ),
  );
}

/// 根节点：监听解锁状态、驱动自动锁定与解锁开帘动效。
class AppRoot extends StatefulWidget {
  const AppRoot({
    super.key,
    required this.services,
    required this.onThemeModeChanged,
  });

  final AppServices services;
  final ValueChanged<AppThemeMode> onThemeModeChanged;

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
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // 系统栏跟随亮暗主题：解锁页等无 AppBar 的画面也能确定图标方向；
      // 星图页内部更近的 AnnotatedRegion 会覆盖本值。
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
            statusBarColor: skin.canvas,
            systemNavigationBarColor: skin.canvas,
            systemNavigationBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
          ),
      child: Stack(
        children: [
          _controller.isUnlocked
              ? MainShell(
                  services: widget.services,
                  autoLock: _autoLock,
                  onThemeModeChanged: widget.onThemeModeChanged,
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
    final skin = context.skin;
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
          color: skin.canvas,
        ),
      ),
    );
  }
}

/// 主壳：首页即倾倒口与资产列表（DESIGN.md 青穹资产云）。
/// 底栏与桌面导航已废除，锁定/设置入口在首页 AppBar 动作区；
/// 哨所转为后台提醒，到期清单入口藏于设置页。
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.services,
    required this.autoLock,
    required this.onThemeModeChanged,
  });

  final AppServices services;
  final AutoLockController autoLock;
  final ValueChanged<AppThemeMode> onThemeModeChanged;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final Future<AppReleaseInfo?> _updateFuture;
  bool _updateDismissed = false;

  @override
  void initState() {
    super.initState();
    _updateFuture = widget.services.updateChecker.checkLatest();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          services: widget.services,
          onThemeModeChanged: widget.onThemeModeChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        children: [
          ?updateBanner,
          Expanded(
            child: AssetListScreen(
              controller: widget.services.controller,
              repository: widget.services.repository,
              onDataChanged: widget.services.syncReminders,
              onOpenSettings: _openSettings,
            ),
          ),
        ],
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
    final skin = context.skin;
    return Material(
      color: skin.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: skin.outline)),
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
