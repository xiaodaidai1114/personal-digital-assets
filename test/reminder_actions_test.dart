import 'package:flutter_test/flutter_test.dart';
import 'package:personal_digital_assets/domain/asset.dart';
import 'package:personal_digital_assets/domain/reminder_actions.dart';

void main() {
  test('订阅续期可推迟 7 天', () {
    final asset = Asset(
      id: 'subscription',
      type: AssetType.subscription,
      title: 'Netflix',
      fields: {'nextRenewalDate': '2026-09-23T00:00:00.000'},
    );

    final updated = markReminderHandled(
      asset,
      ReminderAction.delaySevenDays,
      now: DateTime(2026, 9, 20),
    );

    expect(updated, isNotNull);
    expect(updated!.fields['nextRenewalDate'], '2026-09-30T00:00:00.000');
  });

  test('账单日期推进到下个月并保持月末日', () {
    final bill = Asset(
      id: 'bill',
      type: AssetType.bill,
      title: '云服务费',
      fields: {'date': '2026-01-31T00:00:00.000'},
    );

    final updated = markReminderHandled(
      bill,
      ReminderAction.nextMonth,
      now: DateTime(2026, 1, 31),
    );

    expect(updated!.fields['date'], '2026-02-28T00:00:00.000');
  });

  test('处理动作不触碰加密封缄与无关字段', () {
    final asset = Asset(
      id: 'subscription',
      type: AssetType.subscription,
      title: 'Netflix',
      fields: {'nextRenewalDate': '2026-09-23T00:00:00.000', 'plan': '标准版'},
      encryptedSecret: 'encrypted-value',
    );

    final updated = markReminderHandled(
      asset,
      ReminderAction.nextMonth,
      now: DateTime(2026, 9, 20),
    );

    expect(updated!.fields['plan'], '标准版');
    expect(updated.encryptedSecret, 'encrypted-value');
  });
}
