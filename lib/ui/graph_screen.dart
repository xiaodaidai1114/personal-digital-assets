import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/asset_repository.dart';
import '../domain/asset.dart';
import '../domain/relation.dart';
import '../theme/app_theme.dart';
import '../vault/vault_controller.dart';
import 'asset_detail_screen.dart';
import 'asset_edit_screen.dart';
import 'graph/graph_view.dart';
import 'widgets/asset_type_badge.dart';
import 'widgets/empty_state.dart';

class GraphScreen extends StatefulWidget {
  const GraphScreen({
    super.key,
    required this.controller,
    required this.repository,
    this.initialFocusId,
    this.showBack = false,
  });

  final VaultController controller;
  final AssetRepository repository;
  final String? initialFocusId;
  final bool showBack;

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Asset> _assets = const [];
  List<Relation> _relations = const [];
  Set<AssetType> _selectedTypes = const {};
  Set<RelationType> _selectedRelationTypes = const {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
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
      final focusedAssets = assets.where(
        (asset) => asset.id == widget.initialFocusId,
      );
      if (focusedAssets.isNotEmpty) {
        _searchController.text = focusedAssets.first.title;
      }
    } on Exception {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '图谱读取失败';
      });
    }
  }

  int _relationCountOf(String assetId) => _relations
      .where(
        (relation) =>
            relation.fromAssetId == assetId || relation.toAssetId == assetId,
      )
      .length;

  bool _matches(Asset asset, String query) {
    final keyword = query.trim().toLowerCase();
    if (keyword.isEmpty) {
      return true;
    }
    final text = [
      asset.title,
      asset.type.label,
      ...asset.tags,
      ...asset.fields.values.map((value) => value.toString()),
    ].join('\n').toLowerCase();
    return keyword.split(RegExp(r'\s+')).every(text.contains);
  }

  _GraphSelection get _selection {
    final query = _searchController.text;
    var nodes = _assets
        .where(
          _selectedTypes.isEmpty
              ? (_) => true
              : (asset) => _selectedTypes.contains(asset.type),
        )
        .toList();
    final nodeIds = nodes.map((asset) => asset.id).toSet();
    var focusIds = <String>{};
    if (query.trim().isNotEmpty) {
      final matchingIds = nodes
          .where((asset) => _matches(asset, query))
          .map((asset) => asset.id)
          .toSet();
      final neighborIds = <String>{...matchingIds};
      for (final relation in _relations) {
        if (matchingIds.contains(relation.fromAssetId)) {
          neighborIds.add(relation.toAssetId);
        }
        if (matchingIds.contains(relation.toAssetId)) {
          neighborIds.add(relation.fromAssetId);
        }
      }
      focusIds = neighborIds.intersection(nodeIds);
    }
    final edges = _relations
        .where(
          (relation) =>
              nodeIds.contains(relation.fromAssetId) &&
              nodeIds.contains(relation.toAssetId) &&
              (_selectedRelationTypes.isEmpty ||
                  _selectedRelationTypes.contains(relation.type)),
        )
        .toList();
    return _GraphSelection(nodes, edges, focusIds);
  }

  int get _filterCount => [
    _selectedTypes.isNotEmpty,
    _selectedRelationTypes.isNotEmpty,
  ].where((active) => active).length;

  void _focusAsset(Asset asset) {
    _searchController.text = asset.title;
    setState(() {});
  }

  void _openNode(Asset asset) {
    final relationCount = _relationCountOf(asset.id);
    final metaText =
        '${asset.type.label} · $relationCount 关联${asset.tags.isEmpty ? '' : ' · ${asset.tags.take(2).join('/')}'}';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.nightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (sheetContext) => Theme(
        data: AppTheme.night(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AssetTypeBadge(type: asset.type, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            asset.title,
                            style: Theme.of(sheetContext).textTheme.titleLarge,
                          ),
                          Text(
                            metaText,
                            style: Theme.of(sheetContext).textTheme.bodySmall
                                ?.copyWith(color: AppColors.nightTextSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.nightTextPrimary,
                          side: BorderSide(
                            color: AppColors.nightTextPrimary.withValues(
                              alpha: .38,
                            ),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _focusAsset(asset);
                        },
                        child: const Text('聚焦一跳'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.nightTextPrimary,
                          foregroundColor: AppColors.nightBackground,
                        ),
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AssetDetailScreen(
                                controller: widget.controller,
                                repository: widget.repository,
                                assetId: asset.id,
                              ),
                            ),
                          );
                        },
                        child: const Text('查看详情'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<_GraphFilterDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.nightSurface,
      builder: (sheetContext) => Theme(
        data: AppTheme.night(),
        child: _GraphFilterSheet(
          selectedTypes: _selectedTypes,
          selectedRelationTypes: _selectedRelationTypes,
          assets: _assets,
          relations: _relations,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedTypes = result.types;
        _selectedRelationTypes = result.relationTypes;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    // 星图整页夜墨（DESIGN.md）：系统状态栏/导航栏随之切夜色、启用浅色图标，
    // 避免夜墨画布上顶着纸色系统栏与深色图标；离开星图后由 AppRoot 的
    // 日间注解恢复纸底墨图标（更近的注解优先生效，此处在最上层）。
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: AppColors.nightBackground,
      systemNavigationBarColor: AppColors.nightSurface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
    child: Theme(
      data: AppTheme.night(),
      child: Scaffold(
        body: Container(
          color: AppColors.nightBackground,
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GraphSearchHeader(
                  onBack: widget.showBack
                      ? () => Navigator.of(context).pop()
                      : null,
                  controller: _searchController,
                  filterCount: _filterCount,
                  nodeCount: _selection.nodes.length,
                  relationCount: _selection.edges.length,
                  onChanged: () => setState(() {}),
                  onOpenFilter: _openFilterSheet,
                  onClear: () {
                    _searchController.clear();
                    setState(() {
                      _selectedTypes = const {};
                      _selectedRelationTypes = const {};
                    });
                  },
                ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: _error!,
        actionLabel: '重试',
        onAction: () {
          setState(() => _loading = true);
          _reload();
        },
        dark: true,
      );
    }
    if (_assets.isEmpty) {
      return EmptyState(
        icon: Icons.hub_outlined,
        title: '还没有资产',
        actionLabel: '去新增',
        onAction: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AssetEditScreen(
              controller: widget.controller,
              repository: widget.repository,
            ),
          ),
        ),
        dark: true,
      );
    }

    final selection = _selection;
    if (selection.nodes.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: '没有匹配的节点',
        actionLabel: '清除条件',
        onAction: () {
          _searchController.clear();
          setState(() {
            _selectedTypes = const {};
            _selectedRelationTypes = const {};
          });
        },
        dark: true,
      );
    }
    return Stack(
      children: [
        buildGraphView(
          assets: selection.nodes,
          relations: selection.edges,
          focusIds: selection.focusIds,
          onOpenNode: _openNode,
        ),
        if (selection.edges.isEmpty)
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.nightSurface.withValues(alpha: .86),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '当前筛选没有关系；清空关系类型可查看全部资产网络。',
                style: TextStyle(color: AppColors.nightTextSecondary),
              ),
            ),
          ),
      ],
    );
  }
}

