import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  light('light'),
  dark('dark'),
  system('system');

  const AppThemeMode(this.storageValue);

  final String storageValue;

  /// 映射到 MaterialApp.themeMode。
  ThemeMode get flutter => switch (this) {
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
    AppThemeMode.system => ThemeMode.system,
  };

  /// 兼容旧版 `morning`/`evening` 存量值：一律回到亮色。
  static AppThemeMode fromStorage(String? value) => switch (value) {
    'dark' => AppThemeMode.dark,
    'system' => AppThemeMode.system,
    _ => AppThemeMode.light,
  };
}

/// 应用设置存储抽象：自动锁定时长等。
abstract interface class SettingsStore {
  /// null 表示永不自动锁定。
  Future<Duration?> autoLockDelay();

  Future<void> setAutoLockDelay(Duration? delay);

  Future<AppThemeMode> themeMode();

  Future<void> setThemeMode(AppThemeMode mode);
}

/// 内存实现：测试与依赖注入使用。
class MemorySettingsStore implements SettingsStore {
  Duration? _delay;
  AppThemeMode _themeMode = AppThemeMode.light;

  @override
  Future<Duration?> autoLockDelay() async => _delay;

  @override
  Future<void> setAutoLockDelay(Duration? delay) async {
    _delay = delay;
  }

  @override
  Future<AppThemeMode> themeMode() async => _themeMode;

  @override
  Future<void> setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
  }
}

/// shared_preferences 实现：Android 与 Web 通用。
class SharedPrefsSettingsStore implements SettingsStore {
  static const String _autoLockSecondsKey = 'settings.auto_lock_seconds';
  static const String _appearanceKey = 'settings.appearance';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<Duration?> autoLockDelay() async {
    final prefs = await _prefs;
    if (!prefs.containsKey(_autoLockSecondsKey)) {
      return null;
    }
    final seconds = prefs.getInt(_autoLockSecondsKey);
    if (seconds == null || seconds < 0) {
      return null;
    }
    return Duration(seconds: seconds);
  }

  @override
  Future<void> setAutoLockDelay(Duration? delay) async {
    final prefs = await _prefs;
    if (delay == null) {
      await prefs.remove(_autoLockSecondsKey);
    } else {
      await prefs.setInt(_autoLockSecondsKey, delay.inSeconds);
    }
  }

  @override
  Future<AppThemeMode> themeMode() async {
    final prefs = await _prefs;
    return AppThemeMode.fromStorage(prefs.getString(_appearanceKey));
  }

  @override
  Future<void> setThemeMode(AppThemeMode mode) async {
    final prefs = await _prefs;
    await prefs.setString(_appearanceKey, mode.storageValue);
  }
}
