import 'package:flutter_test/flutter_test.dart';
import 'package:personal_digital_assets/crypto/kdf.dart';
import 'package:personal_digital_assets/vault/biometric_gate.dart';
import 'package:personal_digital_assets/vault/vault_controller.dart';
import 'package:personal_digital_assets/vault/vault_state_store.dart';

void main() {
  VaultController buildController({
    VaultStateStore? store,
    BiometricGate? biometric,
  }) =>
      VaultController(
        deriver: Pbkdf2Deriver(iterations: 1000),
        stateStore: store,
        biometric: biometric,
      );

  test('创建保险库后可持久化恢复：配置但未解锁', () async {
    final store = MemoryVaultStateStore();
    final created = buildController(store: store);
    await created.createVault('test-password-123');
    expect(created.isConfigured, isTrue);
    expect(created.isUnlocked, isTrue);

    final restored = buildController(store: store);
    expect(restored.isConfigured, isFalse);
    await restored.load();
    expect(restored.isConfigured, isTrue);
    expect(restored.isUnlocked, isFalse);
  });

  test('错误主密码解锁失败，正确主密码解锁成功', () async {
    final store = MemoryVaultStateStore();
    final created = buildController(store: store);
    await created.createVault('test-password-123');

    final restored = buildController(store: store);
    await restored.load();
    expect(
      () => restored.unlock('wrong-password'),
      throwsA(isA<VaultUnlockException>()),
    );
    expect(restored.isUnlocked, isFalse);

    await restored.unlock('test-password-123');
    expect(restored.isUnlocked, isTrue);

    restored.lock();
    expect(restored.isUnlocked, isFalse);
  });

  test('解锁态可加密/解密敏感字段', () async {
    final controller = buildController();
    await controller.createVault('test-password-123');
    final encrypted = await controller.encryptSecret('测试密码123');
    expect(encrypted, isNot(contains('测试密码123')));
    expect(await controller.decryptSecret(encrypted), '测试密码123');
    controller.lock();
    expect(
      () => controller.decryptSecret(encrypted),
      throwsA(isA<StateError>()),
    );
  });

  test('生物识别：开启后锁定可刷脸解锁，关闭后不可用', () async {
    final gate = FakeBiometricGate();
    final store = MemoryVaultStateStore();
    final created = buildController(store: store, biometric: gate);
    await created.createVault('test-password-123');

    await created.setBiometricEnabled(true);
    expect(await created.isBiometricEnabled(), isTrue);

    created.lock();
    expect(await created.unlockWithBiometric(), isTrue);
    expect(created.isUnlocked, isTrue);

    await created.setBiometricEnabled(false);
    created.lock();
    expect(await created.unlockWithBiometric(), isFalse);
  });

  test('生物识别验证失败时保持锁定', () async {
    final gate = FakeBiometricGate()..enabled = true;
    gate.shouldSucceed = false;
    final controller = buildController(biometric: gate);
    expect(await controller.unlockWithBiometric(), isFalse);
    expect(controller.isUnlocked, isFalse);
  });
}
