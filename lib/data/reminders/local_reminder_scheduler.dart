import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'bill_calendar.dart';
import 'reminder_scheduler.dart';

/// 移动端本地通知实现：为每个待提醒事项安排一条到期日上午 9 点的通知。
class LocalReminderScheduler implements ReminderScheduler {
  LocalReminderScheduler([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'asset_reminders',
      '资产提醒',
      channelDescription: '账单到期与订阅续期提醒',
      importance: Importance.defaultImportance,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
  }

  @override
  Future<void> reschedule(List<ReminderItem> items) async {
    await initialize();
    await _plugin.cancelAll();
    for (final item in items) {
      await _plugin.zonedSchedule(
        _stableId(item.id),
        item.kind == 'bill' ? '账单到期' : '订阅续期',
        item.title,
        _atNineAM(item.dueDate),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexact,
      );
    }
  }

  tz.TZDateTime _atNineAM(DateTime date) =>
      tz.TZDateTime(tz.local, date.year, date.month, date.day, 9);

  /// 字符串 ID 转稳定的 int 通知 ID（FNV-1a 32 位）。
  int _stableId(String input) {
    var hash = 0x811C9DC5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }
}
