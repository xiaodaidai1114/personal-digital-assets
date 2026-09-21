import 'package:flutter_test/flutter_test.dart';
import 'package:personal_digital_assets/domain/asset.dart';
import 'package:personal_digital_assets/domain/asset_attachment.dart';
import 'package:personal_digital_assets/domain/asset_note.dart';
import 'package:personal_digital_assets/domain/relation.dart';

void main() {
  test('Asset JSON 序列化往返', () {
    final createdAt = DateTime.utc(2026, 9, 19, 8, 0, 0);
    final asset = Asset(
      id: 'asset-1',
      type: AssetType.apiKey,
      title: '示例 Key',
      fields: {'prefix': 'sk-FAKE'},
      tags: ['演示', 'AI'],
      encryptedSecret: '{"version":1}',
      isPinned: true,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    final restored = Asset.fromJson(asset.toJson());
    expect(restored.id, asset.id);
    expect(restored.type, AssetType.apiKey);
    expect(restored.title, asset.title);
    expect(restored.fields, asset.fields);
    expect(restored.tags, asset.tags);
    expect(restored.encryptedSecret, asset.encryptedSecret);
    expect(restored.isPinned, isTrue);
    expect(restored.createdAt, createdAt);
    expect(restored.updatedAt, createdAt);
  });

  test('AssetType.fromName 未知类型回退为 other', () {
    expect(AssetType.fromName('unknown-type'), AssetType.other);
  });

  test('Asset.copyWith 只覆盖指定字段', () {
    final createdAt = DateTime.utc(2026, 9, 19, 8, 0, 0);
    final updatedAt = DateTime.utc(2026, 9, 20, 8, 0, 0);
    final asset = Asset(
      id: 'asset-1',
      type: AssetType.password,
      title: '旧名称',
      tags: ['旧'],
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    final copied = asset.copyWith(
      title: '新名称',
      tags: ['新'],
      updatedAt: updatedAt,
    );
    expect(copied.id, asset.id);
    expect(copied.type, AssetType.password);
    expect(copied.title, '新名称');
    expect(copied.tags, ['新']);
    expect(copied.updatedAt, updatedAt);
  });

  test('Relation JSON 序列化往返', () {
    final createdAt = DateTime.utc(2026, 9, 19, 8, 0, 0);
    final relation = Relation(
      id: 'relation-1',
      fromAssetId: 'asset-1',
      toAssetId: 'asset-2',
      type: RelationType.belongsTo,
      note: '示例备注',
      createdAt: createdAt,
    );
    final restored = Relation.fromJson(relation.toJson());
    expect(restored.id, relation.id);
    expect(restored.fromAssetId, relation.fromAssetId);
    expect(restored.toAssetId, relation.toAssetId);
    expect(restored.type, RelationType.belongsTo);
    expect(restored.note, relation.note);
    expect(restored.createdAt, createdAt);
  });

  test('AssetNote JSON 序列化往返', () {
    final createdAt = DateTime.utc(2026, 9, 21, 8, 0, 0);
    final note = AssetNote(
      id: 'note-1',
      assetId: 'asset-1',
      content: '已开启二次验证',
      createdAt: createdAt,
    );
    final restored = AssetNote.fromJson(note.toJson());
    expect(restored.id, note.id);
    expect(restored.assetId, note.assetId);
    expect(restored.content, note.content);
    expect(restored.createdAt, createdAt);
  });

  test('AssetAttachment JSON 序列化往返（元数据不含字节）', () {
    final createdAt = DateTime.utc(2026, 9, 21, 8, 0, 0);
    final attachment = AssetAttachment(
      id: 'attachment-1',
      assetId: 'asset-1',
      name: 'receipt.jpg',
      mimeType: 'image/jpeg',
      byteSize: 2048,
      createdAt: createdAt,
    );
    final json = attachment.toJson();
    expect(json.containsKey('bytes'), isFalse);
    final restored = AssetAttachment.fromJson(json);
    expect(restored.id, attachment.id);
    expect(restored.assetId, attachment.assetId);
    expect(restored.name, attachment.name);
    expect(restored.mimeType, attachment.mimeType);
    expect(restored.byteSize, attachment.byteSize);
    expect(restored.createdAt, createdAt);
  });
}
