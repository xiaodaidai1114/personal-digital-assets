import 'package:flutter_test/flutter_test.dart';
import 'package:personal_digital_assets/domain/asset.dart';
import 'package:personal_digital_assets/domain/asset_filter.dart';
import 'package:personal_digital_assets/domain/relation.dart';

void main() {
  final now = DateTime(2026, 9, 20, 10);

  final subscription = Asset(
    id: 'subscription',
    type: AssetType.subscription,
    title: 'AI 助手订阅',
    fields: {
      'plan': 'Pro',
      'amount': '20 USD',
      'nextRenewalDate': '2026-10-05',
    },
    tags: ['AI', '生产'],
    isPinned: true,
    createdAt: DateTime(2026, 9, 17),
    updatedAt: DateTime(2026, 9, 18),
  );
  final apiKey = Asset(
    id: 'api-key',
    type: AssetType.apiKey,
    title: '模型平台 Key',
    fields: {'prefix': 'sk-FAKE', 'expiryDate': '2026-09-01'},
    tags: ['AI'],
    createdAt: DateTime(2026, 9, 18),
    updatedAt: DateTime(2026, 9, 19),
  );
  final email = Asset(
    id: 'email',
    type: AssetType.email,
    title: '主邮箱',
    createdAt: DateTime(2026, 9, 19),
    updatedAt: DateTime(2026, 9, 20),
  );
  final device = Asset(
    id: 'device',
    type: AssetType.device,
    title: '备份手机',
    fields: {'amount': '2,999 CNY'},
    tags: ['生产', '硬件'],
    createdAt: DateTime(2026, 9, 16),
    updatedAt: DateTime(2026, 9, 16),
  );
  final assets = [subscription, apiKey, email, device];
  final relations = [
    Relation(
      id: 'r1',
      fromAssetId: 'api-key',
      toAssetId: 'subscription',
      type: RelationType.belongsTo,
    ),
  ];

  test('关键词可匹配字段值与关联资产标题', () {
    final byField = const AssetFilter(query: 'sk-FAKE')
        .apply(assets, relations, now: now);
    expect(byField.map((asset) => asset.id), ['api-key']);

    final byNeighbor = const AssetFilter(query: 'AI 助手订阅')
        .apply(assets, relations, now: now);
    expect(
      byNeighbor.map((asset) => asset.id),
      containsAll(['subscription', 'api-key']),
    );
  });

  test('类型多选与标签包含/排除可组合', () {
    final result = const AssetFilter(
      types: {AssetType.subscription, AssetType.apiKey, AssetType.device},
      includedTags: {'AI'},
      excludedTags: {'生产'},
    ).apply(assets, relations, now: now);
    expect(result.map((asset) => asset.id), ['api-key']);
  });

  test('状态筛选支持置顶、临期、未关联与未打标签', () {
    final actionable = const AssetFilter(
      statuses: {
        AssetStatusFilter.pinned,
        AssetStatusFilter.dueSoon,
        AssetStatusFilter.hasAmount,
      },
    ).apply(assets, relations, now: now);
    expect(actionable.map((asset) => asset.id), ['subscription']);

    final unlinked = const AssetFilter(
      statuses: {AssetStatusFilter.unlinked, AssetStatusFilter.untagged},
    ).apply(assets, relations, now: now);
    expect(unlinked.map((asset) => asset.id), ['email']);
  });

  test('支持名称、到期时间与关系数量排序', () {
    expect(
      const AssetFilter(sort: AssetSortOption.name)
          .apply(assets, relations, now: now)
          .map((asset) => asset.id),
      ['subscription', 'email', 'device', 'api-key'],
    );
    expect(
      const AssetFilter(sort: AssetSortOption.dueDate)
          .apply(assets, relations, now: now)
          .map((asset) => asset.id),
      ['api-key', 'subscription', 'email', 'device'],
    );
    expect(
      const AssetFilter(sort: AssetSortOption.relationCount)
          .apply(assets, relations, now: now)
          .first
          .id,
      anyOf('subscription', 'api-key'),
    );
  });
}
