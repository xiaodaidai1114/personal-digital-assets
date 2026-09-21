import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_digital_assets/data/memory_asset_repository.dart';
import 'package:personal_digital_assets/domain/asset.dart';
import 'package:personal_digital_assets/domain/asset_attachment.dart';
import 'package:personal_digital_assets/domain/asset_note.dart';
import 'package:personal_digital_assets/domain/relation.dart';

void main() {
  late MemoryAssetRepository repository;

  setUp(() {
    repository = MemoryAssetRepository();
  });

  test('资产的增查改删', () async {
    final asset = Asset(id: 'a1', type: AssetType.password, title: '测试密码');
    await repository.saveAsset(asset);
    expect((await repository.listAssets()).length, 1);
    expect((await repository.getAsset('a1'))?.title, '测试密码');

    await repository.saveAsset(asset.copyWith(title: '新名称'));
    expect((await repository.getAsset('a1'))?.title, '新名称');

    await repository.deleteAsset('a1');
    expect(await repository.getAsset('a1'), isNull);
    expect(await repository.listAssets(), isEmpty);
  });

  test('删除资产时级联删除其关系', () async {
    await repository.saveAsset(
      Asset(id: 'a1', type: AssetType.subscription, title: '订阅'),
    );
    await repository.saveAsset(
      Asset(id: 'a2', type: AssetType.email, title: '邮箱'),
    );
    await repository.saveRelation(
      Relation(
        id: 'r1',
        fromAssetId: 'a1',
        toAssetId: 'a2',
        type: RelationType.registeredWith,
      ),
    );
    await repository.deleteAsset('a1');
    expect(await repository.listRelations(), isEmpty);
    expect(await repository.relationsOf('a2'), isEmpty);
  });

  test('relationsOf 同时返回入边与出边', () async {
    await repository.saveAsset(
      Asset(id: 'a1', type: AssetType.apiKey, title: 'Key'),
    );
    await repository.saveAsset(
      Asset(id: 'a2', type: AssetType.subscription, title: '订阅'),
    );
    await repository.saveAsset(
      Asset(id: 'a3', type: AssetType.device, title: '设备'),
    );
    await repository.saveRelation(
      Relation(
        id: 'r1',
        fromAssetId: 'a1',
        toAssetId: 'a2',
        type: RelationType.belongsTo,
      ),
    );
    await repository.saveRelation(
      Relation(
        id: 'r2',
        fromAssetId: 'a3',
        toAssetId: 'a2',
        type: RelationType.chargedFor,
      ),
    );
    final relations = await repository.relationsOf('a2');
    expect(relations.length, 2);
    expect(relations.map((relation) => relation.id), containsAll(['r1', 'r2']));
  });

  test('备注按时间倒序与删除', () async {
    await repository.saveAsset(
      Asset(id: 'a1', type: AssetType.email, title: '邮箱'),
    );
    await repository.addNote(
      AssetNote(
        id: 'n1',
        assetId: 'a1',
        content: '第一条',
        createdAt: DateTime.utc(2026, 9, 20, 8, 0, 0),
      ),
    );
    await repository.addNote(
      AssetNote(
        id: 'n2',
        assetId: 'a1',
        content: '第二条',
        createdAt: DateTime.utc(2026, 9, 21, 8, 0, 0),
      ),
    );
    final notes = await repository.listNotes('a1');
    expect(notes.map((note) => note.id), ['n2', 'n1']);

    await repository.deleteNote('n2');
    expect((await repository.listNotes('a1')).map((note) => note.id), ['n1']);
  });

  test('附件元数据与字节分开存取', () async {
    await repository.saveAsset(
      Asset(id: 'a1', type: AssetType.email, title: '邮箱'),
    );
    final bytes = Uint8List.fromList([1, 2, 3]);
    await repository.addAttachment(
      AssetAttachment(id: 'att1', assetId: 'a1', name: 'card.jpg'),
      bytes,
    );
    final attachments = await repository.listAttachments('a1');
    expect(attachments.single.name, 'card.jpg');
    expect(await repository.attachmentBytes('att1'), bytes);

    await repository.deleteAttachment('att1');
    expect(await repository.listAttachments('a1'), isEmpty);
    expect(await repository.attachmentBytes('att1'), isNull);
  });

  test('删除资产时级联删除其备注与附件', () async {
    await repository.saveAsset(
      Asset(id: 'a1', type: AssetType.email, title: '邮箱'),
    );
    await repository.addNote(AssetNote(id: 'n1', assetId: 'a1', content: '备注'));
    await repository.addAttachment(
      AssetAttachment(id: 'att1', assetId: 'a1', name: 'card.jpg'),
      const [9, 9],
    );
    await repository.deleteAsset('a1');
    expect(await repository.listNotes('a1'), isEmpty);
    expect(await repository.listAttachments('a1'), isEmpty);
    expect(await repository.attachmentBytes('att1'), isNull);
  });
}
