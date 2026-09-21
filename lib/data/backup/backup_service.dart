import 'dart:convert';

import '../../crypto/vault_cipher.dart';
import '../../domain/asset.dart';
import '../../domain/asset_attachment.dart';
import '../../domain/asset_note.dart';
import '../../domain/relation.dart';

/// 解密后的备份内容。
///
/// v1 备份没有备注与图片，导入后 notes/attachments/attachmentBytes 为空集合。
class BackupData {
  const BackupData({
    required this.assets,
    required this.relations,
    required this.exportedAt,
    this.notes = const [],
    this.attachments = const [],
    this.attachmentBytes = const {},
  });

  final List<Asset> assets;
  final List<Relation> relations;
  final DateTime exportedAt;
  final List<AssetNote> notes;
  final List<AssetAttachment> attachments;

  /// 附件图片字节，按附件 id 索引（v1 或缺失字节的附件无条目）。
  final Map<String, List<int>> attachmentBytes;
}

/// 加密备份：整个资产/关系/备注/图片快照作为一个 JSON 文档，
/// 用保险库密钥做 AES-256-GCM 加密后导出。文件内只含密文，无明文导出入口。
class BackupService {
  BackupService(this._cipher);

  final VaultCipher _cipher;

  static const int backupVersion = 2;

  Future<String> exportEncrypted(
    List<Asset> assets,
    List<Relation> relations, {
    List<AssetNote> notes = const [],
    List<AssetAttachment> attachments = const [],
    Map<String, List<int>> attachmentBytes = const {},
  }) async {
    final document = jsonEncode({
      'backupVersion': backupVersion,
      'app': 'personal-digital-assets',
      'exportedAt': DateTime.now().toIso8601String(),
      'assets': assets.map((asset) => asset.toJson()).toList(),
      'relations': relations.map((relation) => relation.toJson()).toList(),
      'notes': notes.map((note) => note.toJson()).toList(),
      'attachments': [
        for (final attachment in attachments)
          {
            ...attachment.toJson(),
            'bytes': base64Encode(attachmentBytes[attachment.id] ?? const []),
          },
      ],
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
    // 兼容 v1（无备注与图片）：1..当前版本均可导入，旧文档新集合为空
    final version = json['backupVersion'];
    if (version is! int || version < 1 || version > backupVersion) {
      throw FormatException('不支持的备份版本: ${json['backupVersion']}');
    }
    final assetList = (json['assets'] as List<dynamic>? ?? const [])
        .map((item) => Asset.fromJson(item as Map<String, dynamic>))
        .toList();
    final relationList = (json['relations'] as List<dynamic>? ?? const [])
        .map((item) => Relation.fromJson(item as Map<String, dynamic>))
        .toList();
    final noteList = (json['notes'] as List<dynamic>? ?? const [])
        .map((item) => AssetNote.fromJson(item as Map<String, dynamic>))
        .toList();
    final attachmentList =
        (json['attachments'] as List<dynamic>? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
    final bytes = <String, List<int>>{};
    for (final entry in attachmentList) {
      final encoded = entry.remove('bytes');
      if (encoded is String && encoded.isNotEmpty) {
        bytes[entry['id'] as String] = base64Decode(encoded);
      }
    }
    return BackupData(
      assets: assetList,
      relations: relationList,
      exportedAt:
          DateTime.tryParse(json['exportedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      notes: noteList,
      attachments: attachmentList
          .map(AssetAttachment.fromJson)
          .toList(growable: false),
      attachmentBytes: bytes,
    );
  }
}
