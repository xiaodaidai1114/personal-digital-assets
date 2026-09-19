import 'dart:convert';

/// 资产类型：一切资产皆为节点，用 type 区分展示方式。
enum AssetType {
  email('邮箱'),
  subscription('订阅'),
  apiKey('API Key'),
  password('密码'),
  device('设备'),
  item('物品'),
  bill('账单'),
  bankCard('银行卡'),
  other('其他');

  const AssetType(this.label);

  final String label;

  static AssetType fromName(String value) => AssetType.values.firstWhere(
        (type) => type.name == value,
        orElse: () => AssetType.other,
      );
}

/// 资产节点。敏感内容只保存加密后的密文（EncryptedPayload JSON），明文永不进入本模型。
class Asset {
  Asset({
    required this.id,
    required this.type,
    required this.title,
    this.fields = const {},
    this.tags = const [],
    this.encryptedSecret,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  final String id;
  final AssetType type;
  final String title;
  final Map<String, dynamic> fields;
  final List<String> tags;
  final String? encryptedSecret;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Asset.fromJson(Map<String, dynamic> json) => Asset(
        id: json['id'] as String,
        type: AssetType.fromName(json['type'] as String),
        title: json['title'] as String,
        fields: (json['fields'] as Map<String, dynamic>?) ?? const {},
        tags: ((json['tags'] as List<dynamic>?) ?? const <dynamic>[])
            .map((tag) => tag as String)
            .toList(),
        encryptedSecret: json['encryptedSecret'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'fields': fields,
        'tags': tags,
        'encryptedSecret': encryptedSecret,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  Asset copyWith({
    String? id,
    AssetType? type,
    String? title,
    Map<String, dynamic>? fields,
    List<String>? tags,
    String? encryptedSecret,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Asset(
        id: id ?? this.id,
        type: type ?? this.type,
        title: title ?? this.title,
        fields: fields ?? this.fields,
        tags: tags ?? this.tags,
        encryptedSecret: encryptedSecret ?? this.encryptedSecret,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  String toString() => jsonEncode(toJson());
}
