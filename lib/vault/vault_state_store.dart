import '../../crypto/vault_cipher.dart';

/// 保险库状态的持久化抽象：盐值与主密码校验密文。
abstract interface class VaultStateStore {
  Future<void> save({
    required List<int> salt,
    required EncryptedPayload verifier,
  });

  Future<StoredVaultState?> load();

  Future<void> clear();
}

class StoredVaultState {
  const StoredVaultState({required this.salt, required this.verifier});

  final List<int> salt;
  final EncryptedPayload verifier;
}

/// 内存实现：测试与 Web 预览使用。
class MemoryVaultStateStore implements VaultStateStore {
  StoredVaultState? _state;

  @override
  Future<void> save({
    required List<int> salt,
    required EncryptedPayload verifier,
  }) async {
    _state = StoredVaultState(salt: salt, verifier: verifier);
  }

  @override
  Future<StoredVaultState?> load() async => _state;

  @override
  Future<void> clear() async {
    _state = null;
  }
}
