import 'dart:math';

import 'package:flutter/foundation.dart';

import '../crypto/kdf.dart';
import '../crypto/vault_cipher.dart';
import 'biometric_gate.dart';
import 'vault_state_store.dart';

/// 解锁失败：主密码错误或校验数据损坏。
class VaultUnlockException implements Exception {
  const VaultUnlockException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 保险库控制器：首次创建主密码、解锁、锁定、生物识别。
/// 盐值与校验数据经 [VaultStateStore] 持久化在加密数据库内。
class VaultController extends ChangeNotifier {
  VaultController({
    KeyDeriver? deriver,
    VaultStateStore? stateStore,
    BiometricGate? biometric,
  }) : _deriver = deriver ?? Pbkdf2Deriver(),
       _stateStore = stateStore ?? MemoryVaultStateStore(),
       _biometric = biometric ?? NoopBiometricGate();

  static const String _verifierPlaintext =
      'personal-digital-assets/vault-check/v1';

  final KeyDeriver _deriver;
  final VaultStateStore _stateStore;
  final BiometricGate _biometric;
  List<int>? _salt;
  EncryptedPayload? _verifier;
  VaultCipher? _cipher;

  bool get isConfigured => _salt != null;
  bool get isUnlocked => _cipher != null;
  VaultCipher? get cipher => _cipher;

  /// 启动时加载持久化的盐值与校验数据（此时仍处于锁定态）。
  Future<void> load() async {
    final state = await _stateStore.load();
    if (state == null) {
      return;
    }
    _salt = state.salt;
    _verifier = state.verifier;
    notifyListeners();
  }

  /// 设备是否支持生物识别解锁。
  Future<bool> canUseBiometric() => _biometric.isAvailable();

  /// 用户是否已开启生物识别解锁。
  Future<bool> isBiometricEnabled() => _biometric.isEnabled();

  /// 开启/关闭生物识别解锁。开启时把当前派生密钥托管到系统安全存储。
  Future<void> setBiometricEnabled(bool enabled) async {
    if (enabled) {
      final cipher = _cipher;
      if (cipher == null) {
        throw StateError('保险库未解锁，无法开启生物识别');
      }
      await _biometric.setEnabled(true, key: await cipher.extractBytes());
    } else {
      await _biometric.setEnabled(false);
    }
    notifyListeners();
  }

  /// 生物识别解锁：验证成功直接进入解锁态。
  Future<bool> unlockWithBiometric() async {
    final cipher = await _biometric.unlock();
    if (cipher == null) {
      return false;
    }
    _cipher = cipher;
    notifyListeners();
    return true;
  }

  Future<void> createVault(String masterPassword) async {
    final salt = _randomBytes(16);
    final key = await _deriver.derive(masterPassword, salt);
    final cipher = VaultCipher(key);
    final verifier = await cipher.encrypt(_verifierPlaintext);
    _salt = salt;
    _verifier = verifier;
    _cipher = cipher;
    await _stateStore.save(salt: salt, verifier: verifier);
    notifyListeners();
  }

  Future<void> unlock(String masterPassword) async {
    final salt = _salt;
    final verifier = _verifier;
    if (salt == null || verifier == null) {
      throw StateError('保险库尚未创建');
    }
    final key = await _deriver.derive(masterPassword, salt);
    final candidate = VaultCipher(key);
    try {
      final plain = await candidate.decrypt(verifier);
      if (plain != _verifierPlaintext) {
        throw const VaultUnlockException('主密码错误');
      }
    } on VaultUnlockException {
      rethrow;
    } on Exception {
      throw const VaultUnlockException('主密码错误');
    }
    _cipher = candidate;
    notifyListeners();
  }

  void lock() {
    _cipher = null;
    notifyListeners();
  }

  Future<String> encryptSecret(String plaintext) async {
    final cipher = _cipher;
    if (cipher == null) {
      throw StateError('保险库未解锁');
    }
    return (await cipher.encrypt(plaintext)).serialize();
  }

  Future<String> decryptSecret(String serialized) async {
    final cipher = _cipher;
    if (cipher == null) {
      throw StateError('保险库未解锁');
    }
    return cipher.decrypt(EncryptedPayload.deserialize(serialized));
  }

  static List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}
