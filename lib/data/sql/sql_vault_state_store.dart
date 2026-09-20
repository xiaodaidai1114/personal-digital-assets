import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';

import '../../crypto/vault_cipher.dart';
import '../../vault/vault_state_store.dart';

/// 保险库状态（盐值 + 校验密文）保存在加密数据库内部的 vault_state 表。
/// 数据库本身由设备级口令（flutter_secure_storage 托管）开启，
/// 因此校验数据落盘时始终处于加密库内，符合敏感字段不落明文的红线。
class SqlVaultStateStore implements VaultStateStore {
  SqlVaultStateStore(this._db);

  final Database _db;

  static const String _table = 'vault_state';

  static Future<void> createTable(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS vault_state(
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
''');
  }

  @override
  Future<void> save({
    required List<int> salt,
    required EncryptedPayload verifier,
  }) async {
    await createTable(_db);
    await _db.insert(_table, {
      'key': 'salt',
      'value': base64Encode(salt),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _db.insert(_table, {
      'key': 'verifier',
      'value': verifier.serialize(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<StoredVaultState?> load() async {
    await createTable(_db);
    final rows = await _db.query(_table);
    if (rows.isEmpty) {
      return null;
    }
    final values = <String, String>{
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
    final saltText = values['salt'];
    final verifierText = values['verifier'];
    if (saltText == null || verifierText == null) {
      return null;
    }
    return StoredVaultState(
      salt: base64Decode(saltText),
      verifier: EncryptedPayload.deserialize(verifierText),
    );
  }

  @override
  Future<void> clear() => _db.delete(_table);
}
