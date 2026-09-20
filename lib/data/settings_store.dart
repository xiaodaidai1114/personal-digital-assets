import 'package:shared_preferences/shared_preferences.dart';

enum AppAppearance {
  morning('morning'),
  evening('evening');

  const AppAppearance(this.storageValue);

  final String storageValue;

  static AppAppearance fromStorage(String? value) =>
      value == AppAppearance.evening.storageValue
      ? AppAppearance.evening
      : AppAppearance.morning;
}

/// 应用设置存储抽象：自动锁定时长等。
abstract interface class SettingsStore {
  /// null 表示永不自动锁定。
  Future<Duration?> autoLockDelay();

  Future<void> setAutoLockDelay(Duration? delay);

  Future<AppAppearance> appearance();

  Future<void> setAppearance(AppAppearance appearance);
}

/// 内存实现：测试与依赖注入使用。
class MemorySettingsStore implements SettingsStore {
  Duration? _delay;
  AppAppearance _appearance = AppAppearance.morning;

  @override
  Future<Duration?> autoLockDelay() async => _delay;

  @override
  Future<void> setAutoLockDelay(Duration? delay) async {
    _delay = delay;
  }

  @override
  Future<AppAppearance> appearance() async => _appearance;

  @override
  Future<void> setAppearance(AppAppearance appearance) async {
    _appearance = appearance;
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
  Future<AppAppearance> appearance() async {
    final prefs = await _prefs;
    return AppAppearance.fromStorage(prefs.getString(_appearanceKey));
  }

  @override
  Future<void> setAppearance(AppAppearance appearance) async {
    final prefs = await _prefs;
    await prefs.setString(_appearanceKey, appearance.storageValue);
  }
}
