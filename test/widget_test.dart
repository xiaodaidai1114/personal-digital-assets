import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_digital_assets/app.dart';
import 'package:personal_digital_assets/crypto/kdf.dart';
import 'package:personal_digital_assets/vault/vault_controller.dart';

void main() {
  testWidgets('首次启动显示创建主密码界面', (tester) async {
    final controller = VaultController(
      deriver: Pbkdf2Deriver(iterations: 1000),
    );
    await tester.pumpWidget(PersonalDigitalAssetsApp(controller: controller));
    expect(find.text('创建主密码'), findsOneWidget);
  });

  testWidgets('创建主密码后进入资产列表并显示演示数据', (tester) async {
    final controller = VaultController(
      deriver: Pbkdf2Deriver(iterations: 1000),
    );
    await tester.pumpWidget(PersonalDigitalAssetsApp(controller: controller));
    await tester.enterText(
      find.byType(TextFormField).first,
      'test-password-123',
    );
    await tester.enterText(
      find.byType(TextFormField).last,
      'test-password-123',
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('我的资产'), findsOneWidget);
    expect(find.text('AI 助手订阅'), findsOneWidget);
  });
}
