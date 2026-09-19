import 'dart:math';

import 'package:flutter/foundation.dart';

import '../crypto/kdf.dart';
import '../crypto/vault_cipher.dart';

/// 解锁失败：主密码错误或校验数据损坏。
class VaultUnlockException implements Exception {
  const VaultUnlockException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 保险库控制器：首次创建主密码、解锁、锁定。
/// MVP 第一阶段盐值与校验数据只驻内存，持久化随数据库迭代接入。
class VaultController extends ChangeNotifier {
  VaultController({KeyDeriver? deriver})
      : _deriver = deriver ?? Pbkdf2Deriver();

  static const String _verifierPlaintext =
      'personal-digital-assets/vault-check/v1';

  final KeyDeriver _deriver;
  List<int>? _salt;
  EncryptedPayload? _verifier;
  VaultCipher? _cipher;

  bool get isConfigured => _salt != null;
  bool get isUnlocked => _cipher != null;
  VaultCipher? get cipher => _cipher;

  Future<void> createVault(String masterPassword) async {
    final salt = _randomBytes(16);
    final key = await _deriver.derive(masterPassword, salt);
    final cipher = VaultCipher(key);
    final verifier = await cipher.encrypt(_verifierPlaintext);
    _salt = salt;
    _verifier = verifier;
    _cipher = cipher;
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
