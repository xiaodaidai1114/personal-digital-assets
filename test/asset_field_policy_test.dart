import 'package:flutter_test/flutter_test.dart';
import 'package:personal_digital_assets/domain/asset_field_policy.dart';

void main() {
  test('允许普通字段保存非敏感标识', () {
    expect(
      AssetFieldPolicy.plainFieldError('username', 'netflix-user'),
      isNull,
    );
    expect(AssetFieldPolicy.plainFieldError('prefix', 'sk-FAKE'), isNull);
    expect(AssetFieldPolicy.plainFieldError('cardNumber', '8888'), isNull);
    expect(AssetFieldPolicy.sensitivePlainTextError('招商银行'), isNull);
  });

  test('拒绝完整卡号进入普通字段', () {
    expect(
      AssetFieldPolicy.plainFieldError('username', '6222 0212 3456 8888'),
      contains('完整卡号'),
    );
  });

  test('拒绝完整 API Key 进入普通字段', () {
    expect(
      AssetFieldPolicy.plainFieldError('username', 'sk-abcdef1234567890'),
      contains('完整 Key'),
    );
  });

  test('拒绝密码样式内容进入名称、标签或普通字段', () {
    expect(
      AssetFieldPolicy.sensitivePlainTextError('password: MySecret123'),
      contains('密码'),
    );
    expect(
      AssetFieldPolicy.sensitivePlainTextError('Ab1-xy9Zq2-Lm7pQr4sT-8Uv'),
      contains('封缄'),
    );
  });

  test('银行卡普通字段只接受四位后四位', () {
    expect(
      AssetFieldPolicy.plainFieldError('cardNumber', '622202'),
      contains('4 位'),
    );
    expect(AssetFieldPolicy.plainFieldError('cardNumber', '8888'), isNull);
  });
}