class _GraphSelection {
  const _GraphSelection(this.nodes, this.edges, this.focusIds);

  final List<Asset> nodes;
  final List<Relation> edges;
  final Set<String> focusIds;
}

class _GraphFilterDraft {
  const _GraphFilterDraft(this.types, this.relationTypes);

  final Set<AssetType> types;
  final Set<RelationType> relationTypes;
}

class _GraphSearchHeader extends StatelessWidget {
  const _GraphSearchHeader({
    this.onBack,
    required this.controller,
    required this.filterCount,
    required this.nodeCount,
    required this.relationCount,
    required this.onChanged,
    required this.onOpenFilter,
    required this.onClear,
  });

  final VoidCallback? onBack;
  final TextEditingController controller;
  final int filterCount;
  final int nodeCount;
  final int relationCount;
  final VoidCallback onChanged;
  final VoidCallback onOpenFilter;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              if (onBack != null) ...[
                Tooltip(
                  message: '返回详情',
                  child: IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                    color: AppColors.nightTextPrimary,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: (_) => onChanged(),
                  style: const TextStyle(color: AppColors.nightTextPrimary),
                  decoration: InputDecoration(
                    hintText: '搜索节点，自动保留一跳邻域',
                    hintStyle: const TextStyle(
                      color: AppColors.nightTextSecondary,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.nightTextSecondary,
                    ),
                    suffixIcon: controller.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清除节点搜索',
                            icon: const Icon(Icons.close),
                            color: AppColors.nightTextSecondary,
                            onPressed: () {
                              controller.clear();
                              onChanged();
                            },
                          ),
                    filled: true,
                    fillColor: AppColors.nightSurface.withValues(alpha: .78),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: onOpenFilter,
                icon: const Icon(Icons.tune),
                label: Text(filterCount == 0 ? '筛选' : '$filterCount'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.nightSurface.withValues(
                    alpha: .86,
                  ),
                  foregroundColor: AppColors.nightTextPrimary,
                  side: BorderSide(
                    color: AppColors.nightTextPrimary.withValues(alpha: .16),
                  ),
                  minimumSize: const Size(52, 48),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$nodeCount 个节点 · $relationCount 条关系',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.nightTextSecondary),
                ),
              ),
              TextButton(onPressed: onClear, child: const Text('清空')),
            ],
          ),
        ],
      ),
    );
  }
}

