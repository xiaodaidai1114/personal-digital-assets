/// 资产备注：时间线上的明文短记录，仅存于加密数据库内，不另落盘。
class AssetNote {
  AssetNote({
    required this.id,
    required this.assetId,
    required this.content,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String assetId;
  final String content;
  final DateTime createdAt;

  factory AssetNote.fromJson(Map<String, dynamic> json) => AssetNote(
    id: json['id'] as String,
    assetId: json['assetId'] as String,
    content: json['content'] as String,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'assetId': assetId,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
  };
}
