import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_sqlcipher/sqflite.dart'
    show databaseFactory, getDatabasesPath;

import 'repository_bundle.dart';
import 'demo_data.dart';
import 'sql/sql_asset_repository.dart';
import 'sql/sql_vault_state_store.dart';

const String _dbPassphraseKey = 'vault.db_passphrase';

/// 移动端：SQLCipher 加密数据库。
///
/// 数据库口令是随机生成的 32 字节（Base64 编码），由 flutter_secure_storage
/// 托管（Android 下落在 Keystore 内），与主密码独立：
/// 主密码保护字段级密文的密钥，数据库口令保护库文件本身。
Future<RepositoryBundle> createRepositoryBundle() async {
  const storage = FlutterSecureStorage();
  var passphrase = await storage.read(key: _dbPassphraseKey);
  if (passphrase == null) {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    passphrase = base64Encode(bytes);
    await storage.write(key: _dbPassphraseKey, value: passphrase);
  }
  final dbPath = '${await getDatabasesPath()}/airy_vault.db';
  final repository = SqlAssetRepository(
    factory: databaseFactory,
    path: dbPath,
    password: passphrase,
  );
  // 确保建库完成后再判空与挂接保险库状态表。
  final db = await repository.database;
  await SqlVaultStateStore.createTable(db);
  if ((await repository.listAssets()).isEmpty) {
    await seedDemoData(repository);
  }
  return RepositoryBundle(
    repository: repository,
    vaultStateStore: SqlVaultStateStore(db),
  );
}
