import 'reminder_scheduler.dart';
import 'reminder_scheduler_stub.dart'
    if (dart.library.html) 'reminder_scheduler_web.dart'
    if (dart.library.io) 'reminder_scheduler_io.dart'
    as impl;

/// 平台对应的提醒调度：移动端本地通知，Web 空实现。
ReminderScheduler createReminderScheduler() => impl.createReminderScheduler();
