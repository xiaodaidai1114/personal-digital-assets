import 'dart:async';

import 'package:flutter/widgets.dart';

import 'vault_controller.dart';

/// 自动锁定：用户无操作或应用退到后台超过设定时长后锁定保险库。
class AutoLockController with WidgetsBindingObserver {
  AutoLockController({required this._vault, required this._delayProvider});

  final VaultController _vault;
  final Future<Duration?> Function() _delayProvider;
  Timer? _timer;

  bool _started = false;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _vault.addListener(_onVaultChanged);
    _restartTimer();
  }

  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _vault.removeListener(_onVaultChanged);
    _started = false;
  }

  void _onVaultChanged() {
    if (_vault.isUnlocked) {
      _restartTimer();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // 退到后台时重新计时；时长到期即锁定。
      _restartTimer();
    }
  }

  /// 用户交互时重置计时（在根 Widget 的 pointer 事件里调用）。
  void notifyUserActive() {
    if (_vault.isUnlocked) {
      _restartTimer();
    }
  }

  Future<void> _restartTimer() async {
    _timer?.cancel();
    if (!_vault.isUnlocked) {
      return;
    }
    final delay = await _delayProvider();
    if (delay == null) {
      return;
    }
    _timer = Timer(delay, () => _vault.lock());
  }
}
