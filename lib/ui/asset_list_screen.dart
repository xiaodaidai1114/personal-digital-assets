import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/asset_repository.dart';
import '../domain/asset.dart';
import '../domain/asset_filter.dart';
import '../domain/relation.dart';
import '../theme/app_theme.dart';
import '../vault/vault_controller.dart';
import 'asset_detail_screen.dart';
import 'asset_edit_screen.dart';
import 'graph_screen.dart';
import 'widgets/asset_type_badge.dart';
import 'widgets/empty_state.dart';

class AssetListScreen extends StatefulWidget {
  const AssetListScreen({
    super.key,
    required this.controller,
    required this.repository,
    this.onDataChanged,
  });

  final VaultController controller;
  final AssetRepository repository;

  /// 数据变化后（新增/编辑/删除/关联变更）回调，用于重排提醒。
  final VoidCallback? onDataChanged;

  @override
  State<AssetListScreen> createState() => _AssetListScreenState();
}

class _AssetListScreenState extends State<AssetListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Asset> _assets = const [];
  List<Relation> _relations = const [];
  AssetFilter _filter = const AssetFilter();
  bool _loading = true;
  String? _error;
  final Set<String> _selectedAssetIds = {};
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (_filter.query != _searchController.text) {
        setState(
          () => _filter = _filter.copyWith(query: _searchController.text),
        );
      }
    });
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    if (_error != null) {
      setState(() => _loading = true);
    }
    try {
      final assets = await widget.repository.listAssets();
      final relations = await widget.repository.listRelations();
      if (!mounted) {
        return;
      }
      setState(() {
        _assets = assets;
        _relations = relations;
        _loading = false;
        _error = null;
      });
      widget.onDataChanged?.call();
    } on Exception {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '读取资产失败';
      });
    }
  }

  Future<void> _openEditor([Asset? asset]) async {
    var initialType = AssetType.password;
    if (asset == null) {
      final selected = await showModalBottomSheet<AssetType>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => const _AssetTypeSheet(),
      );
      if (selected == null) {
        return;
      }
      initialType = selected;
    }
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssetEditScreen(
          controller: widget.controller,
          repository: widget.repository,
          asset: asset,
          initialType: asset?.type ?? initialType,
        ),
      ),
    );
    await _reload();
  }

  Future<void> _openGraph(String focusAssetId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GraphScreen(
          controller: widget.controller,
          repository: widget.repository,
          onManageAssets: () => Navigator.of(context).pop(),
          initialFocusId: focusAssetId,
        ),
      ),
    );
  }

  Future<void> _openDetail(String assetId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssetDetailScreen(
          controller: widget.controller,
          repository: widget.repository,
          assetId: assetId,
          onOpenGraph: () => _openGraph(assetId),
        ),
      ),
    );
    await _reload();
  }

  Future<void> _togglePinned(Asset asset) async {
    await widget.repository.saveAsset(
      asset.copyWith(isPinned: !asset.isPinned),
    );
    await _reload();
  }

  void _toggleSelection(Asset asset) {
    setState(() {
      if (!_selectedAssetIds.remove(asset.id)) {
        _selectedAssetIds.add(asset.id);
      }
      _selectionMode = _selectedAssetIds.isNotEmpty;
    });
  }

  Future<void> _batchAddTag() async {
    final tag = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _BatchTagSheet(),
    );
    final normalizedTag = tag?.trim() ?? '';
    if (normalizedTag.isEmpty) {
      return;
    }
    if (!mounted) {
      return;
    }
    final selectedAssets = _assets
        .where((asset) => _selectedAssetIds.contains(asset.id))
        .toList();
    for (final asset in selectedAssets) {
      if (!asset.tags.contains(normalizedTag)) {
        await widget.repository.saveAsset(
          asset.copyWith(tags: [...asset.tags, normalizedTag]),
        );
      }
    }
    if (mounted) {
      await _reload();
      _exitSelectionMode();
    }
  }

  Future<void> _batchTogglePinned() async {
    final selectedAssets = _assets
        .where((asset) => _selectedAssetIds.contains(asset.id))
        .toList();
    final shouldPin = !selectedAssets.every((asset) => asset.isPinned);
    for (final asset in selectedAssets) {
      await widget.repository.saveAsset(asset.copyWith(isPinned: shouldPin));
    }
    if (mounted) {
      await _reload();
      _exitSelectionMode();
    }
  }

  Future<void> _batchDelete() async {
    final count = _selectedAssetIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除资产'),
        content: Text('确定删除选中的 $count 项资产吗？相关关联也会一并移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final ids = {..._selectedAssetIds};
    for (final id in ids) {
      await widget.repository.deleteAsset(id);
    }
    if (mounted) {
      await _reload();
      _exitSelectionMode();
    }
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedAssetIds.clear();
    });
  }

  Map<String, int> get _relationCounts {
    final counts = <String, int>{};
    for (final relation in _relations) {
      counts[relation.fromAssetId] = (counts[relation.fromAssetId] ?? 0) + 1;
      counts[relation.toAssetId] = (counts[relation.toAssetId] ?? 0) + 1;
    }
    return counts;
  }

  Set<String> get _allTags => _assets.expand((asset) => asset.tags).toSet();

  @override
  Widget build(BuildContext context) {
    final counts = _relationCounts;
    final filtered = _filter.apply(_assets, _relations);
    final pinned = filtered.where((asset) => asset.isPinned).toList();
    final others = filtered.where((asset) => !asset.isPinned).toList();
    final dueSoonCount = _assets
        .where(
          (asset) =>
              AssetFilter.dueDateOf(asset) != null &&
              AssetFilter.dueDateOf(asset)!.isAfter(DateTime.now()) &&
              AssetFilter.dueDateOf(asset)!
                  .isBefore(DateTime.now().add(const Duration(days: 30))),
        )
        .length;
    final tasks = _buildTasks(filtered, counts);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectionMode ? '已选 ${_selectedAssetIds.length} 项' : '保险库',
        ),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              tooltip: '退出多选',
              onPressed: _exitSelectionMode,
              icon: const Icon(Icons.close),
            ),
            IconButton(
              tooltip: '批量打标签',
              onPressed: _batchAddTag,
              icon: const Icon(Icons.sell_outlined),
            ),
            IconButton(
              tooltip:
                  _assets
                      .where((asset) => _selectedAssetIds.contains(asset.id))
                      .every((asset) => asset.isPinned)
                  ? '批量取消置顶'
                  : '批量置顶',
              onPressed: _batchTogglePinned,
              icon: const Icon(Icons.star),
            ),
            IconButton(
              tooltip: '批量删除',
              onPressed: _batchDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ] else if (!_selectionMode)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_assets.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.dayTextSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.sheet,
        elevation: 0,
        focusElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _SearchHeader(
            controller: _searchController,
            filter: _filter,
            resultCount: filtered.length,
            dueSoonCount: dueSoonCount,
            onOpenFilter: () => _openFilterSheet(),
            onClear: () {
              _searchController.clear();
              setState(() => _filter = const AssetFilter());
            },
            onQuickType: (type) => setState(
              () => _filter = _filter.copyWith(
                types: _filter.types.contains(type) ? const {} : {type},
                statuses: _filter.statuses
                    .where((status) => status != AssetStatusFilter.pinned)
                    .toSet(),
              ),
            ),
            onQuickPinned: () => setState(
              () => _filter = _filter.copyWith(
                types: const {},
                statuses: _filter.statuses.contains(AssetStatusFilter.pinned)
                    ? _filter.statuses
                          .where((status) => status != AssetStatusFilter.pinned)
                          .toSet()
                    : {..._filter.statuses, AssetStatusFilter.pinned},
              ),
            ),
            onRemoveQuery: () {
              _searchController.clear();
            },
            onRemoveType: (type) => setState(
              () => _filter = _filter.copyWith(
                types: _filter.types.where((item) => item != type).toSet(),
              ),
            ),
            onRemoveIncludedTag: (tag) => setState(
              () => _filter = _filter.copyWith(
                includedTags: _filter.includedTags
                    .where((item) => item != tag)
                    .toSet(),
              ),
            ),
            onRemoveExcludedTag: (tag) => setState(
              () => _filter = _filter.copyWith(
                excludedTags: _filter.excludedTags
                    .where((item) => item != tag)
                    .toSet(),
              ),
            ),
            onRemoveStatus: (status) => setState(
              () => _filter = _filter.copyWith(
                statuses: _filter.statuses
                    .where((item) => item != status)
                    .toSet(),
              ),
            ),
          ),
          if (_loading)
            const Expanded(child: _LoadingAssets())
          else if (_error != null)
            Expanded(
              child: EmptyState(
                icon: Icons.cloud_off_outlined,
                title: '读取资产失败',
                actionLabel: '重试',
                onAction: _reload,
              ),
            )
          else
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyResult()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 96),
                      children: [
                        ...[
                          const _SectionTitle('哨所'),
                          if (tasks.isEmpty)
                            const _GoodWatchtowerRow()
                          else
                            for (final task in tasks)
                              _TaskCard(
                                task: task,
                                onView: () => _openDetail(task.asset.id),
                              ),
                          const SizedBox(height: 24),
                        ],
                        if (pinned.isNotEmpty) ...[
                          const _SectionTitle('置顶'),
                          for (final asset in pinned)
                            _AssetRow(
                              asset: asset,
                              relationCount: counts[asset.id] ?? 0,
                              selectionMode: _selectionMode,
                              selected: _selectedAssetIds.contains(asset.id),
                              onToggleSelected: () => _toggleSelection(asset),
                              onTap: () => _selectionMode
                                  ? _toggleSelection(asset)
                                  : _openDetail(asset.id),
                              onTogglePinned: () => _togglePinned(asset),
                            ),
                          const SizedBox(height: 20),
                        ],
                        if (others.isNotEmpty) ...[
                          _SectionTitle(pinned.isEmpty ? '全部资产' : '更多资产'),
                          for (final asset in others)
                            _AssetRow(
                              asset: asset,
                              relationCount: counts[asset.id] ?? 0,
                              selectionMode: _selectionMode,
                              selected: _selectedAssetIds.contains(asset.id),
                              onToggleSelected: () => _toggleSelection(asset),
                              onTap: () => _selectionMode
                                  ? _toggleSelection(asset)
                                  : _openDetail(asset.id),
                              onTogglePinned: () => _togglePinned(asset),
                            ),
                        ],
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<AssetFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(
        initialFilter: _filter,
        assets: _assets,
        relations: _relations,
        allTags: _allTags,
      ),
    );
    if (result != null && mounted) {
      _searchController.text = result.query;
      setState(() => _filter = result);
    }
  }

  Widget _buildEmptyResult() {
    if (_assets.isEmpty) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: '还没有资产',
        actionLabel: '新增第一条资产',
        onAction: () => _openEditor(),
      );
    }
    if (_filter.isEmpty) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: '暂无资产',
        actionLabel: '新增资产',
        onAction: () => _openEditor(),
      );
    }
    return EmptyState(
      icon: Icons.filter_alt_off_outlined,
      title: '没有匹配的资产',
      actionLabel: '清除筛选',
      onAction: () {
        _searchController.clear();
        setState(() => _filter = const AssetFilter());
      },
    );
  }

  List<_TaskData> _buildTasks(
    List<Asset> assets,
    Map<String, int> relationCounts,
  ) {
    final tasks = <_TaskData>[];
    final now = DateTime.now();
    final titleCounts = <String, int>{};
    for (final asset in assets) {
      titleCounts[asset.title] = (titleCounts[asset.title] ?? 0) + 1;
    }
    for (final asset in assets) {
      final dueDate = AssetFilter.dueDateOf(asset);
      if (dueDate != null && dueDate.isBefore(now)) {
        tasks.add(
          _TaskData(
            asset: asset,
            icon: Icons.event_busy_outlined,
            title: asset.title,
            message: '已逾期',
            actionLabel: '处理',
            priority: 0,
          ),
        );
      }
      if (dueDate != null &&
          dueDate.isAfter(now) &&
          dueDate.isBefore(now.add(const Duration(days: 7)))) {
        final amount = asset.fields['amount']?.toString();
        tasks.add(
          _TaskData(
            asset: asset,
            icon: Icons.event_available,
            title: asset.title,
            message:
                '${DateFormat('M月d日').format(dueDate)}前扣款'
                '${amount == null ? '' : ' · $amount'}',
            actionLabel: '查看',
            priority: 0,
          ),
        );
      }
      if ((relationCounts[asset.id] ?? 0) == 0) {
        tasks.add(
          _TaskData(
            asset: asset,
            icon: Icons.link_off_outlined,
            title: asset.title,
            message: '还没有关联资产',
            actionLabel: '关联',
            priority: 4,
          ),
        );
      }
      if (asset.encryptedSecret == null) {
        tasks.add(
          _TaskData(
            asset: asset,
            icon: Icons.enhanced_encryption_outlined,
            title: asset.title,
            message: '敏感内容为空',
            actionLabel: '补录',
            priority: 2,
          ),
        );
      }
      if ((titleCounts[asset.title] ?? 0) > 1) {
        tasks.add(
          _TaskData(
            asset: asset,
            icon: Icons.copy_all_outlined,
            title: asset.title,
            message: '标题与其他资产重复',
            actionLabel: '整理',
            priority: 3,
          ),
        );
      }
    }
    tasks.sort((a, b) => a.priority.compareTo(b.priority));
    return tasks.take(3).toList();
  }
}

