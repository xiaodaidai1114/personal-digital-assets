import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../crypto/vault_cipher.dart';
import 'biometric_gate.dart';

/// 生物识别解锁的移动端实现：local_auth 验证 + flutter_secure_storage 托管密钥。
class LocalAuthGate implements BiometricGate {
  LocalAuthGate({LocalAuthentication? auth, FlutterSecureStorage? storage})
    : _auth = auth ?? LocalAuthentication(),
      _storage = storage ?? const FlutterSecureStorage();

  static const String _keyStorageKey = 'vault.biometric_key';

  final LocalAuthentication _auth;
  final FlutterSecureStorage _storage;

  @override
  Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      if (!canCheck || !supported) {
        return false;
      }
      final types = await _auth.getAvailableBiometrics();
      return types.any(
        (type) =>
            type != BiometricType.strong ||
            type == BiometricType.strong ||
            type == BiometricType.weak ||
            type == BiometricType.face ||
            type == BiometricType.fingerprint,
      );
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> isEnabled() async =>
      await _storage.read(key: _keyStorageKey) != null;

  @override
  Future<void> setEnabled(bool enabled, {List<int>? key}) async {
    if (enabled) {
      final bytes = key;
      if (bytes == null) {
        throw StateError('开启生物识别需要当前解锁态的密钥');
      }
      await _storage.write(key: _keyStorageKey, value: base64Encode(bytes));
    } else {
      await _storage.delete(key: _keyStorageKey);
    }
  }

  @override
  Future<VaultCipher?> unlock() async {
    final stored = await _storage.read(key: _keyStorageKey);
    if (stored == null) {
      return null;
    }
    final ok = await _auth.authenticate(
      localizedReason: '验证身份以解锁保险库',
      options: const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: true,
      ),
    );
    if (!ok) {
      return null;
    }
    return VaultCipher(base64Decode(stored));
  }
}

/// 平台默认：local_auth + 安全存储。
BiometricGate createBiometricGate() => LocalAuthGate();
