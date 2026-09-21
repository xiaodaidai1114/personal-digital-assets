/// 资产图片附件元数据；图片字节单独存放（加密库 BLOB），
/// 列表查询只取元数据，需要时再按 id 读取字节。
class AssetAttachment {
  AssetAttachment({
    required this.id,
    required this.assetId,
    required this.name,
    this.mimeType,
    this.byteSize = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String assetId;

  /// 展示名，如 'receipt.jpg'。
  final String name;
  final String? mimeType;
  final int byteSize;
  final DateTime createdAt;

  factory AssetAttachment.fromJson(Map<String, dynamic> json) =>
      AssetAttachment(
        id: json['id'] as String,
        assetId: json['assetId'] as String,
        name: json['name'] as String,
        mimeType: json['mimeType'] as String?,
        byteSize: (json['byteSize'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'assetId': assetId,
    'name': name,
    'mimeType': mimeType,
    'byteSize': byteSize,
    'createdAt': createdAt.toIso8601String(),
  };
}
