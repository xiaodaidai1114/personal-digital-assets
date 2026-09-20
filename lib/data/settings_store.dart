import 'package:shared_preferences/shared_preferences.dart';

/// 应用设置存储抽象：自动锁定时长等。
abstract interface class SettingsStore {
  /// null 表示永不自动锁定。
  Future<Duration?> autoLockDelay();

  Future<void> setAutoLockDelay(Duration? delay);
}

/// 内存实现：测试与依赖注入使用。
class MemorySettingsStore implements SettingsStore {
  Duration? _delay;

  @override
  Future<Duration?> autoLockDelay() async => _delay;

  @override
  Future<void> setAutoLockDelay(Duration? delay) async {
    _delay = delay;
  }
}

/// shared_preferences 实现：Android 与 Web 通用。
class SharedPrefsSettingsStore implements SettingsStore {
  static const String _autoLockSecondsKey = 'settings.auto_lock_seconds';

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
}
