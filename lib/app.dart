import 'package:flutter/material.dart';

import 'data/demo_data.dart';
import 'data/memory_asset_repository.dart';
import 'ui/asset_list_screen.dart';
import 'ui/graph_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/unlock_screen.dart';
import 'vault/vault_controller.dart';

class PersonalDigitalAssetsApp extends StatefulWidget {
  const PersonalDigitalAssetsApp({super.key, this.controller});

  /// 测试时可注入低迭代次数的控制器。
  final VaultController? controller;

  @override
  State<PersonalDigitalAssetsApp> createState() =>
      _PersonalDigitalAssetsAppState();
}

class _PersonalDigitalAssetsAppState extends State<PersonalDigitalAssetsApp> {
  late final VaultController _controller;
  late final Future<MemoryAssetRepository> _repositoryFuture;
  late final VoidCallback _onControllerChanged;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? VaultController();
    _onControllerChanged = () => setState(() {});
    _controller.addListener(_onControllerChanged);
    _repositoryFuture = seedDemoData();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '个人数字资产',
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF3949AB),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: const Color(0xFF3949AB),
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        home: _controller.isUnlocked
            ? FutureBuilder<MemoryAssetRepository>(
                future: _repositoryFuture,
                builder: (context, snapshot) {
                  final repository = snapshot.data;
                  if (repository == null) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return MainShell(
                    controller: _controller,
                    repository: repository,
                  );
                },
              )
            : UnlockScreen(controller: _controller),
      );
}

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.controller,
    required this.repository,
  });

  final VaultController controller;
  final MemoryAssetRepository repository;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      AssetListScreen(
        controller: widget.controller,
        repository: widget.repository,
      ),
      const GraphScreen(),
      SettingsScreen(controller: widget.controller),
    ];
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: '资产',
          ),
          NavigationDestination(
            icon: Icon(Icons.hub_outlined),
            selectedIcon: Icon(Icons.hub),
            label: '图谱',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
