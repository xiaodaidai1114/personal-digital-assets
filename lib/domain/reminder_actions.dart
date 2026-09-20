import 'asset.dart';

enum ReminderAction { delaySevenDays, nextMonth }

/// 推进哨所任务的到期日期。只操作日程字段，不触碰加密封缄。
Asset? markReminderHandled(
  Asset asset,
  ReminderAction action, {
  DateTime? now,
}) {
  final key = _dueDateKeyOf(asset);
  final rawDate = key == null
      ? null
      : DateTime.tryParse(asset.fields[key]?.toString() ?? '');
  if (key == null || rawDate == null) {
    return null;
  }
  final dueDate = DateTime(rawDate.year, rawDate.month, rawDate.day);
  final nextDate = switch (action) {
    ReminderAction.delaySevenDays => dueDate.add(const Duration(days: 7)),
    ReminderAction.nextMonth => _addMonthClamped(dueDate),
  };
  return asset.copyWith(
    fields: {...asset.fields, key: nextDate.toIso8601String()},
    updatedAt: now ?? DateTime.now(),
  );
}

String? _dueDateKeyOf(Asset asset) {
  if (asset.type == AssetType.subscription) {
    return asset.fields.containsKey('nextRenewalDate')
        ? 'nextRenewalDate'
        : 'dueDate';
  }
  if (asset.type == AssetType.bill) {
    return 'date';
  }
  for (final key in const ['dueDate', 'expiryDate', 'warrantyExpiry']) {
    if (asset.fields.containsKey(key)) {
      return key;
    }
  }
  return null;
}

DateTime _addMonthClamped(DateTime date) {
  final target = DateTime(date.year, date.month + 1);
  final daysInTargetMonth = DateTime(
    target.year,
    target.month + 1,
  ).subtract(const Duration(days: 1)).day;
  return DateTime(
    target.year,
    target.month,
    date.day < daysInTargetMonth ? date.day : daysInTargetMonth,
  );
}
