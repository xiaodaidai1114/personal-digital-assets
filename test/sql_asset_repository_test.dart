import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_digital_assets/data/sql/sql_asset_repository.dart';
import 'package:personal_digital_assets/domain/asset.dart';
import 'package:personal_digital_assets/domain/asset_attachment.dart';
import 'package:personal_digital_assets/domain/asset_note.dart';
import 'package:personal_digital_assets/domain/relation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  late String dbPath;

  setUp(() {
    dbPath =
        '${Directory.systemTemp.path}/pda_test_${DateTime.now().microsecondsSinceEpoch}.db';
  });

  tearDown(() async {
    try {
      await File(dbPath).delete();
    } on Exception {
      // 文件不存在时忽略。
    }
  });

  test('资产的增查改删', () async {
    final repository = SqlAssetRepository(
      factory: databaseFactoryFfi,
      path: dbPath,
    );
    final asset = Asset(
      id: 'a1',
      type: AssetType.subscription,
      title: '订阅 A',
      fields: {'plan': 'Pro', 'amount': '20 USD'},
      tags: ['演示', 'AI'],
    );
    await repository.saveAsset(asset);
    expect((await repository.listAssets()).length, 1);
    expect((await repository.getAsset('a1'))?.title, '订阅 A');

    await repository.saveAsset(asset.copyWith(title: '订阅 A+'));
    expect((await repository.listAssets()).length, 1);
    expect((await repository.getAsset('a1'))?.title, '订阅 A+');

    await repository.deleteAsset('a1');
    expect(await repository.getAsset('a1'), isNull);
    await repository.close();
  });

  test('字段与标签 JSON 往返', () async {
    final repository = SqlAssetRepository(
      factory: databaseFactoryFfi,
      path: dbPath,
    );
    final asset = Asset(
      id: 'a2',
      type: AssetType.bill,
      title: '账单',
      fields: {'amount': '20 USD', 'date': '2026-10-01', 'note': '含"引号"'},
      tags: ['月结', '自动扣款'],
    );
    await repository.saveAsset(asset);
    final loaded = await repository.getAsset('a2');
    expect(loaded?.fields['date'], '2026-10-01');
    expect(loaded?.fields['note'], '含"引号"');
    expect(loaded?.tags, ['月结', '自动扣款']);
    await repository.close();
  });

  test('关系增删与 relationsOf 双向查询', () async {
    final repository = SqlAssetRepository(
      factory: databaseFactoryFfi,
      path: dbPath,
    );
    await repository.saveAsset(
      Asset(id: 'a', type: AssetType.email, title: '邮箱'),
    );
    await repository.saveAsset(
      Asset(id: 'b', type: AssetType.subscription, title: '订阅'),
    );
    await repository.saveRelation(
      Relation(
        id: 'r1',
        fromAssetId: 'a',
        toAssetId: 'b',
        type: RelationType.recovers,
      ),
    );
    expect((await repository.relationsOf('a')).length, 1);
    expect((await repository.relationsOf('b')).length, 1);
    expect(
      (await repository.listRelations()).first.type,
      RelationType.recovers,
    );

    await repository.deleteRelation('r1');
    expect(await repository.relationsOf('a'), isEmpty);
    await repository.close();
  });

  test('删除资产级联删除其关系', () async {
    final repository = SqlAssetRepository(
      factory: databaseFactoryFfi,
      path: dbPath,
    );
    await repository.saveAsset(
      Asset(id: 'a', type: AssetType.email, title: '邮箱'),
    );
    await repository.saveAsset(
      Asset(id: 'b', type: AssetType.subscription, title: '订阅'),
    );
    await repository.saveRelation(
      Relation(
        id: 'r1',
        fromAssetId: 'a',
        toAssetId: 'b',
        type: RelationType.relatesTo,
      ),
    );
    await repository.deleteAsset('a');
    expect(await repository.relationsOf('b'), isEmpty);
    await repository.close();
  });

  test('关闭重开后数据仍在（持久化）', () async {
    final repository = SqlAssetRepository(
      factory: databaseFactoryFfi,
      path: dbPath,
    );
    await repository.saveAsset(
      Asset(id: 'persist', type: AssetType.item, title: '物品'),
    );
    await repository.close();

    final reopened = SqlAssetRepository(
      factory: databaseFactoryFfi,
      path: dbPath,
    );
    expect((await reopened.getAsset('persist'))?.title, '物品');
    await reopened.close();
  });

  test('v1 数据库升级 v2 时保留数据并补置顶列', () async {
    final legacyDb = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
CREATE TABLE assets(
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  fields TEXT NOT NULL DEFAULT '{}',
  tags TEXT NOT NULL DEFAULT '[]',
  encrypted_secret TEXT,
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
        },
      ),
    );
    await legacyDb.insert('assets', {
      'id': 'legacy',
      'type': 'apiKey',
      'title': '旧版本 Key',
      'fields': '{"prefix":"sk-FAKE"}',
      'tags': '["旧数据"]',
      'created_at': '2026-09-01T08:00:00.000Z',
      'updated_at': '2026-09-02T08:00:00.000Z',
    });
    await legacyDb.close();

    final repository = SqlAssetRepository(
      factory: databaseFactoryFfi,
      path: dbPath,
    );
    final asset = await repository.getAsset('legacy');
    expect(asset?.title, '旧版本 Key');
    expect(asset?.isPinned, isFalse);
    expect(
      await repository
          .saveAsset(asset!.copyWith(isPinned: true))
          .then((_) => repository.getAsset('legacy')),
      predicate((Asset? updated) => updated?.isPinned == true),
    );
    await repository.close();
  });

  test('备注按时间倒序与删除', () async {
    final repository = SqlAssetRepository(
      factory: databaseFactoryFfi,
      path: dbPath,
    );
    await repository.saveAsset(
      Asset(id: 'a', type: AssetType.email, title: '邮箱'),
    );
    await repository.addNote(
      AssetNote(
        id: 'n1',
        assetId: 'a',
        content: '第一条',
        createdAt: DateTime.utc(2026, 9, 20, 8, 0, 0),
      ),
    );
    await repository.addNote(
      AssetNote(
        id: 'n2',
        assetId: 'a',
        content: '第二条',
        createdAt: DateTime.utc(2026, 9, 21, 8, 0, 0),
      ),
    );
    final notes = await repository.listNotes('a');
    expect(notes.map((note) => note.id), ['n2', 'n1']);
    expect(notes.first.content, '第二条');

    await repository.deleteNote('n2');
    expect((await repository.listNotes('a')).map((note) => note.id), ['n1']);
    await repository.close();
  });

  test('附件字节 BLOB 往返与删除', () async {
    final repository = SqlAssetRepository(
      factory: databaseFactoryFfi,
      path: dbPath,
    );
    await repository.saveAsset(
      Asset(id: 'a', type: AssetType.email, title: '邮箱'),
    );
    final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
    await repository.addAttachment(
      AssetAttachment(
        id: 'att1',
        assetId: 'a',
        name: 'receipt.jpg',
        mimeType: 'image/jpeg',
        byteSize: bytes.length,
      ),
      bytes,
    );
    final attachments = await repository.listAttachments('a');
    expect(attachments, hasLength(1));
    expect(attachments.first.name, 'receipt.jpg');
    expect(attachments.first.byteSize, bytes.length);
    expect(await repository.attachmentBytes('att1'), bytes);

    await repository.deleteAttachment('att1');
    expect(await repository.listAttachments('a'), isEmpty);
    expect(await repository.attachmentBytes('att1'), isNull);
    await repository.close();
  });

  test('删除资产级联删除其备注与附件', () async {
    final repository = SqlAssetRepository(
      factory: databaseFactoryFfi,
      path: dbPath,
    );
    await repository.saveAsset(
      Asset(id: 'a', type: AssetType.email, title: '邮箱'),
    );
    await repository.addNote(AssetNote(id: 'n1', assetId: 'a', content: '备注'));
    await repository.addAttachment(
      AssetAttachment(id: 'att1', assetId: 'a', name: 'card.jpg'),
      const [9, 9, 9],
    );
    await repository.deleteAsset('a');
    expect(await repository.listNotes('a'), isEmpty);
    expect(await repository.listAttachments('a'), isEmpty);
    expect(await repository.attachmentBytes('att1'), isNull);
    await repository.close();
  });

  test('v2 数据库升级 v3 时保留数据并建备注与附件表', () async {
    final legacyDb = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
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
        },
      ),
    );
    await legacyDb.insert('assets', {
      'id': 'legacy',
      'type': 'email',
      'title': '旧版本邮箱',
      'fields': '{"address":"user@example.com"}',
      'tags': '[]',
      'created_at': '2026-09-01T08:00:00.000Z',
      'updated_at': '2026-09-02T08:00:00.000Z',
    });
    await legacyDb.close();

    final repository = SqlAssetRepository(
      factory: databaseFactoryFfi,
      path: dbPath,
    );
    expect((await repository.getAsset('legacy'))?.title, '旧版本邮箱');

    await repository.addNote(
      AssetNote(id: 'n1', assetId: 'legacy', content: '迁移后新增'),
    );
    await repository.addAttachment(
      AssetAttachment(id: 'att1', assetId: 'legacy', name: 'photo.jpg'),
      const [7, 7],
    );
    await repository.close();

    final reopened = SqlAssetRepository(
      factory: databaseFactoryFfi,
      path: dbPath,
    );
    expect((await reopened.listNotes('legacy')).single.content, '迁移后新增');
    expect(await reopened.attachmentBytes('att1'), const [7, 7]);
    await reopened.close();
  });
}
