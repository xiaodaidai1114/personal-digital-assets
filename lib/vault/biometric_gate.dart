import '../crypto/vault_cipher.dart';

/// 生物识别解锁门。
///
/// 启用时把派生密钥托管到系统安全存储（Android Keystore），
/// 解锁时先走生物识别，通过后才取出密钥构造加解密器。
/// 密钥绝不写入普通文件或日志。
abstract interface class BiometricGate {
  /// 设备是否具备可用的生物识别能力。
  Future<bool> isAvailable();

  /// 用户是否已开启生物识别解锁。
  Future<bool> isEnabled();

  /// 开启/关闭生物识别解锁。开启时需要传入当前解锁态的密钥。
  Future<void> setEnabled(bool enabled, {List<int>? key});

  /// 生物识别解锁：验证通过后返回已就绪的加解密器，失败/取消返回 null。
  Future<VaultCipher?> unlock();
}

/// 无生物识别能力时的空实现：Web 预览与测试环境使用。
class NoopBiometricGate implements BiometricGate {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> isEnabled() async => false;

  @override
  Future<void> setEnabled(bool enabled, {List<int>? key}) async {}

  @override
  Future<VaultCipher?> unlock() async => null;
}

/// 内存实现：测试用，可模拟生物识别可用/已开启/解锁成功。
class FakeBiometricGate implements BiometricGate {
  bool available;
  bool enabled;
  List<int>? storedKey;
  bool shouldSucceed = true;

  FakeBiometricGate({
    this.available = true,
    this.enabled = false,
    this.storedKey,
  });

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<void> setEnabled(bool value, {List<int>? key}) async {
    enabled = value;
    storedKey = value ? key : null;
  }

  @override
  Future<VaultCipher?> unlock() async {
    if (!enabled || !shouldSucceed) {
      return null;
    }
    final key = storedKey;
    return key == null ? null : VaultCipher(key);
  }
}
