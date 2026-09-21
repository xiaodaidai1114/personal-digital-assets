import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_digital_assets/data/backup/backup_service.dart';
import 'package:personal_digital_assets/domain/asset.dart';
import 'package:personal_digital_assets/domain/asset_attachment.dart';
import 'package:personal_digital_assets/domain/asset_note.dart';
import 'package:personal_digital_assets/domain/relation.dart';
import 'package:personal_digital_assets/crypto/vault_cipher.dart';

void main() {
  List<Asset> sampleAssets() => [
        Asset(id: 'a1', type: AssetType.email, title: '主邮箱', fields: {
          'address': 'user@example.com',
        }),
        Asset(id: 'a2', type: AssetType.bill, title: '账单', tags: ['月结']),
      ];

  List<Relation> sampleRelations() => [
        Relation(
          id: 'r1',
          fromAssetId: 'a1',
          toAssetId: 'a2',
          type: RelationType.relatesTo,
        ),
      ];

  test('备份导出后可完整恢复', () async {
    final service = BackupService(VaultCipher(List.filled(32, 7)));
    final serialized =
        await service.exportEncrypted(sampleAssets(), sampleRelations());
    // 密文不包含任何明文标题。
    expect(serialized, isNot(contains('主邮箱')));

    final restored = await service.importEncrypted(serialized);
    expect(restored.assets.length, 2);
    expect(restored.assets.first.title, '主邮箱');
    expect(restored.assets.first.fields['address'], 'user@example.com');
    expect(restored.assets.last.tags, ['月结']);
    expect(restored.relations.single.type, RelationType.relatesTo);
  });

  test('备份被篡改或密钥错误时恢复失败', () async {
    final service = BackupService(VaultCipher(List.filled(32, 7)));
    final serialized =
        await service.exportEncrypted(sampleAssets(), sampleRelations());
    expect(
      () => service.importEncrypted(serialized.replaceFirst('a', 'b')),
      throwsA(anything),
    );

    final other = BackupService(VaultCipher(List.filled(32, 8)));
    expect(() => other.importEncrypted(serialized), throwsA(anything));
  });

  test('v2 备份含备注与图片并可完整恢复', () async {
    final cipher = VaultCipher(List.filled(32, 7));
    final service = BackupService(cipher);
    final bytes = List<int>.generate(64, (i) => i);
    final note = AssetNote(id: 'n1', assetId: 'a1', content: '已开启二次验证');
    final attachment = AssetAttachment(
      id: 'att1',
      assetId: 'a1',
      name: 'card.jpg',
      mimeType: 'image/jpeg',
      byteSize: bytes.length,
    );
    final serialized = await service.exportEncrypted(
      sampleAssets(),
      sampleRelations(),
      notes: [note],
      attachments: [attachment],
      attachmentBytes: {'att1': bytes},
    );
    // 密文不包含明文标题与备注内容
    expect(serialized, isNot(contains('主邮箱')));
    expect(serialized, isNot(contains('已开启二次验证')));

    final restored = await service.importEncrypted(serialized);
    expect(restored.notes.single.content, '已开启二次验证');
    expect(restored.notes.single.assetId, 'a1');
    expect(restored.attachments.single.name, 'card.jpg');
    expect(restored.attachments.single.byteSize, bytes.length);
    expect(restored.attachmentBytes['att1'], bytes);
  });

  test('v1 备份仍可导入（备注与图片为空）', () async {
    final cipher = VaultCipher(List.filled(32, 7));
    // 手工构造 v1 文档：只有资产与关联，无 notes/attachments 键
    final v1Document = jsonEncode({
      'backupVersion': 1,
      'app': 'personal-digital-assets',
      'exportedAt': '2026-09-01T08:00:00.000Z',
      'assets': sampleAssets().map((asset) => asset.toJson()).toList(),
      'relations': sampleRelations().map((r) => r.toJson()).toList(),
    });
    final serialized = (await cipher.encrypt(v1Document)).serialize();

    final restored = await BackupService(cipher).importEncrypted(serialized);
    expect(restored.assets.length, 2);
    expect(restored.assets.first.title, '主邮箱');
    expect(restored.relations.single.id, 'r1');
    expect(restored.notes, isEmpty);
    expect(restored.attachments, isEmpty);
    expect(restored.attachmentBytes, isEmpty);
  });

  test('更高版本备份被拒绝', () async {
    final cipher = VaultCipher(List.filled(32, 7));
    final futureDocument = jsonEncode({
      'backupVersion': BackupService.backupVersion + 1,
      'app': 'personal-digital-assets',
      'exportedAt': '2026-09-01T08:00:00.000Z',
      'assets': const [],
      'relations': const [],
    });
    final serialized = (await cipher.encrypt(futureDocument)).serialize();
    expect(
      () => BackupService(cipher).importEncrypted(serialized),
      throwsFormatException,
    );
  });
}
