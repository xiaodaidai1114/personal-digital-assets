import 'asset.dart';
import 'relation.dart';

enum AssetStatusFilter {
  pinned('置顶'),
  dueSoon('30 天临期'),
  overdue('已逾期'),
  unlinked('未关联'),
  untagged('未打标签'),
  hasAmount('有金额');

  const AssetStatusFilter(this.label);

  final String label;
}

enum AssetSortOption {
  updated('最近更新'),
  dueDate('到期时间'),
  name('名称'),
  relationCount('关系数量');

  const AssetSortOption(this.label);

  final String label;
}

/// 可组合的资产查询条件。UI 只负责收集条件，匹配与排序在这里保持可测试。
class AssetFilter {
  const AssetFilter({
    this.query = '',
    this.types = const {},
    this.includedTags = const {},
    this.excludedTags = const {},
    this.statuses = const {},
    this.sort = AssetSortOption.updated,
  });

  final String query;
  final Set<AssetType> types;
  final Set<String> includedTags;
  final Set<String> excludedTags;
  final Set<AssetStatusFilter> statuses;
  final AssetSortOption sort;

  bool get isEmpty =>
      query.trim().isEmpty &&
      types.isEmpty &&
      includedTags.isEmpty &&
      excludedTags.isEmpty &&
      statuses.isEmpty;

  int get conditionCount => [
    query.trim().isNotEmpty,
    types.isNotEmpty,
    includedTags.isNotEmpty,
    excludedTags.isNotEmpty,
    statuses.isNotEmpty,
  ].where((active) => active).length;

  AssetFilter copyWith({
    String? query,
    Set<AssetType>? types,
    Set<String>? includedTags,
    Set<String>? excludedTags,
    Set<AssetStatusFilter>? statuses,
    AssetSortOption? sort,
  }) => AssetFilter(
    query: query ?? this.query,
    types: types ?? this.types,
    includedTags: includedTags ?? this.includedTags,
    excludedTags: excludedTags ?? this.excludedTags,
    statuses: statuses ?? this.statuses,
    sort: sort ?? this.sort,
  );

  List<Asset> apply(
    List<Asset> assets,
    List<Relation> relations, {
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final relationCounts = <String, int>{};
    final adjacentTitles = <String, Set<String>>{};
    final assetById = {for (final asset in assets) asset.id: asset};
    for (final relation in relations) {
      relationCounts[relation.fromAssetId] =
          (relationCounts[relation.fromAssetId] ?? 0) + 1;
      relationCounts[relation.toAssetId] =
          (relationCounts[relation.toAssetId] ?? 0) + 1;
      adjacentTitles[relation.fromAssetId] ??= {};
      adjacentTitles[relation.toAssetId] ??= {};
      final fromTitle = assetById[relation.fromAssetId]?.title;
      final toTitle = assetById[relation.toAssetId]?.title;
      if (fromTitle != null) {
        adjacentTitles[relation.toAssetId]?.add(fromTitle);
      }
      if (toTitle != null) {
        adjacentTitles[relation.fromAssetId]?.add(toTitle);
      }
    }

    final matched = assets.where((asset) {
      if (types.isNotEmpty && !types.contains(asset.type)) {
        return false;
      }
      if (includedTags.any((tag) => !asset.tags.contains(tag))) {
        return false;
      }
      if (excludedTags.any(asset.tags.contains)) {
        return false;
      }
      final count = relationCounts[asset.id] ?? 0;
      for (final status in statuses) {
        final passes = switch (status) {
          AssetStatusFilter.pinned => asset.isPinned,
          AssetStatusFilter.dueSoon => _isDueSoon(asset, currentTime),
          AssetStatusFilter.overdue => _isOverdue(asset, currentTime),
          AssetStatusFilter.unlinked => count == 0,
          AssetStatusFilter.untagged => asset.tags.isEmpty,
          AssetStatusFilter.hasAmount =>
            (asset.fields['amount'] ?? '').toString().trim().isNotEmpty,
        };
        if (!passes) {
          return false;
        }
      }
      return _matchesQuery(asset, adjacentTitles[asset.id] ?? const {});
    }).toList();

    return sortAssets(matched, relationCounts);
  }

  List<Asset> sortAssets(List<Asset> assets, Map<String, int> relationCounts) {
    final sorted = [...assets];
    switch (sort) {
      case AssetSortOption.updated:
        sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      case AssetSortOption.dueDate:
        sorted.sort((a, b) {
          final aDate = dueDateOf(a);
          final bDate = dueDateOf(b);
          if (aDate == null && bDate == null) {
            return b.updatedAt.compareTo(a.updatedAt);
          }
          if (aDate == null) {
            return 1;
          }
          if (bDate == null) {
            return -1;
          }
          return aDate.compareTo(bDate);
        });
      case AssetSortOption.name:
        sorted.sort((a, b) => a.title.compareTo(b.title));
      case AssetSortOption.relationCount:
        sorted.sort(
          (a, b) =>
              (relationCounts[b.id] ?? 0).compareTo(relationCounts[a.id] ?? 0),
        );
    }
    return sorted;
  }

  bool _matchesQuery(Asset asset, Set<String> adjacentTitles) {
    final keyword = query.trim().toLowerCase();
    if (keyword.isEmpty) {
      return true;
    }
    final haystack = [
      asset.title,
      asset.type.label,
      ...asset.tags,
      ...asset.fields.values.map((value) => value.toString()),
      ...adjacentTitles,
    ].join('\n').toLowerCase();
    return keyword
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .every(haystack.contains);
  }

  static DateTime? dueDateOf(Asset asset) {
    final value =
        asset.fields['nextRenewalDate'] ??
        asset.fields['dueDate'] ??
        asset.fields['expiryDate'] ??
        (asset.type == AssetType.bill ? asset.fields['date'] : null);
    return DateTime.tryParse(value?.toString() ?? '');
  }

  static bool _isDueSoon(Asset asset, DateTime now) {
    final dueDate = dueDateOf(asset);
    return dueDate != null &&
        !dueDate.isBefore(DateTime(now.year, now.month, now.day)) &&
        dueDate.isBefore(now.add(const Duration(days: 30)));
  }

  static bool _isOverdue(Asset asset, DateTime now) {
    final dueDate = dueDateOf(asset);
    return dueDate != null && dueDate.isBefore(now);
  }
}
