import 'bill_calendar.dart';

/// 提醒通知调度抽象。Web 等不支持本地通知的平台使用空实现。
abstract interface class ReminderScheduler {
  /// 重新排程：清空旧的本地通知，为给定事项安排新通知。
  Future<void> reschedule(List<ReminderItem> items);
}
