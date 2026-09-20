import '../../domain/asset.dart';

/// 一条待提醒事项（账单到期或订阅续期）。
class ReminderItem {
  const ReminderItem({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.kind,
  });

  /// 稳定 ID（资产 ID + 日期），通知调度用它做去重键。
  final String id;
  final String title;
  final DateTime dueDate;

  /// 'bill' 或 'subscription'。
  final String kind;
}

/// 从资产列表计算未来 N 天内需要提醒的事项。纯逻辑，可单测。
class ReminderPlanner {
  const ReminderPlanner({this.horizonDays = 30});

  final int horizonDays;

  List<ReminderItem> plan(List<Asset> assets, DateTime now) {
    final horizon = DateTime(now.year, now.month, now.day + horizonDays);
    final today = DateTime(now.year, now.month, now.day);
    final items = <ReminderItem>[];
    for (final asset in assets) {
      if (asset.type == AssetType.bill) {
        final date = billDateOf(asset);
        if (date != null && !date.isBefore(today) && !date.isAfter(horizon)) {
          items.add(
            ReminderItem(
              id: '${asset.id}@bill@${date.toIso8601String()}',
              title: asset.title,
              dueDate: date,
              kind: 'bill',
            ),
          );
        }
      } else if (asset.type == AssetType.subscription) {
        final raw = asset.fields['nextRenewalDate'] ?? asset.fields['dueDate'];
        final parsed = DateTime.tryParse(raw?.toString() ?? '');
        if (parsed == null) {
          continue;
        }
        final date = DateTime(parsed.year, parsed.month, parsed.day);
        if (!date.isBefore(today) && !date.isAfter(horizon)) {
          items.add(
            ReminderItem(
              id: '${asset.id}@renew@${date.toIso8601String()}',
              title: asset.title,
              dueDate: date,
              kind: 'subscription',
            ),
          );
        }
      }
    }
    items.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return items;
  }
}

/// 解析账单日期（fields.date），无效返回 null。
DateTime? billDateOf(Asset asset) {
  final raw = asset.fields['date'];
  if (raw == null) {
    return null;
  }
  final parsed = DateTime.tryParse(raw.toString());
  if (parsed == null) {
    return null;
  }
  return DateTime(parsed.year, parsed.month, parsed.day);
}

/// 账单的月视图聚合。纯逻辑，可单测。
class BillCalendar {
  const BillCalendar._();

  /// 某月每一天的账单，键为去掉时分秒的日期。
  static Map<DateTime, List<Asset>> monthMap(
    List<Asset> bills,
    int year,
    int month,
  ) {
    final result = <DateTime, List<Asset>>{};
    for (final bill in bills) {
      final date = billDateOf(bill);
      if (date == null || date.year != year || date.month != month) {
        continue;
      }
      result.putIfAbsent(date, () => []).add(bill);
    }
    return result;
  }
}
