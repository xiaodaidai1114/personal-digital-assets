import 'dart:convert';

import '../../crypto/vault_cipher.dart';
import '../../domain/asset.dart';
import '../../domain/relation.dart';

/// 解密后的备份内容。
class BackupData {
  const BackupData({
    required this.assets,
    required this.relations,
    required this.exportedAt,
  });

  final List<Asset> assets;
  final List<Relation> relations;
  final DateTime exportedAt;
}

/// 加密备份：整个资产/关系快照作为一个 JSON 文档，
/// 用保险库密钥做 AES-256-GCM 加密后导出。文件内只含密文，无明文导出入口。
class BackupService {
  BackupService(this._cipher);

  final VaultCipher _cipher;

  static const int backupVersion = 1;

  Future<String> exportEncrypted(
    List<Asset> assets,
    List<Relation> relations,
  ) async {
    final document = jsonEncode({
      'backupVersion': backupVersion,
      'app': 'personal-digital-assets',
      'exportedAt': DateTime.now().toIso8601String(),
      'assets': assets.map((asset) => asset.toJson()).toList(),
      'relations': relations.map((relation) => relation.toJson()).toList(),
    });
    return (await _cipher.encrypt(document)).serialize();
  }

  Future<BackupData> importEncrypted(String serialized) async {
    final payload = EncryptedPayload.deserialize(serialized);
    final plain = await _cipher.decrypt(payload);
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(plain) as Map<String, dynamic>;
    } on FormatException {
      throw const FormatException('备份文件内容损坏');
    }
    if (json['backupVersion'] != backupVersion) {
      throw FormatException('不支持的备份版本: ${json['backupVersion']}');
    }
    final assetList = (json['assets'] as List<dynamic>? ?? const [])
        .map((item) => Asset.fromJson(item as Map<String, dynamic>))
        .toList();
    final relationList = (json['relations'] as List<dynamic>? ?? const [])
        .map((item) => Relation.fromJson(item as Map<String, dynamic>))
        .toList();
    return BackupData(
      assets: assetList,
      relations: relationList,
      exportedAt:
          DateTime.tryParse(json['exportedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
