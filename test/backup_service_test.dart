import 'package:flutter_test/flutter_test.dart';
import 'package:personal_digital_assets/data/backup/backup_service.dart';
import 'package:personal_digital_assets/domain/asset.dart';
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
}
