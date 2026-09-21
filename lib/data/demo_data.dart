import 'package:uuid/uuid.dart';

import '../domain/asset.dart';
import '../domain/asset_note.dart';
import '../domain/relation.dart';
import 'asset_repository.dart';

/// 向仓库写入演示数据。全部为虚构占位内容，不含任何真实个人信息。
/// 仅在新装（仓库为空）时调用。
Future<void> seedDemoData(AssetRepository repository) async {
  const uuid = Uuid();
  final emailId = uuid.v4();
  final subscriptionId = uuid.v4();
  final apiKeyId = uuid.v4();
  final deviceId = uuid.v4();
  final billId = uuid.v4();
  final passwordId = uuid.v4();

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
      fields: {
        'plan': 'Pro',
        'cycle': 'monthly',
        'amount': '20 USD',
        'nextRenewalDate': '2026-09-28',
      },
      tags: ['演示', 'AI'],
    ),
    Asset(
      id: apiKeyId,
      type: AssetType.apiKey,
      title: 'AI 助手 API Key',
      fields: {'prefix': 'sk-FAKE'},
      tags: ['演示', 'AI'],
      isPinned: true,
    ),
    Asset(
      id: passwordId,
      type: AssetType.password,
      title: '示例网站密码',
      fields: {'username': 'user@example.com', 'url': 'https://example.com'},
      tags: ['演示'],
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
    Relation(
      id: uuid.v4(),
      fromAssetId: passwordId,
      toAssetId: emailId,
      type: RelationType.recovers,
    ),
  ];
  for (final relation in relations) {
    await repository.saveRelation(relation);
  }

  final notes = [
    AssetNote(
      id: uuid.v4(),
      assetId: subscriptionId,
      content: '已开启二次验证，恢复码放在封缄里',
      createdAt: DateTime.now().subtract(const Duration(days: 6)),
    ),
    AssetNote(
      id: uuid.v4(),
      assetId: subscriptionId,
      content: '续费邮件每月 28 号前提醒，记得核对金额',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    AssetNote(
      id: uuid.v4(),
      assetId: emailId,
      content: '主邮箱用于注册重要服务，不参与抽奖等活动',
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
  ];
  for (final note in notes) {
    await repository.addNote(note);
  }
}
