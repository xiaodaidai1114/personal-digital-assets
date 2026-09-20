import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_sqlcipher/sqlite_api.dart'
    show SqlCipherOpenDatabaseOptions;

import '../../domain/asset.dart';
import '../../domain/relation.dart';
import '../asset_repository.dart';

/// 资产与关系的 SQLCipher 持久化实现。
///
/// 通过 [DatabaseFactory] 抽象注入具体工厂：Android/iOS 使用 sqflite_sqlcipher
/// 的加密工厂（传入 [password]），测试环境使用 sqflite_common_ffi 的纯 sqlite 工厂。
class SqlAssetRepository implements AssetRepository {
  SqlAssetRepository({
    required this._factory,
    required this._path,
    this._password,
  });

  static const int schemaVersion = 2;

  final DatabaseFactory _factory;
  final String _path;
  final String? _password;
  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() => _factory.openDatabase(
    _path,
    options: _password == null
        ? OpenDatabaseOptions(
            version: schemaVersion,
            onCreate: _createSchema,
            onUpgrade: _upgradeSchema,
          )
        : _CipherOpenOptions(
            password: _password,
            version: schemaVersion,
            onCreate: _createSchema,
            onUpgrade: _upgradeSchema,
          ),
  );

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
CREATE TABLE assets(
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  fields TEXT NOT NULL DEFAULT '{}',
  tags TEXT NOT NULL DEFAULT '[]',
  encrypted_secret TEXT,
  is_pinned INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
    await db.execute('''
CREATE TABLE relations(
  id TEXT PRIMARY KEY,
  from_asset_id TEXT NOT NULL,
  to_asset_id TEXT NOT NULL,
  type TEXT NOT NULL,
  note TEXT,
  created_at TEXT NOT NULL
)
''');
    await db.execute(
      'CREATE INDEX idx_relations_from ON relations(from_asset_id)',
    );
    await db.execute('CREATE INDEX idx_relations_to ON relations(to_asset_id)');
  }

  Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE assets ADD COLUMN is_pinned INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    await db?.close();
  }

  @override
  Future<List<Asset>> listAssets() async {
    final rows = await (await database).query('assets');
    return rows.map(_assetFromRow).toList(growable: false);
  }

  @override
  Future<Asset?> getAsset(String id) async {
    final rows = await (await database).query(
      'assets',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _assetFromRow(rows.first);
  }

  @override
  Future<void> saveAsset(Asset asset) async {
    final db = await database;
    await db.insert(
      'assets',
      _assetToRow(asset),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteAsset(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('assets', where: 'id = ?', whereArgs: [id]);
      await txn.delete(
        'relations',
        where: 'from_asset_id = ? OR to_asset_id = ?',
        whereArgs: [id, id],
      );
    });
  }

  @override
  Future<List<Relation>> listRelations() async {
    final rows = await (await database).query('relations');
    return rows.map(_relationFromRow).toList(growable: false);
  }

  @override
  Future<void> saveRelation(Relation relation) async {
    final db = await database;
    await db.insert(
      'relations',
      _relationToRow(relation),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteRelation(String id) async {
    await (await database).delete(
      'relations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<Relation>> relationsOf(String assetId) async {
    final rows = await (await database).query(
      'relations',
      where: 'from_asset_id = ? OR to_asset_id = ?',
      whereArgs: [assetId, assetId],
    );
    return rows.map(_relationFromRow).toList(growable: false);
  }

  Asset _assetFromRow(Map<String, Object?> row) => Asset(
    id: row['id'] as String,
    type: AssetType.fromName(row['type'] as String),
    title: row['title'] as String,
    fields:
        jsonDecode((row['fields'] as String?) ?? '{}') as Map<String, dynamic>,
    tags: ((jsonDecode((row['tags'] as String?) ?? '[]') as List<dynamic>))
        .map((tag) => tag as String)
        .toList(),
    encryptedSecret: row['encrypted_secret'] as String?,
    isPinned: (row['is_pinned'] as int? ?? 0) == 1,
    createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
    updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? ''),
  );

  Map<String, Object?> _assetToRow(Asset asset) => {
    'id': asset.id,
    'type': asset.type.name,
    'title': asset.title,
    'fields': jsonEncode(asset.fields),
    'tags': jsonEncode(asset.tags),
    'encrypted_secret': asset.encryptedSecret,
    'is_pinned': asset.isPinned ? 1 : 0,
    'created_at': asset.createdAt.toIso8601String(),
    'updated_at': asset.updatedAt.toIso8601String(),
  };

  Relation _relationFromRow(Map<String, Object?> row) => Relation(
    id: row['id'] as String,
    fromAssetId: row['from_asset_id'] as String,
    toAssetId: row['to_asset_id'] as String,
    type: RelationType.fromName(row['type'] as String),
    note: row['note'] as String?,
    createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
  );

  Map<String, Object?> _relationToRow(Relation relation) => {
    'id': relation.id,
    'from_asset_id': relation.fromAssetId,
    'to_asset_id': relation.toAssetId,
    'type': relation.type.name,
    'note': relation.note,
    'created_at': relation.createdAt.toIso8601String(),
  };
}

/// SQLCipher 打开参数的具体实现（包内未公开实现类，故在本地实现接口）。
class _CipherOpenOptions implements SqlCipherOpenDatabaseOptions {
  _CipherOpenOptions({
    required this.password,
    this.version,
    this.onCreate,
    this.onUpgrade,
  });

  @override
  String? password;

  @override
  int? version;

  @override
  OnDatabaseConfigureFn? onConfigure;

  @override
  OnDatabaseCreateFn? onCreate;

  @override
  OnDatabaseVersionChangeFn? onUpgrade;

  @override
  OnDatabaseVersionChangeFn? onDowngrade;

  @override
  OnDatabaseOpenFn? onOpen;

  @override
  bool readOnly = false;

  @override
  bool singleInstance = true;
}