class _GraphFilterSheet extends StatefulWidget {
  const _GraphFilterSheet({
    required this.selectedTypes,
    required this.selectedRelationTypes,
    required this.assets,
    required this.relations,
  });

  final Set<AssetType> selectedTypes;
  final Set<RelationType> selectedRelationTypes;
  final List<Asset> assets;
  final List<Relation> relations;

  @override
  State<_GraphFilterSheet> createState() => _GraphFilterSheetState();
}

class _GraphFilterSheetState extends State<_GraphFilterSheet> {
  late Set<AssetType> _types;
  late Set<RelationType> _relationTypes;

  @override
  void initState() {
    super.initState();
    _types = {...widget.selectedTypes};
    _relationTypes = {...widget.selectedRelationTypes};
  }

  int _assetCount(AssetType type) =>
      widget.assets.where((asset) => asset.type == type).length;

  int _relationCount(RelationType type) =>
      widget.relations.where((relation) => relation.type == type).length;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .78,
    child: SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '图谱筛选',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context)
                          .pop(const _GraphFilterDraft({}, {})),
                  child: const Text('重置'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                const _GraphSheetTitle('资产类型'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final type in AssetType.values)
                      FilterChip(
                        label: Text('${type.label} · ${_assetCount(type)}'),
                        selected: _types.contains(type),
                        onSelected: (_) => setState(
                          () => _types.contains(type)
                              ? _types.remove(type)
                              : _types.add(type),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                const _GraphSheetTitle('关系类型'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final type in RelationType.values)
                      FilterChip(
                        label: Text('${type.label} · ${_relationCount(type)}'),
                        selected: _relationTypes.contains(type),
                        onSelected: (_) => setState(
                          () => _relationTypes.contains(type)
                              ? _relationTypes.remove(type)
                              : _relationTypes.add(type),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    Navigator.of(context)
                        .pop(_GraphFilterDraft(_types, _relationTypes)),
                child: const Text('应用筛选'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _GraphSheetTitle extends StatelessWidget {
  const _GraphSheetTitle(this.title);

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