class _AssetTypeSheet extends StatelessWidget {
  const _AssetTypeSheet();

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('选择资产类型', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '不同类型会展示对应字段模板',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.dayTextSecondary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 324,
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: .92,
              children: [
                for (final type in AssetType.values)
                  _TypeOptionCard(
                    key: Key('asset-type-${type.name}'),
                    type: type,
                    onTap: () => Navigator.of(context).pop(type),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _TypeOptionCard extends StatelessWidget {
  const _TypeOptionCard({super.key, required this.type, required this.onTap});

  final AssetType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.paper,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.rule),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AssetTypeBadge(type: type, size: 28),
            const SizedBox(height: 6),
            Text(
              type.label,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 3),
            Text(
              _typeHint(type),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.dayTextSecondary,
                fontSize: 10,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _typeHint(AssetType type) => switch (type) {
  AssetType.subscription => '套餐 / 金额 / 扣款',
  AssetType.apiKey => '前缀 / 环境 / 到期',
  AssetType.password => '用户名 / 网址',
  AssetType.email => '地址 / 恢复邮箱',
  AssetType.device => '型号 / 系统 / 保修',
  AssetType.item => '归属 / 位置',
  AssetType.bill => '金额 / 日期 / 支付',
  AssetType.bankCard => '银行 / 后四位',
  AssetType.other => '自定义字段',
};

class _BatchTagSheet extends StatefulWidget {
  const _BatchTagSheet();

  @override
  State<_BatchTagSheet> createState() => _BatchTagSheetState();
}

class _BatchTagSheetState extends State<_BatchTagSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final tag = _controller.text.split(RegExp(r'[,，\n]')).first.trim();
    Navigator.of(context).pop(tag);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      4,
      20,
      20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('批量打标签', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            labelText: '标签',
            helperText: '标签会追加到所有选中资产',
            prefixIcon: Icon(Icons.sell_outlined),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _submit, child: const Text('添加标签')),
      ],
    ),
  );
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.controller,
    required this.filter,
    required this.resultCount,
    required this.dueSoonCount,
    required this.onOpenFilter,
    required this.onClear,
    required this.onQuickType,
    required this.onQuickPinned,
    required this.onRemoveQuery,
    required this.onRemoveType,
    required this.onRemoveIncludedTag,
    required this.onRemoveExcludedTag,
    required this.onRemoveStatus,
  });

  final TextEditingController controller;
  final AssetFilter filter;
  final int resultCount;
  final int dueSoonCount;
  final VoidCallback onOpenFilter;
  final VoidCallback onClear;
  final ValueChanged<AssetType> onQuickType;
  final VoidCallback onQuickPinned;
  final VoidCallback onRemoveQuery;
  final ValueChanged<AssetType> onRemoveType;
  final ValueChanged<String> onRemoveIncludedTag;
  final ValueChanged<String> onRemoveExcludedTag;
  final ValueChanged<AssetStatusFilter> onRemoveStatus;

  @override
  Widget build(BuildContext context) {
    final quickTypes = [
      AssetType.password,
      AssetType.apiKey,
      AssetType.subscription,
    ];
    return Material(
      color: AppColors.dayBackground,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: '搜索标题、标签、字段、关联',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: controller.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => controller.clear(),
                            ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _FilterButton(
                  count: filter.conditionCount,
                  onPressed: onOpenFilter,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuickChip(
                  label: '全部',
                  selected: filter.isEmpty,
                  onTap: onClear,
                ),
                _QuickChip(
                  label: '置顶',
                  selected: filter.statuses.contains(AssetStatusFilter.pinned),
                  onTap: onQuickPinned,
                ),
                for (final type in quickTypes)
                  _QuickChip(
                    label: type.label,
                    selected: filter.types.contains(type),
                    onTap: () => onQuickType(type),
                  ),
                _QuickChip(label: '更多', selected: false, onTap: onOpenFilter),
              ],
            ),
            if (!filter.isEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (filter.query.trim().isNotEmpty)
                    InputChip(
                      avatar: const Icon(Icons.search, size: 14),
                      label: Text(filter.query.trim()),
                      onDeleted: onRemoveQuery,
                      deleteIcon: const Tooltip(
                        message: '删除搜索条件',
                        child: Icon(Icons.clear, size: 18),
                      ),
                    ),
                  for (final type in filter.types)
                    InputChip(
                      label: Text(type.label),
                      onDeleted: () => onRemoveType(type),
                    ),
                  for (final tag in filter.includedTags)
                    InputChip(
                      avatar: const Icon(Icons.sell_outlined, size: 14),
                      label: Text(tag),
                      onDeleted: () => onRemoveIncludedTag(tag),
                    ),
                  for (final tag in filter.excludedTags)
                    InputChip(
                      avatar: const Icon(Icons.block, size: 14),
                      label: Text(tag),
                      onDeleted: () => onRemoveExcludedTag(tag),
                    ),
                  for (final status in filter.statuses)
                    InputChip(
                      label: Text(status.label),
                      onDeleted: () => onRemoveStatus(status),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '当前 $resultCount 项 · 30 天临期 $dueSoonCount 项',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.dayTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: const Icon(Icons.tune),
    label: Text(count == 0 ? '筛选' : '筛选 $count'),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(86, 48),
      maximumSize: const Size(116, 48),
    ),
  );
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
    showCheckmark: false,
    side: BorderSide(color: selected ? AppColors.ink : AppColors.rule),
    labelPadding: const EdgeInsets.symmetric(horizontal: 2),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.initialFilter,
    required this.assets,
    required this.relations,
    required this.allTags,
  });

  final AssetFilter initialFilter;
  final List<Asset> assets;
  final List<Relation> relations;
  final Set<String> allTags;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late AssetFilter _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialFilter;
  }

  void _toggleType(AssetType type) {
    final types = {..._draft.types};
    if (!types.remove(type)) {
      types.add(type);
    }
    setState(() => _draft = _draft.copyWith(types: types));
  }

  void _toggleIncludedTag(String tag) {
    final included = {..._draft.includedTags};
    final excluded = {..._draft.excludedTags}..remove(tag);
    if (!included.remove(tag)) {
      included.add(tag);
    }
    setState(
      () => _draft = _draft.copyWith(
        includedTags: included,
        excludedTags: excluded,
      ),
    );
  }

  void _toggleExcludedTag(String tag) {
    final included = {..._draft.includedTags}..remove(tag);
    final excluded = {..._draft.excludedTags};
    if (!excluded.remove(tag)) {
      excluded.add(tag);
    }
    setState(
      () => _draft = _draft.copyWith(
        includedTags: included,
        excludedTags: excluded,
      ),
    );
  }

  void _toggleStatus(AssetStatusFilter status) {
    final statuses = {..._draft.statuses};
    if (!statuses.remove(status)) {
      statuses.add(status);
    }
    setState(() => _draft = _draft.copyWith(statuses: statuses));
  }

  int _count(AssetType type) =>
      widget.assets.where((asset) => asset.type == type).length;

  int _tagCount(String tag) =>
      widget.assets.where((asset) => asset.tags.contains(tag)).length;

  @override
  Widget build(BuildContext context) {
    final resultCount = _draft.apply(widget.assets, widget.relations).length;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .86,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '筛选资产',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(const AssetFilter()),
                    child: const Text('重置'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const _SheetSectionTitle('类型'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final type in AssetType.values)
                        FilterChip(
                          label: Text('${type.label} · ${_count(type)}'),
                          selected: _draft.types.contains(type),
                          side: BorderSide(
                            color: _draft.types.contains(type)
                                ? AppColors.ink
                                : AppColors.rule,
                          ),
                          onSelected: (_) => _toggleType(type),
                        ),
                    ],
                  ),
                  if (widget.allTags.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    const _SheetSectionTitle('包含标签'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tag in widget.allTags)
                          FilterChip(
                            label: Text('$tag · ${_tagCount(tag)}'),
                            selected: _draft.includedTags.contains(tag),
                            side: BorderSide(
                              color: _draft.includedTags.contains(tag)
                                  ? AppColors.ink
                                  : AppColors.rule,
                            ),
                            onSelected: (_) => _toggleIncludedTag(tag),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const _SheetSectionTitle('排除标签'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tag in widget.allTags)
                          FilterChip(
                            label: Text(tag),
                            selected: _draft.excludedTags.contains(tag),
                            side: BorderSide(
                              color: _draft.excludedTags.contains(tag)
                                  ? AppColors.ink
                                  : AppColors.rule,
                            ),
                            onSelected: (_) => _toggleExcludedTag(tag),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 22),
                  const _SheetSectionTitle('状态'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final status in AssetStatusFilter.values)
                        FilterChip(
                          label: Text(status.label),
                          selected: _draft.statuses.contains(status),
                          side: BorderSide(
                            color: _draft.statuses.contains(status)
                                ? AppColors.ink
                                : AppColors.rule,
                          ),
                          onSelected: (_) => _toggleStatus(status),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const _SheetSectionTitle('排序'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in AssetSortOption.values)
                        ChoiceChip(
                          label: Text(option.label),
                          selected: _draft.sort == option,
                          side: BorderSide(
                            color: _draft.sort == option
                                ? AppColors.ink
                                : AppColors.rule,
                          ),
                          onSelected: (_) => setState(
                            () => _draft = _draft.copyWith(sort: option),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '当前 $resultCount 项',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: AppColors.dayTextSecondary),
                    ),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_draft),
                    child: const Text('应用筛选'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetSectionTitle extends StatelessWidget {
  const _SheetSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w600),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 10),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: AppColors.dayTextSecondary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _TaskData {
  const _TaskData({
    required this.asset,
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    this.priority = 0,
  });

  final Asset asset;
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final int priority;
}

class _GoodWatchtowerRow extends StatelessWidget {
  const _GoodWatchtowerRow();

  @override
  Widget build(BuildContext context) => Container(
    height: 56,
    alignment: Alignment.centerLeft,
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.rule)),
    ),
    child: const Row(
      children: [
        Icon(Icons.verified_outlined, size: 20, color: AppColors.ok),
        SizedBox(width: 10),
        Expanded(child: Text('保险库状态良好')),
      ],
    ),
  );
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.onView});

  final _TaskData task;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.zero,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        overlayColor: WidgetStatePropertyAll(
          AppColors.paper2.withValues(alpha: 1),
        ),
        onTap: onView,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.rule)),
          ),
          child: Row(
            children: [
              Icon(task.icon, color: AppColors.ink2, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.dayTextSecondary),
                    ),
                  ],
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(64, 44),
                ),
                onPressed: onView,
                child: Text(task.actionLabel),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AssetRow extends StatelessWidget {
  const _AssetRow({
    required this.asset,
    required this.relationCount,
    required this.selectionMode,
    required this.selected,
    required this.onToggleSelected,
    required this.onTap,
    required this.onTogglePinned,
  });

  final Asset asset;
  final int relationCount;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onToggleSelected;
  final VoidCallback onTap;
  final VoidCallback onTogglePinned;

  @override
  Widget build(BuildContext context) {
    final dueDate = AssetFilter.dueDateOf(asset);
    final amount =
        (asset.type == AssetType.bill || asset.type == AssetType.subscription)
        ? asset.fields['amount']?.toString()
        : null;
    final meta = [
      asset.type.label,
      if (asset.tags.isNotEmpty) asset.tags.take(2).join(' / '),
      if (dueDate != null) DateFormat('M月d日').format(dueDate),
      '更新 ${DateFormat('M月d日').format(asset.updatedAt)}',
    ].where((item) => item.trim().isNotEmpty).join(' · ');

    return Material(
      color: selected ? AppColors.paper2 : Colors.transparent,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          overlayColor: WidgetStatePropertyAll(
            AppColors.paper2.withValues(alpha: 1),
          ),
          onTap: onTap,
          onLongPress: onToggleSelected,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: asset.isPinned ? AppColors.ink : Colors.transparent,
                  width: 2,
                ),
                bottom: const BorderSide(color: AppColors.rule),
              ),
            ),
            child: Row(
              children: [
                if (selectionMode) ...[
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: selected,
                      onChanged: (_) => onToggleSelected(),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                AssetTypeBadge(type: asset.type, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.dayTextSecondary),
                      ),
                    ],
                  ),
                ),
                if (amount != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    amount,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ] else if (!selectionMode)
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.ink3,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingAssets extends StatelessWidget {
  const _LoadingAssets();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: List.generate(6, (_) => const _SkeletonRow()),
  );
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      height: 72,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}
