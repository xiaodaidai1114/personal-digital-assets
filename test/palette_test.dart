import 'package:flutter_test/flutter_test.dart';
import 'package:personal_digital_assets/domain/asset.dart';
import 'package:personal_digital_assets/ui/palette/fuzzy_match.dart';
import 'package:personal_digital_assets/ui/widgets/smart_truncate.dart';

Asset _asset(
  String id,
  String title, {
  AssetType type = AssetType.password,
  Map<String, String> fields = const {},
  List<String> tags = const [],
}) => Asset(
  id: id,
  type: type,
  title: title,
  fields: fields,
  tags: tags,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  final assets = [
    _asset(
      'mail',
      '主邮箱',
      type: AssetType.email,
      fields: {'address': 'user@example.com'},
      tags: ['演示'],
    ),
    _asset(
      'ai-sub',
      'AI 助手订阅',
      type: AssetType.subscription,
      tags: ['演示', 'AI'],
    ),
    _asset(
      'ai-key',
      'AI 助手 API Key',
      fields: {'prefix': 'sk-FAKE'},
      tags: ['AI'],
    ),
    _asset(
      'phone',
      '安卓手机',
      type: AssetType.device,
      fields: {'os': 'Android 15'},
      tags: ['演示'],
    ),
    _asset(
      'bill',
      '10 月订阅账单',
      type: AssetType.bill,
      fields: {'amount': '20 USD'},
    ),
  ];

  group('rankAssets', () {
    test('空查询返回全部且零分', () {
      final hits = rankAssets('', assets);
      expect(hits.length, assets.length);
      expect(hits.every((hit) => hit.score == 0), isTrue);
    });

    test('标题命中优先于仅标签/字段命中', () {
      final hits = rankAssets('ai', assets);
      expect(hits, isNotEmpty);
      // 「AI 助手订阅」「AI 助手 API Key」标题命中，必须排在仅靠标签命中的资产之前
      expect(hits.first.asset.title, contains('AI 助手'));
      final titleHit = hits.firstWhere(
        (hit) => hit.asset.title == 'AI 助手 API Key',
      );
      expect(titleHit.ranges, isNotNull);
      final tagOnly = hits.where((hit) => hit.asset.id == 'ai-sub').toList();
      expect(tagOnly, isNotEmpty);
    });

    test('字段值可检索（暗数据不出暗区）', () {
      final hits = rankAssets('android', assets);
      // 「安卓手机」标题不含 android，仅靠 os 字段命中
      expect(hits.map((hit) => hit.asset.id), contains('phone'));
      expect(hits.first.asset.id, 'phone');
    });

    test('大小写不敏感的子序列匹配', () {
      final hits = rankAssets('akey', assets);
      expect(hits.map((hit) => hit.asset.id), contains('ai-key'));
    });

    test('不匹配时返回空', () {
      expect(rankAssets('zzz不存在的查询', assets), isEmpty);
    });

    test('高亮区间为连续段且端点排他', () {
      final hits = rankAssets('邮箱', assets);
      final hit = hits.singleWhere((hit) => hit.asset.id == 'mail');
      expect(hit.ranges, hasLength(1));
      final range = hit.ranges!.first;
      expect(hit.asset.title.substring(range.start, range.end), '邮箱');
    });
  });

  group('smartTruncate', () {
    test('短文本原样返回', () {
      expect(smartTruncate('sk-FAKE-1234', max: 28), 'sk-FAKE-1234');
    });

    test('长文本中段折叠保留首尾', () {
      final text = 'api.openai.com/v1/organization/project-token-9f8e7d6c';
      final out = smartTruncate(text, max: 20);
      expect(out.length, 20);
      expect(out.contains('…'), isTrue);
      expect(out.startsWith('api.openai.'), isTrue);
      expect(out.endsWith('9f8e7d6c'.substring('9f8e7d6c'.length - 7)), isTrue);
    });

    test('max 过小直接原样返回', () {
      expect(smartTruncate('abcdefgh', max: 4), 'abcdefgh');
    });
  });
}
