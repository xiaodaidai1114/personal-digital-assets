import 'bill_calendar.dart';
import 'reminder_scheduler.dart';

/// 无本地通知能力平台的空实现。
class NoopReminderScheduler implements ReminderScheduler {
  @override
  Future<void> reschedule(List<ReminderItem> items) async {}
}
