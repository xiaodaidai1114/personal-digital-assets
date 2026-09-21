import 'package:flutter/painting.dart' show TextRange;

import '../../domain/asset.dart';

/// 命令面板命中结果：得分 + 标题高亮区间（供 TextSpan 渲染）。
class PaletteHit {
  const PaletteHit({required this.asset, required this.score, this.ranges});

  final Asset asset;
  final int score;
  final List<TextRange>? ranges;
}

/// 极模糊匹配（DESIGN.md 命令控制台）：
/// 大小写不敏感的子序列匹配，对连续段、词首、短命中加分；
/// 标题权重最高，其次标签与类型，再次自定义字段键值。
/// 全部命中字段进入索引，消除无法检索的暗数据。
List<PaletteHit> rankAssets(String query, List<Asset> assets) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) {
    return [for (final asset in assets) PaletteHit(asset: asset, score: 0)];
  }
  final hits = <PaletteHit>[];
  for (final asset in assets) {
    final title = _match(trimmed, asset.title, weight: 10);
    if (title != null) {
      hits.add(
        PaletteHit(asset: asset, score: title.score, ranges: title.ranges),
      );
      continue;
    }
    var best = 0;
    for (final tag in asset.tags) {
      final hit = _match(trimmed, tag, weight: 6);
      if (hit != null && hit.score > best) {
        best = hit.score;
      }
    }
    final type = _match(trimmed, asset.type.label, weight: 5);
    if (type != null && type.score > best) {
      best = type.score;
    }
    for (final entry in asset.fields.entries) {
      for (final candidate in [entry.key, entry.value.toString()]) {
        final hit = _match(trimmed, candidate, weight: 4);
        if (hit != null && hit.score > best) {
          best = hit.score;
        }
      }
    }
    if (best > 0) {
      hits.add(PaletteHit(asset: asset, score: best));
    }
  }
  hits.sort((a, b) => b.score.compareTo(a.score));
  return hits;
}

class _ScoredMatch {
  const _ScoredMatch(this.score, this.ranges);
  final int score;
  final List<TextRange> ranges;
}

_ScoredMatch? _match(String needle, String haystack, {required int weight}) {
  final hay = haystack.toLowerCase();
  final need = needle.toLowerCase();
  final indices = <int>[];
  var cursor = 0;
  for (var i = 0; i < need.length; i++) {
    final found = hay.indexOf(need[i], cursor);
    if (found < 0) {
      return null;
    }
    indices.add(found);
    cursor = found + 1;
  }
  // 连续段越长越优；词首（行首或分隔符后）命中额外加分
  var score = weight;
  var run = 1;
  for (var i = 1; i < indices.length; i++) {
    if (indices[i] == indices[i - 1] + 1) {
      run++;
    } else {
      score += _runBonus(run);
      run = 1;
    }
  }
  score += _runBonus(run);
  for (final index in indices) {
    final atWordStart =
        index == 0 ||
        _isSeparator(hay.codeUnitAt(index - 1)) ||
        _isCaseBoundary(hay, index);
    if (atWordStart) {
      score += 2;
    }
  }
  // 短命中（命中字符占比高）优先
  score += ((need.length / hay.length) * 10).round();
  // 折叠出连续高亮区间
  final ranges = <TextRange>[];
  var start = indices.first;
  var end = start;
  for (var i = 1; i < indices.length; i++) {
    if (indices[i] == end + 1) {
      end = indices[i];
    } else {
      ranges.add(TextRange(start: start, end: end + 1));
      start = indices[i];
      end = start;
    }
  }
  ranges.add(TextRange(start: start, end: end + 1));
  return _ScoredMatch(score, ranges);
}

int _runBonus(int run) => run >= 3 ? run * 2 : run;

bool _isSeparator(int code) =>
    code == 0x20 || code == 0x2D || code == 0x5F || code == 0x2E; // 空格 - _ .

bool _isCaseBoundary(String text, int index) {
  if (index == 0 || index >= text.length) {
    return false;
  }
  final prev = text.codeUnitAt(index - 1);
  final current = text.codeUnitAt(index);
  final prevLower = prev >= 0x61 && prev <= 0x7A;
  final currentUpper = current >= 0x41 && current <= 0x5A;
  return prevLower && currentUpper;
}
