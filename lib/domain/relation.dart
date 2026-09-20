/// 关系类型：资产之间的有向边。
enum RelationType {
  registeredWith('注册于'),
  belongsTo('属于'),
  storedOn('存储在'),
  usedBy('被使用'),
  recovers('恢复'),
  paidWith('支付方式'),
  chargedFor('计费对象'),
  receiptIn('账单收于'),
  relatesTo('关联');

  const RelationType(this.label);

  final String label;

  static RelationType fromName(String value) => RelationType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => RelationType.relatesTo,
  );
}

/// 关系边：从 fromAsset 指向 toAsset。
class Relation {
  Relation({
    required this.id,
    required this.fromAssetId,
    required this.toAssetId,
    required this.type,
    this.note,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String fromAssetId;
  final String toAssetId;
  final RelationType type;
  final String? note;
  final DateTime createdAt;

  factory Relation.fromJson(Map<String, dynamic> json) => Relation(
    id: json['id'] as String,
    fromAssetId: json['fromAssetId'] as String,
    toAssetId: json['toAssetId'] as String,
    type: RelationType.fromName(json['type'] as String),
    note: json['note'] as String?,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'fromAssetId': fromAssetId,
    'toAssetId': toAssetId,
    'type': type.name,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
  };
}
