import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_sqlcipher/sqlite_api.dart'
    show SqlCipherOpenDatabaseOptions;

import '../../domain/asset.dart';
import '../../domain/asset_attachment.dart';
import '../../domain/asset_note.dart';
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

  static const int schemaVersion = 3;

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
    await _createNotesAndAttachmentsSchema(db);
  }

  /// v3 新增：资产备注与图片附件表（附件字节为 BLOB，随库加密）。
  Future<void> _createNotesAndAttachmentsSchema(Database db) async {
    await db.execute('''
CREATE TABLE asset_notes(
  id TEXT PRIMARY KEY,
  asset_id TEXT NOT NULL,
  content TEXT NOT NULL,
  created_at TEXT NOT NULL
)
''');
    await db.execute(
      'CREATE INDEX idx_asset_notes_asset ON asset_notes(asset_id)',
    );
    await db.execute('''
CREATE TABLE asset_attachments(
  id TEXT PRIMARY KEY,
  asset_id TEXT NOT NULL,
  name TEXT NOT NULL,
  mime_type TEXT,
  byte_size INTEGER NOT NULL DEFAULT 0,
  bytes BLOB NOT NULL,
  created_at TEXT NOT NULL
)
''');
    await db.execute(
      'CREATE INDEX idx_asset_attachments_asset ON asset_attachments(asset_id)',
    );
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
    if (oldVersion < 3) {
      await _createNotesAndAttachmentsSchema(db);
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
      await txn.delete('asset_notes', where: 'asset_id = ?', whereArgs: [id]);
      await txn.delete(
        'asset_attachments',
        where: 'asset_id = ?',
        whereArgs: [id],
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

  @override
  Future<List<AssetNote>> listNotes(String assetId) async {
    final rows = await (await database).query(
      'asset_notes',
      where: 'asset_id = ?',
      whereArgs: [assetId],
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(_noteFromRow).toList(growable: false);
  }

  @override
  Future<void> addNote(AssetNote note) async {
    await (await database).insert('asset_notes', _noteToRow(note));
  }

  @override
  Future<void> deleteNote(String noteId) async {
    await (await database).delete(
      'asset_notes',
      where: 'id = ?',
      whereArgs: [noteId],
    );
  }

  @override
  Future<List<AssetAttachment>> listAttachments(String assetId) async {
    final rows = await (await database).query(
      'asset_attachments',
      where: 'asset_id = ?',
      whereArgs: [assetId],
      // 列表查询不读 BLOB，只取元数据
      columns: ['id', 'asset_id', 'name', 'mime_type', 'byte_size',
          'created_at'],
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(_attachmentFromRow).toList(growable: false);
  }

  @override
  Future<void> addAttachment(AssetAttachment attachment, List<int> bytes) async {
    final db = await database;
    await db.insert('asset_attachments', {
      ..._attachmentToRow(attachment),
      'bytes': Uint8List.fromList(bytes),
    });
  }

  @override
  Future<Uint8List?> attachmentBytes(String attachmentId) async {
    final rows = await (await database).query(
      'asset_attachments',
      columns: ['bytes'],
      where: 'id = ?',
      whereArgs: [attachmentId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['bytes'] as Uint8List?;
  }

  @override
  Future<void> deleteAttachment(String attachmentId) async {
    await (await database).delete(
      'asset_attachments',
      where: 'id = ?',
      whereArgs: [attachmentId],
    );
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

  AssetNote _noteFromRow(Map<String, Object?> row) => AssetNote(
    id: row['id'] as String,
    assetId: row['asset_id'] as String,
    content: row['content'] as String,
    createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
  );

  Map<String, Object?> _noteToRow(AssetNote note) => {
    'id': note.id,
    'asset_id': note.assetId,
    'content': note.content,
    'created_at': note.createdAt.toIso8601String(),
  };

  AssetAttachment _attachmentFromRow(Map<String, Object?> row) =>
      AssetAttachment(
        id: row['id'] as String,
        assetId: row['asset_id'] as String,
        name: row['name'] as String,
        mimeType: row['mime_type'] as String?,
        byteSize: row['byte_size'] as int? ?? 0,
        createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
      );

  Map<String, Object?> _attachmentToRow(AssetAttachment attachment) => {
    'id': attachment.id,
    'asset_id': attachment.assetId,
    'name': attachment.name,
    'mime_type': attachment.mimeType,
    'byte_size': attachment.byteSize,
    'created_at': attachment.createdAt.toIso8601String(),
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
