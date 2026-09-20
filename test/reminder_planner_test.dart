import 'package:flutter_test/flutter_test.dart';
import 'package:personal_digital_assets/data/reminders/bill_calendar.dart';
import 'package:personal_digital_assets/domain/asset.dart';

void main() {
  Asset bill(String id, String date) => Asset(
        id: id,
        type: AssetType.bill,
        title: '账单 $id',
        fields: {'date': date},
      );

  Asset subscription(String id, String nextRenewalDate) => Asset(
        id: id,
        type: AssetType.subscription,
        title: '订阅 $id',
        fields: {'nextRenewalDate': nextRenewalDate},
      );

  test('ReminderPlanner 收集未来 30 天内的账单与续期，按日期排序', () {
    final now = DateTime(2026, 9, 20);
    final items = const ReminderPlanner().plan([
      bill('past', '2026-09-19'),
      bill('today', '2026-09-20'),
      bill('soon', '2026-09-25'),
      bill('beyond', '2026-11-01'),
      subscription('sub', '2026-10-01'),
    ], now);

    expect(items.map((i) => i.kind), ['bill', 'bill', 'subscription']);
    expect(items[0].title, '账单 today');
    expect(items[1].dueDate, DateTime(2026, 9, 25));
    expect(items[2].dueDate, DateTime(2026, 10, 1));
  });

  test('billDateOf 解析失败返回 null', () {
    expect(billDateOf(bill('x', 'not-a-date')), isNull);
    expect(billDateOf(bill('y', '2026-10-01')), DateTime(2026, 10, 1));
  });

  test('BillCalendar.monthMap 只聚合当月账单', () {
    final bills = [
      bill('a', '2026-09-01'),
      bill('b', '2026-09-01'),
      bill('c', '2026-09-30'),
      bill('d', '2026-10-01'),
    ];
    final map = BillCalendar.monthMap(bills, 2026, 9);
    expect(map.length, 2);
    expect(map[DateTime(2026, 9, 1)]?.length, 2);
    expect(map[DateTime(2026, 9, 30)]?.length, 1);
  });
}
