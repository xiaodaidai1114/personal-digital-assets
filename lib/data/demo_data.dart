import 'package:uuid/uuid.dart';

import '../domain/asset.dart';
import '../domain/relation.dart';
import 'memory_asset_repository.dart';

/// 写入演示数据。全部为虚构占位内容，不含任何真实个人信息。
Future<MemoryAssetRepository> seedDemoData() async {
  final repository = MemoryAssetRepository();
  const uuid = Uuid();
  final emailId = uuid.v4();
  final subscriptionId = uuid.v4();
  final apiKeyId = uuid.v4();
  final deviceId = uuid.v4();
  final billId = uuid.v4();

  final assets = [
    Asset(
      id: emailId,
      type: AssetType.email,
      title: '主邮箱',
      fields: {'address': 'user@example.com'},
      tags: ['演示'],
    ),
    Asset(
      id: subscriptionId,
      type: AssetType.subscription,
      title: 'AI 助手订阅',
      fields: {'plan': 'Pro', 'cycle': 'monthly', 'amount': '20 USD'},
      tags: ['演示', 'AI'],
    ),
    Asset(
      id: apiKeyId,
      type: AssetType.apiKey,
      title: 'AI 助手 API Key',
      fields: {'prefix': 'sk-FAKE'},
      tags: ['演示', 'AI'],
    ),
    Asset(
      id: deviceId,
      type: AssetType.device,
      title: '安卓手机',
      fields: {'os': 'Android'},
      tags: ['演示'],
    ),
    Asset(
      id: billId,
      type: AssetType.bill,
      title: '10 月订阅账单',
      fields: {'amount': '20 USD', 'date': '2026-10-01'},
      tags: ['演示'],
    ),
  ];
  for (final asset in assets) {
    await repository.saveAsset(asset);
  }

  final relations = [
    Relation(
      id: uuid.v4(),
      fromAssetId: subscriptionId,
      toAssetId: emailId,
      type: RelationType.registeredWith,
    ),
    Relation(
      id: uuid.v4(),
      fromAssetId: apiKeyId,
      toAssetId: subscriptionId,
      type: RelationType.belongsTo,
    ),
    Relation(
      id: uuid.v4(),
      fromAssetId: billId,
      toAssetId: subscriptionId,
      type: RelationType.chargedFor,
    ),
    Relation(
      id: uuid.v4(),
      fromAssetId: apiKeyId,
      toAssetId: deviceId,
      type: RelationType.storedOn,
    ),
  ];
  for (final relation in relations) {
    await repository.saveRelation(relation);
  }
  return repository;
}
