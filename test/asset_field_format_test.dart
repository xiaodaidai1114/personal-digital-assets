import 'package:flutter_test/flutter_test.dart';
import 'package:personal_digital_assets/domain/asset_field_format.dart';

void main() {
  test('字段英文名映射为中文标签', () {
    expect(AssetFieldFormat.label('nextRenewalDate'), '下次续费');
    expect(AssetFieldFormat.label('cardNumber'), '卡号后四位');
  });

  test('日期、周期、支付状态与金额按中文习惯展示', () {
    expect(
      AssetFieldFormat.value('nextRenewalDate', '2026-09-23'),
      '2026年9月23日',
    );
    expect(AssetFieldFormat.value('cycle', 'monthly'), '每月');
    expect(AssetFieldFormat.value('paid', 'true'), '已支付');
    expect(AssetFieldFormat.value('amount', '138'), '138.00');
    expect(AssetFieldFormat.value('amount', '¥138'), '¥138.00');
    expect(AssetFieldFormat.value('amount', '20 USD'), 'USD 20.00');
  });

  test('银行卡后四位做掩码展示', () {
    expect(AssetFieldFormat.value('cardNumber', '8888'), '•••• 8888');
  });
}
