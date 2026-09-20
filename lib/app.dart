import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'app_services.dart';
import 'data/asset_repository.dart';
import 'data/demo_data.dart';
import 'data/memory_asset_repository.dart';
import 'data/backup/backup_file_store.dart';
import 'data/backup/backup_file_store_factory.dart';
import 'data/reminders/noop_reminder_scheduler.dart';
import 'data/reminders/reminder_scheduler.dart';
import 'data/reminders/reminder_scheduler_factory.dart';
import 'data/repository_factory.dart';
import 'data/settings_store.dart';
import 'theme/app_theme.dart';
import 'ui/asset_list_screen.dart';
import 'ui/calendar_screen.dart';
import 'ui/graph_screen.dart';
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
  });

  /// 测试时可注入低迭代次数的控制器与内存仓库。
  final VaultController? controller;
  final AssetRepository? repository;
  final SettingsStore? settingsStore;
  final ReminderScheduler? reminderScheduler;
  final BackupFileStore? backupFileStore;

  @override
  State<PersonalDigitalAssetsApp> createState() =>
      _PersonalDigitalAssetsAppState();
}

class _PersonalDigitalAssetsAppState extends State<PersonalDigitalAssetsApp> {
  late final Future<AppServices> _servicesFuture;

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
      return AppServices(
        controller: injected,
        repository: repository,
        settingsStore: widget.settingsStore ?? MemorySettingsStore(),
        reminderScheduler: widget.reminderScheduler ?? NoopReminderScheduler(),
        backupFileStore: widget.backupFileStore ?? MemoryBackupFileStore(),
      );
    }
    final bundle = await createRepositoryBundle();
    final controller = VaultController(
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
    );
    await services.syncReminders();
    return services;
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '个人数字资产',
    theme: AppTheme.day(),
    themeMode: ThemeMode.light,
    builder: (context, child) {
      final size = MediaQuery.sizeOf(context);
      if (!kIsWeb || size.width < 760 || child == null) {
        return child ?? const SizedBox.shrink();
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
        return AppRoot(services: services);
      },
    ),
  );
}

/// 根节点：监听解锁状态、驱动自动锁定与解锁开帘动效。
class AppRoot extends StatefulWidget {
  const AppRoot({super.key, required this.services});

  final AppServices services;

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
  Widget build(BuildContext context) => Stack(
    children: [
      _controller.isUnlocked
          ? MainShell(services: widget.services, autoLock: _autoLock)
          : UnlockScreen(controller: _controller),
      if (_openingCurtain)
        _OpeningCurtain(
          onFinished: () => setState(() => _openingCurtain = false),
        ),
    ],
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

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.services, required this.autoLock});

  final AppServices services;
  final AutoLockController autoLock;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

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
      GraphScreen(
        controller: services.controller,
        repository: services.repository,
        onManageAssets: () => setState(() => _selectedIndex = 0),
      ),
      SettingsScreen(services: services),
    ];
    final graphSelected = _selectedIndex == 2;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => widget.autoLock.notifyUserActive(),
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            for (var i = 0; i < pages.length; i++)
              TickerMode(enabled: i == _selectedIndex, child: pages[i]),
          ],
        ),
        bottomNavigationBar: Theme(
          data: graphSelected ? AppTheme.night() : AppTheme.day(),
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            backgroundColor: graphSelected
                ? AppColors.nightSurface
                : AppColors.sheet,
            indicatorColor: graphSelected
                ? AppColors.nightTextPrimary.withValues(alpha: .12)
                : AppColors.paper2,
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
                icon: Icon(Icons.hub_outlined),
                selectedIcon: Icon(Icons.hub_outlined),
                label: '星图',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: '设置',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
